import concurrent.futures
import json
import multiprocessing
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import flake
from protocol import ToolError


def command_host(argv):
    target = next(arg for arg in argv if arg.startswith(".#nixosConfigurations."))
    return target.split(".")[2]


def invoke_in_process(state, start, active, peak, results):
    flake.STATE = Path(state)

    def run_split(argv, timeout):
        with active.get_lock():
            active.value += 1
            peak.value = max(peak.value, active.value)
        threading.Event().wait(0.05)
        with active.get_lock():
            active.value -= 1
        return 0, command_host(argv), ""

    try:
        with patch.object(flake, "run_split", side_effect=run_split):
            start.wait(timeout=5)
            text, failed = flake.tool_eval_all({"hosts": ["pc", "server"]}, None, None)
        results.put((json.loads(text), failed))
    except Exception as error:
        results.put((str(error), True))


class EvalAllTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(dir=Path(__file__).parent)
        self.addCleanup(temporary.cleanup)
        self.state = Path(temporary.name)
        state_patch = patch.object(flake, "STATE", self.state)
        state_patch.start()
        self.addCleanup(state_patch.stop)

    def evaluate(self, args, runner):
        with patch.object(flake, "run_split", side_effect=runner):
            text, failed = flake.tool_eval_all(args, None, None)
        return json.loads(text), failed

    def test_preserves_requested_order_duplicates_and_errors(self):
        launched = []

        def run_split(argv, timeout):
            host = command_host(argv)
            launched.append(host)
            if host == "server":
                return 1, "", "error: attribute 'missing' missing"
            return 0, f"{host}\n", ""

        result, failed = self.evaluate({"hosts": ["pc", "server", "pc"]}, run_split)
        self.assertEqual(launched, ["pc", "server", "pc"])
        self.assertEqual(result, {
            "attr": "config.system.build.toplevel.drvPath",
            "checked": 3,
            "broken": ["server"],
            "next": "rebuild action=switch",
            "hosts": [
                {"host": "pc", "ok": True, "value": "pc"},
                {"host": "server", "ok": False, "error": "error: attribute 'missing' missing"},
                {"host": "pc", "ok": True, "value": "pc"},
            ],
        })
        self.assertTrue(failed)

    def test_concurrent_calls_and_retries_share_one_evaluator_slot(self):
        active = 0
        peak = 0
        counter_lock = threading.Lock()
        start = threading.Barrier(2)

        def run_split(argv, timeout):
            nonlocal active, peak
            with counter_lock:
                active += 1
                peak = max(peak, active)
            threading.Event().wait(0.02)
            with counter_lock:
                active -= 1
            return 1, "", "error: database is locked"

        def invoke():
            start.wait(timeout=5)
            return flake.tool_eval_all({}, None, None)

        with patch.object(flake, "run_split", side_effect=run_split):
            with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
                futures = [pool.submit(invoke) for _ in range(2)]
                results = [future.result(timeout=5) for future in futures]
        self.assertEqual(peak, 1)
        for text, failed in results:
            self.assertTrue(failed)
            rows = json.loads(text)["hosts"]
            self.assertEqual([row["host"] for row in rows], ["pc", "fx516", "notebook", "server"])
            self.assertTrue(all(row.get("attempts") == 2 for row in rows))

    def test_separate_servers_share_one_evaluator_slot(self):
        context = multiprocessing.get_context("fork")
        start = context.Barrier(2)
        active = context.Value("i", 0)
        peak = context.Value("i", 0)
        results = context.Queue()
        processes = [
            context.Process(target=invoke_in_process, args=(str(self.state), start, active, peak, results))
            for _ in range(2)
        ]
        try:
            for process in processes:
                process.start()
            received = [results.get(timeout=5) for _ in processes]
            for process in processes:
                process.join(timeout=5)
                self.assertEqual(process.exitcode, 0)
        finally:
            for process in processes:
                if process.is_alive():
                    process.terminate()
                if process.pid is not None:
                    process.join(timeout=5)
            results.close()
            results.join_thread()
        self.assertEqual(peak.value, 1)
        for result, failed in received:
            self.assertFalse(failed, result)
            self.assertEqual(result["hosts"], [
                {"host": "pc", "ok": True, "value": "pc"},
                {"host": "server", "ok": True, "value": "server"},
            ])

    def test_probes_enter_bounded_user_scope(self):
        commands = []

        def run_split(argv, timeout):
            commands.append((argv, timeout))
            return 0, '"package"\n', ""

        result, failed = self.evaluate({"hosts": ["server"], "attr": ".services.nginx.package", "raw": False}, run_split)
        self.assertFalse(failed)
        self.assertEqual(result["hosts"], [{"host": "server", "ok": True, "value": '"package"'}])
        argv, timeout = commands[0]
        self.assertEqual(argv[:4], ["systemd-run", "--user", "--scope", "--quiet"])
        self.assertIn("--slice=nix-control-eval.slice", argv)
        for property_value in ("MemoryHigh=6G", "MemoryMax=8G", "MemorySwapMax=0"):
            self.assertIn(property_value, argv)
        self.assertEqual(argv[argv.index("--") + 1:], [
            "nix", "eval", "--impure", ".#nixosConfigurations.server.config.services.nginx.package", "--json",
        ])
        self.assertEqual(timeout, 1800)

    def test_transient_failure_retries_once_using_full_stderr(self):
        outcomes = iter([
            (1, "", "error: unexpected end-of-file\n" + "warning: detail\n" * 13),
            (0, "recovered\n", ""),
        ])
        result, failed = self.evaluate({"hosts": ["pc"]}, lambda argv, timeout: next(outcomes))
        self.assertFalse(failed)
        self.assertEqual(result["hosts"], [{"host": "pc", "ok": True, "value": "recovered", "attempts": 2}])

    def test_persistent_transient_failure_has_two_attempts(self):
        launched = []

        def run_split(argv, timeout):
            launched.append(command_host(argv))
            return 1, "", "error: database is locked"

        result, failed = self.evaluate({"hosts": ["pc"]}, run_split)
        self.assertTrue(failed)
        self.assertEqual(launched, ["pc", "pc"])
        self.assertEqual(result["hosts"], [{"host": "pc", "ok": False, "error": "error: database is locked", "attempts": 2}])

    def test_killed_or_oom_evaluators_never_retry_transient_text(self):
        for code, error in [
            (-9, "error: interrupted by the user"),
            (137, "error: unexpected end-of-file"),
            (1, "error: out of memory\nerror: connection reset"),
            (1, "Result: oom-kill\nerror: timed out"),
            (1, "error: out of memory\n" + "warning: detail\n" * 13 + "error: unexpected end-of-file"),
        ]:
            with self.subTest(code=code, error=error):
                launched = []

                def run_split(argv, timeout):
                    launched.append(command_host(argv))
                    return code, "", error

                result, failed = self.evaluate({"hosts": ["pc", "server"]}, run_split)
                self.assertTrue(failed)
                self.assertEqual(launched, ["pc", "server"])
                self.assertEqual(result["broken"], ["pc", "server"])
                self.assertTrue(all("attempts" not in row for row in result["hosts"]))

    def test_sigkill_without_stderr_returns_useful_host_error(self):
        result, failed = self.evaluate({"hosts": ["pc"]}, lambda argv, timeout: (-9, "", ""))
        self.assertTrue(failed)
        self.assertIn("SIGKILL", result["hosts"][0]["error"])
        self.assertNotIn("attempts", result["hosts"][0])

    def test_subprocess_error_does_not_drop_remaining_hosts(self):
        def run_split(argv, timeout):
            if command_host(argv) == "pc":
                raise ToolError("executable not found: systemd-run")
            return 0, "server", ""

        result, failed = self.evaluate({"hosts": ["pc", "server"]}, run_split)
        self.assertTrue(failed)
        self.assertEqual(result["broken"], ["pc"])
        self.assertEqual(result["hosts"], [
            {"host": "pc", "ok": False, "error": "executable not found: systemd-run"},
            {"host": "server", "ok": True, "value": "server"},
        ])

    def test_timeout_retries_once_and_preserves_other_hosts(self):
        attempts = {}

        def run_split(argv, timeout):
            host = command_host(argv)
            attempts[host] = attempts.get(host, 0) + 1
            if host == "pc" and attempts[host] == 1:
                raise ToolError("timed out after 1800s: systemd-run")
            return 0, host, ""

        result, failed = self.evaluate({"hosts": ["pc", "server"]}, run_split)
        self.assertFalse(failed)
        self.assertEqual(attempts, {"pc": 2, "server": 1})
        self.assertEqual(result["hosts"], [
            {"host": "pc", "ok": True, "value": "pc", "attempts": 2},
            {"host": "server", "ok": True, "value": "server"},
        ])

    def test_unknown_host_is_rejected_before_evaluation(self):
        def run_split(argv, timeout):
            self.fail("unknown host launched an evaluator")

        with self.assertRaises(ToolError):
            self.evaluate({"hosts": ["unknown"]}, run_split)


if __name__ == "__main__":
    unittest.main()

import contextlib
import io
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location(
    "openwrt_collector", Path(__file__).with_name("openwrt-murmur-collector.py")
)
collector = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(collector)


def process_stat(start=1000):
    fields = ["S", "1", "1", "1", "0", "-1", "0", "7", "0", "3", "0", "250", "50", "0", "0", "20", "0", "4", "0", str(start), "10485760", "20"]
    return "3350 (murmur worker (main)) " + " ".join(fields)


def snapshot():
    providers = {"providers": {"subscription": {"proxies": [
        {"name": "secret-node", "alive": True, "extra": {
            "https://platform.claude.com/": {"alive": True, "history": [{"time": "2026-10-16T12:00:00+03:00", "delay": 25}]},
            "http://cp.cloudflare.com/generate_204": {"alive": False, "history": [{"time": "2026-10-16T09:00:30Z", "delay": 0}]}
        }},
        {"name": "another-secret", "alive": True, "extra": {}}
    ]}}}
    return {
        "timestamp": "1792141260", "uptime": "200.00 100.00", "loadavg": "0.25 0.5 0.5 1/20 42",
        "boot_id": "f4a5c972-2388-4651-a44f-37253751ab74", "boot_id_after": "f4a5c972-2388-4651-a44f-37253751ab74",
        "auxv": struct.pack("<QQQQQQ", 6, 4096, 17, 100, 0, 0),
        "stat": "cpu 100 20 30 400 50 10 5 0 2 0\nbtime 1792141060\n",
        "meminfo": "MemTotal: 1024 kB\nMemAvailable: 512 kB\nMemFree: 100 kB\nCached: 200 kB\nSlab: 64 kB\nSReclaimable: 40 kB\nSUnreclaim: 24 kB\nShmem: 30 kB\n",
        "vmstat": "pgfault 10\noom_kill 2\n",
        "netdev": "Inter-| Receive | Transmit\n face |bytes packets errs drop fifo frame compressed multicast|bytes packets errs drop fifo colls carrier compressed\n eth0: 1000 10 2 3 0 0 0 0 2000 20 4 5 0 0 0 0\n",
        "sockstat": "sockets: used 40\nTCP: inuse 4 orphan 0 tw 2 alloc 6 mem 5\nUDP: inuse 2 mem 3\n",
        "pid": "3350", "cmdline": b"/usr/bin/murmur\0-f\0/etc/murmur/config.yaml\0",
        "pid_after": "3350",
        "cmdline_after": b"/usr/bin/murmur\0-f\0/etc/murmur/config.yaml\0",
        "process_stat": process_stat(), "process_stat_after": process_stat(),
        "process_status": "Name:\tmurmur\nVmRSS:\t80 kB\nRssAnon:\t50 kB\nRssFile:\t20 kB\nRssShmem:\t10 kB\nVmHWM:\t100 kB\nVmSize:\t10240 kB\nThreads:\t4\n",
        "fd_count": "12",
        "connections_rc": "0", "connections_status": "200",
        "connections": json.dumps({"connections": [{"metadata": {"destinationIP": "secret-ip"}}], "uploadTotal": 1200, "downloadTotal": 3400, "memory": 999999}),
        "proxy_providers_rc": "0", "proxy_providers_status": "200", "proxy_providers": json.dumps(providers),
        "rule_providers_rc": "0", "rule_providers_status": "200", "rule_providers": json.dumps({"providers": {"rules": {"ruleCount": 42}}}),
    }


def framed(values):
    result = b""
    for name, value in values.items():
        raw = value if isinstance(value, bytes) else value.encode()
        result += b"@@OPENWRT:" + name.encode() + b"\n" + raw.hex().encode() + b"\n"
    return result


def rendered(values=None, router="openwrt"):
    return collector.render_snapshot(collector.parse_frames(framed(values or snapshot())), router, 1.25, 1792141262)


class CollectorTests(unittest.TestCase):
    def test_exact_memory_hz_page_and_cpu_units(self):
        text = rendered()
        for expected in [
            'openwrt_memory_bytes{router="openwrt",kind="total"} 1048576',
            'openwrt_murmur_resident_memory_bytes{router="openwrt"} 81920',
            'openwrt_murmur_cpu_seconds_total{router="openwrt"} 3',
            'openwrt_cpu_seconds_total{router="openwrt",mode="user"} 0.98',
            'openwrt_socket_memory_bytes{router="openwrt",protocol="tcp"} 20480',
            'openwrt_murmur_start_time_seconds{router="openwrt"} 1792141070',
            'openwrt_murmur_page_faults_total{router="openwrt",kind="minor"} 7',
            'openwrt_murmur_page_faults_total{router="openwrt",kind="major"} 3',
        ]:
            self.assertIn(expected + '\n', text)

    def test_auxv_controls_nondefault_units(self):
        values = snapshot()
        values["auxv"] = struct.pack("<QQQQQQ", 6, 16384, 17, 250, 0, 0)
        text = rendered(values)
        self.assertIn('openwrt_murmur_cpu_seconds_total{router="openwrt"} 1.2\n', text)
        self.assertIn('openwrt_socket_memory_bytes{router="openwrt",protocol="tcp"} 81920\n', text)

    def test_missing_process_has_no_process_values(self):
        values = snapshot()
        values["pid"] = "0"
        values["pid_after"] = "0"
        for key in list(values):
            if key.startswith("process_") or key in ("cmdline", "cmdline_after", "fd_count"):
                del values[key]
        text = rendered(values)
        self.assertIn('openwrt_murmur_up{router="openwrt"} 0\n', text)
        self.assertNotIn("openwrt_murmur_resident_memory_bytes", text)

    def test_pid_reuse_and_wrong_configuration_fail(self):
        for key, value in [("process_stat_after", process_stat(2000)), ("cmdline_after", b"murmur\0-f\0/tmp/probe.yaml\0"), ("cmdline", b"murmur\0-f\0/tmp/probe.yaml\0")]:
            with self.subTest(key=key):
                values = snapshot()
                values[key] = value
                with self.assertRaises(ValueError):
                    rendered(values)

    def test_api_failure_omits_data_and_records_failure(self):
        values = snapshot()
        values["proxy_providers_rc"] = "28"
        values["proxy_providers"] = "private error"
        text = rendered(values)
        self.assertIn('openwrt_murmur_api_success{router="openwrt",endpoint="proxy_providers"} 0\n', text)
        self.assertNotIn("openwrt_murmur_provider_proxies", text)
        self.assertNotIn("private error", text)
        self.assertIn('openwrt_collector_success{router="openwrt"} 1\n', text)

    def test_malformed_api_does_not_publish_partial_endpoint(self):
        for name, payload in [("connections", {"connections": [], "uploadTotal": 0}), ("proxy_providers", {"providers": {"ok": {"proxies": []}, "bad": {}}}), ("rule_providers", {"providers": {"ok": {"ruleCount": 42}, "bad": {"ruleCount": -1}}})]:
            with self.subTest(name=name):
                values = snapshot()
                values[name] = json.dumps(payload)
                text = rendered(values)
                self.assertIn('endpoint="' + name + '"} 0\n', text)
                self.assertNotIn('provider="ok"', text)

    def test_health_uses_timestamped_per_url_history(self):
        text = rendered()
        for line in [
            'openwrt_murmur_probe_proxies{router="openwrt",provider="subscription",probe="claude",state="healthy"} 1',
            'openwrt_murmur_probe_proxies{router="openwrt",provider="subscription",probe="claude",state="unknown"} 1',
            'openwrt_murmur_probe_proxies{router="openwrt",provider="subscription",probe="cloudflare",state="unhealthy"} 1',
            'openwrt_murmur_provider_proxies{router="openwrt",provider="subscription",state="unhealthy"} 1',
            'openwrt_murmur_provider_proxies{router="openwrt",provider="subscription",state="unknown"} 1',
            'openwrt_murmur_probe_newest_timestamp_seconds{router="openwrt",provider="subscription",probe="claude"} 1792141200',
        ]:
            self.assertIn(line + '\n', text)
        for secret in ("secret-node", "another-secret", "secret-ip", "platform.claude", "generate_204", "999999"):
            self.assertNotIn(secret, text)

    def test_cold_alive_and_zero_dates_are_unknown(self):
        values = snapshot()
        values["proxy_providers"] = json.dumps({"providers": {"cold": {"proxies": [{"alive": True, "extra": {"https://platform.claude.com/": {"alive": True, "history": [{"time": "0001-01-01T00:00:00Z", "delay": 0}]}}}]}}})
        text = rendered(values)
        self.assertIn('provider="cold",state="unknown"} 1\n', text)
        self.assertNotIn("openwrt_murmur_probe_newest_timestamp_seconds", text)

    def test_timestamped_per_url_alive_wins_over_delay(self):
        for alive, delay, state in [(False, 25, "unhealthy"), (True, 0, "healthy"), (None, 25, "unknown")]:
            values = snapshot()
            values["proxy_providers"] = json.dumps({"providers": {"p": {"proxies": [{"alive": True, "extra": {"https://platform.claude.com/": {"alive": alive, "history": [{"time": "2026-10-16T09:00:30Z", "delay": delay}]}}}]}}})
            text = rendered(values)
            self.assertIn('provider="p",probe="claude",state="' + state + '"} 1\n', text)

    def test_labels_escape_and_dynamic_node_names_do_not_add_series(self):
        values = snapshot()
        provider = 'p"\\\nlabel'
        proxies = [{"name": "private-" + str(i), "alive": True} for i in range(100)]
        values["proxy_providers"] = json.dumps({"providers": {provider: {"proxies": proxies}}})
        text = rendered(values, 'r"\\\n')
        self.assertIn('router="r\\"\\\\\\n",provider="p\\"\\\\\\nlabel",state="unknown"} 100\n', text)
        self.assertEqual(sum(line.startswith("openwrt_murmur_probe_proxies{") for line in text.splitlines()), 6)
        self.assertNotIn("private-", text)

    def test_network_and_connections_are_aggregate_counters(self):
        text = rendered()
        for expected in [
            'openwrt_network_bytes_total{router="openwrt",device="eth0",direction="receive"} 1000',
            'openwrt_network_errors_total{router="openwrt",device="eth0",direction="transmit"} 4',
            'openwrt_murmur_connections{router="openwrt"} 1',
            'openwrt_murmur_traffic_bytes_total{router="openwrt",direction="download"} 3400',
        ]:
            self.assertIn(expected + '\n', text)

    def test_optional_oom_absence_is_not_zero(self):
        values = snapshot()
        values["vmstat"] = "pgfault 10\n"
        self.assertNotIn("openwrt_oom_kills_total", rendered(values))

    def test_required_snapshot_fields_fail_closed(self):
        for key in ("auxv", "meminfo", "stat", "uptime", "netdev", "boot_id", "sockstat", "timestamp"):
            with self.subTest(key=key):
                values = snapshot()
                del values[key]
                with self.assertRaises((ValueError, KeyError)):
                    rendered(values)

    def test_boot_change_fails_closed(self):
        values = snapshot()
        values["boot_id_after"] = "e4a5c972-2388-4651-a44f-37253751ab74"
        with self.assertRaises(ValueError):
            rendered(values)

    def test_invalid_auxv_and_meminfo_are_rejected(self):
        for key, value in [("auxv", b"short"), ("auxv", struct.pack("<QQ", 0, 0)), ("meminfo", "MemTotal: 100 MB\n")]:
            with self.subTest(key=key, value=value):
                values = snapshot()
                values[key] = value
                with self.assertRaises(ValueError):
                    rendered(values)

    def test_duplicate_truncated_or_foreign_frames_fail(self):
        for payload in [framed(snapshot()) + b"@@OPENWRT:uptime\n31\n", b"@@OPENWRT:uptime\n", b"private banner\n", b"@@OPENWRT:uptime\n!\n"]:
            with self.subTest(payload=payload[-60:]):
                with self.assertRaises(ValueError):
                    collector.parse_frames(payload)

    def test_failure_replaces_all_stale_gauges(self):
        previous = rendered()
        text = collector.render_failure("openwrt", 2.5, collector.previous_success(previous, "openwrt"))
        self.assertIn('openwrt_collector_success{router="openwrt"} 0\n', text)
        self.assertIn('openwrt_collector_last_success_timestamp_seconds{router="openwrt"} 1792141262\n', text)
        self.assertNotIn("openwrt_memory_bytes", text)
        self.assertNotIn("openwrt_murmur_up", text)
        self.assertIsNone(collector.previous_success(previous, "different"))

    def test_atomic_publication_and_permissions(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as directory:
            path = Path(directory) / "router.prom"
            path.write_text("old\n")
            collector.publish(path, rendered())
            self.assertEqual(path.read_text(), rendered())
            self.assertEqual(path.stat().st_mode & 0o777, 0o644)
            self.assertEqual([p.name for p in Path(directory).iterdir()], ["router.prom"])

    def test_failed_atomic_replacement_preserves_old_complete_file(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as directory:
            path = Path(directory) / "router.prom"
            path.write_text("complete old\n")
            with patch.object(collector.os, "replace", side_effect=OSError("private")):
                with self.assertRaises(OSError):
                    collector.publish(path, "complete new\n")
            self.assertEqual(path.read_text(), "complete old\n")
            self.assertEqual([p.name for p in Path(directory).iterdir()], ["router.prom"])

    def test_process_identity_change_rejects_snapshot(self):
        values = snapshot()
        values["pid_after"] = "4450"
        with self.assertRaises(ValueError):
            rendered(values)

    def test_empty_providers_are_successful_without_invented_counts(self):
        values = snapshot()
        values["proxy_providers"] = '{"providers": {}}'
        values["rule_providers"] = '{"providers": {}}'
        text = rendered(values)
        self.assertIn('endpoint="proxy_providers"} 1\n', text)
        self.assertIn('endpoint="rule_providers"} 1\n', text)
        self.assertNotIn("openwrt_murmur_provider_proxies", text)
        self.assertNotIn("openwrt_murmur_rules", text)

    def test_http_error_and_missing_metadata_fail_only_endpoint(self):
        for key, value in [("connections_status", "403"), ("connections_rc", None)]:
            values = snapshot()
            if value is None:
                del values[key]
            else:
                values[key] = value
            text = rendered(values)
            self.assertIn('endpoint="connections"} 0\n', text)
            self.assertNotIn("openwrt_murmur_traffic_bytes_total", text)
            self.assertIn('openwrt_collector_success{router="openwrt"} 1\n', text)

    def test_future_and_unzoned_probe_times_are_unknown(self):
        for stamp in ("2099-01-01T00:00:00Z", "2026-10-16T09:00:00"):
            values = snapshot()
            values["proxy_providers"] = json.dumps({"providers": {"p": {"proxies": [{"extra": {"https://platform.claude.com/": {"history": [{"time": stamp, "delay": 30}]}}}]}}})
            text = rendered(values)
            self.assertIn('provider="p",probe="claude",state="unknown"} 1\n', text)
            self.assertNotIn("openwrt_murmur_probe_newest_timestamp_seconds", text)

    def test_cardinality_limit_discards_whole_endpoint(self):
        values = snapshot()
        values["proxy_providers"] = json.dumps({"providers": {"p": {"proxies": [{}] * 4097}}})
        text = rendered(values)
        self.assertIn('endpoint="proxy_providers"} 0\n', text)
        self.assertNotIn("openwrt_murmur_probe_proxies", text)

    def test_optional_temperature_converts_millicelsius(self):
        values = snapshot()
        values["temperature"] = "44442"
        self.assertIn('openwrt_temperature_celsius{router="openwrt",sensor="thermal_zone0"} 44.442\n', rendered(values))

    def test_main_transport_failure_publishes_sanitized_failure(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as directory:
            path = Path(directory) / "router.prom"
            path.write_text(rendered())
            errors = io.StringIO()
            with patch.object(collector.sys, "argv", ["collector", "--target", "root@openwrt", "--output", str(path)]), patch.object(collector, "collect", side_effect=ValueError("private payload and secret")), contextlib.redirect_stderr(errors):
                result = collector.main()
            self.assertEqual(result, 1)
            self.assertEqual(errors.getvalue(), "ValueError\n")
            content = path.read_text()
            self.assertIn('openwrt_collector_success{router="openwrt"} 0\n', content)
            self.assertIn('openwrt_collector_last_success_timestamp_seconds{router="openwrt"} 1792141262\n', content)
            self.assertNotIn("openwrt_memory_bytes", content)

    def test_main_success_publishes_real_parsed_metrics(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as directory:
            path = Path(directory) / "router.prom"
            with patch.object(collector.sys, "argv", ["collector", "--target", "root@openwrt", "--output", str(path)]), patch.object(collector, "collect", return_value=collector.parse_frames(framed(snapshot()))):
                result = collector.main()
            self.assertEqual(result, 0)
            self.assertIn('openwrt_murmur_resident_memory_bytes{router="openwrt"} 81920\n', path.read_text())

    def test_stale_probe_is_unknown_but_retains_timestamp(self):
        values = snapshot()
        values["timestamp"] = "1792142001"
        text = rendered(values)
        self.assertIn('provider="subscription",probe="claude",state="unknown"} 2\n', text)
        self.assertIn('provider="subscription",probe="claude"} 1792141200\n', text)

    def test_null_connections_are_empty_but_missing_connections_fail(self):
        values = snapshot()
        values["connections"] = '{"connections":null,"uploadTotal":12,"downloadTotal":34}'
        text = rendered(values)
        self.assertIn('openwrt_murmur_connections{router="openwrt"} 0\n', text)
        self.assertIn('endpoint="connections"} 1\n', text)
        values["connections"] = '{"uploadTotal":12,"downloadTotal":34}'
        self.assertIn('endpoint="connections"} 0\n', rendered(values))

    def test_probe_freshness_boundary_and_nanosecond_timestamp(self):
        values = snapshot()
        values["timestamp"] = "1792141800"
        values["proxy_providers"] = json.dumps({"providers": {"p": {"proxies": [{"extra": {"https://platform.claude.com/": {"alive": True, "history": [{"time": "2026-10-16T09:00:00.000000000Z", "delay": 0}]}}}]}}})
        self.assertIn('provider="p",probe="claude",state="healthy"} 1\n', rendered(values))
        values["timestamp"] = "1792141801"
        self.assertIn('provider="p",probe="claude",state="unknown"} 1\n', rendered(values))

    def test_main_publication_error_reports_only_exception_class(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as directory:
            path = Path(directory) / "absent" / "router.prom"
            errors = io.StringIO()
            with patch.object(collector.sys, "argv", ["collector", "--target", "root@openwrt", "--output", str(path)]), patch.object(collector, "collect", return_value=collector.parse_frames(framed(snapshot()))), contextlib.redirect_stderr(errors):
                result = collector.main()
            self.assertEqual(result, 1)
            self.assertEqual(errors.getvalue(), "FileNotFoundError\n")
            self.assertFalse(path.exists())


if __name__ == "__main__":
    unittest.main()

import { describe, expect, test } from "bun:test";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import grepGate from "./extensions/grep-gate.ts";

type Verdict = { block: boolean; reason: string } | undefined;
type Handler = (event: { toolName: string; input: Record<string, unknown> }, ctx: { cwd: string }) => Promise<Verdict> | Verdict;

let handler: Handler;
grepGate({
  on(name: string, callback: Handler) {
    if (name === "tool_call") handler = callback;
  },
} as unknown as ExtensionAPI);

const commands: [string, string, boolean][] = [
  ["plain grep", "grep -rn foo .", true],
  ["extended grep", "egrep 'a|b' file", true],
  ["fixed grep", "fgrep needle file", true],
  ["pipeline grep", "cat log | grep -i error", true],
  ["chained grep", "ls && grep foo file", true],
  ["semicolon grep", "echo start; grep foo file", true],
  ["newline grep", "ls\ngrep foo file", true],
  ["absolute path", "/usr/bin/grep -r foo .", true],
  ["relative path", "./bin/grep foo", true],
  ["sudo wrapper", "sudo grep -r foo /etc", true],
  ["env wrapper", "env LC_ALL=C grep foo file", true],
  ["assignment prefix", "LC_ALL=C grep foo file", true],
  ["command wrapper", "command grep foo file", true],
  ["command -v lookup", "command -v grep", false],
  ["command -V lookup", "command -V grep", false],
  ["timeout wrapper", "timeout 5 grep foo file", true],
  ["xargs wrapper", "printf '%s\\n' file | xargs grep foo", true],
  ["shell -c", "bash -c 'grep -r foo .'", true],
  ["shell -lc", 'sh -lc "grep foo file"', true],
  ["negated grep", "! grep -q foo file", true],
  ["prefix then shell", 'sudo bash -c "grep foo file"', true],
  ["shell positionals are args", "bash -c 'echo grep' grep", false],
  ["if condition", "if grep foo file; then echo yes; fi", true],
  ["elif condition", "if true; then echo; elif grep foo file; then echo; fi", true],
  ["while condition", "while grep foo file; do break; done", true],
  ["until condition", "until grep -q foo file; do sleep 1; done", true],
  ["for body", 'for f in *; do grep foo "$f"; done', true],
  ["leading redirect", "<file grep foo", true],
  ["echo of exec words", "echo -exec grep", false],
  ["ssh remote command", 'ssh host "grep foo /etc/passwd"', true],
  ["find -exec", "find . -name '*.ts' -exec grep -n foo {} +", true],
  ["subshell", "(grep foo file)", true],
  ["command substitution", "echo $(grep foo file)", true],
  ["backtick substitution", "echo `grep foo file`", true],
  ["grep with redirect", "grep foo file > out.txt", true],
  ["rg is allowed", "rg -n foo .", false],
  ["echo of the word", "echo grep", false],
  ["quoted command text", "echo 'grep foo'", false],
  ["double-quoted command text", 'echo "grep foo"', false],
  ["comment line", "# grep -r foo .", false],
  ["comment before command text", "# note; grep foo", false],
  ["trailing comment", "ls # grep foo", false],
  ["command after comment line", "# note\ngrep foo file", true],
  ["heredoc body is text", "cat <<'EOF'\ngrep foo\nEOF", false],
  ["command after heredoc body", "cat <<EOF\ngrep foo\nEOF\ngrep -n bar file", true],
  ["backslash heredoc body", "cat <<\\EOF\ngrep foo\nEOF", false],
  ["command after backslash heredoc", "cat <<\\EOF\ngrep foo\nEOF\ngrep -n bar file", true],
  ["heredoc spaces are body", "cat <<EOF\n  EOF\ngrep foo\nEOF", false],
  ["command after tab heredoc", "cat <<-EOF\n\tgrep foo\n\tEOF\ngrep -n bar file", true],
  ["rg searching for the word", "rg 'grep|egrep' .", false],
  ["documentation mention", "printf 'grep is banned\\n'", false],
  ["man page", "man grep", false],
  ["git log grep option", "git log --grep=needle", false],
  ["script filename", "bun test modules/omp/grep-gate.test.ts", false],
  ["prototype key as command", "constructor", false],
  ["prototype method as command", "toString", false],
  ["prototype method with argument", "valueOf file", false],
  ["file named after gate", "chmod +x extensions/grep-gate.ts", false],
  ["editor on the module", "vim modules/omp/extensions/grep-gate.ts", false],
  ["sed rewriting the word", "sed -i 's/grep/rg/' notes.txt", false],
  ["cat of a grep-named file", "cat docs/grep.md", false],
  ["rg in substitution", 'echo "$(rg foo)"', false],
];

describe("shell grep gate", () => {
  for (const [name, command, expected] of commands) {
    test(name, async () => {
      expect((await handler({ toolName: "bash", input: { command } }, { cwd: process.cwd() }))?.block ?? false).toBe(expected);
    });
  }

  test("denial tells the agent to use rg", async () => {
    const result = await handler({ toolName: "bash", input: { command: "grep -rn foo ." } }, { cwd: process.cwd() });
    expect(result?.block).toBe(true);
    expect(result?.reason ?? "").toContain("Blocked: use rg (ripgrep) instead of grep");
    expect(result?.reason ?? "").toContain("Rewrite the command and retry.");
  });

  test("the native grep tool stays available", async () => {
    expect((await handler({ toolName: "grep", input: { pattern: "grep", path: "." } }, { cwd: process.cwd() }))?.block ?? false).toBe(false);
  });

  test("unrelated tools are untouched", async () => {
    expect((await handler({ toolName: "read", input: { path: "grep.md" } }, { cwd: process.cwd() }))?.block ?? false).toBe(false);
  });
});

const code: [string, string, boolean][] = [
  ["subprocess list", 'subprocess.run(["grep", "-rn", "foo", "."])', true],
  ["subprocess shell", 'subprocess.run("grep -r foo .", shell=True)', true],
  ["os.system", 'os.system("grep foo file")', true],
  ["node execSync", 'execSync("grep -r foo .")', true],
  ["prose only", 'print("use rg, not grep")', false],
  ["string constant", 'pattern = "grep"', false],
  ["comment", "# grep would match this line\nvalue = 1", false],
  ["rg invocation", 'subprocess.run(["rg", "foo"])', false],
  ["echo of the word", 'subprocess.run(["echo", "grep"])', false],
  ["source edit", 'write("grep.txt", "grep")', false],
];

describe("eval grep gate", () => {
  for (const [name, snippet, expected] of code) {
    test(name, async () => {
      expect((await handler({ toolName: "eval", input: { code: snippet } }, { cwd: process.cwd() }))?.block ?? false).toBe(expected);
    });
  }
});

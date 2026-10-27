import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const DENIAL = "Blocked: use rg (ripgrep) instead of grep. Rewrite the command and retry.";
const GREP = new Set(["grep", "egrep", "fgrep"]);
const EXPAND = "\u0000expand";

const PREFIX_VALUE = new Map<string, string[]>([
  ["env", ["-u", "-C", "-S", "--unset", "--chdir"]],
  ["sudo", ["-u", "-g", "-C", "-h", "-p", "-r", "-t", "-U", "--user", "--group", "--host", "--prompt", "--role", "--type", "--other-user"]],
  ["doas", ["-u", "-C"]],
  ["nice", ["-n", "--adjustment"]],
  ["stdbuf", ["-i", "-o", "-e"]],
  ["timeout", ["-s", "--signal", "-k", "--kill-after"]],
  ["xargs", ["-I", "-n", "-P", "-L", "-s", "-a", "-d", "-E", "-R", "-S", "--delimiter", "--max-args", "--max-procs", "--max-lines", "--max-chars", "--arg-file", "--eof", "--replace"]],
  ["time", ["-f", "-o", "--format", "--output"]],
  ["command", []],
  ["exec", ["-a"]],
  ["nohup", []],
]);

const SHELLS = new Set(["sh", "bash", "zsh", "dash", "ksh", "fish", "su", "script"]);

const SSH_VALUE = new Set(["-b", "-c", "-D", "-e", "-F", "-i", "-J", "-L", "-l", "-m", "-O", "-o", "-p", "-Q", "-R", "-S", "-W", "-w"]);

const LEADING = new Set(["!", "{", "}", "if", "then", "elif", "else", "do", "while", "until", "for", "case", "esac", "in", "fi", "done"]);

const EXEC_CALL = /(?:\bsubprocess\.\w+|\bos\.(?:system|popen)|\bchild_process\.\w+|\bexecSync|\bexecFileSync|\bexecFile|\bspawnSync|\bspawn)\s*\(\s*(?:\[\s*)?[fFrRbBuU]{0,2}["'`]\s*(?:[^"'`\s]*\/)?(?:e|f)?grep(?![\w-])/;

function base(token: string): string {
  return token.slice(token.lastIndexOf("/") + 1);
}

function substitution(src: string, at: number): { end: number; body: string } | null {
  if (src[at] === "`") {
    let j = at + 1;
    let body = "";
    while (j < src.length && src[j] !== "`") {
      if (src[j] === "\\") {
        body += src[j + 1] ?? "";
        j += 2;
        continue;
      }
      body += src[j++];
    }
    return { end: j < src.length ? j + 1 : src.length, body };
  }
  if (src[at] !== "$" || src[at + 1] !== "(") return null;
  let depth = 0;
  let body = "";
  let j = at + 1;
  for (; j < src.length; j++) {
    if (src[j] === "(") {
      depth++;
      if (depth === 1) continue;
    } else if (src[j] === ")") {
      depth--;
      if (depth === 0) {
        j++;
        break;
      }
    }
    body += src[j];
  }
  return { end: j, body };
}

function heredoc(src: string, at: number): { end: number; delimiter: string; stripTabs: boolean } | null {
  if (src[at] !== "<" || src[at + 1] !== "<" || src[at + 2] === "<") return null;
  let j = at + 2;
  const stripTabs = src[j] === "-";
  if (stripTabs) j++;
  while (j < src.length && (src[j] === " " || src[j] === "\t")) j++;
  const quote = src[j] === "'" || src[j] === '"' ? src[j++] : "";
  let delimiter = "";
  while (j < src.length && (quote ? src[j] !== quote : !/[\s;&|()<>]/.test(src[j]))) {
    if (src[j] === "\\" && quote !== "'") {
      delimiter += src[j + 1] ?? "";
      j += 2;
      continue;
    }
    delimiter += src[j++];
  }
  if (quote && src[j] === quote) j++;
  return delimiter ? { end: j, delimiter, stripTabs } : null;
}

function skipHeredoc(src: string, at: number, delimiter: string, stripTabs: boolean): number {
  let j = at;
  while (j < src.length) {
    let end = src.indexOf("\n", j);
    if (end < 0) end = src.length;
    const line = src.slice(j, end);
    if ((stripTabs ? line.replace(/^\t+/, "") : line) === delimiter) return Math.min(end + 1, src.length);
    j = end + 1;
  }
  return src.length;
}

type Parsed = { commands: string[][]; nested: string[] };

function parse(src: string): Parsed {
  const commands: string[][] = [];
  const nested: string[] = [];
  const pending: { delimiter: string; stripTabs: boolean }[] = [];
  let current: string[] = [];
  let token = "";
  let started = false;
  let i = 0;

  const endToken = () => {
    if (!started) return;
    current.push(token);
    token = "";
    started = false;
  };
  const endCommand = () => {
    endToken();
    if (current.length) commands.push(current);
    current = [];
  };
  const expansion = (at: number): boolean => {
    const found = substitution(src, at);
    if (!found) return false;
    nested.push(found.body);
    token += EXPAND;
    started = true;
    i = found.end;
    return true;
  };

  while (i < src.length) {
    const c = src[i];
    if (c === "\\") {
      token += src[i + 1] ?? "";
      started = true;
      i += 2;
      continue;
    }
    if (c === "'") {
      const end = src.indexOf("'", i + 1);
      token += end < 0 ? src.slice(i + 1) : src.slice(i + 1, end);
      started = true;
      i = end < 0 ? src.length : end + 1;
      continue;
    }
    if (c === '"') {
      i++;
      while (i < src.length && src[i] !== '"') {
        if (src[i] === "\\") {
          token += src[i + 1] ?? "";
          i += 2;
          continue;
        }
        if (expansion(i)) continue;
        token += src[i++];
      }
      i++;
      started = true;
      continue;
    }
    if (expansion(i)) continue;
    if (c === "#" && !started) {
      const end = src.indexOf("\n", i);
      i = end < 0 ? src.length : end;
      continue;
    }
    if (c === "<") {
      const found = heredoc(src, i);
      if (found) {
        pending.push(found);
        i = found.end;
        continue;
      }
    }
    if ((c === "&" && src[i + 1] === "&") || (c === "|" && src[i + 1] === "|")) {
      endCommand();
      i += 2;
      continue;
    }
    if (c === "\n") {
      endCommand();
      i++;
      while (pending.length) {
        const body = pending.shift()!;
        i = skipHeredoc(src, i, body.delimiter, body.stripTabs);
      }
      continue;
    }
    if (c === ";" || c === "|" || c === "&" || c === "(" || c === ")") {
      endCommand();
      i++;
      continue;
    }
    if (c === " " || c === "\t" || c === "\r") {
      endToken();
      i++;
      continue;
    }
    token += c;
    started = true;
    i++;
  }
  endCommand();
  return { commands, nested };
}

function commandStart(command: string[]): number {
  let i = 0;
  for (;;) {
    while (i < command.length) {
      const lead = command[i];
      if (LEADING.has(lead)) {
        i++;
        continue;
      }
      if (/^(?:\d+|&)?[<>]+$/.test(lead)) {
        i += 2;
        continue;
      }
      if (/^(?:\d+|&)?[<>]/.test(lead)) {
        i++;
        continue;
      }
      break;
    }
    if (i >= command.length) return i;
    const token = command[i];
    if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(token)) {
      i++;
      continue;
    }
    const name = base(token);
    const valued = PREFIX_VALUE.get(name);
    if (valued === undefined) return i;
    i++;
    if (name === "command" && (command[i] === "-v" || command[i] === "-V")) return i;
    while (i < command.length) {
      const arg = command[i];
      if (name === "env" && /^[A-Za-z_][A-Za-z0-9_]*=/.test(arg)) {
        i++;
        continue;
      }
      if (arg === "--") {
        i++;
        break;
      }
      if (!arg.startsWith("-") || arg === "-") break;
      i += valued.includes(arg) ? 2 : 1;
    }
    if (name === "timeout") i++;
  }
}

function invokesGrep(command: string[]): boolean {
  const at = commandStart(command);
  if (at >= command.length) return false;
  const name = base(command[at]);
  if (GREP.has(name)) return true;
  if (name !== "find") return false;
  for (let j = at + 1; j < command.length - 1; j++) {
    if (command[j] === "-exec" || command[j] === "-execdir" || command[j] === "-ok" || command[j] === "-okdir") {
      if (GREP.has(base(command[j + 1]))) return true;
    }
  }
  return false;
}

function nestedCommands(command: string[], at: number): string[] {
  const name = base(command[at] ?? "");
  if (SHELLS.has(name)) {
    for (let j = at + 1; j < command.length - 1; j++) {
      if (/^-[A-Za-z]*c[A-Za-z]*$/.test(command[j])) return [command[j + 1]];
    }
    return [];
  }
  if (name !== "ssh") return [];
  let j = at + 1;
  while (j < command.length && command[j].startsWith("-")) j += SSH_VALUE.has(command[j]) ? 2 : 1;
  j++;
  return j < command.length ? [command.slice(j).join(" ")] : [];
}

function carriesGrep(src: string, depth: number): boolean {
  const parsed = parse(src);
  for (const command of parsed.commands) {
    if (invokesGrep(command)) return true;
    if (depth >= 2) continue;
    for (const inner of nestedCommands(command, commandStart(command))) {
      if (carriesGrep(inner, depth + 1)) return true;
    }
  }
  if (depth < 2) {
    for (const nested of parsed.nested) {
      if (carriesGrep(nested, depth + 1)) return true;
    }
  }
  return false;
}

export default function grepGate(pi: ExtensionAPI): void {
  pi.on("tool_call", async (event) => {
    const source =
      event.toolName === "bash"
        ? String(event.input.command ?? "")
        : event.toolName === "eval"
          ? String(event.input.code ?? "")
          : null;
    if (source === null) return;
    const found = event.toolName === "bash" ? carriesGrep(source, 0) : EXEC_CALL.test(source);
    if (!found) return;
    return { block: true, reason: DENIAL };
  });
}

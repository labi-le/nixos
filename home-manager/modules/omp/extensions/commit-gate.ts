import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

// Enforces rules/commit-style.md on the agent instead of merely asking it to
// comply: a rule is context the model may lose, outrank or talk itself out of,
// while a blocked tool call is a fact it has to deal with. Only `-m`/`-F`
// invocations are inspected -- an editor-driven commit belongs to the human.

const RULE = "~/.omp/agent/rules/commit-style.md";
const SUBJECT_CEILING = 70;
const BODY_CEILING = 500;
const BODY_LINES = 6;

// Commands that carry another command inside an argument (`ssh host "…"`).
const WRAPPERS: Record<string, true> = {
  ssh: true,
  sudo: true,
  doas: true,
  su: true,
  sh: true,
  bash: true,
  zsh: true,
  env: true,
  docker: true,
  podman: true,
};
// Markers that a snippet spawns a process rather than merely mentioning one.
const EXECUTES = /\bsubprocess\b|\bexecSync\b|\bspawnSync\b|\bspawn\b|\bpopen\b|os\.system|check_output|Bun\.\$|\$`/;

type Simple = string[];

/** Split a command line into simple commands, honouring quotes. */
function splitCommands(src: string): Simple[] {
  const cmds: Simple[] = [];
  let cur: Simple = [];
  let tok = "";
  let started = false;
  let i = 0;

  const pushTok = () => {
    if (started) {
      cur.push(tok);
      tok = "";
      started = false;
    }
  };
  const endCmd = () => {
    pushTok();
    if (cur.length) cmds.push(cur);
    cur = [];
  };

  while (i < src.length) {
    const c = src[i];

    if (c === "\\") {
      tok += src[i + 1] ?? "";
      started = true;
      i += 2;
      continue;
    }
    if (c === "'") {
      const end = src.indexOf("'", i + 1);
      tok += end < 0 ? src.slice(i + 1) : src.slice(i + 1, end);
      started = true;
      i = end < 0 ? src.length : end + 1;
      continue;
    }
    if (c === '"') {
      i++;
      while (i < src.length && src[i] !== '"') {
        if (src[i] === "\\") {
          tok += src[i + 1] ?? "";
          i += 2;
          continue;
        }
        tok += src[i++];
      }
      i++;
      started = true;
      continue;
    }
    // Command substitutions stay opaque: their content is not our command.
    if (c === "$" && src[i + 1] === "(") {
      let depth = 1;
      let j = i + 2;
      while (j < src.length && depth > 0) {
        if (src[j] === "(") depth++;
        else if (src[j] === ")") depth--;
        j++;
      }
      tok += src.slice(i, j);
      started = true;
      i = j;
      continue;
    }
    if ((c === "&" && src[i + 1] === "&") || (c === "|" && src[i + 1] === "|")) {
      endCmd();
      i += 2;
      continue;
    }
    if (c === ";" || c === "|" || c === "&" || c === "\n") {
      endCmd();
      i++;
      continue;
    }
    if (c === " " || c === "\t" || c === "\r") {
      pushTok();
      i++;
      continue;
    }
    tok += c;
    started = true;
    i++;
  }
  endCmd();
  return cmds;
}

type Invocation = { messages: string[]; file?: string; exempt: boolean };

/** Recognise `git … commit …` and collect what it would use as a message. */
function readCommit(cmd: Simple): Invocation | null {
  const gitAt = cmd.findIndex((t) => t === "git" || t.endsWith("/git"));
  if (gitAt < 0) return null;

  let i = gitAt + 1;
  // Global options sit before the subcommand; two of them take a value.
  while (i < cmd.length && cmd[i].startsWith("-")) {
    i += cmd[i] === "-C" || cmd[i] === "-c" ? 2 : 1;
  }
  if (cmd[i] !== "commit") return null;

  const inv: Invocation = { messages: [], exempt: false };
  for (i++; i < cmd.length; i++) {
    const t = cmd[i];
    // git writes these itself, or reuses a message we never composed.
    if (
      t === "--dry-run" ||
      t === "--fixup" ||
      t === "--squash" ||
      t === "-C" ||
      t === "--reuse-message" ||
      t === "-c" ||
      t === "--reedit-message" ||
      t.startsWith("--fixup=") ||
      t.startsWith("--squash=")
    ) {
      inv.exempt = true;
      continue;
    }
    if (t === "--message" || /^-[a-zA-Z]*m$/.test(t)) {
      if (cmd[i + 1] !== undefined) inv.messages.push(cmd[++i]);
      continue;
    }
    if (t.startsWith("--message=")) {
      inv.messages.push(t.slice(10));
      continue;
    }
    const attached = /^-[a-zA-Z]*m(.+)$/.exec(t);
    if (attached) {
      inv.messages.push(attached[1]);
      continue;
    }
    if (t === "--file" || t === "-F") {
      inv.file = cmd[++i];
      continue;
    }
    if (t.startsWith("--file=")) {
      inv.file = t.slice(7);
      continue;
    }
  }
  return inv;
}

/** Returns the rule each message breaks, or null when the message is fine. */
export function checkMessage(messages: string[]): string | null {
  const text = messages.join("\n\n");
  const lines = text.split("\n");
  const subject = lines[0] ?? "";
  const body = lines.slice(1).join("\n").trim();

  // git composes these; they are not ours to shape.
  if (/^(merge|revert|fixup!|squash!|amend!)\b/i.test(subject)) return null;

  if (!subject.trim()) return "the subject is empty";

  if (/^[a-z]+\([^)]*\):/.test(subject)) {
    return `the subject uses the conventional-commits \`type(scope):\` form; the prefix is a component -- the module, host or package the change belongs to (\`omp:\`, \`nginx:\`, \`server:\`)`;
  }
  if (!/^[a-z0-9][a-z0-9._/-]*: \S/.test(subject)) {
    return "the subject is not `component: what changed` with a lowercase component";
  }
  if (subject.length > SUBJECT_CEILING) {
    return `the subject is ${subject.length} characters; ${SUBJECT_CEILING} is the hard ceiling and the median belongs under 30`;
  }
  if (subject.endsWith(".")) return "the subject ends with a period";

  const after = subject.slice(subject.indexOf(": ") + 2);
  if (/^[A-Z]/.test(after)) {
    return "the text after the colon is capitalised; it should read as a lowercase imperative";
  }

  const trailer = /^(co-authored-by:|generated with\b)|🤖/im.exec(text);
  if (trailer) return `the message carries a generated trailer (\`${trailer[0].trim()}\`)`;

  if (body) {
    if (body.length > BODY_CEILING) {
      return `the body is ${body.length} characters; it should hold a couple of lines carrying a decision the diff cannot show`;
    }
    if (body.split("\n").filter((l) => l.trim()).length > BODY_LINES) {
      return "the body runs past a couple of lines";
    }
  }
  return null;
}

/** Every commit invocation in a command line, including wrapped ones. */
function collectInvocations(src: string, depth = 0): Invocation[] {
  const out: Invocation[] = [];
  for (const simple of splitCommands(src)) {
    const inv = readCommit(simple);
    if (inv) {
      out.push(inv);
      continue;
    }
    if (depth >= 2 || !WRAPPERS[(simple[0] ?? "").replace(/^.*\//, "")]) continue;
    for (const tok of simple.slice(1)) {
      if (/\bgit\b/.test(tok) && /\bcommit\b/.test(tok)) {
        out.push(...collectInvocations(tok, depth + 1));
      }
    }
  }
  return out;
}

export default function commitGate(pi: ExtensionAPI): void {
  pi.on("tool_call", async (event, ctx) => {
    // Every process-spawning tool has to be covered. A gate watching `bash`
    // alone is one tool choice away from being decoration.
    const source =
      event.toolName === "bash"
        ? String(event.input.command ?? "")
        : event.toolName === "eval"
          ? String(event.input.code ?? "")
          : null;
    if (source === null || !/\bgit\b/.test(source) || !/\bcommit\b/.test(source)) return;

    const found = collectInvocations(source);
    let broken: string | null = null;

    for (const inv of found) {
      if (inv.exempt) continue;

      let messages = inv.messages;
      if (!messages.length && inv.file) {
        try {
          messages = [await Bun.file(inv.file).text()];
        } catch {
          // An earlier link of this very command may be what writes the file,
          // so it is unreadable here -- and unverifiable is not compliant.
          broken = `the message file \`${inv.file}\` cannot be read, so the message cannot be checked; pass it with -m instead`;
          break;
        }
      }
      if (!messages.length) continue;

      broken = checkMessage(messages);
      if (broken) {
        broken = `${broken}\n\nSubject: ${messages[0].split("\n")[0]}`;
        break;
      }
    }

    // An exec that did not parse is refused rather than trusted: a template
    // literal can carry the message in a variable that exists only at runtime.
    if (!broken && !found.length && event.toolName === "eval" && EXECUTES.test(source)) {
      broken =
        "a commit spawned from `eval` cannot be read as a command line; run it through the bash tool so the message is visible";
    }
    if (!broken) return;

    const reason = `Commit blocked: ${broken}\n\nRewrite it and run the command again. Full convention: ${RULE}`;

    // The human outranks the rule, so give them the override when they are
    // actually at the keyboard; a subagent or headless run just stops.
    if (ctx.hasUI) {
      const allow = await ctx.ui.confirm("Commit style", `${reason}\n\nCommit anyway?`);
      if (allow) return;
    }
    return { block: true, reason };
  });
}

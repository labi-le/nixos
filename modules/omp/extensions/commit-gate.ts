import { resolve } from "node:path";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

// Enforces rules/commit-style.md on the agent instead of merely asking it to
// comply: a rule is context the model may lose, outrank or talk itself out of,
// while a blocked tool call is a fact it has to deal with. The message has to
// be literal text in the command; an editor-driven commit belongs to the human.

const RULE = "~/.omp/agent/rules/commit-style.md";
const SUBJECT_CEILING = 70;

// Commands that carry another command inside an argument (`ssh host "…"`).
const WRAPPERS: Record<string, true> = {
  command: true,
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
const FOREIGN: Record<string, true> = { ssh: true, docker: true, podman: true };
const COMMIT_TOKEN = /(?<![\w./-])commit(?![\w./-])/;
const EVAL_RISK = /(?<![\w./-])(commit|--amend|--force|--hard)(?![\w./-])/;
const MR_EVAL_RISK = /\b(?:gh|glab)\b.{0,100}\b(?:pr|mr)\b.{0,100}\b(?:create|new|edit|update)\b|\bmerge_request\.(?:create|title|description)\b|\bgit\b.{0,100}\bpush\b.{0,100}(?:-o|--push-option)/s;
const ADD_SWEEP = /^-[a-zA-Z]*[Au][a-zA-Z]*$/;
const AMEND = "\u0000amend";
const EXPAND = "\u0000expand";
const ELSEWHERE =
  "`--amend` targets another worktree, where HEAD cannot be checked from here; point the tool's `cwd` at that directory instead of moving with `cd`";

function expansionEnd(src: string, at: number): number {
  const c = src[at];
  if (c === "`") {
    const end = src.indexOf("`", at + 1);
    return end < 0 ? src.length : end + 1;
  }
  if (c !== "$") return 0;
  const next = src[at + 1] ?? "";
  if (next === "(") {
    let depth = 1;
    let j = at + 2;
    while (j < src.length && depth > 0) {
      if (src[j] === "(") depth++;
      else if (src[j] === ")") depth--;
      j++;
    }
    return j;
  }
  if (next === "{") {
    const end = src.indexOf("}", at + 2);
    return end < 0 ? src.length : end + 1;
  }
  if (/[0-9@*#?$!'"]/.test(next)) return at + 2;
  if (!/[A-Za-z_]/.test(next)) return 0;
  let j = at + 1;
  while (j < src.length && /[A-Za-z0-9_]/.test(src[j])) j++;
  return j;
}

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
      if (cur.length || (tok !== "{" && tok !== "}" && tok !== "!")) cur.push(tok);
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
        const inner = expansionEnd(src, i);
        if (inner) {
          tok += EXPAND;
          i = inner;
          continue;
        }
        tok += src[i++];
      }
      i++;
      started = true;
      continue;
    }
    const expand = expansionEnd(src, i);
    if (expand) {
      tok += EXPAND;
      started = true;
      i = expand;
      continue;
    }
    if ((c === "&" && src[i + 1] === "&") || (c === "|" && src[i + 1] === "|")) {
      endCmd();
      i += 2;
      continue;
    }
    if (c === ";" || c === "|" || c === "&" || c === "\n" || c === ")" || (!started && c === "(")) {
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

type Invocation = { messages: string[]; indirect?: string; exempt: boolean };

/** Recognise `git … commit …` and collect what it would use as a message. */
function readCommit(cmd: Simple): Invocation | null {
  const gitAt = cmd.findIndex((t) => t === "git" || t.endsWith("/git"));
  if (gitAt < 0) return null;

  let i = gitAt + 1;
  const globals: string[] = [];
  // Global options sit before the subcommand; two of them take a value.
  while (i < cmd.length && cmd[i].startsWith("-")) {
    const pair = cmd[i] === "-C" || cmd[i] === "-c";
    globals.push(cmd[i]);
    if (pair && cmd[i + 1] !== undefined) globals.push(cmd[i + 1]);
    i += pair ? 2 : 1;
  }
  if (cmd[i] !== "commit") return null;

  const inv: Invocation = { messages: [], exempt: false };
  const env = cmd
    .slice(0, gitAt)
    .find((t) => /^((GIT_)?(EDITOR|VISUAL|SEQUENCE_EDITOR)|GIT_CONFIG\w*)=/.test(t));
  if (env) inv.indirect = `an environment override (\`${env.split("=")[0]}\`)`;
  const override = globals
    .map((t) => /(^|=)(core\.editor|sequence\.editor|commit\.template)=/i.exec(t))
    .find((hit) => hit !== null);
  if (override) inv.indirect = `a config override (\`${override[2].toLowerCase()}\`)`;
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
    const cluster = t.startsWith("--") ? "" : t.split("m")[0];
    if (t === "--edit" || /^-[a-zA-Z]*e/.test(cluster)) {
      inv.indirect = "`--edit`, which hands the message to an editor";
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
    if (t === "--file" || t === "-F" || t === "--template" || t === "-t") {
      inv.indirect = `\`${t}\``;
      i++;
      continue;
    }
    if (t.startsWith("--file=") || t.startsWith("--template=")) {
      inv.indirect = `\`${t.slice(0, t.indexOf("="))}\``;
      continue;
    }
  }
  return inv;
}

/** Returns the rule each message breaks, or null when the message is fine. */
export function checkMessage(messages: string[]): string | null {
  const text = messages.join("\n\n");
  const subject = text.split("\n")[0] ?? "";

  if (text.includes(EXPAND)) {
    return "the message is assembled by the shell, so what git would record cannot be read; pass the literal text";
  }

  // git composes these; they are not ours to shape.
  if (/^(merge|revert|fixup!|squash!|amend!)\b/i.test(subject)) return null;

  if (messages.length > 1) {
    return "the message is split across repeated `-m` flags; pass a single `-m` holding one line";
  }
  if (text.trim().includes("\n")) {
    return "the message carries a body; it is one line only -- a decision the diff cannot show belongs in `docs/`";
  }
  if (!subject.trim()) return "the subject is empty";

  if (/^[a-zA-Z]+\([^)]*\):/.test(subject)) {
    return `the subject uses the conventional-commits \`type(scope):\` form; the prefix is a component -- the module, host or package the change belongs to (\`omp:\`, \`nginx:\`, \`server:\`)`;
  }
  const word = "[a-zA-Z0-9][a-zA-Z0-9._/-]*";
  if (!new RegExp(`^${word}( ${word}){0,2}: \\S`).test(subject)) {
    return "the subject is not `component: what changed`, with at most three words before the colon";
  }
  if (subject.length > SUBJECT_CEILING) {
    return `the subject is ${subject.length} characters; ${SUBJECT_CEILING} is the hard ceiling and the median belongs under 30`;
  }
  if (subject.endsWith(".")) return "the subject ends with a period";

  const trailer = /^(co-authored-by:|generated with\b)|🤖/im.exec(text);
  if (trailer) return `the message carries a generated trailer (\`${trailer[0].trim()}\`)`;

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

function checkMrTitle(title: string): string | null {
  if (title.includes(EXPAND) || title.includes("\u0000")) return "the MR title is assembled by the shell; pass literal text";
  if (!title.trim() || /[\r\n\u2028\u2029]/.test(title)) return "the MR title must be nonempty and one line";
  if ([...title].length > SUBJECT_CEILING) return "the MR title exceeds 70 Unicode characters";
  return null;
}

function checkMrOptions(options: string[], create: boolean): string | null {
  let title = false;
  let description = false;
  for (const option of options) {
    if (option.includes(EXPAND) || option.includes("\u0000") || option.startsWith("$") || option.startsWith("`")) return "an MR push option is assembled by the shell; pass literal text";
    if (option === "merge_request.create") {
      create = true;
      continue;
    }
    if (option.startsWith("merge_request.title=")) {
      title = true;
      const broken = checkMrTitle(option.slice("merge_request.title=".length));
      if (broken) return broken;
    }
    if (option.startsWith("merge_request.description=")) {
      description = true;
      if (option.slice("merge_request.description=".length) !== "") return "the MR description must be exactly empty";
    }
  }
  if (create && (!title || !description)) return "MR creation requires an explicit literal title and empty description";
  return null;
}

function readMrRisk(cmd: Simple): string | null {
  const gitAt = cmd.findIndex((t) => t === "git" || t.endsWith("/git"));
  if (gitAt >= 0) {
    let i = gitAt + 1;
    const globalOptions: string[] = [];
    while (i < cmd.length && cmd[i].startsWith("-")) {
      const token = cmd[i++];
      if (token === "-c") {
        if (i < cmd.length) globalOptions.push(cmd[i++]);
      } else if (token.startsWith("-c") && token.length > 2) {
        globalOptions.push(token.slice(2));
      } else if (token === "-C" || token === "--git-dir" || token === "--work-tree") {
        i++;
      }
    }
    const action = cmd[i++];
    if (action !== "push" && action !== "config") return null;
    const options: string[] = [];
    for (const token of globalOptions) {
      if (/^push\.pushOption=/i.test(token)) options.push(token.slice(token.indexOf("=") + 1));
    }
    if (action === "config") {
      const rest = cmd.slice(i);
      const at = rest.findIndex((token) => /^push\.pushOption$/i.test(token));
      if (at < 0 || rest[at + 1] === undefined) return null;
      return checkMrOptions([rest[at + 1]], false);
    }
    while (i < cmd.length) {
      const token = cmd[i++];
      if (token === "-o" || token === "--push-option") {
        if (cmd[i] === undefined) return "a push option has no readable value";
        options.push(cmd[i++]);
      } else if (token.startsWith("--push-option=")) {
        options.push(token.slice("--push-option=".length));
      } else if (token.startsWith("-o") && token.length > 2) {
        options.push(token.slice(token[2] === "=" ? 3 : 2));
      }
    }
    return checkMrOptions(options, false);
  }
  const cliAt = cmd.findIndex((t) => /(?:^|\/)(gh|glab)$/.test(t));
  if (cliAt < 0) return null;
  const cli = cmd[cliAt].replace(/^.*\//, "");
  let groupAt = cliAt + 1;
  while (cmd[groupAt]?.startsWith("-")) {
    const flag = cmd[groupAt++];
    if (flag === "-R" || flag === "--repo" || flag === "--hostname" || flag === "-h") groupAt++;
  }
  if (cmd[groupAt] !== (cli === "gh" ? "pr" : "mr")) return null;
  const action = cmd[groupAt + 1];
  const create = action === "create" || action === "new";
  if (!create && action !== (cli === "gh" ? "edit" : "update")) return null;
  let title = false;
  let description = false;
  for (let i = groupAt + 2; i < cmd.length; i++) {
    const token = cmd[i];
    if (/^--(?:fill(?:-first|-verbose|-commit-body)?|template|editor|recover|attach|signoff|web|body-file|description-file|title-file)(?:=|$)/.test(token) ||
        /^-[A-Za-z]*[fe][A-Za-z]*$/.test(token) ||
        (cli === "gh" && /^-[FT](?:=|.|$)/.test(token))) {
      return "MR text from a file, template, editor or generated source cannot be checked";
    }
    let kind: "title" | "description" | null = null;
    let value: string | undefined;
    if (token === "--title" || token === "-t" ||
        (cli === "gh" && (token === "--body" || token === "-b")) ||
        (cli === "glab" && (token === "--description" || token === "-d"))) {
      kind = token === "--title" || token === "-t" ? "title" : "description";
      value = cmd[++i];
    } else {
      const long = /^--(title|body|description)=(.*)$/s.exec(token);
      const short = /^-([tbd])=?(.*)$/s.exec(token);
      if (long && (long[1] === "title" || long[1] === (cli === "gh" ? "body" : "description"))) {
        kind = long[1] === "title" ? "title" : "description";
        value = long[2];
      } else if (short && (short[1] === "t" || short[1] === (cli === "gh" ? "b" : "d"))) {
        kind = short[1] === "t" ? "title" : "description";
        value = short[2];
      }
    }
    if (!kind) continue;
    if (kind === "title") title = true;
    else description = true;
    if (value === undefined) return "MR text flag has no literal value";
    const broken = kind === "title" ? checkMrTitle(value) : value === "" ? null : "the MR description must be exactly empty";
    if (broken) return broken;
  }
  if (create && (!title || !description)) return "MR creation requires an explicit literal title and empty description";
  return null;
}

function collectMrRisks(src: string, depth = 0): string[] {
  const out: string[] = [];
  for (const simple of splitCommands(src)) {
    const risk = readMrRisk(simple);
    if (risk) out.push(risk);
    if (depth >= 2 || !WRAPPERS[(simple[0] ?? "").replace(/^.*\//, "")]) continue;
    for (const token of simple.slice(1)) {
      if (/\b(?:git|gh|glab)\b/.test(token)) out.push(...collectMrRisks(token, depth + 1));
    }
  }
  return out;
}

function readDanger(cmd: Simple): string | null {
  const gitAt = cmd.findIndex((t) => t === "git" || t.endsWith("/git"));
  if (gitAt < 0) return null;

  let i = gitAt + 1;
  let elsewhere = false;
  while (i < cmd.length && cmd[i].startsWith("-")) {
    const t = cmd[i];
    if (t === "-C" || /^--(git-dir|work-tree)(=|$)/.test(t)) elsewhere = true;
    i += t === "-C" || t === "-c" || t === "--git-dir" || t === "--work-tree" ? 2 : 1;
  }
  const rest = cmd.slice(i + 1);

  switch (cmd[i]) {
    case "add": {
      if (rest.some((t) => t === "-N" || t === "--intent-to-add")) return null;
      const sweep = rest.find((t) => t === "--all" || t === "--update" || ADD_SWEEP.test(t));
      if (sweep) {
        return `\`git add ${sweep}\` stages whatever else sits in the worktree, including work that is not yours; name the paths`;
      }
      if (rest.some((t) => t === "." || t === ":/" || t === "*")) {
        return "`git add` with a whole-tree pathspec stages work that is not yours; name the paths";
      }
      return null;
    }
    case "commit":
      if (!rest.includes("--amend")) return null;
      return elsewhere ? ELSEWHERE : AMEND;
    case "reset":
      return rest.includes("--hard")
        ? "`git reset --hard` throws away uncommitted work in the worktree, including work that is not yours"
        : null;
    case "push": {
      const forced = rest.find((t) => t === "-f" || t === "--force" || t.startsWith("--force="));
      return forced
        ? `\`git push ${forced}\` overwrites remote history; \`--force-with-lease\` refuses instead when the remote moved`
        : null;
    }
    default:
      return null;
  }
}

function collectDangers(src: string, depth = 0): string[] {
  const out: string[] = [];
  let moved = false;
  for (const simple of splitCommands(src)) {
    const name = (simple[0] ?? "").replace(/^.*\//, "");
    if (name === "cd" || name === "pushd" || name === "popd" || name === "chdir") moved = true;
    const risk = readDanger(simple);
    if (risk) {
      out.push(risk === AMEND && moved ? ELSEWHERE : risk);
      continue;
    }
    if (depth >= 2 || !WRAPPERS[name]) continue;
    for (const tok of simple.slice(1)) {
      if (!/\bgit\b/.test(tok)) continue;
      for (const nested of collectDangers(tok, depth + 1)) {
        out.push(
          nested === AMEND && FOREIGN[name]
            ? "`--amend` runs on another host or container, where HEAD cannot be checked from here"
            : nested === AMEND && moved
              ? ELSEWHERE
              : nested,
        );
      }
    }
  }
  return out;
}

async function amendRisk(pi: ExtensionAPI, cwd: string): Promise<string | null> {
  let head;
  try {
    head = await pi.exec("git", ["log", "-1", "--format=%H %P"], { cwd, timeout: 5000 });
  } catch {
    return "`--amend` cannot be checked because git did not run; verify HEAD yourself before rewriting it";
  }
  if (head.code !== 0) {
    return "`--amend` cannot be checked here because HEAD does not resolve; run it where the repository is";
  }
  const [sha, ...parents] = head.stdout.trim().split(/\s+/);
  const short = sha.slice(0, 7);
  if (parents.length > 1) {
    return `HEAD ${short} is a merge commit, so \`--amend\` would rewrite someone else's merge rather than your own work`;
  }
  const published = await pi.exec("git", ["branch", "-r", "--contains", sha], { cwd, timeout: 5000 });
  const branches = published.stdout.split("\n").map((l) => l.trim()).filter(Boolean);
  const on = branches.find((l) => !l.includes("->")) ?? branches[0];
  if (published.code === 0 && on) {
    return `HEAD ${short} is already published on ${on}, so \`--amend\` would rewrite history others have pulled`;
  }
  return null;
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
    if (source === null || !/\b(?:git|gh|glab)\b/.test(source)) return;

    const risks = collectDangers(source);
    let broken: string | null = collectMrRisks(source)[0] ?? risks.find((r) => r !== AMEND) ?? null;
    if (!broken && risks.includes(AMEND)) {
      const where = String(event.input.cwd ?? "");
      broken = await amendRisk(pi, where ? resolve(ctx.cwd, where) : ctx.cwd);
    }
    const found = !broken && COMMIT_TOKEN.test(source) ? collectInvocations(source) : [];

    for (const inv of found) {
      if (inv.exempt) continue;

      if (inv.indirect) {
        broken = `the message would come from ${inv.indirect} instead of the command line; pass the literal text in a single \`-m\` so what git records can be read`;
        break;
      }
      if (!inv.messages.length) {
        broken =
          "the commit carries no `-m`, so the message would come from git's editor buffer -- a template, a hook or a prepared `COMMIT_EDITMSG` -- and cannot be read here; pass the literal text in a single `-m`";
        break;
      }

      broken = checkMessage(inv.messages);
      if (broken) {
        const subject = inv.messages[0].split("\n")[0];
        if (!subject.includes(EXPAND)) broken = `${broken}\n\nSubject: ${subject}`;
        break;
      }
    }

    // An exec that did not parse is refused rather than trusted: a template
    // literal can carry the message in a variable that exists only at runtime.
    if (!broken && event.toolName === "eval" &&
        ((!found.length && EVAL_RISK.test(source)) || MR_EVAL_RISK.test(source))) {
      broken =
        "a commit, MR mutation or history rewrite driven from `eval` cannot be read as a command line; run it through the bash tool so the command is visible";
    }
    if (!broken) return;

    const reason = `Blocked: ${broken}\n\nAdjust the command and run it again. Commit convention: ${RULE}`;

    return { block: true, reason };
  });
}

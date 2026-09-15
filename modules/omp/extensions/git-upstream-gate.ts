import { execFileSync } from "node:child_process";

import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

// A feature branch created with `git checkout -B feature origin/master` keeps
// `origin/master` as its upstream, so a later bare `git push` targets master.
// The gate blocks a push whose real destination is not the branch of the same
// name, and warns right after a branch is created with a mismatched upstream.

const PROTECTED = /^(?:master|main|develop|trunk|RELEASE-.*|release\/.*|releases\/.*)$/;

/** Where a push would actually land, resolved from the repository. */
export type PushTarget = {
  /** Current local branch, or null on a detached HEAD. */
  local: string | null;
  /** Remote branch the push would update, or null when git decides at push time. */
  remote: string | null;
  /** How `remote` was obtained; carried into the block reason. */
  via: "refspec" | "push" | "upstream" | null;
};

export type Probe = (args: string[]) => string | null;

const SEPARATORS = /(?:\|\||&&|[;\n|])/;

export type Invocation = { args: string[]; cwd: string; local: string | null };

function resolve(base: string, dir: string): string {
  if (dir.startsWith("/")) return dir;
  if (dir.startsWith("~")) return dir;

  return `${base.replace(/\/+$/, "")}/${dir}`;
}

const SWITCHES = /^(?:checkout|switch)$/;

// Leave HEAD somewhere the name of a branch cannot be read off the argv.
const OPAQUE_SWITCH = /^(?:--|--detach|-d|-p|--patch|--orphan|--merge|-m)$/;

/** Branch a `git checkout`/`git switch` leaves HEAD on, or null when unclear. */
function switchedTo(argv: string[], at: number): string | null {
  for (let i = at + 1; i < argv.length; i += 1) {
    const arg = argv[i]!;
    if (OPAQUE_SWITCH.test(arg)) return null;
    if (arg.startsWith("-")) continue;

    return arg;
  }

  return null;
}

/**
 * Every `git push` in a shell line, with the directory and the branch it would
 * run on — an earlier `cd` or `checkout` in the same line has already happened
 * by the time the push runs, so the repository's current state is not it.
 */
export function pushInvocations(command: string, base: string): Invocation[] {
  const found: Invocation[] = [];
  let cwd = base;
  let local: string | null = null;

  for (const segment of command.split(SEPARATORS)) {
    const argv = segment.trim().split(/\s+/).filter(Boolean);

    if (argv[0] === "cd" && argv[1] && !argv[1].startsWith("-")) {
      cwd = resolve(cwd, argv[1]);
      local = null;
      continue;
    }

    const git = argv.findIndex((word) => word === "git" || word.endsWith("/git"));
    if (git === -1) continue;

    let at = git + 1;
    let chdir: string | null = null;
    while (at < argv.length && argv[at]!.startsWith("-")) {
      if (argv[at] === "-C") chdir = argv[at + 1] ?? null;
      at += argv[at] === "-C" || argv[at] === "-c" ? 2 : 1;
    }

    const sub = argv[at];
    if (sub && SWITCHES.test(sub) && !chdir) {
      local = switchedTo(argv, at);
      continue;
    }
    if (sub !== "push") continue;

    found.push({ args: argv.slice(at + 1), cwd: chdir ? resolve(cwd, chdir) : cwd, local: chdir ? null : local });
  }

  return found;
}

/** Directory a shell line ends up in, following its `cd` steps. */
export function finalCwd(command: string, base: string): string {
  let cwd = base;

  for (const segment of command.split(SEPARATORS)) {
    const argv = segment.trim().split(/\s+/).filter(Boolean);
    if (argv[0] === "cd" && argv[1] && !argv[1].startsWith("-")) cwd = resolve(cwd, argv[1]);
  }

  return cwd;
}

const NO_WRITE = /^(?:--dry-run|-n|--help)$/;

// Flags that swallow the following word, which is therefore not a refspec.
const TAKES_VALUE = /^(?:-o|--push-option|--receive-pack|--exec|--repo|--force-with-lease)$/;

/** Refspec destination of an explicit `git push <remote> <refspec>`, if any. */
export function refspecTarget(args: string[]): string | null | undefined {
  const positional: string[] = [];

  for (let at = 0; at < args.length; at += 1) {
    const arg = args[at]!;
    if (NO_WRITE.test(arg)) return undefined;
    if (TAKES_VALUE.test(arg)) {
      at += 1;
      continue;
    }
    if (arg.startsWith("-")) continue;
    positional.push(arg);
  }

  // [0] is the remote; a refspec may follow. `--all`/`--tags` leave none.
  const refspec = positional[1];
  if (refspec === undefined) return null;

  const colon = refspec.lastIndexOf(":");
  const dst = colon === -1 ? refspec : refspec.slice(colon + 1);

  return dst.replace(/^\+/, "").replace(/^refs\/heads\//, "") || null;
}

/** Resolves the destination of one `git push` from the repository state. */
export function resolveTarget(args: string[], probe: Probe, known: string | null = null): PushTarget | null {
  const local = known ?? probe(["symbolic-ref", "--short", "-q", "HEAD"]);

  const spec = refspecTarget(args);
  if (spec === undefined) return null; // --dry-run and friends write nothing
  if (spec !== null) return { local, remote: spec, via: "refspec" };
  if (!local) return { local, remote: null, via: null };

  for (const [suffix, via] of [
    ["@{push}", "push"],
    ["@{upstream}", "upstream"],
  ] as const) {
    const resolved = probe(["rev-parse", "--abbrev-ref", "--symbolic-full-name", `${local}${suffix}`]);
    if (!resolved) continue;

    // "origin/KID-4467" — the remote name itself may contain no slash.
    const slash = resolved.indexOf("/");

    return { local, remote: slash === -1 ? resolved : resolved.slice(slash + 1), via };
  }

  // No tracking configured: git either creates the same-named branch or refuses.
  return { local, remote: null, via: null };
}

const HOW = [
  "Point the branch at its own remote branch, then push:",
  "  git branch --unset-upstream",
  "  git push -u origin <branch>",
].join("\n");

/** The reason this push must not run, or null when it is safe. */
export function pushViolation(target: PushTarget): string | null {
  const { local, remote, via } = target;
  if (!remote || !local || remote === local) return null;
  if (PROTECTED.test(local)) return null; // deliberately working on the base branch

  const source =
    via === "refspec"
      ? "the refspec you passed"
      : via === "push"
        ? "this branch's push target (branch.<name>.pushRemote / push.default)"
        : "this branch's upstream";

  const danger = PROTECTED.test(remote)
    ? `That is a protected branch — the push would land ${local} straight in ${remote}.`
    : `Local branch and remote branch disagree, so the push would update the wrong branch.`;

  return [
    `local branch \`${local}\` would push to \`${remote}\` (${source}).`,
    danger,
    "",
    HOW,
  ].join("\n");
}

/** Upstream mismatch worth warning about after a branch was just created. */
export function upstreamWarning(probe: Probe): string | null {
  const local = probe(["symbolic-ref", "--short", "-q", "HEAD"]);
  if (!local || PROTECTED.test(local)) return null;

  const upstream = probe(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"]);
  if (!upstream) return null;

  const slash = upstream.indexOf("/");
  const remote = slash === -1 ? upstream : upstream.slice(slash + 1);
  if (remote === local) return null;

  return [
    `Upstream check: \`${local}\` tracks \`${upstream}\`, so a bare \`git push\` targets \`${remote}\`.`,
    HOW,
  ].join("\n");
}

const CREATES_BRANCH = /\bgit\b[^;|&]*\b(?:checkout\s+(?:-b|-B)|switch\s+(?:-c|-C)|branch\s+--set-upstream-to)\b/;

function commandOf(input: Record<string, unknown>): string {
  const command = input.command;

  return typeof command === "string" ? command : "";
}

function probeIn(cwd: string): Probe {
  return (args) => {
    try {
      const out = execFileSync("git", args, {
        cwd,
        encoding: "utf8",
        stdio: ["ignore", "pipe", "ignore"],
      });

      return out.trim() || null;
    } catch {
      return null; // no upstream configured, or not a repository
    }
  };
}

export default function gitUpstreamGate(pi: ExtensionAPI): void {
  pi.on("tool_call", (event, ctx) => {
    if (event.toolName !== "bash") return;

    const input: Record<string, unknown> = event.input;
    const base = typeof input.cwd === "string" && input.cwd ? input.cwd : ctx.cwd;

    for (const { args, cwd, local } of pushInvocations(commandOf(input), base)) {
      const target = resolveTarget(args, probeIn(cwd), local);
      if (!target) continue;

      const broken = pushViolation(target);
      if (broken) return { block: true, reason: `Blocked: ${broken}` };
    }
  });

  pi.on("tool_result", (event, ctx) => {
    if (event.toolName !== "bash") return;

    const input: Record<string, unknown> = event.input;
    const command = commandOf(input);
    if (!CREATES_BRANCH.test(command)) return;

    const base = typeof input.cwd === "string" && input.cwd ? input.cwd : ctx.cwd;
    const warning = upstreamWarning(probeIn(finalCwd(command, base)));
    if (!warning) return;

    return { content: [...event.content, { type: "text" as const, text: warning }] };
  });
}

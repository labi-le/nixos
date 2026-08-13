import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

// Enforces rules/code-comments.md on the agent instead of merely asking it to
// comply. Only the deterministic classes are gated -- a scaffolding marker,
// code parked behind a comment, and real production data -- because whether a
// comment is redundant is a judgement the rule text has to carry on its own.

const RULE = "~/.omp/agent/rules/code-comments.md";

type Syntax = "slash" | "hash" | "dash";

// Per language, because nix `//` is an update operator and a TypeScript `#x`
// is a private field: one shared comment syntax would refuse valid code.
const SYNTAX: Record<string, Syntax> = {
  ts: "slash", tsx: "slash", js: "slash", jsx: "slash", mjs: "slash",
  cjs: "slash", go: "slash", rs: "slash", c: "slash", h: "slash", cc: "slash",
  cpp: "slash", hpp: "slash", java: "slash", kt: "slash", kts: "slash",
  swift: "slash", cs: "slash", scala: "slash", zig: "slash", dart: "slash",
  php: "slash", nix: "hash", py: "hash", sh: "hash", bash: "hash",
  zsh: "hash", rb: "hash", pl: "hash", yaml: "hash", yml: "hash",
  toml: "hash", sql: "dash", lua: "dash", hs: "dash",
};

const MARKER = /\b(TODO|FIXME|XXX|HACK|WIP|TBD)\b/;
// Prose wraps with a trailing `;` in this tree, so a terminator alone proves
// nothing: a statement shape has to carry it.
const PARKED = [
  /^(?:[)\]}'"`]+;?|''\s*;)$/,
  /^["'[]?[A-Za-z_$][\w$.[\]"'-]*\s*=\s*.+;$/,
  /^["'[]?[A-Za-z_$][\w$.[\]"'-]*\s*=\s*[\w$.]+\(.*\)$/,
  /^(?:if|for|while|switch|return|import|export|from|def|class|fn|func|function|let|const|var|await|async|use|pub)\b.*[;{]$/,
  /^[\w$.]+\([^)]*\);?$/,
];

const EMAIL = /[A-Za-z0-9._%+-]+@([A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+)/g;
const SAFE_DOMAIN = /(?:^|\.)(?:example\.(?:com|org|net)|invalid|test|localhost)$/i;
const IPV4 = /\b(?:\d{1,3}\.){3}\d{1,3}\b/g;
const SAFE_IP =
  /^(192\.0\.2\.\d{1,3}|198\.51\.100\.\d{1,3}|203\.0\.113\.\d{1,3}|127\.0\.0\.1|0\.0\.0\.0|255\.255\.255\.255)$/;
const INTERNAL_HOST =
  /\b[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.(?:internal|intranet|corp|lan|prod|prd|stage|stg)\b/;
const HOME = /\/home\/([A-Za-z0-9._-]+)/;
const SAFE_HOME = /^(user|foo|bar|example)$/;
const CREDENTIAL = [
  /gh[pousr]_[A-Za-z0-9]{20,}/,
  /sk-[A-Za-z0-9]{20,}/,
  /AKIA[0-9A-Z]{16}/,
  /xox[baprs]-/,
  /eyJ[A-Za-z0-9_-]{10,}\./,
  /-----BEGIN [A-Z ]*PRIVATE KEY-----/,
];

function extensionOf(path: string): string {
  const base = path.slice(path.lastIndexOf("/") + 1);
  const dot = base.lastIndexOf(".");
  return dot === -1 ? "" : base.slice(dot + 1).toLowerCase();
}

type Scan = { comments: string[]; block: boolean };

/** Comment text on one line, with quote state tracked so a URL is not one. */
function scanLine(line: string, syntax: Syntax, first: boolean, inBlock: boolean): Scan {
  const comments: string[] = [];
  let block = inBlock;
  let quote = "";
  let i = 0;

  while (i < line.length) {
    if (block) {
      const end = line.indexOf("*/", i);
      comments.push(line.slice(i, end === -1 ? line.length : end));
      if (end === -1) return { comments, block: true };
      i = end + 2;
      block = false;
      continue;
    }
    const c = line[i];
    if (quote) {
      if (c === "\\") {
        i += 2;
        continue;
      }
      if (c === quote) quote = "";
      i++;
      continue;
    }
    if (c === '"' || c === "'" || c === "`") {
      quote = c;
      i++;
      continue;
    }
    if (syntax === "slash" && c === "/" && line[i + 1] === "*") {
      block = true;
      i += 2;
      continue;
    }
    if (syntax === "slash" && c === "/" && line[i + 1] === "/") {
      comments.push(line.slice(i + 2));
      break;
    }
    if (syntax === "hash" && c === "#") {
      if (first && i === 0 && line[1] === "!") break;
      comments.push(line.slice(i + 1));
      break;
    }
    if (syntax === "dash" && c === "-" && line[i + 1] === "-") {
      comments.push(line.slice(i + 2));
      break;
    }
    i++;
  }
  return { comments, block };
}

function realData(text: string): string | null {
  for (const re of CREDENTIAL) {
    const hit = re.exec(text);
    if (hit) return hit[0];
  }
  EMAIL.lastIndex = 0;
  for (let m = EMAIL.exec(text); m; m = EMAIL.exec(text)) {
    if (!SAFE_DOMAIN.test(m[1])) return m[0];
  }
  IPV4.lastIndex = 0;
  for (let m = IPV4.exec(text); m; m = IPV4.exec(text)) {
    if (!SAFE_IP.test(m[0])) return m[0];
  }
  const host = INTERNAL_HOST.exec(text);
  if (host) return host[0];
  const home = HOME.exec(text);
  if (home && !SAFE_HOME.test(home[1])) return home[0];
  return null;
}

/** Returns the rule the added lines break, or null when they are fine. */
export function checkAdded(path: string, added: string[]): string | null {
  const syntax = SYNTAX[extensionOf(path)];
  if (!syntax) return null;
  let block = false;

  for (let n = 0; n < added.length; n++) {
    const line = added[n];
    // A leaked token is a leak wherever it sits, so the line is checked whole.
    for (const re of CREDENTIAL) {
      const hit = re.exec(line);
      if (hit) {
        return `the added line carries a credential (\`${hit[0]}\`); never write a real token into the tree`;
      }
    }

    const scan = scanLine(line, syntax, n === 0, block);
    block = scan.block;

    for (const raw of scan.comments) {
      const text = raw.trim();
      if (!text) continue;

      const marker = MARKER.exec(text);
      if (marker) {
        return `the added comment carries a scaffolding marker (\`${marker[1]}\`); finish the work or delete the line`;
      }
      if (PARKED.some((re) => re.test(text))) {
        return `the added comment is commented-out code (\`${text.slice(0, 40)}\`); delete it, git remembers`;
      }
      const data = realData(text);
      if (data) {
        return `the added comment carries real data (\`${data}\`); use a neutral placeholder such as \`foo\`, \`bar\`, \`user@example.com\` or \`192.0.2.1\``;
      }
    }
  }
  return null;
}

type Candidate = { path: string; added: string[] };

const HEADER = /^\[(.+)#[0-9a-fA-F]{4}\]$/;
const MOVE = /^MV\s+(.+)$/;

/** Hashline patch: `+` rows under the section header they belong to. */
function fromHashline(src: string): Candidate[] {
  const out: Candidate[] = [];
  let current: Candidate | null = null;

  for (const line of src.split("\n")) {
    const header = HEADER.exec(line.trim());
    if (header) {
      if (current) out.push(current);
      current = { path: header[1], added: [] };
      continue;
    }
    if (!current) continue;
    const move = MOVE.exec(line.trim());
    if (move) {
      current.path = move[1].replace(/^["']|["']$/g, "");
      continue;
    }
    if (line.startsWith("+")) current.added.push(line.slice(1));
  }
  if (current) out.push(current);
  return out;
}

function fromAstEdit(content: string): Candidate[] {
  let parsed: unknown;
  try {
    parsed = JSON.parse(content);
  } catch {
    return [];
  }
  if (typeof parsed !== "object" || parsed === null) return [];

  const rawPaths = "paths" in parsed && Array.isArray(parsed.paths) ? parsed.paths : [];
  const target = rawPaths.find(
    (p): p is string => typeof p === "string" && SYNTAX[extensionOf(p)] !== undefined,
  );
  if (!target) return [];

  const added: string[] = [];
  const rawOps = "ops" in parsed && Array.isArray(parsed.ops) ? parsed.ops : [];
  for (const op of rawOps) {
    if (typeof op !== "object" || op === null || !("out" in op)) continue;
    const out = op.out;
    if (typeof out === "string" && out) added.push(...out.split("\n"));
  }
  return [{ path: target, added }];
}

const PATH_FIELD: Record<string, true> = { path: true, file: true, filename: true, target: true };

/** Every file a tool call would add lines to, whatever edit mode it uses. */
function collect(toolName: string, input: Record<string, unknown>): Candidate[] {
  if (toolName === "edit") return fromHashline(String(input.input ?? ""));

  let path = "";
  for (const [key, value] of Object.entries(input)) {
    if (PATH_FIELD[key] && typeof value === "string" && value) {
      path = value;
      break;
    }
  }
  const content = typeof input.content === "string" ? input.content : "";
  const replacement = typeof input.new_string === "string" ? input.new_string : "";
  const payload = content || replacement;
  if (!path || !payload) return [];
  if (path === "xd://ast_edit") return fromAstEdit(content);
  return [{ path, added: payload.split("\n") }];
}

export default function commentGate(pi: ExtensionAPI): void {
  pi.on("tool_call", (event) => {
    const input: Record<string, unknown> = event.input;

    let broken: string | null = null;
    for (const candidate of collect(event.toolName, input)) {
      broken = checkAdded(candidate.path, candidate.added);
      if (broken) break;
    }
    if (!broken) return;

    const reason = `Blocked: ${broken}\n\nAdjust the edit and run it again. Comment policy: ${RULE}`;

    return { block: true, reason };
  });
}

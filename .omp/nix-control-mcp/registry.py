from agenix import tool_secret_list, tool_secret_read, tool_secret_rekey, tool_secret_write
from config import HOSTS
from flake import tool_eval, tool_flake_age, tool_flake_update
from routes import tool_route, tool_route_file, tool_routes_audit
from rules import tool_rules
from system import (
    tool_diff_generations,
    tool_gc,
    tool_generations,
    tool_health,
    tool_rebuild,
    tool_rebuild_log,
    tool_rollback,
)

TOOLS = [
    {
        "name": "rebuild",
        "title": "nixos-rebuild",
        "description": (
            "Run nixos-rebuild for this flake (switch|boot|test|dry-activate|build). "
            "Mirrors the Makefile invocation (--impure --cores nproc). Runs detached, so it "
            "survives an MCP restart; returns the job id, exit code, first error and a log tail. "
            "Refuses when untracked .nix files exist, and refuses to activate another host."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["switch", "boot", "test", "dry-activate", "build"],
                    "description": "switch = make switch; boot adds --install-bootloader; build needs no root",
                },
                "host": {"type": "string", "enum": list(HOSTS), "description": "defaults to this machine"},
                "wait_s": {"type": "integer", "description": "seconds to wait before returning the job id (default 1800)"},
                "allow_untracked": {"type": "boolean", "description": "proceed despite untracked .nix files"},
            },
            "required": ["action"],
        },
        "annotations": {"readOnlyHint": False, "destructiveHint": True, "idempotentHint": False, "openWorldHint": False},
        "handler": tool_rebuild,
    },
    {
        "name": "rebuild_log",
        "title": "Rebuild job log",
        "description": "Tail the log of a rebuild/rollback/flake-update job started by this server. Omit job for the most recent one.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "job": {"type": "string", "description": "job id from rebuild"},
                "lines": {"type": "integer", "description": "log lines to return (default 80)"},
                "grep": {"type": "string", "description": "keep only lines matching this regex"},
            },
        },
        "annotations": {"readOnlyHint": True, "openWorldHint": False},
        "handler": tool_rebuild_log,
    },
    {
        "name": "eval",
        "title": "Evaluate nix",
        "description": (
            "Short-hand `nix eval` against this flake. `attr` is a path under the host's "
            "config, so `security.sudo.extraRules` expands to "
            "`.#nixosConfigurations.<host>.config.security.sudo.extraRules`; prefixes `hm.` "
            "(home-manager user config) and `options.` are understood, and any string "
            "containing `#` is used as a literal flake attr. `expr` instead evaluates a Nix "
            "expression with these bindings already in scope: flake, hosts, configs, config, "
            "options, pkgs, lib, hm - so no `builtins.getFlake` boilerplate. Returns parsed "
            "JSON by default, falls back to nix's own printer for values JSON cannot hold; "
            "raw=true gives `--raw` for strings. On a missing attribute it lists the "
            "available names of the parent."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "attr": {"type": "string", "description": "option path, hm.<path>, options.<path>, or a literal flake attr with #"},
                "expr": {"type": "string", "description": "nix expression; flake/hosts/configs/config/options/pkgs/lib/hm are pre-bound"},
                "apply": {"type": "string", "description": "nix function applied to the value, e.g. builtins.attrNames (attr mode only)"},
                "raw": {"type": "boolean", "description": "use --raw instead of --json (strings and paths)"},
                "host": {"type": "string", "enum": list(HOSTS), "description": "defaults to this machine"},
            },
        },
        "annotations": {"readOnlyHint": True, "openWorldHint": False},
        "handler": tool_eval,
    },
    {
        "name": "generations",
        "title": "System generations",
        "description": "List NixOS system generations with build date, nixos version and kernel.",
        "inputSchema": {
            "type": "object",
            "properties": {"limit": {"type": "integer", "description": "newest N generations (default 10)"}},
        },
        "annotations": {"readOnlyHint": True, "openWorldHint": False},
        "handler": tool_generations,
    },
    {
        "name": "rollback",
        "title": "Roll back one generation",
        "description": "Activate the previous system generation via nixos-rebuild switch --rollback. Requires confirm=\"yes\".",
        "inputSchema": {
            "type": "object",
            "properties": {"confirm": {"type": "string", "description": "must be \"yes\""}},
            "required": ["confirm"],
        },
        "annotations": {"readOnlyHint": False, "destructiveHint": True, "idempotentHint": False, "openWorldHint": False},
        "handler": tool_rollback,
    },
    {
        "name": "diff_generations",
        "title": "Diff two generations",
        "description": "nix store diff-closures between two system generations. Defaults to the previous generation vs the current one.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "from": {"type": "integer", "description": "older generation number"},
                "to": {"type": "integer", "description": "newer generation number (default: current)"},
            },
        },
        "annotations": {"readOnlyHint": True, "openWorldHint": False},
        "handler": tool_diff_generations,
    },
    {
        "name": "gc",
        "title": "Collect garbage",
        "description": (
            "sudo nix-collect-garbage: delete old generations of every profile, then sweep "
            "unreachable store paths. mode=full is `-d` (all non-current generations); "
            "mode=older_than is `--delete-older-than <days>d`. The current generation is always "
            "kept, but rollbacks to the deleted ones become impossible, so it needs "
            "confirm=\"yes\". dry_run=true previews and deletes nothing."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "mode": {
                    "type": "string",
                    "enum": ["full", "older_than"],
                    "description": "full = -d (default); older_than needs days",
                },
                "days": {"type": "integer", "description": "keep generations newer than this many days"},
                "confirm": {"type": "string", "description": "must be \"yes\" unless dry_run is set"},
                "dry_run": {"type": "boolean", "description": "report what would be deleted, delete nothing"},
                "wait_s": {"type": "integer", "description": "seconds to wait before returning the job id (default 1800)"},
            },
        },
        "annotations": {"readOnlyHint": False, "destructiveHint": True, "idempotentHint": False, "openWorldHint": False},
        "handler": tool_gc,
    },
    {
        "name": "flake_update",
        "title": "Update flake inputs",
        "description": (
            "nix flake update for all or selected inputs, then report which locked revisions moved. "
            "Rewrites flake.lock, so it requires confirm=\"yes\". Verify with rebuild action=\"switch\" afterwards."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "inputs": {"type": "array", "items": {"type": "string"}, "description": "input names; empty = every input"},
                "confirm": {"type": "string", "description": "must be \"yes\""},
                "wait_s": {"type": "integer", "description": "seconds to wait before returning the job id (default 900)"},
            },
            "required": ["confirm"],
        },
        "annotations": {"readOnlyHint": False, "destructiveHint": True, "idempotentHint": False, "openWorldHint": True},
        "handler": tool_flake_update,
    },
    {
        "name": "flake_age",
        "title": "Flake input age",
        "description": (
            "How stale a root flake input is. Resolves .nodes[.root].inputs.<name> in flake.lock, "
            "never the same-named transitive copy, and reports rev, date, age in days and the "
            "repo commit that bumped it."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "input": {"type": "string", "description": "root input name (default nixpkgs)"},
                "with_commit": {"type": "boolean", "description": "also find the bump commit (default true)"},
            },
        },
        "annotations": {"readOnlyHint": True, "openWorldHint": False},
        "handler": tool_flake_age,
    },
    {
        "name": "health",
        "title": "Unit health",
        "description": "Failed system and user units, plus the journal for one unit. Use after a switch to verify activation.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "unit": {"type": "string", "description": "unit name to fetch the journal for"},
                "lines": {"type": "integer", "description": "journal lines (default 60)"},
            },
        },
        "annotations": {"readOnlyHint": True, "openWorldHint": False},
        "handler": tool_health,
    },
    {
        "name": "route",
        "title": "Route a config task to a file",
        "description": (
            "Resolve a natural-language config task to the exact file(s) to edit, from "
            "docs/routes.md. Use this INSTEAD of glob/grep when locating a NixOS or Home Manager "
            "module. Returns ranked rows with section, host scope, notes and path existence."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "task in plain language, e.g. 'enable bluetooth on the laptop'"},
                "host": {"type": "string", "enum": list(HOSTS), "description": "restrict to rows applicable to this host"},
                "limit": {"type": "integer", "description": "max matches (default 5)"},
            },
            "required": ["query"],
        },
        "annotations": {"readOnlyHint": True, "openWorldHint": False},
        "handler": tool_route,
    },
    {
        "name": "route_file",
        "title": "Reverse route lookup",
        "description": "What a file owns according to docs/routes.md: matching concerns, sections and host scope. Use before editing a file, or to check whether a new module still needs a row.",
        "inputSchema": {
            "type": "object",
            "properties": {"path": {"type": "string", "description": "repo-relative path, e.g. modules/grafana.nix"}},
            "required": ["path"],
        },
        "annotations": {"readOnlyHint": True, "openWorldHint": False},
        "handler": tool_route_file,
    },
    {
        "name": "routes_audit",
        "title": "Routing table audit",
        "description": "Section map of docs/routes.md, plus rows of one section, dead path references and .nix files that have no row.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "section": {"type": "string", "description": "dump the rows of one section (prefix match on the heading)"},
                "validate": {"type": "boolean", "description": "report dead and unrouted paths (default true)"},
            },
        },
        "annotations": {"readOnlyHint": True, "openWorldHint": False},
        "handler": tool_routes_audit,
    },
    {
        "name": "rules",
        "title": "Agent rule files",
        "description": (
            "Inspect the omp agent rule files in home-manager/modules/omp: parsed frontmatter, "
            "the bucket each rule resolves to (ttsr, always-apply, rulebook, unreachable) and "
            "warnings for the silent failure modes (invisible rule, glob-shaped condition, "
            "alwaysApply plus description, body deduplicated against AGENTS.md). Use before "
            "editing a rule to check it will actually reach the model."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "name": {"type": "string", "description": "dump one rule in full, e.g. commit-style or RULES"},
                "validate": {"type": "boolean", "description": "report bucket warnings (default true)"},
            },
        },
        "annotations": {"readOnlyHint": True, "openWorldHint": False},
        "handler": tool_rules,
    },
    {
        "name": "secret_list",
        "title": "Agenix secrets",
        "description": (
            "Every secret declared in secrets.nix: recipients, whether the .age file exists, "
            "and which local private key could decrypt it. `decrypt_here: null` means no key on "
            "this host is a recipient, so that secret cannot be opened here at any privilege "
            "level. Also reports .age files with no rule and rules with no file."
        ),
        "inputSchema": {"type": "object", "properties": {}},
        "annotations": {"readOnlyHint": True, "openWorldHint": False},
        "handler": tool_secret_list,
    },
    {
        "name": "secret_write",
        "title": "Write an agenix secret",
        "description": (
            "Create or replace a secret with `age`, encrypting to the recipients declared for "
            "that path in secrets.nix. Needs no root and no editor, because encryption only uses "
            "public keys. It does NOT read the old value, so replacing an existing secret is "
            "destructive and needs confirm=\"yes\". Prefer `from_file` (absolute path outside the "
            "repo) over `content`, which would put the plaintext in the session transcript."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "repo-relative path exactly as keyed in secrets.nix"},
                "content": {"type": "string", "description": "plaintext; lands in the transcript"},
                "from_file": {"type": "string", "description": "absolute path outside the repo holding the plaintext"},
                "confirm": {"type": "string", "description": "must be \"yes\" to overwrite an existing secret"},
            },
            "required": ["path"],
        },
        "annotations": {"readOnlyHint": False, "destructiveHint": True, "idempotentHint": False, "openWorldHint": False},
        "handler": tool_secret_write,
    },
    {
        "name": "secret_read",
        "title": "Read an agenix secret",
        "description": (
            "Decrypt one secret and return its plaintext. Picks a recipient key readable "
            "without root when one exists; otherwise uses the host key via `sudo -A`, which "
            "pops a password prompt on the desktop — the password never passes through this "
            "server or the transcript. The decrypted value DOES land in the transcript, so it "
            "needs confirm=\"yes\"."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "repo-relative path as keyed in secrets.nix"},
                "confirm": {"type": "string", "description": "must be \"yes\""},
            },
            "required": ["path", "confirm"],
        },
        "annotations": {"readOnlyHint": True, "openWorldHint": False},
        "handler": tool_secret_read,
    },
    {
        "name": "secret_rekey",
        "title": "Rekey agenix secrets",
        "description": (
            "Re-encrypt secrets to the publicKeys currently declared in secrets.nix. Run it "
            "after adding or removing a recipient. Decrypts with a local recipient key, "
            "prompting for the sudo password on the desktop when only the host key qualifies. "
            "Plaintext never leaves the server process. Secrets no host key here can open are "
            "reported as skipped, not failed."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "paths": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "secrets to rekey; empty means every rule in secrets.nix",
                }
            },
        },
        "annotations": {"readOnlyHint": False, "destructiveHint": False, "idempotentHint": True, "openWorldHint": False},
        "handler": tool_secret_rekey,
    },
]

TOOL_INDEX = {tool["name"]: tool for tool in TOOLS}
PUBLIC_TOOLS = [{key: tool[key] for key in tool if key != "handler"} for tool in TOOLS]

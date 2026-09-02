---
name: service-docs
description: Use when writing or updating a docs/ file that describes a running service (resolver, proxy, gateway, monitor) — keeps it to gotchas, rejected alternatives, measured numbers and upstream links instead of prose. Also use after any change that falsifies something a doc claims.
---

# Service documentation

A service doc exists so the next operator does not rediscover what already
cost someone an evening. It is not an introduction to the service, and it is
not the module retold in sentences.

## Admission test

A paragraph stays only if it answers one of these four. Delete anything else.

| Question | Shape it takes |
|---|---|
| What surprised us? | the gotcha, and the symptom it produced |
| What did we reject? | one line for the choice, one for the reason |
| What did we measure? | the number, its conditions, its date |
| How is a claim rechecked? | the exact command, and what a wrong answer looks like |

If a competent operator could read it off `modules/<name>.nix`, it is not
documentation — cite the module path and move on. The config is the source of
truth for *what is set*; the doc is only for *what the config cannot say*.

## Never

- **Never paraphrase upstream documentation.** Link the exact manual page for
  every non-obvious option named. Get NixOS/Home Manager option text from the
  `nixos_nix` MCP tools and library docs from Context7, per
  `docs/nix-project-rules.md`; link the service's own manual for the rest.
- **Never narrate.** No "first we do X, then Y", no "as we can see", no
  restating the diff or listing touched files.
- **Never keep history that no longer changes behaviour** unless the reader
  would otherwise reintroduce the mistake. Then it is one line, dated.
- **Never carry a number across a change that invalidates it.** Re-measure, or
  say in the doc that it was measured under the old configuration and has not
  been re-measured. A stale figure is worse than none.

## Numbers

Every figure carries the conditions that produced it, or it is decoration:

```
319 MB resident, measured with 499 200 rules loaded, 2026-09-02
```

Counts, sizes and timings measured in a scratch or export tree describe that
tree. Never publish them as figures about the deployed system.

## Verification blocks

A doc's `## Verify` section is the part that rots fastest and is worth the
most. Each entry gives the command, the expected answer, **and the shape of a
wrong answer** — a command whose failure is silent teaches nothing.

State the discriminator, not just the command. Four ways a check answers a
different question than the one asked, all observed in practice:

| Trap | Why the answer was meaningless |
|---|---|
| `dig @<public resolver>` | port 53 is intercepted on-path; the reply never left the LAN |
| querying a resolver from `127.0.0.1` | untagged source, so `access-control-tag` policy did not apply |
| `systemctl cat <unit>` | prints the unit, not the script body that `ExecStart` points at |
| backgrounding a daemon without `-d` | `$!` is the parent that already exited, so the check watched the wrong process |

When a check has a trap like that, the doc says so next to the command.

## Size

A service doc is a reference, not an essay. Past roughly 150 lines it has
started narrating; past 40 lines in one section, that section has. When a doc
grows, the fix is deletion, not reorganisation.

Prose wraps at 80 columns. Tables may exceed it.

## Keeping it true

Update the doc in the same change that falsifies it, and name what changed:
which sentence, which number, which command. A doc nobody compiles against
rots silently, and the next operator acts on it.

Before claiming a doc is current, grep it for its own claims and recheck the
ones a reader would bet on — the option names, the counts, the log strings.

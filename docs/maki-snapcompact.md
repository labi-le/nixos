# Snapcompact plugin for maki

Research against maki 0.7.2 (`github:tontinton/maki`) and omp 19.0.1
(`github:can1357/oh-my-pi`). Current state of this repo: `modules/maki/init.lua`
sets `agent.compaction_buffer = "40%"`; omp uses
`compaction.methodOrder = [ "snapcompact" "shake" "remote" "soft" ]` in
`modules/omp/settings/config.nix:23`.

## Verdict

A real snapcompact compaction method cannot be added as a maki plugin. Maki
compaction is native and its plugin API cannot replace the summary or rewrite
the live history.

The manual `/snapcompact` command is implemented. It reads the session,
renders the older turns into PNG frames with `snapcompact-render`, and opens a
new session whose first user message carries those frames plus the recent
turns. The old session stays: the command runs inside it, so maki refuses the
delete, and the plugin flashes the reason and keeps it as the recovery path.
This is a handoff, not an in-place compaction: the session id changes and todos
and tool state are lost. There is no automatic trigger at the context threshold.

Automatic behavior needs an upstream maki change (or a fork): a slot that
returns ready content blocks in place of the LLM summary, or an API that
replaces the message history of a live session.

## maki 0.7.2 compaction surface

Maki reserves `agent.compaction_buffer` (repo value `"40%"`), summarizes older
turns with an LLM, and replaces them in the live log with the summary. Dropped
turns are archived under the session state directory. `/compact` triggers it
early, `MAKI_DISABLE_AUTOCOMPACT=1` disables the automatic pass, and the
`compaction` tier model writes the summary when one is assigned. See
`site/docs/content/context/_index.md`, section "When the window fills".

### Hooks

`agent.compact.before` fires before a compaction. Payload:
`{ reason, context_size, usable, request_instructions }`, where `reason` is
`auto`, `overflow`, `manual` or `requested`. A layer may return `skip=true`,
`defer=text`, `instructions`, or `continue`. `skip` is refused for `overflow`
because the run cannot continue without compacting. A layer can shell out
before it answers, but the decision itself cannot supply replacement content.

`agent.compact.prepare` fires before the transcript goes to the summarizer.
Payload: `results` (oldest first, each `{ index, tool, input, bytes, text }`,
`text` cut to 4 KB), `budget`, and `collapse` (indexes kept in full). The layer
may change `collapse`; maki applies the pick itself and cannot split a tool call
from its result.

Neither slot can add image blocks, replace the summary text, or move the run to
another session. Sources: `maki-agent/src/agent/hook.rs`,
`maki-agent/src/agent/compaction.rs`, `site/docs/content/hooks/_index.md`.

### Session API

Read paths: `maki.session.list`, `live`, `current`, `read`, `export`,
`messages`, `windows`, `subagents`. `export` returns the document
`{ format, model, mode, thinking, fast, title, facts, messages }`; image blocks
come back as `maki.image.Image` userdata, and JSON conversion produces
`{ type = "base64", media_type, data }`.

Write paths: `new`, `focus`, `delete`, `prompt`, `notify`, `set_mode`,
`set_title`, `request_compact`. There is no function that replaces or appends
to an existing session's message list. `maki.session.new` accepts a complete
document, including image blocks, and `focus=true` opens it in a tab. A
document with messages gets no permissions (`yolo`, session rules) from either
side, and thinking blocks and `thought_signature` are dropped. Under `maki -p`,
SDK and ACP, `new` with `prompt` or `focus` answers
`nil, "no interactive UI attached"`, so the manual flow is TUI-only.

`maki.session.request_compact` queues the same native compaction as
`/compact`, with optional guidance text. `agent.compact.before` still sees it
and may steer or skip it.

### Primitives a plugin can use

- `maki.api.register_command` registers a slash command with a handler.
- `maki.fn.jobstart` runs an external process (string through `bash -c`, or an
  argv table), returns a job id, and streams stdout/stderr through callbacks.
  `maki.fn.jobwait` returns `{ stdout, stderr, exit_code, truncated }`. There is
  no stdin option, so the plugin passes the request through a temporary file or
  argv.
- `maki.fs.write`, `read`, `read_bytes` and `maki.base64.encode` move the
  request and frames. `maki.image` exposes only `probe` and `decode`; it cannot
  encode PNG.
- Permissions: `run` for `jobstart`, `session_read` for `export`/`messages`,
  `session_write` for `new`/`focus`/`prompt`, `agent` for `prompt` and model
  turns, `fs_write` for the temporary request file.

## Manual `/snapcompact` (implemented)

1. Register `maki.api.register_command({ name = "snapcompact", ... })`.
2. `local id = maki.session.current()`, then
   `local doc = assert(maki.session.export({ session = id }))`.
3. Split `doc.messages`: keep the newest turns up to a byte budget, archive the
   rest. Maki does not expose per-message token counts here, so estimate from
   bytes or reuse the `usable` value from a future hook.
4. Serialize the archive to text with caps similar to omp: tool results
   truncated head and tail (about 2,000 chars, 0.6 head ratio), tool arguments
   capped per value and per call (about 500 and 2,000), tool output wrapped in
   `U+000E`/`U+000F` so the renderer draws it gray.
5. Flow the text before rendering: blank rows go, lines join with a space, and
   `--- N role ---` keeps its own row. `archive.txt` keeps the pretty form for
   the model to page through; `req.json` carries the flowed text.
6. Write `req.json` and `archive.txt` under
   `maki.env.state_dir()/snapcompact/<session>-<timestamp>/`, then call
   `maki.fn.jobstart({ "snapcompact-render", req_path, frames_dir })`. The
   renderer writes `frame-NNN.png` and `manifest.json`; the plugin reads them
   and base64-encodes the PNGs. `maki.session.data_dir()` is removed with the
   session, so the archive cannot live there.
7. Build a new document from `doc.facts` and metadata. The first user message
   is a short lead-in plus one image block per frame; the recent turns follow
   unchanged. Copy tables with `maki.deepcopy` so empty lists keep their tags.
8. `maki.session.new({ messages = newdoc.messages, facts = doc.facts, model =
   doc.model, mode = doc.mode, thinking = doc.thinking, fast = doc.fast, title =
   doc.title, focus = true })`.
9. Try `maki.session.delete({ id = old })` after `session.new` returns with
   `focus`. In practice maki refuses it: the command runs inside the old
   session, which is still the focused one, so deletion fails and the plugin
   flashes the reason and keeps it. That is the recovery path, and the text
   archive lives outside the session data directory, so it survives either way.

Pitfalls:

- New session has no permissions from the old one. The user re-approves tools.
- Todos, tool state, thinking blocks and `thought_signature` do not survive.
- Session id changes; anything keyed to it (hooks, cost rows, archives) splits.
- The old session stays. In the first live run `maki session list` still showed
  it: the delete is refused while that session is focused and running. The
  command flashes and keeps it rather than retrying. `archive.txt` is the
  recovery copy and lives under `maki.env.state_dir()`, not the session data
  directory.
- The 8x13 default now covers the whole transcript. Measured on the 9,468-line,
  437,628-char archive: flowed to 424,704 chars, it renders as 28 frames with
  `truncated: false` and 420,796 chars of visible text, about 88k tokens
  against 122k for the same text. Before the reflow and the per-glyph fallback
  it was 40 frames, 151,642 chars (34.7%), `truncated: true`, 125k tokens.
- `/snapcompact` takes `key=value` words: `frames=1..100`, `font=` one of
  5x8, 8x8, 6x12, 8x13, silver, `size=512..4096`, `columns=1..2`,
  `variant=bw|sent`. 6x12 covers Cyrillic and doubles the columns, so it is
  the densest safe pick for a Cyrillic archive.
- Maki sends at most 100 images per request and replaces the oldest 25 with a
  note past that; the command caps frames at 40.
- Providers bill images by area. A 1568 px frame is about 3.1k tokens; after
  the reflow the archive costs about 4.8 chars per token against 3.5 for text.
  Dense rows are the point of the format, so any change that keeps one archive
  line per rendered row gives the win back.
- Tool output is dimmed gray (`[128, 128, 128]`). Headers stay black. If OCR
  loses dimmed text, pass nothing and edit the serializer's `dim` gate.
- Vision is not preflighted. The command always tries; a text-only model answers
  with a provider error or loses the archive. `maki.agent.resolve_model` has no
  modalities, and `maki.model.info` does not expose `supports_vision`.
- Headless maki cannot open the new session; the command is TUI-only.

## Renderer

`pkgs/snapcompact-render` is a Rust CLI port of omp's native renderer. It keeps
the rasterization (`fontdue`, PNG encoding) and the fonts (5x8, 6x12, 8x13 BDF,
unscii-8, Silver), and drops N-API, the Lanczos stretch path and the TS
serializer and per-model shape table. `pkgs/snapcompact-render.nix` builds it
with `rustPlatform.buildRustPackage`.

A bitmap font keeps its own grid; a glyph it lacks is drawn from Silver inside
the same cell. The font switches wholesale only when the requested name is
unknown, where `fallback_font` takes over. Switching on coverage instead costs
2.4x: one box-drawing character used to force a 16 px grid at 98 columns.

Contract:

```text
snapcompact-render <req.json> <out-dir>
req:  { text, font, fallback_font, size, variant, columns, max_frames }
out:  frame-NNN.png, manifest.json { frames, truncated, font }
```

Defaults: `8x13` at 1568 px, `silver` fallback, `bw`, one column, 40 frames.
The serializer is Lua, with the caps in the manual section. Per-model shapes,
Lanczos and an explicit byte budget remain a follow-up.

Licenses: MIT for the omp code, public domain for the BDF and unscii fonts,
CC BY 4.0 for Silver with attribution in `pkgs/snapcompact-render/NOTICE`.

## Upstream change for automatic mode

The smallest useful change is a new slot, for example
`agent.compact.summarize`, where a layer returns content blocks
(`{ text, images }`) instead of the LLM summary. maki would place those blocks
in the compaction entry and continue in the same session. An alternative is a
`session.replace_messages(id, messages)` API that rewrites the live history
under the same session id.

With either change, a plugin can react to the compaction threshold, render the
archive locally, replace the summary, and keep todos, tool state and session
identity. Without it, `skip` only postpones the problem and `defer` only buys
one turn.

## Verification

- Renderer: `cargo test` in `pkgs/snapcompact-render`, 20 tests covering word
  wrap, pagination, Cyrillic, CJK fallback, `max_frames`, manifest and PNG
  output; `nix build` of the package through the overlay.
- Plugin: `nix run nixpkgs#lua5_1 -- modules/maki/tests/snapcompact_test.lua`,
  22 tests with a stubbed `maki`.
- Integration: `make switch`, then in a TUI session with a long transcript run
  `/snapcompact` and inspect `maki session export` for the new session: lead-in,
  image blocks, recent turns and `facts`. The old session is still listed, and
  `archive.txt` remains under the maki state directory.
- Headless: `maki -p` cannot open the new session; the command is TUI-only.

## Recommendation

The manual command is implemented and deployed on pc. Automatic snapcompact
still needs the upstream `agent.compact.summarize` slot. If OCR recall proves
insufficient, the next step is the per-model shape table and an explicit byte
budget, not a different plugin API.

## Sources

- maki hooks: `site/docs/content/hooks/_index.md`, `maki-agent/src/agent/hook.rs`,
  `maki-agent/src/agent/compaction.rs`.
- maki session API: `site/docs/content/lua-api/_index.md`,
  `maki-lua/src/api/session.rs`, `maki-lua/src/api/image.rs`.
- maki compaction behavior: `site/docs/content/context/_index.md`.
- omp compaction and snapcompact: `docs/compaction.md`, section
  "Snapcompact method"; `packages/snapcompact/README.md`;
  `packages/snapcompact/src/snapcompact.ts`; `crates/natives/src/snapcompact.rs`.
- Repo config: `modules/omp/settings/config.nix`, `modules/maki/init.lua`,
  `modules/maki/plugin.toml`, `modules/maki/lua/llm_labile.lua`.
- Implementation: `modules/maki/lua/snapcompact.lua`,
  `modules/maki/tests/snapcompact_test.lua`, `pkgs/snapcompact-render/`,
  `pkgs/snapcompact-render.nix`.

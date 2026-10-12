# buer — GitHub triage / fix bot

`buer` is [upstream robomp](https://github.com/can1357/oh-my-pi/tree/main/python/robomp)
run as-is: two containers on the server, wired to one webhook endpoint. It
triages every issue opened in the allowlisted repository, labels it, then either
reproduces and fixes it on a fresh branch with a PR whose body carries
`## Repro / ## Cause / ## Fix / ## Verification` and `Fixes #N`, answers a
question, or comments on a proposal. It also reviews pull requests opened by
someone other than the bot. Follow-up comments from `labi-le` resume the same
omp session on the same per-issue worktree.

## Why upstream-as-is instead of a Nix-native rewrite

The container *is* the trust boundary, and Nix cannot reproduce it cheaply:

- The orchestration process drops every agent subprocess to its own slot user
  (`omp-1`…`omp-N`, uid `2000+i`, shared gid `omp` 2000) created by
  `entrypoint.sh`. That only happens as root on Linux, so a host-native run
  either needs root plus N generated system users or loses per-task isolation.
- The PAT lives in the `buer-gh-proxy` container only, on an `internal: true`
  network, behind HMAC-signed requests with a ±30 s skew window. Host-native
  same-uid execution would let the agent read both the PAT and the HMAC key out
  of `/proc/<pid>/environ` and bypass the pre-publish gates.
- The pinned checkout supplies both the container's `omp` binary (built by
  `Dockerfile` stage `pi-base`) and the `omp_rpc` client robomp drives over
  `omp --mode rpc`; vendoring one rev keeps the RPC protocol and the client
  identical. Rebuilding `Dockerfile.robomp` in `dockerTools` would mean
  reimplementing the pi toolchain (bun, lazy rustup, pi-natives, the omp shim,
  the dashboard bundle) plus robomp's own slot users.

The pinned rev is `v18.8.9` — the same version `pkgs.omp` comes from
(`inputs.llm-agents`), so host and container agree on the agent build.

## Layout

| Path | Role |
|---|---|
| `modules/buer/default.nix` | NixOS module: images build unit, compose unit, nginx vhost, agenix secret, tmpfiles |
| `modules/buer/docker-compose.yml` | Upstream compose file with the dev-only bits removed (no `build:`, no host `HOME` mounts, no `extra_hosts`), one container-name rename, and per-service environment allowlists kept intact |
| `modules/buer/agent-AGENTS.md` | Global instruction file staged into the agent's `~/.agent/AGENTS.md` |
| `secrets/buer-env.age` | `GITHUB_TOKEN`, `ROBOMP_LITELLM_KEY`, `GITHUB_WEBHOOK_SECRET`, `ROBOMP_GH_PROXY_HMAC_KEY` — recipients in `secrets.nix` (server key) |

## Wiring

- **Source pin**: `fetchFromGitHub` on `can1357/oh-my-pi` tag `v18.8.9`,
  hash `sha256-t3OZP4E0mWFJU0RW3OMcGU2G52p5uasQdVPhITHnZec=`. That tree is the
  docker build context only. At runtime the `omp` shim runs the **image's own
  baked copy** (`PI_ROOT=/pi`), not a mounted checkout: `Dockerfile.dockerignore`
  keeps `**/node_modules` out of the build context, so a tree mounted from the
  store has no dependencies and the shim dies with
  `Cannot find module '@oh-my-pi/pi-tui/key-hint-format'`. The `pi-runtime`
  stage the images are built from (default target of `Dockerfile`) is the same
  rev plus `bun install --frozen-lockfile`, i.e. `/pi/node_modules` with the
  workspace links the CLI resolves.
- **Images**: `buer-images.service` builds `oh-my-pi/pi:v18.8.9` then
  `robomp:v18.8.9`. The unit is marker-guarded (`/drive/state/buer/image-rev`
  holds `path|pi-tag|bot-tag`), so boots and switches are no-ops until the pin
  or the tags change. First build compiles the Rust pi-natives inside the image
  and takes tens of minutes; `TimeoutStartSec=infinity`.
- **State**: `/drive/state/buer` on the ZFS `data/state` dataset is bind-mounted at
  `/data` — clone pool, per-issue worktrees, cargo toolchain/target caches,
  `robomp.sqlite`, JSON logs. Cargo caches matter here: murmur is a Rust repo, so
  every fix task builds it. The directory is created by `buer-images.service`
  (`install -d`), **not** by a `systemd.tmpfiles.rules` entry: tmpfiles refuses
  the path with `Detected unsafe path transition /drive (owned by labile) →
  /drive/state (owned by root)` and would silently create nothing, so a `d
  /drive/state/buer …` rule is dead weight here.
- **Model**: a LiteLLM virtual key (alias `buer-agent`) restricted to
  `deepseek-v4.1-flash`, injected as `ROBOMP_LITELLM_KEY`. The generated
  `models.yml` declares one provider, `llm-labile`, base URL
  `http://litellm:4000/v1` over the external docker network `litellm` that
  `modules/litellm` creates — not `https://llm.labile.cc`, because a container
  reaching the server's own public address depends on router hairpin NAT.
  `apiKey` is the env-var *name*, resolved by omp inside the agent subprocess.
- **Ingress** (vhost lives in `modules/nginx.nix`, helper `buer`):
  `buer.labile.cc` exposes exactly `/webhook/github` → `127.0.0.1:6543`; every
  other path answers 404. The dashboard is mounted for whitelisted sources
  only: `/ui/` strips the prefix onto robomp's root, and `/static/`, `/api/`,
  `/events`, `/issues` mirror the absolute URLs the SPA fetches, all under the
  same `include /var/lib/nginx/ip_whitelist.conf; deny all;` that every
  `internal = true` vhost uses. Plain 403, not the `@error404` remap: probes of
  this host would otherwise feed the `nginx-scan-404` jail (5 per 60 s, 5 h
  ban). `https://buer.labile.cc/ui` 302s to `/ui/`. Wildcard DNS for
  `*.labile.cc` already points at this host, so no record is needed. The bind
  port is written both here (`BUER_BIND_PORT`) and in the vhost — the same
  duplication `llm.labile.cc` carries.
- **Dashboard control surface**: `buer-replay-token` writes
  `/run/buer/replay-token.env` (`openssl rand -hex 32`, tmpfs, mode 0600) before
  `buer` starts; the value becomes `ROBOMP_REPLAY_TOKEN`, which gates robomp's
  `POST /api/trigger` (`triage` / `retry`), `POST /api/cancel`, `/replay` and the
  issue picker behind the `X-Robomp-Replay-Token` header. The SPA is handed the
  token inlined in the page it is served, so nobody types it and there is no
  agenix secret to rotate; it rotates on boot, which only means a long-lived tab
  needs a reload. `buer` requires the token unit and lists the file last in
  `EnvironmentFile`, so a missing file fails loudly instead of silently leaving
  the controls off; a blank `ROBOMP_REPLAY_TOKEN` disables the whole surface
  (`/api/trigger` then answers `404`).
- **Secrets reach the containers only through the compose allowlists**:
  `GITHUB_TOKEN` appears in `buer-gh-proxy`'s block alone; the orchestrator
  never sees it. `ROBOMP_GH_PROXY_HMAC_KEY` and `GITHUB_WEBHOOK_SECRET` are in
  both, as upstream requires.
- **External reviewer**: `ROBOMP_REVIEWER_BOTS=chatgpt-codex-connector`. The
  router matches the login after stripping `[bot]` (`_reviewer_bot_login`), so
  the value is the bare app slug. An inline review comment from a listed bot on
  a **bot-authored** PR arrives as `pull_request_review_comment.created`, is
  queued as `handle_review` with `directive=True`, and the bot amends the
  branch in response — no `@`-mention needed. Review *bodies* without inline
  comments (`pull_request_review`) have no route and are ignored. The mention
  that starts a review must come from an identity with a Codex account connected
  to GitHub: the bot's own `@codex review` is answered with "To use Codex here,
  create a Codex account and connect to github" and runs nothing (verified
  2026-10-12 on PR #163, reply three seconds after the ping; the rule that made
  the bot ping from `agent-AGENTS.md` was removed for that reason). Codex's
  review is also triggered without any mention by its own setting —
  `https://app.chatgpt.com/settings/code-review`, per-repository **Automatic
  review** under *Review code* plus the **Personal preferences** toggle and its
  **Review trigger** — and only there can it be made automatic; check that the
  trigger covers pull requests authored by others.
- **A failed hook delivery is silent and permanent**: GitHub does not retry,
  and a lost event leaves no trace past the delivery record — the request
  reaches neither container. Verified 2026-10-12: the first inline Codex review
  on PR #163 died at the edge with `500` and `use of closed network connection`,
  the proxy log had no line for it, `events` had no row, and the bot therefore
  never saw the finding. Detect with
  `gh api repos/<owner>/<repo>/hooks/<hook>/deliveries` — anything but `202` is
  a loss. Recover by re-POSTing a rebuilt event: take the comment body and id
  from `GET /repos/<owner>/<repo>/pulls/<n>/comments`, wrap it in the
  `pull_request_review_comment` shape the router reads
  (`comment.user.login`, `comment.body`, `pull_request.number`,
  `pull_request.user.login`, `repository.full_name`), HMAC-SHA256 the body with
  the proxy's `GITHUB_WEBHOOK_SECRET`, and send `X-GitHub-Event`,
  `X-GitHub-Delivery` (a fresh UUID, or the original GUID when it never
  arrived) and `X-Hub-Signature-256: sha256=<hmac>` to
  `https://buer.labile.cc/webhook/github`. The plain
  `/deliveries/<id>/attempts` redelivery is cleaner when the token has
  `admin:repo_hook` — neither the user's nor the proxy's token does today.
- **Delivery watchdog**: `buer-watchdog.service` (oneshot, three-minute timer)
  runs `modules/buer/watchdog.py` over two sources. The one that needs no
  privileges does the real work: it lists the repository's recent comments
  through the API and compares each of them with the robot's own `events` table
  (`payload_json LIKE '%issuecomment-<id>%'`), so a comment with **no row** is a
  delivery that never arrived and a row skipped with `rate limit` is a directive
  the router threw away — both are rebuilt from the API object, signed with
  `GITHUB_WEBHOOK_SECRET` and posted to `http://127.0.0.1:6543/webhook/github`,
  loopback so a replay never rides the path that lost the original. The
  admin-only deliveries list stays as a second source for tokens that can read
  it: the bot cannot, because GitHub refuses to raise a bot account to repository
  admin (`422 Cannot assign int8-ptr permission of admin`, verified 2026-10-12),
  so its `404` is an informational line rather than an error. State lives in
  `/var/lib/buer-watch/state.json` — one key per delivery and one per comment,
  with a 30-minute `retry_after` after a rate-limit drop — the per-run budget is
  five replays, the steady-state lookback is 900 s, and the first-ever run trims
  itself to 300 s so an install does not resurrect history. The delivery cap is
  `ROBOMP_RATE_LIMIT_DEFAULT=10` in `composeEnv` instead of upstream's 3, after
  three genuine Codex findings were dropped within one hour on 2026-10-12.
  `buer-images` and `buer` carry the same
  `RequiresMountsFor` under `[Service]`, where systemd logs it as an unknown key
  and ignores it; they keep it until a restart is cheap, because moving it
  restarts the compose stack.
- **Local patches over the pinned tag**: `robompSource` applies two textual
  substitutions, and only the robomp image builds from it — the pi image keeps
  building from the pinned checkout. (1) `max_event_history` in
  `python/robomp/src/worker.py` goes 50 000 → 500 000: `omp_rpc` retains every
  notification of the current turn and aborts the task with "Event history
  limit was exceeded" once the window rolls past the caller's `start_index`;
  the observed rate is ≈135 events/s, so the upstream 50 000 was already
  exhausted six minutes into a turn, while a 40-minute turn can reach roughly
  330 000 — the raised ceiling keeps about 1.5x headroom. The window holds
  parsed notification dicts, so the ceiling costs on the order of a few hundred
  megabytes per running task. (2) `time.localtime` in place of `time.gmtime`
  in the pretty console formatter of `python/robomp/src/logging_config.py`
  makes its prefix follow `TZ`; the JSON file handler keeps `time.gmtime`, so
  the JSONL stays UTC with a `Z` suffix, which is what the DB and the dashboard
  expect.
- **Time**: both containers take `TZ` from `config.time.timeZone`
  (`Europe/Moscow`, set in `modules/locale.nix`) and bind-mount the host
  `/etc/localtime`, so `date`, file mtimes and the offset on bot commits match
  the host instead of the image's built-in `Etc/UTC`.

## What it reacts to

Every agent run starts from a webhook delivery that `github_events.py` routes;
there is no polling and no generic "run a prompt on event X" switch, so a new
event type means a route upstream plus a webhook subscription here.

| Trigger | Task | Gates |
|---|---|---|
| `issues.opened` / `reopened` | `triage_issue`: classify → repro → fix → PR | repo in `ROBOMP_REPO_ALLOWLIST`; rate limits (OWNER/MEMBER/COLLABORATOR bypass) |
| `issue_comment.created` | resume that issue's session and answer; a maintainer **mention** or a configured reviewer bot turns it into an authoritative directive | `ROBOMP_MAINTAINER_LOGINS`, `ROBOMP_REVIEWER_BOTS` |
| `pull_request.opened` / `reopened` / `ready_for_review`, author ≠ bot | `review_pr`: `COMMENT` review with inline comments | `ROBOMP_PR_REVIEW_ENABLED` |
| `pull_request_review_comment.created` on a bot PR | amend that branch and push; a listed reviewer bot's comment is authoritative without a mention | PR authored by the bot; `ROBOMP_REVIEWER_BOTS` |
| `pull_request.closed` with `merged` | `cleanup_workspace`: drop worktree, local branch and caches | — |
| `workflow_run.completed` on the default branch or a `v…` tag whose commit starts with `ROBOMP_RELEASE_COMMIT_PREFIX` | `handle_release_ci`: repair a release whose CI failed, up to `ROBOMP_RELEASE_MAX_ROUNDS` rounds, `release_*` host tools | `ROBOMP_RELEASE_SENTINEL_ENABLED` (**off** here) and a `Workflow runs` hook subscription |
| question-type issue with no reply | close it | `ROBOMP_QUESTION_AUTOCLOSE_*` |
| `POST /api/trigger` / `POST /replay` | `triage` / `retry` an issue or a stored event | `ROBOMP_REPLAY_TOKEN`, i.e. the dashboard |

## GitHub-side prerequisites

1. `int8-ptr` (bot) must be a collaborator with **Write** on every repository in
   `ROBOMP_REPO_ALLOWLIST`; it is not a member of `labi-le`'s private repos and
   gets `404` until invited and the invitation is accepted.
2. The bot needs a **classic** PAT: a fine-grained token owned by a personal
   account can only be scoped to repositories that account *owns* — its
   "Repository access" picker offers only *Public repositories* and *All
   repositories (… you own)*, so `labi-le/murmur` cannot be selected at all and
   every API call returns `404 Not Found` even though the account is a write
   collaborator. Create the token at
   `https://github.com/settings/tokens/new` with scopes **`repo`** (and
   **`workflow`** if the bot may touch `.github/workflows`).
3. Repository webhook: payload URL `https://buer.labile.cc/webhook/github`,
   content type `application/json`, secret = `GITHUB_WEBHOOK_SECRET` from the
   agenix secret, events **Issues, Issue comments, Pull requests, Pull request
   reviews, Pull request review comments**. GitHub's `ping` must return `202`.
4. `ROBOMP_MAINTAINER_LOGINS=labi-le` is what lets your `@int8-ptr <text>`
   comments act as authoritative directives and keeps follow-up comments
   resuming the same session.
5. Repository setting **Automatically delete head branches** is on for
   `labi-le/murmur` (enabled 2026-10-12) — otherwise every merged
   `farm/<hex>/<slug>` branch outlives its PR. The two deletions are
   independent and harmless together: robomp queues `cleanup_workspace` on
   `pull_request.closed` with `merged: true` and removes the worktree plus the
   local branch, while a later reopen gets a fresh branch, so the remote one
   disappearing changes nothing for the next run.

## Operations

```sh
# state of the stack
systemctl status buer-images buer
journalctl -fu buer
curl -fsS http://127.0.0.1:6543/healthz

# dashboard, whitelisted sources only (LAN or the current MY_IP):
#   https://buer.labile.cc/ui/            from any allowed client
#   ssh -L 6543:127.0.0.1:6543 server     then http://127.0.0.1:6543/
#   Triage tab, per-task cancel and event replay are live: the page carries the
#   token buer-replay-token generated, so no header needs typing

# one-shot prompt against the gateway, exactly as the tasks do it
docker exec -e HOME=/srv/agent-home buer omp -p --model llm-labile/deepseek-v4.1-flash "say ok"

# rebuild images by hand (same commands the unit runs)
systemctl start buer-images

# re-enqueue a stored event / synthesize an issue event inside the container
docker compose --project-directory /nix/store/<flake-source> exec buer \
  robomp triage labi-le/murmur#<n>

# inspect durable state
sqlite3 /drive/state/buer/robomp.sqlite 'select state,count(*) from events group by state'
sqlite3 /drive/state/buer/robomp.sqlite 'select * from issues order by updated_at desc limit 5'
```

- Run container-side commands **without a login shell**: `docker exec buer omp …`
  is right, `docker exec buer sh -lc 'omp …'` fails with `bun: not found`
  because Debian's `/etc/profile` resets `PATH` and drops `/opt/bun/bin`.
- Changing the model, allowlist, bot login or author identity means editing the
  `let` block in `modules/buer/default.nix` and switching.
- Rotating the PAT or the LiteLLM key means re-encrypting `secrets/buer-env.age`
  (recipients already declared) and switching: the unit carries
  `restartTriggers` on that file's hash, so the containers are recreated with
  the new values. A bare `systemctl restart buer` is not available over ssh —
  polkit demands interactive authentication — and `docker restart` would be
  wrong here anyway, since a container keeps the environment it was created
  with.
- Bumping the pinned agent means changing `tag` and `hash` in the module; the
  marker changes and the next switch rebuilds both images.

## Known gaps

- The pre-publish gates upstream runs before `gh_open_pr` (`bun run fix`,
  `bun check`, `bun run test`) only fire when the repository defines them.
  `labi-le/murmur` has no `package.json`, so no gate runs there: the PR's
  `## Verification` section is the agent's own cargo/make run, not an enforced
  suite. Verify with the repo's `Makefile` targets rather than trusting the body.
- Reviews are submitted as `COMMENT` only (upstream never approves or requests
  changes) and a pull request authored by the bot is never reviewed by the bot —
  that path is dropped in `github_events.route` as `bot-authored PR`.
- The release sentinel is disabled; enabling it requires the *Workflow runs*
  webhook event, `Actions: Read` on the PAT, and the fact that it may push to the
  default branch and move an existing release tag.
- `ROBOMP_MAX_CONCURRENCY=2` on this host: each task may compile murmur, and the
  server is not a fast builder.

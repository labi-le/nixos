# litellm proxy on `server`

`modules/litellm/default.nix`. Two containers on one docker network:
`litellm-db` (`postgres:17`) and `litellm`
(`ghcr.io/berriai/litellm:main-stable`), published as `127.0.0.1:27015` and
proxied by `llm.labile.cc`. Keys, spend and models live in PostgreSQL, not in
the container, so they survive restarts, rebuilds and image updates.

jcode consumes the group as its default provider (`llm-labile` with model
`deepseek-v4.1-flash` in `modules/jcode/providers.nix`) on every host that
receives the master key, so interactive turns shuffle across the four accounts;
hosts outside the secret's recipients (fx516) keep the direct `opencode-go`
profile. That provider's model list is derived from the catalog
(`import ../litellm/models`), one entry per group, so a new group file appears in
jcode's `/model` picker without an edit here. omp
reaches the same gateway as provider `llm-labile` (`discovery.type = "litellm"`
over `https://llm.labile.cc/v1`, declared only on hosts that receive the master
key), so its roster, limits and prices come from the proxy's own metadata rather
than from a list here, and an OpenAI-backed group is dispatched over the
Responses route; it also authenticates against `byesu` and `closerouter`
directly.

## Model groups

Groups are data, not code: `modules/litellm/models/<group>.nix` holds one
group's upstream id, costs and capabilities, `models/default.nix` expands each
group into one deployment per account key, `config.nix` is the rest of the
generated `config.yaml`, and `default.nix` keeps the NixOS side (secrets,
containers, units). Adding a model is one new file under `models/`.

Three groups were served between 2026-10-10 and 2026-10-11; two are now, both
from `https://opencode.ai/zen/go/v1` with the same four account keys:

- `deepseek-v4.1-flash` — the four-account pool of `openai/deepseek-v4.1-flash`
  deployments, renamed from `opencode-go-pool` on 2026-10-10. The old name
  outlived the rename twice and is now gone entirely: first as a
  `router_settings.model_group_alias`, then — after the alias turned out to be
  load-bearing — as a real third group
  (`models/opencode-go-pool.nix`, a one-line import of the canonical record with
  `name` overridden) so that the two client keys scoped to it kept working:
  `vanya` (`omp/18.4.4`) and `anyouh` (`opencode/latest/2.0.25/cli`, sending the
  old name every few seconds). Both were deleted the same day and those keys were
  rescoped to `["deepseek-v4.1-flash"]`, so their clients only have to name the
  canonical model. Until they do they get
  `400 /chat/completions: Invalid model name passed in model=opencode-go-pool`
  with the master key, and `403 The requested model 'opencode-go-pool' is not
  available for this key` with a key scoped to a group.
- `step-5-preview` — `openai/step-5-preview-free`, the free Go-tier model
  (upstream publishes `step-5-preview-free`; the group name is deliberately
  shorter, and it is what `/v1/models` and the spend log show).

A model name is a contract with every client that sends it, and the alias
mechanism hid how hard it is to withdraw: `model_group_alias` resolved *before*
the key-permission check and appended its target to the candidate names
(`_can_object_call_model`), so a key scoped to `["opencode-go-pool"]` answered
`200` for `opencode-go-pool` and `403` for `deepseek-v4.1-flash` (measured
2026-10-10), while a key scoped to the canonical name could call the group
through either name. Nothing in the config said two live keys depended on the
old name — the evidence lives in `LiteLLM_VerificationToken.models` and in the
spend log's `model_group` column, and `GET /v1/models` answers it per key in one
call. With the alias gone each group name is exclusive: a key scoped to one
group answers `403` for the other and `400` for a name no group carries.

The free group's deployments carry `model_info.opencode_usage_metered = false`
and zero costs, and the pool-usage callback skips exactly those deployments:
the rolling/weekly/monthly windows meter the subscription, not the free model,
so benching a free deployment because the paid quota ran out would withdraw the
model for no reason. The callback benches *every* metered deployment that
shares an account key, which is what keeps the paid pool protected now that two
groups share the same four keys. The `/v1/usage` snapshot keeps its
`provider: opencode-go-pool` label: it names the account pool, not a model
group.

Error-driven cooldown is off for every deployment of both groups:
`models/default.nix` gives each deployment `model_info.cooldown_time = 0` and
`litellm_params.num_retries = 0`, so the `router_settings.cooldown_time = 600`
and `num_retries = 30` left in `config.nix` are defaults none of these eight
deployments reaches. Cooldown keys on the deployment id — one per account key —
not on the group or the request, which is why the reasoning below applies
identically to the free and the paid pool.

Error-driven cooldown was an amplifier, not a protection. On 2026-10-11 zen/go
answered `429 {"error":{"type":"server_error","message":"Upstream request
failed: Endpoint is unavailable."}}` for `step-5-preview-free` on all four
account keys at once (the string is zen's; it appears nowhere in the litellm
image), and litellm's retry loop re-picks a deployment after each cooldown, so
a *single* client request walked all four keys and benched all four. Measured
on this image with an isolated router, the same config shape and a 429-only echo
upstream: one `acompletion` made four upstream attempts and left four
600-second cooldowns, and the next request answered `RouterRateLimitError ...
All deployments for selected model are in cooldown` with exactly those four ids
in 16 ms. The group then stayed out of rotation for the whole window even after
zen recovered, and the message's `Try again in 600 seconds` is the *configured*
`cooldown_time` — `CooldownCache.get_min_cooldown` returns the stored value, not
the time remaining — so it read 600 with one second left. Both groups paid for
that: 4 139 `RouterRateLimitError` records for `step-5-preview` against 173 real
upstream failures (87 `Endpoint is unavailable`, 35 connection errors, 33 idle
timeouts, 10 per-key `Rate limit exceeded`, 7 5xx), in bursts of up to 1 588 an
hour; and 49 for the paid pool (40 logged under the canonical name, 9 under
`opencode-go-pool`, an alias at the time), whose entire origin was two
`InternalServerError`s at 01:09 that benched all four accounts from 01:09 to
01:16.

`cooldown_time = 0` makes `_should_run_cooldown_logic` skip the deployment
entirely, so nothing but the usage poller takes an account out of rotation. The
retry amplification the cooldown used to bound then has to come from
`num_retries`, and it must be set explicitly: the router default of 30 finds
nothing excluded once nothing is ever cooldowned, so left unset a single request
against a dead upstream makes 31 attempts. At `num_retries = 0` the pool-wide
walk is left to `enable_weighted_failover` — measured against the deployed
`config.yaml` with a 429-only echo upstream, an all-dead request makes 4
attempts, one per account key, against 16 with the retry count at 3, because the
weighted-failover layer re-walks all four keys once per retry (4 × (1 +
`num_retries`)) — and with exactly one account key dead all 40 requests
succeeded, 27 on the first attempt and 13 on a second. That keeps the failure
bound identical to the old cooldown-bounded one (one pass over `poolSize`)
without the 600-second blackout, and it couples both groups to
`enable_weighted_failover`: with that off, `num_retries = 0` is a single
attempt, so a request that happens to pick a broken account fails and the
deployments need `num_retries = poolSize - 1`.

Quota protection is the poller's, and it survives: `exhausted_window()` benches
a key whose window is `rate-limited` or at `OPENCODE_USAGE_LIMIT_PERCENT` (95)
by calling `cooldown_cache.add_deployment_to_cooldown` directly, a path that
does not consult `model_info.cooldown_time` — verified with `cooldown_time = 0`
on every deployment, where a bench added by hand kept that account out of 40
consecutive requests (0 served) while the other three took 14, 15 and 11.

The allowance itself belongs to the account key, not to the proxy and not to the
group: the four keys report their own percentages and their own reset instants —
2026-10-11, `rolling` 4/9/12/9 %, `weekly` 51/50/51/50 %, `monthly` 36/73/73/75 %
resetting `2026-11-02T20:30` for the first key against `2026-10-28T23:15`…`23:51`
for the rest — so each key is its own bucket and the pool multiplies the
allowance by four. `https://opencode.ai/docs/go/` sets the metered models'
limits as a monthly dollar amount per model, spent as 5-hour 20 %, weekly 50 %,
monthly 100 % of it, and lists `step-5-preview-free` (like
`longcat-2.5-preview-free`) as `Unlimited`, which is why the free group has no
plan quota to protect. Exactly two 429 flavours came back from zen/go for that
group, and they differ in scope. `Upstream request failed: Rate
limit exceeded. Please try again later.` — 10 records, all on one account key
(`08d8ea64…`, 2026-10-11 06:03:03…06:03:19) while the other three kept
answering — is a per-key throttle. `Upstream request failed: Endpoint is
unavailable.` — 87 records across all four keys (44/18/13/12) — is zen's own
upstream failing, which no extra key can route around. The paid group took no
limit 429 at all: its upstream failures were two 5xx, seven connection errors
and seven `BadRequestError`s, and every client-visible 429 it produced was the
cooldown record described above.

Capabilities live in the group files and are declared from measurements rather
than from a catalog: `maxInputTokens`, `maxOutputTokens`, `supportsVision`,
`supportsFunctionCalling` and `reasoningEffortLevels` become the group's
`model_info`, and litellm republishes them on `GET /model_group/info`
(`/v1/models` stays OpenAI-shaped and carries ids only) with `max_*_tokens`
taken as the maximum across the group's deployments. Measured 2026-10-10
against `zen/go` with a pool key: both models answer a 300k-token prompt
(300 036 / 300 017 prompt tokens), both describe an image sent as a data URI or
an https URL, both return `tool_calls` for a tools request, and every declared
level is accepted — except `none` on `step-5-preview`, which answers `400
Reasoning is mandatory for this endpoint and cannot be disabled`, so that group
declares six levels. `none` on `deepseek-v4.1-flash` really does switch
reasoning off (0 reasoning tokens, against 73–234 for the other six levels), and
the proxy forwards `reasoning_effort` untouched — `drop_params` does not cover
it, so a rejected level reaches the client as `litellm.BadRequestError` instead
of being silently dropped. `max_output_tokens` (384 000 / 65 536) is the one
number taken from models.dev and not probed here.

Prompt caching is the upstream's, not the proxy's: litellm only forwards the
request and prices the result from `cache_read_input_token_cost` (6.0e-9 against
3.0e-7 fresh input). Measured 2026-10-10 through this proxy with a 20 043-token
prompt: the first call reports `cached_tokens: 0` and costs $0.0060609, the next
ones report `cached_tokens: 19968` and cost $0.000190308 — 32× less. The cache
is not per account: six identical calls landed on four different deployments
(`x-litellm-model-id` in the response headers names the serving one) and every
one of them hit, so `simple-shuffle` across the four accounts costs nothing in
cache hits and `deployment_affinity` is not needed for them. The proxy's own
response cache is deliberately off — `GET /cache/ping` answers `503 Cache not
initialized. litellm.cache is None` — because an agent's prompts are unique
enough that an exact-match cache would only add staleness.

## ChatGPT subscription groups

Three groups — `gpt-6-astra`, `gpt-6-luna` and `gpt-6.1-sol` — are served from a
ChatGPT subscription of one account (`d74f3468-…`), not from the four-account
OpenCode Go pool: each is a single deployment of litellm's own `chatgpt/`
provider, which speaks to `https://chatgpt.com/backend-api/codex` with the
Codex-CLI client id and Codex headers. The catalog names the provider per group
(`provider = "chatgpt"` against `"opencode-go"`), and `models/default.nix`
expands only the pool groups into `poolSize` deployments: these have one
deployment each, no `api_base` and no `api_key` — the provider owns both — and
`model_info.mode = "responses"`, which is the surface the backend really
implements. `/v1/chat/completions` is bridged to it by litellm, and that bridge
is what our chat-completions-only clients call.

Auth is a device-code flow litellm runs by itself, lazily, on the first request
that needs the provider, so a `chatgpt/` model is uncallable until somebody
signs in:

1. `docker logs -f litellm` shows `Sign in with ChatGPT using device code:
   1) Visit https://auth.openai.com/codex/device 2) Enter code: XXXX-XXXXX`.
2. Open that URL, sign in, enter the code.
3. The request that was waiting completes, and litellm writes `auth.json`
   (`access_token`, `refresh_token`, `id_token`, `account_id`) to
   `~/.config/litellm/chatgpt`, mounted from `/var/lib/litellm-chatgpt`
   (root-only, `tmpfiles` `0700`). It then refreshes the access token with the
   stored refresh token; only a dead refresh chain asks for a code again, and
   that again needs a human.

The router health-checks the new deployments as it loads them, so the first
rebuild that adds these groups asks for a code at startup and **blocks the
whole proxy** until the code is answered — `/health/readiness` and every other
route wait with it, and `llm.labile.cc` answers `502` meanwhile. Do the login
right after that rebuild. Afterwards the token lives in the volume and survives
`make switch` (measured 2026-10-11: the container was recreated, kept the same
`auth.json`, and answered without a second sign-in).

Which models the subscription serves is not what litellm's cost map lists, and
the map is what the first pass over this catalog was built from: it declares 14
`chatgpt/` models, the newest of them the `gpt-5.6-*` three, so enumerating the
map finds those and misses everything newer. The authority is the provider's own
catalog — omp reads the same backend and prints it with
`omp models openai-codex --json` — and it lists exactly seven ids:

| group | max input | max output | effort levels | price per 1M in/out |
| --- | --- | --- | --- | --- |
| `gpt-6-astra` | 922 000 | 128 000 | `low`…`max` | $10 / $50 |
| `gpt-6-luna` | 872 000 | 128 000 | `low`…`max` | $0.10 / $0.50 |
| `gpt-6.1-sol` | 922 000 | 128 000 | `low`…`max` | $2 / $10 |

The five the catalog does not carry are deliberate: `gpt-6-sol` (872 000) is the
6.0 tier `gpt-6.1-sol` already covers, and `gpt-5.6-luna`, `gpt-5.6-sol`,
`gpt-5.6-terra` and `gpt-5.5` were never exposed. Any id outside those seven is
refused with `400 The '<model>' model is not supported when using Codex with a
ChatGPT account` — `gpt-5.3-codex` and `gpt-5.4` that the cost map does know,
and names that look newer but do not exist such as `gpt-6-terra` and
`gpt-6.1-luna`.

All three answer non-streamed and streamed `/v1/chat/completions` (measured
`pong` from each), return `tool_calls` with `finish_reason: tool_calls`, and
take `low`, `medium`, `high`, `xhigh` and `max`; the backend also tolerated
`none` and `minimal` on the 5.6 tier, but the provider's catalog declares those
five, so the groups declare those five. `usage` carries `reasoning_tokens` and
cached prompt tokens, and the prompt overhead is the Codex system instructions —
~1.6k tokens for a one-word answer, most of them cacheable.

Pricing comes from the provider's catalog, not from litellm's cost map, which
has no entries for these models at all; the three fields per group are
`inputCostPerToken`, `outputCostPerToken` and `cacheReadInputTokenCost`, taken
from the rates the subscription reports as `fixed` with `cacheWrite` at zero
(`gpt-6-astra` 1.0e-5 / 5.0e-5 / 1.0e-6, `gpt-6-luna` 1.0e-7 / 5.0e-7 / 1.0e-8,
`gpt-6.1-sol` 2.0e-6 / 1.0e-5 / 1.0e-7). Before those fields were set every call
was priced at zero and the spend log recorded `$0`; now the same one-word call
lands in `LiteLLM_SpendLogs` at `0.003324` on a cold prompt and `0.0006488` on a
cached one, and the response headers break it down — `x-litellm-response-cost
-input: 0.000458` (229 fresh tokens at 2e-6), `-cache-read: 0.0001408` (1 408
cached at 1e-7) and `-output: 5e-05` (5 tokens at 1e-5) — which is the
arithmetic above exactly. That cost is what consumes a key's budget, and it is
what makes the subscription's usage visible at all: the flat plan itself bills
nothing per call.

The provider mirrors every Codex response header back as `llm_provider-*`,
including the quota windows (`x-codex-primary-used-percent`,
`x-codex-primary-window-minutes`, `x-codex-turn-state`) and a `set-cookie` that
is ~900 bytes on its own; nginx's default header buffer is 4k and too small for
that set, so the vhost's `/` location sets `proxy_buffer_size 16k` with
`proxy_buffers 8 16k`. Without it every non-streamed call answers `502 Bad
Gateway` from Angie while litellm's own log says `200 OK` — the proxy never sees
the reason because the error is raised while reading response headers.

Two traps outside the repo's own state:

- Container DNS. `auth.openai.com` has to resolve through the router
  (`--dns=192.168.1.1` in the container's `extraOptions`): the host resolves
  through the local resolver, which answers a `198.18.1.0/24` fake-IP for the
  `vpn` rule-set (see `docs/dns-resolver.md`) and routes the connection through
  the router's tunnel, while Docker's generated `8.8.8.8` fallback answers the
  real Cloudflare address, the request leaves from the household address, and
  OpenAI refuses it with `403 {"error":{"code":
  "unsupported_country_region_territory"}}`. Measured from one container:
  `1.1.1.1` → `104.18.41.241` → `403`, `192.168.1.1` → `198.18.1.210` → `200`.
  `10.8.0.1` does not answer a container at all.
- The responses→chat bridge drops what it cannot parse:
  `litellm.APIConnectionError: ChatgptException - Unknown items in responses API
  response: []`, roughly one call in three when the backend answers with
  reasoning but no visible output item (seen at `low` and `medium` on `gpt-5.5`
  and `gpt-5.6-sol`, absent on retry). `retries = 2` in the three group files
  exists for it — a retry hits the same single deployment, which is why these
  groups carry a retry count while the pool groups deliberately carry none.

## The client session header

OpenCode Go asks every client for a stable per-conversation
`x-opencode-session` ("so we can optimize routing and prompt caching"). The
deployments send a deterministic per-account UUID in `extra_headers`, so the
header is never missing, but it is the same value for every conversation that
account serves. `modules/litellm/opencode-session.py` (mounted at
`/app/opencode_session.py` and registered as the second
`LITELLM_WORKER_STARTUP_HOOKS` entry) replaces it with the client's own value
when the client sends one, and leaves the per-account UUID in place when it does
not.

Two mechanisms were tried and only one works, measured 2026-10-11 on an isolated
litellm instance of the same image with an echo upstream, the same config shape
and the same plugin file:

- `general_settings.forward_client_headers_to_llm_api = true`, the documented
  way to pass client `x-*` headers upstream, changed nothing here: with it on
  and no plugin, the echo still received the deployment's `extra_headers` value
  for a request that carried `x-opencode-session`. It would also forward *every*
  client `x-*` header, not just the session.
- Setting `data["extra_headers"]` from a `CustomLogger.async_pre_call_hook`
  does reach the provider and wins over the deployment's `extra_headers` for
  that request. `data["headers"]`, the key the forwarding path writes, is inert
  — a first version of the plugin used it and the echo never saw the value.

On the probe, a request carrying `x-opencode-session:
REAL-CLIENT-SESSION-XYZ` arrived upstream as exactly that, and a request without
it arrived as `DEPLOYMENT-FALLBACK-UUID`. Live, `GET /v1/usage` now carries a
`sessions` block counting both branches (`{"client": 1, "fallback": 1}` after
one request of each kind), which is how to tell whether a given client sends the
header at all.

## Why containers instead of `services.litellm`

The nixpkgs package cannot talk to a database at all, in three separate ways:

- prisma-client-py needs a generated client, which the package never ships:
  `prisma.Prisma()` →
  `RuntimeError: The Client hasn't been generated yet, you must run 'prisma generate'`;
- engines have no NixOS build: `prisma --version` →
  `Precompiled engine files are not available for nixos … linux-nixos/schema-engine.sha256 - 404`;
- the versions are locked together: prisma-client-py 0.15.0 pins CLI `5.17.0`
  and engine `393aa359c9ad4a4bb28630fb5613f9c281cde053`, while nixpkgs ships
  only `prisma-engines_6` and `prisma-engines_7` (7.8.0).

The upstream image carries the prisma CLI at
`/opt/prisma/binaries/node_modules/.bin/prisma` and applies migrations during
startup, so the DB path works unmodified.

Rejected: fetching 5.17 engine binaries as fixed-output derivations and
running `prisma generate` ourselves (client/engine version match is a coin
flip); an nginx-level static token with no database (no expiry, budget or
revocation).

Measured 2026-10-01: the `main-stable` tag contained LiteLLM 1.103.2, while
the native nixpkgs package it replaced was 1.89.0. The tag floats; pin the
image by digest if that becomes a problem.

## Key lifecycle

The admin key is `LITELLM_MASTER_KEY` in `secrets/litellm-env.age`, deployed
as `/run/agenix/litellm-env`. Everything below was verified against the
deployed proxy on 2026-10-01, LiteLLM 1.103.2.

Create — the response contains the key exactly once and the API will never
show it again, so capture it before the shell prints anything else:

```
curl -sX POST https://llm.labile.cc/key/generate \
  -H "Authorization: Bearer $MASTER" -H 'Content-Type: application/json' \
  -d '{"key_alias":"friend","duration":"365d","models":["deepseek-v4.1-flash"]}'
```

Extend or shorten — `duration` sets the expiry to *now + duration*; it does
not add to the existing expiry. Measured: a key created with `duration: 1d`
and updated with `duration: 30d` moved from `now+1d` to `now+30d`.

```
curl -sX POST https://llm.labile.cc/key/update \
  -H "Authorization: Bearer $MASTER" -H 'Content-Type: application/json' \
  -d '{"key":"sk-…","duration":"365d"}'
```

Revoke — the row is deleted from `LiteLLM_VerificationToken`:

```
curl -sX POST https://llm.labile.cc/key/delete \
  -H "Authorization: Bearer $MASTER" -H 'Content-Type: application/json' \
  -d '{"keys":["sk-…"]}'
# {"deleted_keys":["sk-…"]}
```

Inspect: `GET /key/info?key=sk-…` returns `expires`, `models`, `spend`,
`max_budget`.

Permissions, measured with a model-scoped virtual key against the same
endpoints it may call: `/key/info` on itself `200`, `/key/update` on itself
`401`, `/key/delete` on itself `401`, `/key/list` `403`. So a handed-out key
can see its own spend and expiry but cannot extend or revoke anything, and
cannot enumerate other keys.

Creating, extending and revoking keys needs no rebuild — the master key and
the running container are enough. Changing models, router settings or the
pool-usage callback does need one: those are rendered by Nix and mounted
read-only at `/app/config.yaml` and `/app/opencode_go_usage.py`.

### What a client key can see

Measured 2026-10-11 with a throwaway key scoped to four groups: `/v1/models`
returned exactly those four ids, while `/model/info`, `/v1/model/info` and
`/v2/model/info` returned every deployment, including `step-5-preview`, which
that key answers `403 key_model_access_denied`. `/model_group/info`, the route a
LiteLLM-aware client reads first, is scope-filtered like `/v1/models`. A client
must therefore discover its roster rather than pin one — a hand-written list is
how you ship a model the proxy advertises and the key refuses.

The same measurement, from an omp client (`~/.omp/agent/models.yml`):

```yaml
providers:
  llm-labile:
    baseUrl: https://llm.labile.cc/v1
    api: openai-completions
    apiKey: sk-… # an env var name, a literal, or !command
    discovery:
      type: litellm
```

`api` is required by the schema for every discovery but `proxy` and acts only as
a fallback: verified on this proxy, `deepseek-v4.1-flash` leaves as
`POST /v1/responses`, so reasoning summaries survive. Management routes answer a
plain client key, so a scoped key still gets prices, limits and vision flags;
the roster is cached for two hours, and `omp models refresh llm-labile` re-reads
it after a rescope or a new group. One gap: omp shows no effort ladder for
`deepseek-v4.1-flash` although `/model_group/info` advertises
`supported_reasoning_efforts` from `none` to `max`; a client that wants
`/thinking` levels pins them with `modelOverrides`.

Verify: `omp models llm-labile --json` lists exactly the key's groups with
`pricingStatus: fixed`, and a group the key lacks is absent from it. A
`403 key_model_access_denied` on first use means the client pinned its roster
instead of discovering it.

jcode discovers too, through `model_catalog`, which reads the same live
`GET /v1/models` (`jcode provider add --model-catalog` writes the profile that
way, `/refresh-model-list` re-reads it inside a session). Measured 2026-10-11 in
an isolated `JCODE_HOME` with a profile carrying nothing but `base_url`,
`api_key_env` and `model_catalog`:
`jcode model list --provider-profile llm-labile-probe` returned all five groups
as `available`, and `jcode run` on `deepseek-v4.1-flash` answered. Two things the
catalog does not carry. Ids arrive bare — LiteLLM publishes
`id/object/created/owned_by` — so reasoning, context and effort still come from
the declared `models` entries, the same reason `space-bunny-free` is pinned by
hand in `modules/jcode/space-bunny.nix`. And a bare `openai-compatible` profile
without `default_model` selects a synthetic `anthropic/claude-sonnet-4`, which
this proxy rejects with `400 Invalid model name … Call /v1/models`. Minimal
profile in `~/.jcode/config.toml`:

```toml
[providers.llm-labile]
type = "openai-compatible"
base_url = "https://llm.labile.cc/v1"
api_key_env = "LITELLM_MASTER_KEY"
default_model = "deepseek-v4.1-flash"
model_catalog = true
supports_reasoning_effort = true

[[providers.llm-labile.models]]
id = "deepseek-v4.1-flash"
reasoning = true
context_window = 1000000
input = ["text", "image"]
```

A named profile is not a `-p` value; select it with
`--provider-profile <name>`, or choose it from `/model` in a session.

Measured against the deployed profiles on 2026-10-11, `jcode model list
--provider-profile <p> --json` returns the live rosters — 30 ids for `byesu`,
98 for `closerouter`, 5 for `llm-labile` — so the `[[providers.<p>.models]]`
blocks in `modules/jcode/providers.nix` are metadata overlays, not rosters.
Deleting them costs capability rather than staleness, and the reason is a key
mismatch rather than missing data: LiteLLM's `/v1/models` answers
`id/object/created/owned_by` plus `max_input_tokens`/`max_output_tokens`, and
byesu's answers `supported_endpoint_types` — none of them the `context_length` /
`max_model_len` / `architecture.input_modalities` keys jcode's catalog parser
reads, so the parsed cache (`$JCODE_HOME/cache/<profile>_models.json`) records
`context_length: null` and `input: []` even though the proxy does answer
`max_input_tokens: 1000000`. jcode asks only `/v1/models`: in the `docker-litellm`
journal the `/model_group/info`, `/model/info` and `/v2/model/info` requests come
from omp, never from jcode. jcode's models.dev integration is a *pricing* catalog
(`models_dev_pricing.json`, "models.dev pricing catalog"), not a capability one —
so context, modalities and the reasoning flag have no other source, and these
declarations only become unnecessary once one side learns the other's keys: the
jcode parser accepting LiteLLM's names, or a gateway-side `/v1/models` shim
emitting the OpenRouter-style ones. `closerouter` is the exception: its payload
carries `context_length`, `pricing` and `architecture.input_modalities`, which the
same cache shows parsed, and that is why its catalog also advertises image and
video ids (`black-forest-labs/*`, `bytedance/seedream-*`, `bytedance/seedance-*`)
alongside chat models.

## Keys and usage from the command line

`litellm-key` (`modules/litellm/litellm-key.nix`, installed by the litellm
module, so it exists only on `server`) talks to the proxy with the master key
from `/run/agenix/opencode-litellm-master-key`; override with `LITELLM_URL`,
`LITELLM_KEY_FILE` and `LITELLM_MODELS`:

```
litellm-key                 # alias, expiry, spend, budget, models, blocked
litellm-key logs 50         # last 50 request rows
litellm-key logs -f         # keep printing new rows, Ctrl-C to stop
litellm-key totals 7        # spend, tokens, requests per alias, last 7 days
litellm-key create vanya    # new key, 365 days, models from LITELLM_MODELS
litellm-key create guest 30 # 30 days instead of a year
litellm-key extend vanya 30d
litellm-key extend vanya -30d # 30 days off the current expiry
litellm-key budget vanya 5 1d # cap vanya at $5 per day
litellm-key budget vanya off  # remove the cap
litellm-key revoke vanya
```

The stored timestamps are UTC; the `time` column and the `totals` window line
are converted to the host zone (MSK), so `logs` reads like `date`.

`logs -f` polls `/spend/logs` every 5 seconds
(`LITELLM_FOLLOW_SECONDS`) and prints only request ids it has not shown yet,
which means a row appears roughly when litellm flushes it, not when the
request returns.

`create` prints the key exactly once, so it is the only moment that value can
be captured. `extend` and `revoke` accept either the alias or the full `sk-…`
value, and the proxy stores a key as `sha256(key)`, which is why an alias has
to be unique for them to work — the tool refuses and asks for the explicit
`sk-…` when two keys share one.

`extend` sets the expiry to now + DURATION for a positive duration, while a
negative one moves the *current* expiry back by that much: `extend vanya -30d`
takes 30 days off a key's remaining life and `extend vanya -400d` expires it
immediately, because the computed target is clamped at now and sent as a
non-negative duration. That translation is client-side by necessity — litellm's
parser is `(\d+)(mo|[smhdw]?)` and answers `400 Invalid duration format` for any
sign, and `UpdateKeyRequest` has no absolute `expires` field (a request that
carries one is silently ignored), so the only way to move an expiry backwards is
to restate the target as a duration from now. A key that never expires has
nothing to reduce, and the tool says so instead of guessing. This also takes
`-1` away from litellm, where `duration = "-1"` is a special case meaning "never
expires" — the opposite of what a minus sign suggests, and how a key silently
becomes permanent; a negative duration never reaches the proxy. DURATION is a
litellm duration (`30d`, `12h`, `2mo`), a bare number of days, or a negative
one; a negative `mo` counts 30 days.

`budget` rides litellm's `max_budget`/`budget_duration` pair through
`/key/update`, so an existing key can be capped without touching the running
container. Measured 2026-10-11 against the deployed 1.103.2, key capped at
`max_budget: 1e-09, budget_duration: 1d`: the first call answered `200`, the
second `429 Budget has been exceeded! Key=… Current cost: 3.58e-05, Max budget:
1e-09`. `_virtual_key_max_budget_check` compares the key's spend counter before
the current request's own cost lands, so a capped key overshoots its cap by
exactly one request, and the refusal is hard — the cap is a wall, not a warning.
`soft_budget` is the alert-only variant and `throttle_on_budget_exceeded` the
throttle one; neither is set here.

`budget_reset_at` is the next boundary, not the window's start: a key created at
23:39 UTC with `budget_duration: 1d` carried `2026-10-11 00:00:00`. One day
means the next `reset_time_of_day` in `litellm_settings.timezone` — both unset
here, so midnight UTC; `7d` means the next Monday and `30d` the 1st of the next
month, at the same time of day. It is a calendar boundary, not 24 hours from
creation and not a rolling window. The proxy's `reset_budget_job` zeroes the
key's `spend` and advances the timestamp, but only on its own tick —
`PROXY_BUDGET_RESCHEDULER_MIN_TIME` and `PROXY_BUDGET_RESCHEDULER_MAX_TIME` are
597 and 605 seconds, so the zeroing lands up to ten minutes *after* the
boundary and a capped key stays refused across that gap. Measured 2026-10-11 on
`vanya`: `spend 55.3917` with `budget_reset_at 2026-10-11 00:00:00` at 00:02:02
UTC, then `spend 0` with `budget_reset_at 2026-10-12 00:00:00` and `updated_at
00:02:59` — 2 m 59 s late. `spend` is the window counter, `total_spend` the
lifetime one: that reset left `total_spend` at 55.3917, which is what the
`total` column in `keys` shows while `spend` reads 0. Spend writes are batched
as well (`PROXY_BATCH_WRITE_AT`, 10 s), so the row trails the live counter by a
few seconds. The boundary is configurable —
`litellm_settings.timezone = "Europe/Moscow"` in `modules/litellm/config.nix`
puts it at MSK midnight — and that is a config change, so it needs the rebuild
that key administration otherwise does not.

zsh completion ships in the same package as
`share/zsh/site-functions/_litellm-key`, which the system zsh already has on
`fpath`, so it needs no shell configuration. Completing `extend`, `budget` or
`revoke` queries `/key/list` for the alias list on every tab press.

Revoking deletes the row; nothing keeps the key value, so a revoked key cannot
be restored, only replaced.

### Pricing

`spend` does not come from litellm's cost map — `openai/deepseek-v4.1-flash`
has no entry there, which is why every figure read `0.0000` until
2026-10-04. The deployments carry explicit costs in
`modules/litellm/models/deepseek-v4.1-flash.nix`, taken from the OpenCode Go
price list ([Go plans](https://opencode.ai/docs/go), read 2026-10-10), which
bills DeepSeek V4.1 Flash in two tariffs: **peak** — $0.30 per 1M input, $1.20
output, $0.006 cached read — and **off-peak**, exactly half: $0.15, $0.60,
$0.003. Peak hours are 01:00–04:00 and 06:00–10:00 UTC, Monday to Friday; every
other hour, weekends included, is off-peak.

The declared standard rates are the peak ones (`3.0e-7`, `1.2e-6`, `6.0e-9` per
token) and the half rates sit in `model_info.off_peak_pricing`, litellm's own
time-windowed pricing: `hours_utc` carries the three daily off-peak windows
(`00:00-01:00`, `04:00-06:00`, `10:00-00:00` — a window that ends at midnight
wraps, so it means 10:00–24:00) and `windows` adds the weekend, where the whole
day is off-peak, as `weekdays = [ "sat" "sun" ]` with an equal-ended
`00:00-00:00` window. An off-peak rate *replaces* the standard rate while a
window is open rather than discounting it, and any rate left unset falls back to
the standard one.

Nothing recomputes this by hand: `spend` is already the tariff that applied when
the request was logged. Verified 2026-10-10 on the deployed proxy — rows logged
before the change read exactly the peak figure (`191730`/`632` tokens →
`0.001942296`), rows after read exactly half (`205278`/`1622` →
`0.001640484`), and a 39/32-token request logged `2.505e-05`, which is
`39×1.5e-7 + 32×6e-7`. The window logic was also checked against the deployed
block at twelve timestamps: Mon 01:30, 02:00, 07:00 and 09:59 peak; Mon 00:30,
05:00, 10:00, 23:59, Fri 23:00, Sat 02:00, Sat 09:00 and Sun 23:00 off-peak.

The number is a billing equivalent, not money the pool actually charges: the
four accounts are a flat subscription, and Zen reports consumption only as a
percentage of the rolling, weekly and monthly windows
(`https://opencode.ai/zen/go/v1/usage`).

Rows written before 2026-10-04 stay at `0` — cost is computed when the request
is logged and never rewritten. Verified on a fresh request: 32 prompt and 3
completion tokens produced `1.32e-05`, exactly `32×3.0e-7 + 3×1.2e-6`. The CLI
prints anything below `0.0001` in scientific notation, so a live row reads
`1.32e-05` rather than `0.0000`.

Traffic authenticated with the master key — everything omp and jcode send — is
logged under the alias `master`, and a key hash that matches no key in the DB
shows as `other`; neither is a virtual key.

## Pool quota API

`GET /v1/usage` is served by the proxy itself (`modules/litellm/opencode-usage.py`,
installed through `LITELLM_WORKER_STARTUP_HOOKS`), not by any upstream. It
reports the four OpenCode Go accounts as one shared pool, because the quota
belongs to the accounts and every key spends the same four:

```json
{
  "provider": "opencode-go-pool",
  "plan": "OpenCode Go",
  "fetched_at": "2026-10-04T20:41:27Z",
  "usage": {
    "rolling": {"percent": 68, "status": "ok", "resetsAt": "2026-10-04T21:00:00Z"},
    "weekly": {"percent": 75, "status": "ok", "resetsAt": null},
    "monthly": {"percent": 25, "status": "ok", "resetsAt": null}
  },
  "key": {"alias": "friend", "spend_usd": 1.23, "max_budget_usd": null, "expires_at": null}
}
```

`rolling` is the 5-hour window, `weekly` the 7-day one, `monthly` anchors on the
subscription anniversary. `percent` is the mean across accounts that answered, so
it reaches 100 only when the whole pool is spent; `status` becomes `rate-limited`
only then, and `resetsAt` is the earliest reset among the throttled accounts.
`key` is that key's own litellm spend, separate from the shared pool quota.

Any key works: a `/key/info` lookup against the proxy authenticates the bearer,
so a model-scoped virtual key sees the pool quota plus its own spend, and the
master key sees the quota with an empty `key` block. The route 503s with
`Retry-After: 30` until the first poll (at most one interval after start).

The same poller drives the cooldown that keeps a spent account out of rotation,
and refreshes at most every `OPENCODE_USAGE_SYNC_SECONDS` (120s). The poller has
exactly one entry point, the startup hook: an earlier revision also registered
it as a config `callbacks` entry, which litellm loads by path under the module
name `/app/opencode_go_usage`, not importable, so the callback loader crashed
the proxy. Keep the module a plain module with `install_usage_route` and no
`CustomLogger` subclass.

Verify cooldown against a real router rather than the live log, since a spent
account is usually cooldowned by its own 429 before the poller sees it:

```sh
docker exec litellm python3 -c '
from litellm.router import Router
import yaml
r = Router(model_list=yaml.safe_load(open("/app/config.yaml"))["model_list"], cooldown_time=600)
r.cooldown_cache.add_deployment_to_cooldown(
    model_id=r.model_list[0]["model_info"]["id"],
    original_exception=Exception("probe"), exception_status=429, cooldown_time=600)
print(r.cooldown_cache.get_active_cooldowns(
    model_ids=[d["model_info"]["id"] for d in r.model_list], parent_otel_span=None))'
```

`totals` reads the whole request log and filters locally. Do not swap it for
`/spend/logs?start_date=…&end_date=…`: with dates that endpoint switches shape
and returns a per-day aggregate, including days with no traffic, so counting
requests from it silently under-reports.

## Gotchas

`LITELLM_SALT_KEY` must never change: it encrypts provider credentials stored
in the database, upstream documents no rotation, and a new value produces
`Error decrypting value, Did your master_key/salt key change recently?`
([deploy docs](https://docs.litellm.ai/docs/proxy/deploy)). It is generated
once, in the same secret as `DATABASE_URL`.

The vhost carries no IP restriction since commit `93392bf`, so a key is the
only gate. Every key spends the same four `deepseek-v4.1-flash` accounts.

The data directory `/var/lib/litellm-db` is `999:999` mode `700`. On the host
uid 999 is a dynamic user named `nm-iodine` — identical number, unrelated
name, no effect on the bind mount.

The container gets its secrets as environment variables, so anything running
inside it can read them; that is why the master key never needs to enter the
container's own config.

The ChatGPT groups bill the same subscription the agent's own `openai-codex`
login uses, so their calls compete with it for the plan's Codex windows: the
provider reports the state on every response
(`x-codex-primary-used-percent`, `x-codex-primary-window-minutes`), and the
proxy copies those headers to the client as `llm_provider-x-codex-*`.

Every key may call the three groups. A key created without a `models` list is
unrestricted and needs nothing; the two scoped client keys carry
`["deepseek-v4.1-flash", "gpt-6-astra", "gpt-6-luna", "gpt-6.1-sol"]` since
2026-10-11 (`vanya`, `anyouh`; verified with a throwaway key scoped to one GPT
group, which answers 200 for it and 403 for `deepseek-v4.1-flash`). Because the
groups now carry real rates, their calls consume a key's budget — `anyouh` sat at
$1.88 of $5 — and `gpt-6-astra` is the expensive one at $10/$50 per million
against `gpt-6-luna`'s $0.10/$0.50, so a runaway key is bounded only by its
`max_budget`.

`/var/lib/litellm-chatgpt/auth.json` is a live OAuth refresh token for that
account, root-owned inside a `0700` directory. It is deliberately not in
agenix: litellm rewrites it whenever it refreshes, so a secret managed by the
repo would be overwritten in place. Deleting the volume means one more device
login.

## Verify

- Containers up: `docker ps --filter name=litellm --format '{{.Names}} {{.Status}}'`
  → both `litellm-db` and `litellm` `Up`. Only `litellm-db` means the proxy
  died; read `journalctl -u docker-litellm -n 50`.
- Migrations ran: `journalctl -u docker-litellm | grep 'All migrations have
  been successfully applied'`. Missing, together with `prisma` errors, means
  the DB was unreachable; confirm with
  `docker exec litellm-db pg_isready -U litellm`.
- A key actually works:
  `curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $KEY"
  https://llm.labile.cc/v1/models` → `200`; `401` revoked, expired or typo'd;
- `502` the container is down; `404` would mean the IP whitelist is back on
  the vhost.
- The ChatGPT groups answer:
  `curl -s -X POST https://llm.labile.cc/v1/chat/completions -H "Authorization:
  Bearer $MASTER" -H 'Content-Type: application/json' -d '{"model":"gpt-5.6-sol",
  "messages":[{"role":"user","content":"say pong"}]}'` → `"content":"pong"` with
  `llm_provider-x-codex-*` headers on the response. `502` from Angie with
  litellm logging `200 OK` means the header buffers above are missing; a
  `chatgpt_exception` about a missing token means the device login has not been
  done (watch `docker logs -f litellm` while calling it).
- Keys are in the DB, not in process memory:
  `docker exec litellm-db psql -U litellm -d litellm -c 'select key_alias,
  expires, models, spend from "LiteLLM_VerificationToken";'`
- Trap: `systemctl cat docker-litellm` prints the unit, not the `docker run`
  line — the arguments are in the `ExecStart` script it points at. Use that
  script path, or `docker inspect litellm` for the effective mounts and
  network.

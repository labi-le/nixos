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

Four groups are served from `https://opencode.ai/zen/go/v1` with the same four
account keys; a fifth, `opencode-go-pool`, was a rename shim deleted on
2026-10-11:

- `beam-free` — `openai/beam-free`, one of the two rows the Go plan lists as
  `Free / Unlimited` (limited time), and the only free Go id that is not shared
  with the Zen tier. Costs are zero, so the group exists for reach, not for
  accounting. Measured 2026-10-16 through the deployed route: `tool_calls` come
  back for a tools request, images are refused upstream (`Beam supports text
  input only`), and `reasoning_effort` is accepted for `low`…`max` but rejected
  with `400 unsupported_value` for `minimal`, `none` and `off`, which is the
  ladder the group declares. Limits 1 048 576 in / 131 072 out (models.dev,
  `opencode-go`).
- `longcat-2.5-preview-free` — `openai/longcat-2.5-preview-free`, the other
  `Free / Unlimited` Go row, and the same request shape: `tool_calls` work,
  `reasoning_effort` covers `minimal`…`max` (`none` and `off` are answered with
  a 200 and no content, so no level below `minimal` is declared), limits
  1 000 000 in / 131 072 out. Images are sent but not seen: a red, a blue and a
  green 64×64 square all came back as `White`, `Black` and `pink`, while the
  same three images through `deepseek-v4.1-flash` answered `Red`, `Blue` and
  `Green`, so the group declares `supportsVision = false`.
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
- `step-5-preview` — the second four-deployment group over the same four
  account keys. Its upstream is `openai/step-5-preview` since 2026-10-16, when
  the Go tier withdrew the `step-5-preview-free` id and published a priced
  `step-5-preview` row in its place (see Pricing). The group name was already
  that id, so no client had to change, and the deployments that still named
  `openai/step-5-preview-free` answered every request with
  `400 Upstream request failed: Model is unavailable.` (`/models` dropped the
  free id in the same release; the `space-bunny-free` → `space-bunny` rename of
  2026-10-08 was the first of these).
- `deepseek-v4.1-flash-free`, `space-bunny-free`,
  `muse-spark-1.2-contributor-free` and `muse-spark-1.3-contributor-free` — the
  Zen tier's free set, one deployment each, with no account of ours attached
  (see the gate below). Measured 2026-10-17 through that gate:
  `deepseek-v4.1-flash-free` takes `reasoning_effort` `none`…`max` (200 000 in /
  32 000 out), `space-bunny-free` `minimal`…`max` (1 048 576 / 524 288),
  `muse-spark-1.2-contributor-free` `minimal`…`xhigh` and
  `muse-spark-1.3-contributor-free` `minimal`…`max` (1 048 576 / 131 072 each).
  All four call tools (`bash` comes back as a `tool_calls` entry; the muse pair
  accepts only `tool_choice: "auto"`) and all four read images (a red, a blue and
  a green square answered `Red`, `Blue`, `Green`).

The Zen tier's free ids are gated by client identity rather than by
entitlement, and this catalog serves four of them anyway. A plain request gets
`403 FreeTierError`, `OpenCode's free tier can only be used from within
OpenCode`; the same body answers `200` once it carries a `User-Agent` whose
leading token is `opencode/…`, a session header shaped
`ses_<12 lowercase hex><14 alnum>` whose head's low 12 bits land in
`0xfc0…0xfff` (the range OpenCode's own descending-id generator produces for
counters 0–63, so a digest-derived head passes roughly 2 % of the time and looks
intermittent), `stream: true` and two of OpenCode's core tool names (`bash` +
`read` are enough). `Authorization: Bearer public` passes the same gate, which
is why these groups carry `api_key = "public"` and none of our accounts is
attached to their requests. `muse-spark-1.2-`/`-1.3-` answer only on
`/responses`.

`modules/litellm/zen-free.py` is the fourth `LITELLM_WORKER_STARTUP_HOOKS`
entry and holds that fingerprint. It patches `httpx.AsyncClient.__init__` and
`httpx.Client.__init__` to append a request event hook, because `User-Agent`
cannot be set from `litellm_params`, from `extra_headers` or from a pre-call
hook: the OpenAI SDK writes its own value after all of them (measured on this
image, openai 2.33.0, where `default_headers` and per-request `extra_headers`
both lose to `OpenAI/Python 2.33.0`), while an httpx event hook runs last and
rewrites the header in place. Such a hook must be async for the async clients
(httpx awaits each one; a plain function fails with `object NoneType can't be
used in 'await' expression`). The hook matches `opencode.ai/zen/v1/` only, so
the Go tier under `/zen/go/v1/` keeps the per-account session headers it sets
itself, and it keeps a client's own session when that one already satisfies the
shape and bit rule, otherwise it mints one per process. A second half, a
`CustomLogger` pre-call hook, pads `tools` with stubs up to two core names
(`bash`, `read`; the stubs are never registered in any harness, so a model that
calls one gets an error and recovers), which is what a plain client that sends
no tools needs to get past the gate at all.

Two limits belong to the provider and reach clients unchanged: a non-streaming
request is refused with the same `403`, and a protocol the model does not serve
is refused with `400 ModelProtocolUnsupported`. The deployment declares
`mode = "responses"` for the muse pair so discovery picks that protocol, and
`modules/omp/default.nix` pins `deepseek-v4.1-flash-free` and
`space-bunny-free` to `openai-completions`, because their upstreams are
chat-only and omp would otherwise send them as Responses.

This is a deliberate bypass of a control the provider enforces, and it is the
only one in this repo. The public thread for that gate reports one prober's
account blocked for repeated policy violations and the gate has been revised at
least three times; these requests carry no account of ours, but they leave from
the same address as the paid pool, so a block by IP would reach everything.
Nothing watches these four groups yet: if the gate moves, they fail with `403`
and only the clients see it.

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

The two priced groups' deployments carry `model_info.opencode_usage_metered =
true`, the two free Go rows and the four `zen-free` groups carry `false`, and the
pool-usage callback benches
*every* metered deployment that shares an exhausted account key
(`metered_deployments_by_key` skips only the ones flagged `false`): one rule for
the accounts, which is what keeps the pool protected now that `deepseek-v4.1-flash`
and `step-5-preview` share the same four keys. The flag follows the row, not the
tier: `step-5-preview` carried `false` while the Go table listed it as
`Unlimited`, and the two `Free / Unlimited` rows carry it now, because benching a
free model when the paid allowance runs out would withdraw it for no reason. The
`/v1/usage` snapshot keeps its `provider: opencode-go-pool` label: it names the
account pool, not a model group.

Error-driven cooldown is off for every deployment of every pool group:
`models/default.nix` gives each deployment `model_info.cooldown_time = 0` and
`litellm_params.num_retries = 0`, so the `router_settings.cooldown_time = 600`
and `num_retries = 30` left in `config.nix` are defaults none of these sixteen
deployments reaches. Cooldown keys on the deployment id — one per account key —
not on the group or the request, which is why the reasoning below applies
identically to every deployment of every pool group.

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
without the 600-second blackout, and it couples every pool group to
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
monthly 100 % of it. `step-5-preview-free` was listed `Unlimited` there until
2026-10-16, which is why that group carried no plan quota to protect; the row is
now `Step 5 Preview`, at $1.00/$2.70/$0.10 per 1M input/output/cached read with a
$60 monthly limit — a 4× promotion over the $15 list value — so every priced
group is metered and one rule covers them all. The two `Free / Unlimited` rows
carry no plan quota at all, which is what `metered = false` marks. Exactly two
429 flavours came back from zen/go for the group, and they differ in scope. `Upstream request failed: Rate
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
  -d '{"key_alias":"friend","duration":"365d","models":["deepseek-v4.1-flash","step-5-preview","gpt-6-astra","gpt-6-luna","gpt-6.1-sol"]}'
```

`models` is the whole scope: a key can call exactly the groups listed, and an
unlisted group answers `403 key_model_access_denied`. Both live client keys
(`anyouh`, `vanya`) carry the five names that existed on 2026-10-11, when
`step-5-preview` was added to them with `POST /key/update` — same shape as
above, with the key hash from `GET /key/list?return_full_object=true` instead of
a plaintext key, which is the only identifier left once the key itself has been
handed out. A scope is frozen at the names it lists: the two free rows added on
2026-10-16 answer `403` for those keys until somebody extends their scope the
same way.

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

Rotate — the rotation endpoints exist and are enterprise-only: `/key/regenerate`
and `/key/{key}/regenerate` are in the 1.103.2 spec, but calling them answers
`500 Regenerating Virtual Keys is an Enterprise feature` without a
`LITELLM_LICENSE` (measured 2026-10-15 against this proxy with a throwaway key,
whose row the failed call left untouched). Rotation is therefore `/key/delete`
followed by `/key/generate` with the old row's parameters, and the alias can be
reused as soon as the old row is gone (verified). `key_alias` is unique —
creating a second key under a live alias answers `400` — so a rotation that must
not leave a client without a working key stages the new key under a temporary
alias, verifies it, deletes the old row and renames with `/key/update`
(`key_alias` is a settable field, and a rename carrying nothing else left
`expires` exactly where it was; measured 2026-10-15 on `anyouh`). `spend` is
writable on both
`/key/generate` and `/key/update` (verified `1.25` → `2.5`, and the DB agrees),
so a rebuilt key can carry the spend already burned in its budget window. What
does not survive is `total_spend`, which `/key/list` aggregates from
`LiteLLM_SpendLogs` under the old `token`, and `expires` only ever moves as
`now + duration` — no endpoint takes an absolute expiry.

`/key/generate` also accepts an explicit `key` without a license: passing
`"key":"sk-…"` makes the response echo that exact string and stores its sha256 as
`token`. That is how a value gets chosen instead of drawn; it cannot bring back
the old one, which was never readable.

A live client key (`anyouh`, measured 2026-10-15):

```
litellm-key revoke anyouh
curl -sX POST https://llm.labile.cc/key/generate \
  -H "Authorization: Bearer $MASTER" -H 'Content-Type: application/json' \
  -d '{"key_alias":"anyouh","duration":"365d",
       "models":["deepseek-v4.1-flash","step-5-preview","gpt-6-astra","gpt-6-luna","gpt-6.1-sol"],
       "max_budget":5,"budget_duration":"1d"}'
```

`litellm-key create` is not enough on its own for a key that had a budget — it
takes `ALIAS [DAYS]` and models from `LITELLM_MODELS`, so the cap has to follow
as `litellm-key budget anyouh 5 1d`, or come from the curl above.

To preserve an existing deadline instead of renewing, send the remaining time as
whole seconds — `duration` accepts `<int>s` and lands within a second of the
target (`20415s` came back `+0.226s` off the old `expires`), while `45.5s`
answers `500 Unsupported duration unit`.

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
it after a rescope or a new group.

The effort ladder has to come from the gateway, and it now does:
`modules/litellm/reasoning-params.py` is a startup hook
(`LITELLM_WORKER_STARTUP_HOOKS`) that appends `reasoning_effort` to
`supported_openai_params` for every deployment whose
`model_info.reasoning_effort_levels` is non-empty — on the deployment route and
on `Router.get_model_group_info` alike. Both are needed: a client gates the
ladder on `supported_openai_params`, and omp reads that gate from the
*deployment* metadata (`/model/info`, `/v2/model/info`), while ignoring
`supported_reasoning_efforts` completely — that field is not in omp's bundle at
all. Measured 2026-10-11 with the hook in place: `deepseek-v4.1-flash` gets
`['low','high','max']` and `step-5-preview` `['low','medium','high']`, both empty
before it. LiteLLM itself never publishes `reasoning_effort` for these two
groups, because it resolves `openai/deepseek-v4.1-flash` and
`openai/step-5-preview` to a generic OpenAI chat parameter list; the
`chatgpt/gpt-6-*` groups carry it because LiteLLM knows them as Responses
models.

One transport caveat, specific to `step-5-preview`: omp's LiteLLM discovery
sends it over `POST /v1/responses` — its upstream is an `openai/…` id — and Zen
answered `400 ModelProtocolUnsupported` for that protocol on `step-5-preview-free`,
the id the Go tier published when this was measured (2026-10-11), so the omp
provider pins it to chat completions with
`modelOverrides.step-5-preview.api = "openai-completions"` in
`modules/omp/default.nix`. Giving the deployment `model_info.mode = "chat"` does
not change that choice (measured 2026-10-11: omp still sent Responses, so the
override was reverted), and jcode never hit it: an `openai-compatible` profile
speaks chat completions only, and `jcode run --provider-profile llm-labile -m
step-5-preview` answers through the same gateway.

Verify: `omp models llm-labile --json` lists exactly the key's groups with
`pricingStatus: fixed`, and a group the key lacks is absent from it. A
`403 key_model_access_denied` on first use means the client pinned its roster
instead of discovering it.

jcode discovers too, through `model_catalog`, which reads the same live
`GET /v1/models` (`jcode provider add --model-catalog` writes the profile that
way, `/refresh-model-list` re-reads it inside a session). Measured 2026-10-11 in
an isolated `JCODE_HOME` with a profile carrying nothing but `base_url`,
`api_key_env` and `model_catalog`:
`jcode model list --provider-profile llm-labile-probe` returned the five groups
that existed then as `available`, and `jcode run` on `deepseek-v4.1-flash` answered. Two things the
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
2026-10-04. The deployments carry explicit costs, taken from the OpenCode Go
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

Prices are sourced per provider and never copied across: the Zen groups take
their figures from OpenCode's own tables — [Go plans](https://opencode.ai/v2/docs/console/go/),
the subscription this pool uses, which also carries the per-model monthly limits
and the `5 h / week / month = 20 % / 50 % / 100 %` rule the `/v1/usage` hook
mirrors, plus [Console models](https://opencode.ai/v2/docs/console/models/) for
pay-as-you-go — while the chatgpt groups keep the rates the subscription itself
reports (see ChatGPT subscription groups above; OpenAI's model cards,
`developers.openai.com/api/docs/models/<id>`, publish the same figures). The same
id appears in both OpenCode tables at identical base rates, so the numbers alone
never say which credential paid — the owning provider does. The chatgpt groups
model the flat card only: the `> 272K` input tier (2× input and cache, 1.5×
output for the whole request) and the cache-write rate are not applied, so their
`spend` is the untiered figure.

The Zen rates are not written by hand any more. `modules/litellm/models/prices.json`
is a generated snapshot — its `source` key names the table it came from — and
`models/default.nix` injects its three rates into every `provider = "opencode-go"`
group plus the off-peak rates into the windows that group declares, so editing a
rate in a Zen group file would have no effect. `modules/litellm/sync-prices.py`
keeps the snapshot honest: the `litellm-price-sync` oneshot — started at every
boot (`wantedBy = multi-user.target`) and behind the daily `litellm-price-sync.timer`
(`Persistent = true`, 30-minute jitter) — fetches the Go plan table as markdown
(`Accept: text/markdown`), parses the price rows for the groups
`models/default.nix` exports as `zenGroupNames`, and then

- writes nothing when every rate already matches — the usual outcome, exit 0;
- on a change writes the snapshot, commits and pushes it as `labile`
  (`litellm: sync Zen prices from the OpenCode Go table`, the diffs in the body),
  runs `nixos-rebuild switch` under the same 8G/10G caps the Makefile puts on a
  build, then re-reads `GET /model/info` and asserts the proxy serves the new
  rates; when it does not, it reverts its own commit, pushes, rebuilds and exits
  non-zero;
- on anything it refuses — a row that disappeared from the table, a rate moving
  more than 5×, an off-peak tariff appearing or disappearing (a free model going
  paid), a group with no label mapping — writes nothing and exits 1.

The refusal that needs a human is the free-model-going-paid shape, and
2026-10-16 was one: the table renamed `Step 5 Preview Free` to
`Step 5 Preview` and priced it, and Zen withdrew the `step-5-preview-free` model
id in the same release, so the run exited 1 with `refusing to apply: the Go table
no longer has the row 'Step 5 Preview Free'` while `step-5-preview` answered
`400 … Upstream request failed: Model is unavailable.` to every client. Three
hand edits repaired it, and the script can make none of them itself: the
snapshot's three rates, `metered = true` in `models/step-5-preview.nix` — a
priced row is metered against the account allowance — and the new upstream id in
the same file. Ordinary rate moves never need a hand: the script applies those.

One trap for those hand edits: the numbers in `prices.json` are the doubles the
parser computes, not the decimals the table prints, and the diff lines print
them through `:g`, which hides a one-ulp difference. `$0.10` per 1M is
`0.1 / 1e6`, one ulp above `1e-07`, so a hand-written `1e-07` in that field reads
as permanent drift — every later run rewrites the file and commits the ulp. Write
`repr(float('0.10') / 1e6)`, or take the value from a run that applied the change
itself.

The exit code is the alarm: a failed run leaves the unit in `failed` state, which
`modules/monitoring/failures.nix` already pages on, and
`modules/monitoring/litellm.nix` adds the specific rules — `litellm_price_sync_anomaly > 0`
(refused or errored), a rate change (routed to `telegram-admin-events`, so no
RESOLVED message), and three days without a successful run. Those series live in
the textfile-collector file the script writes next to `docker-container-state.prom`,
and the last outcome is kept in `/var/lib/litellm-price-sync/state.json`.

Manual use: `python3 modules/litellm/sync-prices.py --repo /home/labile/nix`
prints the drift against the live table and exits 1 when there is any, writing
nothing without `--apply`; `--table <file>` reads a saved page instead of the
network, which is how the refusals above are exercised.

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

## Provider limits in Prometheus and Grafana

`GET /v1/usage` shows the pool as one aggregate, which hides what each of the
four accounts has left and says nothing about the ChatGPT subscription.
`modules/litellm/limits-exporter.py` fills both gaps: it runs as
`litellm-limits-exporter` (oneshot, `wantedBy = multi-user.target`, every five
minutes through `litellm-limits-exporter.timer`) as root, reads the pool keys
from `/run/agenix/opencode-go-pool-env` and the ChatGPT OAuth token from
`/var/lib/litellm-chatgpt/auth.json`, and writes
`/var/lib/prometheus-node-textfile-collector/litellm-provider-limits.prom` for
node_exporter's textfile collector.

Two upstreams, both pull-based, so the series stay fresh without traffic:

- `GET https://opencode.ai/zen/go/v1/usage` once per pool account — the endpoint
  the in-container poller already uses — labelled by the key's index in the
  secret: `litellm_opencode_go_used_percent{account,window}`,
  `litellm_opencode_go_window_status` (1 when the provider reports the window as
  `rate-limited`, which is what benches the account in the router),
  `litellm_opencode_go_reset_at` and `litellm_opencode_go_fetch_ok`.
- `GET https://chatgpt.com/backend-api/wham/usage` — the endpoint the Codex CLI
  itself polls — with the stored access token and `chatgpt-account-id`:
  `litellm_codex_used_percent{account,plan,window}`,
  `litellm_codex_window_present` (0 for a window the plan does not have; this
  plan reports only `primary` at 604 800 s), `litellm_codex_window_seconds`,
  `litellm_codex_reset_at`, `litellm_codex_limit_reached`,
  `litellm_codex_model_available` and `litellm_codex_token_expires_at`. The
  account label is the first eight characters of the account id; the plan's
  email is deliberately not exported.

The same numbers arrive as `llm_provider-x-codex-*` response headers on every
Codex call (`x-codex-primary-used-percent`, `x-codex-primary-reset-at`, …), but
those exist only while traffic flows, while `wham/usage` answers the same
question without a request — measured 2026-10-11, the header on a live call and
the endpoint both reported 48 percent. The exporter only *reads* `auth.json`:
the access token lasts ten days and litellm refreshes it on the next request, so
the token-expiry panel is what shows that refresh has stopped happening.

Three rules keep the series honest, because each upstream fails on its own:

- `litellm_limits_source_up{source}` is 1 when that upstream answered this run,
  so a transient failure that empties one half of the dashboard (a TLS handshake
  failure through the tunnel was observed on 2026-10-11) is distinguishable from
  an empty catalog. A pool account that failed gets `fetch_ok 0` under its index
  instead of silently disappearing.
- `litellm_limits_exporter_success` is 0 whenever any source failed. A run in
  which nothing at all answered does not fail the unit by itself: it increments
  `empty_runs` in `/var/lib/litellm-limits-exporter/state.json`, and only the
  third consecutive one exits non-zero and reaches the generic failed-unit
  alert. Such a run is usually the router's proxy rather than the provider: it
  pulls `/stable.txt` from the local sub-preprocessor every hour at `:00:09`,
  the exporter's `:00` run starts between `:00:09` and `:00:34`, and when that
  reload lands on a dead node every fake-IP destination fails TLS for the rest
  of the run — 2026-10-12 12:00: all four pool accounts and codex
  `SSL: UNEXPECTED_EOF_WHILE_READING` for 22 s, the next run green, and the
  12:02 page was the tail of that noise, the only one in two weeks. A run that
  cannot write the metric file — or the counter — exits non-zero at once, so a
  full disk or a lost secret cannot silently stop the metrics.
- A window whose payload carries no reset time gets no `..._reset_at` sample at
  all, rather than a zero the panels would render as a countdown to 1970.

The dashboard is `LiteLLM provider limits` (uid `litellm-limits`,
`modules/monitoring/dashboards/litellm-limits.json`, provisioned like the other
system dashboards — into the `litellm` Grafana folder, while the disk dashboards
live in `storage` and node-exporter stays in `system`): accounts still in
rotation, windows that bench them (provider-reported `rate-limited`, or 95
percent of a window spent — the poller's own `LIMIT_PERCENT`), mean weekly and
monthly headroom stats (the monthly pool is the whole subscription budget, so
it answers whether a dry week is within budget or the subscription itself is
running out), headroom per account and window, weekly and monthly batteries
per account, the Codex weekly headroom and reset, token expiry,
per-source reachability, and the price sync's state.
`100 - used_percent` is the headroom everywhere, because both providers report
what is *spent*. `count(…) or vector(0)` keeps a "nothing benched" panel at 0
instead of `No data`, since `count()` over an empty vector returns nothing.

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
- Provider limits are published:
  `cat /var/lib/prometheus-node-textfile-collector/litellm-provider-limits.prom`
  → four pool accounts with three windows each, then the Codex block;
  `systemctl status litellm-limits-exporter` for the last run and
  `curl -s 'http://127.0.0.1:3020/api/v1/query?query=litellm_opencode_go_used_percent'`
  for what Prometheus kept; `cat
  /var/lib/litellm-limits-exporter/state.json` for the empty-run count the unit
  itself fails on.
- Trap: `systemctl cat docker-litellm` prints the unit, not the `docker run`
  line — the arguments are in the `ExecStart` script it points at. Use that
  script path, or `docker inspect litellm` for the effective mounts and
  network.

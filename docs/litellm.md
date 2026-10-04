# litellm proxy on `server`

`modules/litellm/default.nix`. Two containers on one docker network:
`litellm-db` (`postgres:17`) and `litellm`
(`ghcr.io/berriai/litellm:main-stable`), published as `127.0.0.1:27015` and
proxied by `llm.labile.cc`. Keys, spend and models live in PostgreSQL, not in
the container, so they survive restarts, rebuilds and image updates.

jcode consumes the group as its default provider (`pool/opencode-go-pool` in
`modules/jcode/default.nix`) on every host that receives the master key, so
interactive turns shuffle across the four accounts; hosts outside the secret's
recipients (fx516) keep the direct `opencode-go` profile. omp does not use this
gateway; it authenticates against `closerouter` and `tokenharbor` directly.

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
  -d '{"key_alias":"friend","duration":"365d","models":["opencode-go-pool"]}'
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

## Keys and usage from the command line

`litellm-key` (`modules/litellm/litellm-key.nix`, installed by the litellm
module, so it exists only on `server`) talks to the proxy with the master key
from `/run/agenix/opencode-litellm-master-key`; override with `LITELLM_URL`,
`LITELLM_KEY_FILE` and `LITELLM_MODELS`:

```
litellm-key                 # alias, expiry, spend, models, blocked
litellm-key logs 50         # last 50 request rows
litellm-key totals 7        # spend, tokens, requests per alias, last 7 days
litellm-key create vanya    # new key, 365 days, models from LITELLM_MODELS
litellm-key create guest 30 # 30 days instead of a year
litellm-key extend vanya 30d
litellm-key revoke vanya
```

`create` prints the key exactly once, so it is the only moment that value can
be captured. `extend` and `revoke` accept either the alias or the full `sk-…`
value, and the proxy stores a key as `sha256(key)`, which is why an alias has
to be unique for them to work — the tool refuses and asks for the explicit
`sk-…` when two keys share one.

Revoking deletes the row; nothing keeps the key value, so a revoked key cannot
be restored, only replaced.

Traffic authenticated with the master key — everything omp and jcode send —
is logged under the alias `master`, and a key hash that matches no key in the
DB shows as `other`; neither is a virtual key. Measured 2026-10-04: three days
of log held 1456 `master` requests against 22 for both virtual keys, and
`spend` was `0.0000` throughout because the pool model has no entry in
litellm's cost map — tokens, not spend, is the number that tracks pool
consumption.

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
only gate. Every key spends the same four `opencode-go-pool` accounts.

The data directory `/var/lib/litellm-db` is `999:999` mode `700`. On the host
uid 999 is a dynamic user named `nm-iodine` — identical number, unrelated
name, no effect on the bind mount.

The container gets its secrets as environment variables, so anything running
inside it can read them; that is why the master key never needs to enter the
container's own config.

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
  `502` the container is down; `404` would mean the IP whitelist is back on
  the vhost.
- Keys are in the DB, not in process memory:
  `docker exec litellm-db psql -U litellm -d litellm -c 'select key_alias,
  expires, models, spend from "LiteLLM_VerificationToken";'`
- Trap: `systemctl cat docker-litellm` prints the unit, not the `docker run`
  line — the arguments are in the `ExecStart` script it points at. Use that
  script path, or `docker inspect litellm` for the effective mounts and
  network.

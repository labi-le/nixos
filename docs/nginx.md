# Reverse proxy on `server`

Angie 1.11.8 (nginx 1.29.3 core, OpenSSL 3.6.3), `modules/nginx.nix`. Every
proxied vhost comes from the `proxy` helper, which pins `kTLS = true` *after*
merging caller arguments — passing `kTLS = false` as an argument is silently
overridden, so an exception needs `lib.recursiveUpdate` around the call, the
way `cache.labile.cc` and `llm.labile.cc` do it.

## KTLS aborts HTTP/2 connections at teardown

[nginx#651](https://github.com/nginx/nginx/issues/651), open, reproduced on
1.30.0 and 1.31.3. With OpenSSL 3.2.0 or later, KTLS enabled and
`lingering_close on` (the default; the config sets no `lingering_close`
anywhere), `recv()` in `ngx_http_v2_lingering_close_handler` returns `-1`
with `EIO` where it should return 0. Angie logs

```
[alert] recv() failed (5: Input/output error) while processing HTTP/2
connection, client: <ip>, server: 0.0.0.0:443
```

and drops the connection without a TLS `close_notify`, so every stream still
in flight on it dies. Clients see `SSL_read: SSL_ERROR_SYSCALL, errno 0` or
`unexpected eof while reading`, and — because a downloading client can no
longer send its flow-control updates — the misleading `curl (55) Failed
sending data to the peer` on what was purely a download.

`cache.labile.cc` was the worst victim: `nixos-rebuild` fetches thousands of
NARs, libcurl multiplexes them onto one HTTP/2 connection, and
`keepalive_requests 100` forces a teardown every 100 requests. Each teardown
killed up to 25 in-flight NAR downloads; five retries later the build failed
with `error: Cannot build ... 1 dependency failed`.

KTLS is therefore off for that vhost, and only that one. The alternative
workaround, `lingering_close off`, was rejected: it changes teardown
semantics for every client of every vhost to fix one of them. KTLS stays on
the other 11 vhosts, where the bug is latent — a teardown there aborts one
interactive request that the browser retries invisibly.

## Measured

2026-09-02, from `pc` over the LAN, 48 distinct NARs replayed to the request
count shown, 25 concurrent, `curl` 8.21.0 with nghttp2 1.69.0:

|Arm|Failures|
|---|---|
|HTTP/2, KTLS on, 200 requests|5–7 of 200, repeatable|
|HTTP/2, KTLS on, 40 requests|0 (no teardown inside the run)|
|HTTP/1.1, KTLS on, 400 requests|0 — the bug is in the HTTP/2 handler only|
|HTTP/2, KTLS off, 1000 requests|0|

Throughput did not measurably change: 184.8 MB across 48 parallel NARs in
2.05 s, 90 MB/s, the same as a single HTTP/1.1 fetch measured before the
change. The box is not CPU-bound on TLS at LAN speed.

## Verify

```sh
# reproduce: >100 requests over one multiplexed h2 connection
curl -sZ --parallel-max 25 --http2 -w '%{http_code}\n' \
  $(awk '{printf "--url %s -o /dev/null ", $0}' nars.txt) | grep -c '^000'
```

Zero is the pass. A non-zero count means KTLS came back on the vhost, or the
bug reached a vhost that still has it.

Two traps in checking this:

- **The alert is not in the journal.** `appendHttpConfig` sets
  `error_log /var/log/nginx/error.log`, so http-level alerts go to that file
  and `journalctl -u nginx` shows nothing at all for them.
- **A worker abort does not restart the unit.** `systemctl show nginx
  -p ExecMainStartTimestamp` stays put across these failures, so uptime
  proves nothing about whether connections were dropped.

# Reverse proxy on `server`

Angie 1.11.8 (nginx 1.29.3 core, OpenSSL 3.6.3), `modules/nginx.nix`. Every
proxied vhost comes from the `proxy` helper, which pins `kTLS = true` *after*
merging caller arguments — passing `kTLS = false` as an argument is silently
overridden, so an exception needs `lib.recursiveUpdate` around the call, the
way `cache.labile.cc` and `llm.labile.cc` do it.

## KTLS breaks concurrent HTTP/2 downloads

Measured: with `kTLS = true` on the cache vhost, 5 to 7 of every 200
concurrent HTTP/2 NAR fetches abort mid-body — HTTP 200 headers already
delivered, connection closed without a TLS `close_notify`. With KTLS off,
zero in 1480 requests. Clients see `SSL_read: SSL_ERROR_SYSCALL, errno 0` or
`unexpected eof while reading`, and — because a downloading client can no
longer send its flow-control updates — the misleading `curl (55) Failed
sending data to the peer` on what was purely a download. `nixos-rebuild`
retries five times per NAR and then fails the build with
`error: Cannot build ... 1 dependency failed`.

KTLS is therefore off for that vhost, and only that one, set through
`lib.recursiveUpdate` because the `proxy` helper would otherwise win.

Angie also logs, at the same time, the alert from
[nginx#651](https://github.com/nginx/nginx/issues/651) — KTLS with OpenSSL
3.2.0 or later makes `recv()` in `ngx_http_v2_lingering_close_handler` return
`-1`/`EIO` where it should return 0:

```
[alert] recv() failed (5: Input/output error) while processing HTTP/2
connection, client: <ip>, server: 0.0.0.0:443
```

**That alert is not the explanation for the aborts, and this file previously
claimed it was.** A reproducer on vanilla nginx 1.30.4 with OpenSSL 4.0.1
(loopback, `keepalive_requests` deliberately small, `limit_rate` holding
streams open, tried with both a static root and `proxy_pass`, with
`sendfile on` and 10 s `send_timeout`) emits exactly one such alert per
connection teardown and **never** aborts a request: 150 of 150 completed in
every arm. So both symptoms depend on KTLS, but the aborts are not produced
by the code path in nginx#651, and their mechanism is unidentified.
Differences not yet tested: Angie 1.11.8 versus vanilla nginx, OpenSSL 3.6.3
versus 4.0.1, a real network versus loopback.

KTLS stays on the other 11 vhosts. None of them serves bulk downloads, and
the reproducer says the alert alone costs nothing but log noise — but that is
an argument from a reproducer that does not reproduce the aborts, so treat it
as provisional.

## Measured

2026-09-02, from `pc` over the LAN, 48 distinct NARs replayed to the request
count shown, 25 concurrent, `curl` 8.21.0 with nghttp2 1.69.0:

|Arm|Failed requests|
|---|---|
|HTTP/2, KTLS on, 200 requests|5–7 of 200, repeatable over 6 rounds|
|HTTP/2, KTLS on, 40 requests|0 — no connection teardown inside the run|
|HTTP/1.1, KTLS on, 400 requests|0|
|HTTP/2, KTLS off, 1480 requests|0|

Throughput did not measurably change: 184.8 MB across 48 parallel NARs in
2.05 s, 90 MB/s, the same as a single HTTP/1.1 fetch measured before the
change. The box is not CPU-bound on TLS at LAN speed.

The isolated reproducer, vanilla nginx 1.30.4 with OpenSSL 4.0.1 on the same
kernel, 150 requests at 25 concurrent with `keepalive_requests 20`:

|Arm|nginx#651 alerts|Failed requests|
|---|---|---|
|HTTP/2, KTLS on, `lingering_close on`|7 — one per teardown|0|
|HTTP/2, KTLS off|0|0|
|HTTP/2, KTLS on, `lingering_close off`|0|0|
|HTTP/1.1, KTLS on|0|0|

`TlsTxSw` in `/proc/net/tls_stat` moved only in the KTLS-on arms, which is
what proves KTLS was engaged rather than silently falling back to userspace.

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

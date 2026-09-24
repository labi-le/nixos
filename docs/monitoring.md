# Monitoring stack (server)

Prometheus (`127.0.0.1:3020`), Loki and Grafana Alloy all live in
`modules/grafana.nix`; the exporters and scrape jobs Prometheus polls are
declared there too. Grafana-managed alert rules are split one file per
concern under `modules/monitoring/`, all imported by
`modules/monitoring/default.nix`: `contact-points.nix` (shared Telegram
receivers), `storage.nix` (ZFS/SMART, see `docs/zfs-pool.md`),
`tidal-syncer.nix`, `frp.nix`, `container-state.nix` (the Docker
container-state textfile exporter service+timer) and `failures.nix` (this
page).

## Incident, 2026-09-23

Two independent failures on the same day exposed the same blind spot —
nothing in this stack watched process/container liveness or per-process
memory:

- `postfix-mailcow` and `dovecot-mailcow` crash-looped for over a day
  (6592 and 1444 restarts) after a kernel change. No systemd unit ever
  entered `failed` (Docker's own restart loop kept re-executing them), and
  Prometheus had no visibility into container state at all, so nothing
  paged while mail was down.
- The same day the server hung from memory exhaustion (`MemAvailable`
  19 GiB → 2.6 GiB, swap filled to 15.7 GiB, memory PSI `full` at 43%).
  The ~16 GiB culprit could not be identified after the fact because
  nothing recorded memory per process.

## Failure alerting (`modules/monitoring/failures.nix`)

Eight Grafana alert rules in the `failures` group, all routed to
`telegram-admin`. Every rule that watches a metric which can vanish
outright when its source dies has a sibling rule that pages on that
absence instead of going quiet, the same pairing `storage.nix` uses
between its pool-health rules and its `*-exporter-down` rules — the whole
point of this file is that a service dying silently (mailcow) or a check
itself dying silently (the SMART exporter false-negative from the same
day) must never be the reason nobody was paged.
The three event-based rules (`oom-kill`, `systemd-restart-loop`, `container-restart-loop`) route to `telegram-admin-events` instead, which disables resolved messages; these rules fire on metric increases over time windows (`[5m]` or `[15m]`), so their resolved state just means the window passed without further increases, not meaningful recovery.


**Systemd unit failed** (`systemd-unit-failed`, critical, `for = 2m`)
fires on `node_systemd_unit_state{state="failed"} > 0`. `noDataState =
"OK"`: the metric is one series per `(unit, state)` pair with node_exporter
`--collector.systemd` — a genuinely missing series set means node_exporter
itself is down, which `scrape-target-down` below already pages on, so
this rule does not need to duplicate it.

**Systemd restart loop** (`systemd-restart-loop`, critical, `for = 0s`)
fires on `increase(node_systemd_service_restart_total[15m]) > 5`, catching
a unit that restarts fast enough to never sit in `failed` long enough for
the rule above to see it (exactly mailcow's failure mode, had it been a
native systemd service instead of a container: `Restart=always` +
`RestartSec` short enough that `ActiveState` bounces back to `active`
between failures). Requires
`services.prometheus.exporters.node.extraFlags` to carry
`--collector.systemd.enable-restarts-metrics` (`modules/grafana.nix`);
without it `node_systemd_service_restart_total` does not exist.
`noDataState = "OK"` for the same node_exporter-liveness reason as above.

**Container restart loop** (`container-restart-loop`, critical, `for =
0s`) fires on `increase(docker_container_restart_count[15m]) or
(docker_container_restart_count unless docker_container_restart_count offset 15m)` > 3.
The first arm (`increase()`) catches containers that have been looping for a while;
the second arm catches newly created containers whose `docker_container_restart_count` did not exist 15 minutes ago.
The second arm is needed because `increase()` measures growth between samples in the window,
and a container that crashes from the moment of `docker compose up` (scrape interval 1 m)
already carries all its restarts in the first sample, so they are never counted as growth.
A long-lived container that starts looping later (the mailcow case) is still caught by the first arm.
One known side effect: a newly created container that inherited a `RestartCount` above 3 would fire once,
but Docker resets `RestartCount` on container recreation, so this cannot happen in practice.
`noDataState = "OK"`: total absence of `docker_container_restart_count` means the textfile exporter
died, which `container-state-stale` below pages on.

**Container down** (`container-down`, critical, `for = 5m`) fires on
`docker_container_running == 0 and on(name)
docker_container_restart_policy_info{policy="always"}`.
The join against restart-policy is deliberate: `unless-stopped` means
Docker restarts the container unless an operator stopped it, so a
container an operator stopped on purpose (`freqtrade`, `freqtrade-perp`,
`tg-sub-crawler` all use `unless-stopped`) would otherwise page for a
state the operator chose. Only `policy="always"` is watched, since Docker
itself is supposed to keep those containers running regardless of how they
stopped. Residual caveat: an `always` container stopped by hand still
pages — there is no metric that distinguishes an operator's `docker stop`
from an unexpected exit for that policy. Restart loops of `unless-stopped`
containers are still caught by `container-restart-loop` above. `noDataState =
"OK"` for the same textfile-exporter-liveness reason.

**Container unhealthy** (`container-unhealthy`, warning, `for = 5m`)
fires on `docker_container_healthy == 0`. Warning, not critical, because
an unhealthy check does not necessarily mean the service is down — it
means the container's own healthcheck script says something is wrong,
which is real but usually less urgent than the container being gone
outright. `docker_container_healthy` is omitted entirely for containers
with no configured healthcheck and while a container's health status is
`starting` (see `container-state.nix` below), so this rule does not fire
during a container's `start_period` — `mailcowdockerized-clamd-mailcow-1`
alone declares `start_period=6m0s`, longer than this rule's own `for =
5m`. `noDataState = "OK"`, same reasoning.
The metric is also omitted for stopped containers (Docker preserves the last health status after exit, which would cause false alerts for containers intentionally stopped in a failed state, like freqtrade with an unhealthy check).

**Container-state exporter stale** (`container-state-stale`, critical,
`for = 1m`) is the rule that makes the three rules above safe to leave
`noDataState = "OK"`: `(time() -
docker_container_exporter_last_run_timestamp_seconds > 180) or
absent(docker_container_exporter_last_run_timestamp_seconds)`. The
`absent()` branch covers the exporter having never run at all (fresh
install, unit disabled); the `time() - ... > 180` branch covers it having
stopped updating (timer disabled, the writer script erroring every run).
180s is roughly two exporter cycles rather than six: the sample itself is
up to one scrape interval old (`scrape_interval: 1m`), so a healthy
reading already sits near 60-90s, not the 30s the timer period alone would
suggest. The timer pins `AccuracySec = "1s"` so systemd cannot coalesce
its 30s period out toward its default ~1min accuracy window, which would
otherwise push the healthy reading toward the 180s threshold itself.

**OOM kill** (`oom-kill`, critical, `for = 0s`) fires immediately on
`increase(node_vmstat_oom_kill[5m]) > 0` — any kernel OOM kill is worth
paging on the moment it is observed; there is no benign case to debounce
against. This does not by itself explain *what* was killed or *why*
memory ran out; that is the per-process memory recording below.
`noDataState = "OK"`: `node_vmstat_oom_kill` disappearing means
node_exporter is down, covered by `scrape-target-down`.

**Scrape target down** (`scrape-target-down`, critical, `for = 5m`) fires
on `up{job!~"^(zfs|smartctl|tidal-syncer)$"} < 1`. Those three jobs are
excluded because `storage.nix` and `tidal-syncer.nix` already have
dedicated, more specific `up{job="..."} < 1` rules for them (with their
own summaries naming the exact unit to check); alerting twice for the
same cause would just be noise. Every other scrape job (`nodes`, `nginx`,
`process`, `sub-preprocessor`, `frp` if scraped) is covered here instead
of needing its own per-job rule. `noDataState = "Alerting"`, matching
`storage-zfs-exporter-down`'s reasoning exactly: `up` disappearing
entirely means the scrape target was dropped from the Prometheus config,
which is strictly worse than a target merely failing to respond, and must
never go quiet.

## Container-state exporter (`modules/monitoring/container-state.nix`)

A oneshot `docker-container-state-exporter.service` plus a
`docker-container-state-exporter.timer` (every 30s) runs `docker ps -aq`
then a single `docker inspect` over all container IDs, and writes a
node_exporter textfile-collector file at
`/var/lib/prometheus-node-textfile-collector/docker-container-state.prom`.
The write is atomic (temp file in the same directory, then `mv`) so
node_exporter's textfile collector — which globs that directory on every
scrape — never reads a half-written file. Metrics, all labelled `name`
(the container name with Docker's leading `/` stripped):

- `docker_container_running` — 0/1.
- `docker_container_restart_count` — Docker's own `RestartCount`.
- `docker_container_healthy` — 1 healthy, 0 unhealthy; the series is
  omitted entirely (not emitted as some third value) when the container
  has no healthcheck configured, or while its health status is
  `starting` (Docker's state for the whole of a container's
  `start_period` and again after every restart until the first passing
  check), so `container-unhealthy` above can treat its absence for a
  given container as "not applicable" rather than "unhealthy".
- `docker_container_restart_policy_info{policy="..."}` — always 1; a
  info-style metric so `container-down` can join on it by label.
- `docker_container_exporter_last_run_timestamp_seconds` — one series, no
  labels, the Unix timestamp of the last successful run; this is what
  `container-state-stale` watches.

node_exporter's textfile collector is enabled by pointing
`--collector.textfile.directory` at that same directory
(`modules/grafana.nix`); the collector itself is on by default in
node_exporter, so no `enabledCollectors` entry is needed for it.

## Per-process memory (`services.prometheus.exporters.process`)

`modules/grafana.nix` enables the process exporter
(`127.0.0.1:9256`, scraped as job `process`), grouped by
`process_names = [ { name = "{{.Comm}}"; cmdline = [ ".+" ]; } ]` — one
Prometheus series per distinct command name, matching every process
(`cmdline: [".+"]` matches all argv). Per-thread metrics are disabled via
`extraFlags = [ "-threads=false" ]`; the process exporter's own default is
enabled, and thread-level detail was never the gap this closes. This is
forensic and dashboard data, not an alert source: on the next
memory-exhaustion hang,
`namedprocess_namegroup_memory_bytes{memtype="resident"}` grouped
by `groupname` in Grafana identifies which command was holding the memory
that `oom-kill` (or a hang with no OOM kill at all, as happened on
2026-09-23 since swap absorbed the pressure instead) could not.

import argparse
import datetime
import json
import math
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import tempfile
import time
import uuid


PROBES = {
    "claude": "https://platform.claude.com/",
    "cloudflare": "http://cp.cloudflare.com/generate_204",
}
STATES = ("healthy", "unhealthy", "unknown")
PROBE_FRESHNESS_SECONDS = 600
METRIC_HELP = {
    "openwrt_collector_success": "Whether the latest SSH base snapshot was collected and parsed successfully.",
    "openwrt_collector_last_success_timestamp_seconds": "Server Unix time of the last successful base snapshot.",
    "openwrt_collector_duration_seconds": "Elapsed wall-clock time spent collecting the latest snapshot.",
    "openwrt_uptime_seconds": "Router uptime reported by procfs.",
    "openwrt_snapshot_timestamp_seconds": "Router Unix time when the snapshot began.",
    "openwrt_load1": "Router one-minute load average.",
    "openwrt_memory_bytes": "Router memory accounting by kind; overlapping kinds must not be summed.",
    "openwrt_cpu_seconds_total": "Router CPU time across all logical cores by mode with guest time separated.",
    "openwrt_oom_kills_total": "Kernel OOM kills since router boot when this counter is available.",
    "openwrt_network_bytes_total": "Router interface bytes by direction; interfaces may overlap.",
    "openwrt_network_errors_total": "Router interface errors by direction.",
    "openwrt_network_drops_total": "Router interface dropped packets by direction.",
    "openwrt_sockets_used": "Router sockets allocated across protocols.",
    "openwrt_sockets": "Router socket accounting by protocol and lifecycle kind.",
    "openwrt_socket_memory_bytes": "Router protocol socket memory accounting converted from pages.",
    "openwrt_temperature_celsius": "Router thermal sensor temperature.",
    "openwrt_murmur_up": "Whether the production murmur process was present throughout the snapshot.",
    "openwrt_murmur_resident_memory_bytes": "Production murmur total resident memory, not live heap bytes.",
    "openwrt_murmur_anonymous_memory_bytes": "Production murmur anonymous resident pages.",
    "openwrt_murmur_file_memory_bytes": "Production murmur file-backed resident pages.",
    "openwrt_murmur_shared_memory_bytes": "Production murmur shared resident pages.",
    "openwrt_murmur_peak_memory_bytes": "Production murmur lifetime high-water mark of resident memory.",
    "openwrt_murmur_virtual_memory_bytes": "Production murmur virtual address space size, not physical RAM usage.",
    "openwrt_murmur_start_time_seconds": "Production murmur start time as Unix seconds.",
    "openwrt_murmur_cpu_seconds_total": "Production murmur CPU seconds summed across threads.",
    "openwrt_murmur_threads": "Production murmur thread count.",
    "openwrt_murmur_open_fds": "Production murmur open file descriptor count.",
    "openwrt_murmur_page_faults_total": "Production murmur page faults by minor or major kind.",
    "openwrt_murmur_api_success": "Whether a controller endpoint returned valid expected snapshot data.",
    "openwrt_murmur_connections": "Active connections tracked by the murmur controller.",
    "openwrt_murmur_traffic_bytes_total": "Cumulative tracked murmur traffic by direction, reset with process statistics.",
    "openwrt_murmur_provider_proxies": "Provider proxy counts by combined fresh fixed-probe state.",
    "openwrt_murmur_probe_proxies": "Provider proxy counts by per-URL state; missing or older-than-600-second history is unknown.",
    "openwrt_murmur_probe_newest_timestamp_seconds": "Newest valid probe history timestamp across a provider, not every-node freshness.",
    "openwrt_murmur_rules": "Loaded rules per rule provider.",
}
SNAPSHOT_SCRIPT = r'''set -eu
frame() {
    printf '@@OPENWRT:%s\n' "$1"
    printf '%s' "$2" | hexdump -v -e '1/1 "%02x"'
    printf '\n'
}
file_frame() {
    printf '@@OPENWRT:%s\n' "$1"
    hexdump -v -e '1/1 "%02x"' "$2"
    printf '\n'
}
nl='
'
production_pid() {
    found=0
    for candidate in $(pidof murmur 2>/dev/null || true); do
        [ -r "/proc/$candidate/cmdline" ] || continue
        command=$(tr '\000' '\n' < "/proc/$candidate/cmdline")
        case "$command$nl" in
            *"$nl-f$nl/etc/murmur/config.yaml$nl"*)
                [ "$found" = 0 ] || return 1
                found=$candidate
                ;;
        esac
    done
    printf '%s' "$found"
}
api_frame() {
    endpoint=$1
    route=$2
    rc=0
    response=$(curl --config /etc/murmur/controller.curl --silent --connect-timeout 2 --max-time 4 --write-out '\n%{http_code}' "http://127.0.0.1:9090/$route" 2>/dev/null) || rc=$?
    status=${response##*"$nl"}
    body=${response%"$nl"*}
    frame "${endpoint}_rc" "$rc"
    frame "${endpoint}_status" "$status"
    frame "$endpoint" "$body"
}
file_frame boot_id /proc/sys/kernel/random/boot_id
frame timestamp "$(date +%s)"
file_frame auxv /proc/self/auxv
file_frame uptime /proc/uptime
file_frame stat /proc/stat
file_frame loadavg /proc/loadavg
file_frame meminfo /proc/meminfo
file_frame vmstat /proc/vmstat
file_frame netdev /proc/net/dev
file_frame sockstat /proc/net/sockstat
pid=$(production_pid)
frame pid "$pid"
if [ "$pid" != 0 ]; then
    file_frame cmdline "/proc/$pid/cmdline"
    file_frame process_stat "/proc/$pid/stat"
    file_frame process_status "/proc/$pid/status"
    count=0
    for descriptor in /proc/"$pid"/fd/*; do
        [ -L "$descriptor" ] || continue
        count=$((count + 1))
    done
    [ -d "/proc/$pid/fd" ]
    frame fd_count "$count"
    file_frame process_stat_after "/proc/$pid/stat"
    file_frame cmdline_after "/proc/$pid/cmdline"
fi
frame pid_after "$(production_pid)"
if [ -r /sys/class/thermal/thermal_zone0/temp ]; then
    file_frame temperature /sys/class/thermal/thermal_zone0/temp
fi
api_frame connections connections
api_frame proxy_providers providers/proxies
api_frame rule_providers providers/rules
file_frame boot_id_after /proc/sys/kernel/random/boot_id
'''


def parse_frames(payload):
    lines = payload.splitlines()
    if not lines or len(lines) % 2:
        raise ValueError("framing")
    frames = {}
    for index in range(0, len(lines), 2):
        match = re.fullmatch(rb"@@OPENWRT:([a-z_]+)", lines[index])
        if match is None:
            raise ValueError("framing")
        name = match[1].decode("ascii")
        if name in frames or not re.fullmatch(rb"(?:[0-9a-f]{2})*", lines[index + 1]):
            raise ValueError("framing")
        frames[name] = bytes.fromhex(lines[index + 1].decode("ascii"))
    return frames


def text(frames, name):
    return frames[name].decode("utf-8", errors="strict").strip()


def number(value, integer=False):
    if isinstance(value, bool):
        raise ValueError("number")
    result = int(value) if integer else float(value)
    if not math.isfinite(result) or result < 0:
        raise ValueError("number")
    if integer and isinstance(value, float) and result != value:
        raise ValueError("integer")
    return result


def escape_label(value):
    return str(value).replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')


class Metrics:
    def __init__(self, router):
        self.router = router
        self.lines = []
        self.types = set()

    def add(self, name, value, labels=None, kind="gauge"):
        value = number(value)
        if name not in self.types:
            self.lines.append("# HELP " + name + " " + METRIC_HELP[name])
            self.lines.append("# TYPE " + name + " " + kind)
            self.types.add(name)
        pairs = [("router", self.router)] + list((labels or {}).items())
        rendered_labels = ",".join(key + '="' + escape_label(val) + '"' for key, val in pairs)
        self.lines.append(name + "{" + rendered_labels + "} " + format(value, ".15g"))

    def render(self):
        return "\n".join(self.lines) + "\n"


def parse_auxv(raw):
    if not raw or len(raw) % 16:
        raise ValueError("auxv")
    values = {}
    terminated = False
    for key, value in struct.iter_unpack("<QQ", raw):
        if key == 0:
            terminated = True
            break
        if key in values:
            raise ValueError("auxv")
        values[key] = value
    if not terminated or not values.get(17) or not values.get(6):
        raise ValueError("auxv")
    return values[17], values[6]


def parse_status(value):
    result = {}
    for line in value.splitlines():
        key, separator, raw = line.partition(":")
        if separator:
            result[key] = raw.strip()
    return result


def memory_kib(value):
    parts = value.split()
    if len(parts) != 2 or parts[1] != "kB":
        raise ValueError("memory")
    return number(parts[0], integer=True) * 1024


def parse_process_stat(value):
    left = value.find(" (")
    right = value.rfind(") ")
    if left < 1 or right <= left:
        raise ValueError("process stat")
    pid = number(value[:left], integer=True)
    fields = value[right + 2:].split()
    if len(fields) < 22:
        raise ValueError("process stat")
    return pid, fields


def production_command(value):
    args = value.rstrip(b"\0").split(b"\0")
    return bool(args and args[0].rsplit(b"/", 1)[-1] == b"murmur" and any(
        args[index:index + 2] == [b"-f", b"/etc/murmur/config.yaml"]
        for index in range(1, len(args) - 1)
    ))


def add_base(metrics, frames):
    boot = str(uuid.UUID(text(frames, "boot_id")))
    if boot != str(uuid.UUID(text(frames, "boot_id_after"))):
        raise ValueError("boot changed")
    timestamp = number(text(frames, "timestamp"))
    if timestamp == 0:
        raise ValueError("timestamp")
    hz, page_size = parse_auxv(frames["auxv"])
    uptime = number(text(frames, "uptime").split()[0])
    metrics.add("openwrt_uptime_seconds", uptime)
    metrics.add("openwrt_snapshot_timestamp_seconds", timestamp)
    metrics.add("openwrt_load1", number(text(frames, "loadavg").split()[0]))
    memory = parse_status(text(frames, "meminfo"))
    for name, field in {
        "total": "MemTotal", "available": "MemAvailable", "free": "MemFree", "cached": "Cached",
        "slab": "Slab", "reclaimable": "SReclaimable", "unreclaimable": "SUnreclaim", "shmem": "Shmem",
    }.items():
        metrics.add("openwrt_memory_bytes", memory_kib(memory[field]), {"kind": name})
    stat = {}
    for line in text(frames, "stat").splitlines():
        fields = line.split()
        if fields:
            stat[fields[0]] = fields[1:]
    cpu = [number(value, integer=True) for value in stat["cpu"]]
    if len(cpu) < 8:
        raise ValueError("cpu")
    modes = ("user", "nice", "system", "idle", "iowait", "irq", "softirq", "steal", "guest", "guest_nice")
    for index, ticks in enumerate(cpu[:10]):
        if index in (0, 1) and len(cpu) > index + 8:
            ticks -= cpu[index + 8]
        metrics.add("openwrt_cpu_seconds_total", ticks / hz, {"mode": modes[index]}, "counter")
    boot_time = number(stat["btime"][0])
    vmstat = dict(line.split() for line in text(frames, "vmstat").splitlines())
    if "oom_kill" in vmstat:
        metrics.add("openwrt_oom_kills_total", number(vmstat["oom_kill"], integer=True), kind="counter")
    devices = []
    for line in text(frames, "netdev").splitlines():
        if ":" not in line:
            continue
        device, raw = line.split(":", 1)
        device = device.strip()
        fields = raw.split()
        if not re.fullmatch(r"[A-Za-z0-9_.:@-]{1,32}", device) or len(fields) != 16 or device in devices:
            raise ValueError("network")
        devices.append(device)
        if len(devices) > 64:
            raise ValueError("interfaces")
        values = [number(value, integer=True) for value in fields]
        for direction, offset in (("receive", 0), ("transmit", 8)):
            labels = {"device": device, "direction": direction}
            for suffix, index in (("bytes", 0), ("errors", 2), ("drops", 3)):
                metrics.add("openwrt_network_" + suffix + "_total", values[offset + index], labels, "counter")
    if not devices:
        raise ValueError("network")
    sockets = {}
    for line in text(frames, "sockstat").splitlines():
        protocol, separator, raw = line.partition(":")
        fields = raw.split()
        if not separator or len(fields) % 2:
            raise ValueError("sockets")
        sockets[protocol] = {fields[index]: number(fields[index + 1], integer=True) for index in range(0, len(fields), 2)}
    metrics.add("openwrt_sockets_used", sockets["sockets"]["used"])
    for protocol in ("TCP", "UDP", "RAW", "FRAG"):
        for field in ("inuse", "orphan", "tw", "alloc"):
            if field in sockets.get(protocol, {}):
                metrics.add("openwrt_sockets", sockets[protocol][field], {"protocol": protocol.lower(), "kind": field})
        if protocol in ("TCP", "UDP") and "mem" in sockets.get(protocol, {}):
            metrics.add("openwrt_socket_memory_bytes", sockets[protocol]["mem"] * page_size, {"protocol": protocol.lower()})
    pid = number(text(frames, "pid"), integer=True)
    if pid != number(text(frames, "pid_after"), integer=True):
        raise ValueError("process changed")
    metrics.add("openwrt_murmur_up", int(pid != 0))
    if pid:
        before_pid, before = parse_process_stat(text(frames, "process_stat"))
        after_pid, after = parse_process_stat(text(frames, "process_stat_after"))
        if before_pid != pid or after_pid != pid or before[19] != after[19]:
            raise ValueError("process changed")
        if frames["cmdline"] != frames["cmdline_after"] or not production_command(frames["cmdline"]):
            raise ValueError("process changed")
        status = parse_status(text(frames, "process_status"))
        for suffix, field in {
            "resident_memory_bytes": "VmRSS", "anonymous_memory_bytes": "RssAnon", "file_memory_bytes": "RssFile",
            "shared_memory_bytes": "RssShmem", "peak_memory_bytes": "VmHWM", "virtual_memory_bytes": "VmSize",
        }.items():
            metrics.add("openwrt_murmur_" + suffix, memory_kib(status[field]))
        metrics.add("openwrt_murmur_start_time_seconds", boot_time + number(before[19], integer=True) / hz)
        metrics.add("openwrt_murmur_cpu_seconds_total", (number(before[11], integer=True) + number(before[12], integer=True)) / hz, kind="counter")
        metrics.add("openwrt_murmur_threads", number(status["Threads"], integer=True))
        metrics.add("openwrt_murmur_open_fds", number(text(frames, "fd_count"), integer=True))
        for name, index in (("minor", 7), ("major", 9)):
            metrics.add("openwrt_murmur_page_faults_total", number(before[index], integer=True), {"kind": name}, "counter")
    if "temperature" in frames:
        metrics.add("openwrt_temperature_celsius", number(text(frames, "temperature")) / 1000, {"sensor": "thermal_zone0"})
    return timestamp


def provider_items(payload):
    if not isinstance(payload, dict) or not isinstance(payload.get("providers"), dict) or len(payload["providers"]) > 128:
        raise ValueError("providers")
    for name, provider in payload["providers"].items():
        if not isinstance(name, str) or not name or len(name) > 256 or not isinstance(provider, dict):
            raise ValueError("provider")
        yield name, provider


def probe_state(proxy, url, timestamp):
    extra = proxy.get("extra", {})
    if not isinstance(extra, dict):
        return "unknown", None
    entry = extra.get(url, {})
    if not isinstance(entry, dict) or not isinstance(entry.get("history", []), list):
        return "unknown", None
    history = entry.get("history", [])
    if len(history) > 128:
        raise ValueError("history")
    newest = None
    for sample in history:
        if not isinstance(sample, dict):
            continue
        try:
            date = datetime.datetime.fromisoformat(sample["time"].replace("Z", "+00:00"))
            if date.tzinfo is None:
                continue
            stamp = date.timestamp()
            delay = number(sample["delay"], integer=True)
            if delay > 65535 or stamp <= 0 or stamp > timestamp + 60:
                continue
            if newest is None or stamp >= newest[0]:
                newest = (stamp, delay)
        except (KeyError, ValueError, TypeError, OverflowError, AttributeError):
            continue
    if newest is None:
        return "unknown", None
    if timestamp - newest[0] > PROBE_FRESHNESS_SECONDS or not isinstance(entry.get("alive"), bool):
        return "unknown", newest[0]
    return ("healthy" if entry["alive"] else "unhealthy"), newest[0]


def add_connections(metrics, payload, timestamp):
    if not isinstance(payload, dict) or "connections" not in payload or (payload["connections"] is not None and not isinstance(payload["connections"], list)):
        raise ValueError("connections")
    metrics.add("openwrt_murmur_connections", len(payload["connections"]) if payload["connections"] is not None else 0)
    for direction, key in (("upload", "uploadTotal"), ("download", "downloadTotal")):
        metrics.add("openwrt_murmur_traffic_bytes_total", number(payload[key], integer=True), {"direction": direction}, "counter")


def add_proxy_providers(metrics, payload, timestamp):
    for name, provider in provider_items(payload):
        proxies = provider.get("proxies")
        if not isinstance(proxies, list) or len(proxies) > 4096:
            raise ValueError("proxies")
        totals = {state: 0 for state in STATES}
        probe_totals = {probe: {state: 0 for state in STATES} for probe in PROBES}
        newest = {}
        for proxy in proxies:
            if not isinstance(proxy, dict):
                raise ValueError("proxy")
            states = []
            for probe, url in PROBES.items():
                state, stamp = probe_state(proxy, url, timestamp)
                states.append(state)
                probe_totals[probe][state] += 1
                if stamp is not None:
                    newest[probe] = max(stamp, newest.get(probe, stamp))
            combined = "unhealthy" if "unhealthy" in states else "unknown" if "unknown" in states else "healthy"
            totals[combined] += 1
        for state, count in totals.items():
            metrics.add("openwrt_murmur_provider_proxies", count, {"provider": name, "state": state})
        for probe, counts in probe_totals.items():
            for state, count in counts.items():
                metrics.add("openwrt_murmur_probe_proxies", count, {"provider": name, "probe": probe, "state": state})
            if probe in newest:
                metrics.add("openwrt_murmur_probe_newest_timestamp_seconds", newest[probe], {"provider": name, "probe": probe})


def add_rule_providers(metrics, payload, timestamp):
    for name, provider in provider_items(payload):
        metrics.add("openwrt_murmur_rules", number(provider["ruleCount"], integer=True), {"provider": name})


def render_snapshot(frames, router, duration, now):
    metrics = Metrics(router)
    timestamp = add_base(metrics, frames)
    for endpoint, parser in (("connections", add_connections), ("proxy_providers", add_proxy_providers), ("rule_providers", add_rule_providers)):
        data = Metrics(router)
        success = False
        try:
            if text(frames, endpoint + "_rc") != "0" or text(frames, endpoint + "_status") != "200":
                raise ValueError("api")
            payload = json.loads(frames[endpoint])
            parser(data, payload, timestamp)
            success = True
        except (ValueError, KeyError, TypeError, OverflowError, UnicodeError):
            pass
        metrics.add("openwrt_murmur_api_success", int(success), {"endpoint": endpoint})
        if success:
            metrics.lines.extend(data.lines)
            metrics.types.update(data.types)
    metrics.add("openwrt_collector_success", 1)
    metrics.add("openwrt_collector_last_success_timestamp_seconds", now)
    metrics.add("openwrt_collector_duration_seconds", duration)
    return metrics.render()


def previous_success(previous, router):
    prefix = 'openwrt_collector_last_success_timestamp_seconds{router="' + escape_label(router) + '"} '
    for line in previous.splitlines():
        if line.startswith(prefix):
            try:
                return number(line[len(prefix):])
            except ValueError:
                return None
    return None


def render_failure(router, duration, last_success=None):
    metrics = Metrics(router)
    metrics.add("openwrt_collector_success", 0)
    metrics.add("openwrt_collector_duration_seconds", duration)
    if last_success is not None:
        metrics.add("openwrt_collector_last_success_timestamp_seconds", last_success)
    return metrics.render()


def publish(path, content):
    path = Path(path)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, prefix="." + path.name + ".", suffix=".tmp", delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
            os.fchmod(stream.fileno(), 0o644)
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def collect(target):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+@[A-Za-z0-9_.-]+", target):
        raise ValueError("target")
    result = subprocess.run(
        ["ssh", "-F", "/dev/null", "-T", "-o", "IdentityAgent=none", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", "-o", "ConnectTimeout=5", target, "/bin/ash", "-s"],
        input=SNAPSHOT_SCRIPT.encode("ascii"), stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=30, check=True,
    )
    return parse_frames(result.stdout)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--router", default="openwrt")
    args = parser.parse_args()
    started = time.monotonic()
    failed = False
    try:
        frames = collect(args.target)
        content = render_snapshot(frames, args.router, time.monotonic() - started, time.time())
    except Exception as error:
        failed = True
        print(type(error).__name__, file=sys.stderr)
        last_success = None
        try:
            last_success = previous_success(args.output.read_text(encoding="utf-8"), args.router)
        except (OSError, UnicodeError):
            pass
        content = render_failure(args.router, time.monotonic() - started, last_success)
    try:
        publish(args.output, content)
    except Exception as error:
        print(type(error).__name__, file=sys.stderr)
        return 1
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())

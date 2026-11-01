set -uo pipefail

slot_dir=${CARGO_SLOT_DIR:-/run/cargo-slots}
remote_host=${CARGO_SLOT_REMOTE-pc}
remote_cache=${CARGO_SLOT_REMOTE_CACHE:-/home/labile/.cache/cargo-pc}
remote_sources=${CARGO_SLOT_REMOTE_SOURCES:-/home/labile/.cache/cargo-src}
remote_sccache=${CARGO_SLOT_REMOTE_SCCACHE:-/home/labile/.cache/sccache}
marker=.cargo-slot-owned
forward_names=${CARGO_SLOT_FORWARD:-RUST_BACKTRACE RUST_LOG RUST_TEST_THREADS SKIP_SYSTEM_IPV6_CHECK}

enqueue_epoch=$(date +%s)

cargo_sub() {
  local args=("$@") i
  for i in "${!args[@]}"; do
    if [ "${args[$i]}" = cargo ]; then
      echo "${args[$((i + 1))]:-}"
      return
    fi
  done
}

log_run() {
  local slot=$1 acquired=$2 finish=$3 rc=$4
  printf '%s %s %s %s %s %s\n' \
    "$enqueue_epoch" "$acquired" "$finish" "$slot" "$rc" "${CARGO_TARGET_DIR:-default}" \
    >>"$slot_dir/log"
}

project_root() {
  local root=$PWD
  while [ "$root" != / ] && [ ! -f "$root/Cargo.toml" ]; do
    root=$(dirname "$root")
  done
  if [ -f "$root/Cargo.toml" ]; then
    echo "$root"
  fi
}

workspace_members() {
  local root=$1
  ( cd "$root" && cargo metadata --no-deps --format-version 1 2>/dev/null ) |
    tr ',' '\n' |
    sed -n 's/.*"name":"\([^"]*\)".*/\1/p' |
    sort -u
}

seed_target() {
  local target=$1 template=$2 root lockhash build
  root=$(project_root)
  [ -n "$root" ] || return 0
  lockhash=$(cat "$root/Cargo.lock" "$root/Cargo.toml" <(rustc --version) <(printf '%s' "${RUSTFLAGS:-}") | sha256sum | cut -d' ' -f1)
  if [ -f "$template/.cargo-slot-seed-hash" ] && [ "$(cat "$template/.cargo-slot-seed-hash" 2>/dev/null)" = "$lockhash" ]; then
    return 0
  fi
  build="$template.build.$$"
  rm -rf "$build"
  mkdir -p "$build"
  if ( cd "$root" && CARGO_TARGET_DIR="$build" cargo build --lib && CARGO_TARGET_DIR="$build" cargo test --lib --no-run ); then
    echo "$lockhash" >"$build/.cargo-slot-seed-hash"
    rm -rf "$template"
    mv "$build" "$template"
  else
    rm -rf "$build"
  fi
}

target_built() {
  [ -e "$1" ] && [ -n "$(ls -A "$1" 2>/dev/null)" ]
}

seed_copy() {
  local target=$1 template=$2 tmp root member
  target_built "$target" && return 0
  mkdir -p "$(dirname "$template")"
  exec 7>"$template.lock"
  flock 7
  seed_target "$target" "$template"
  exec 7>&-
  target_built "$target" && return 0
  [ -d "$template" ] || return 0
  root=$(project_root)
  tmp="$target.seed.$$"
  rm -rf "$tmp"
  if cp -a --reflink=auto "$template" "$tmp" 2>/dev/null; then
    if [ -n "$root" ]; then
      while IFS= read -r member; do
        [ -n "$member" ] || continue
        member=${member//-/_}
        find "$tmp" -mindepth 1 \
          \( -path "*/deps/$member-*" -o -path "*/deps/lib$member-*" \
             -o -path "*/.fingerprint/$member-*" -o -path "*/incremental/$member-*" \) \
          -exec rm -rf {} + 2>/dev/null
      done <<<"$(workspace_members "$root")"
    fi
    mv -T "$tmp" "$target" 2>/dev/null || rm -rf "$tmp"
  else
    rm -rf "$tmp"
  fi
}

do_seed() {
  local target=$1 template=$2
  [ -n "$target" ] && [ -n "$template" ] || return 0
  seed_copy "$target" "$template"
  mkdir -p "$target" && touch "$target/$marker"
}

evict_script() {
  local root=$1 trigger=$2 target=$3 minage=$4 dryrun=$5 skip=$6 script
  script=$(cat <<'TEOF'
set -euo pipefail
root="__ROOT__"
trigger=__TRIGGER__
target=__TARGET__
minage=__MINAGE__
skip="__SKIP__"
dryrun=__DRYRUN__
cd "$root"
root_real=$(realpath "$root")
avail_kb=$(df --output=avail -k "$root_real" | tail -1)
avail=$((avail_kb * 1024))
if [ "$avail" -ge "$trigger" ]; then
  echo "NOACTION root=$root_real avail=$avail trigger=$trigger"
  exit 0
fi
echo "TRIGGER root=$root_real avail=$avail trigger=$trigger target=$target"
now=$(date +%s)
cands=$(mktemp)
trap 'rm -f "$cands"' EXIT
while IFS= read -r -d '' d; do
  [ "$(basename "$d")" = tgt-template ] && continue
  [ -n "$skip" ] && [ "$(basename "$d")" = "$skip" ] && continue
  [ -f "$d/.cargo-slot-owned" ] || continue
  d_real=$(realpath "$d") || continue
  [ "$(dirname "$d_real")" = "$root_real" ] || continue
  mt=$(stat -c %Y "$d/.cargo-slot-owned" 2>/dev/null) || continue
  age=$((now - mt))
  [ "$age" -ge "$minage" ] || continue
  printf '%s\t%s\0' "$mt" "$d_real" >>"$cands"
done < <(find "$root_real" -mindepth 1 -maxdepth 1 -type d -print0)
if [ ! -s "$cands" ]; then
  echo "NOACTION root=$root_real no-eligible-dirs"
  exit 0
fi
sort -z -n "$cands" | while IFS=$'\t' read -r -d '' mt d_real; do
  avail_kb=$(df --output=avail -k "$root_real" | tail -1)
  avail=$((avail_kb * 1024))
  if [ "$avail" -ge "$target" ]; then
    echo "DONE root=$root_real avail=$avail target=$target"
    break
  fi
  [ -f "$d_real/.cargo-slot-owned" ] || { echo "SKIP-UNMARKED $d_real"; continue; }
  if [ "$dryrun" = 1 ]; then
    size=$(du -sb "$d_real" 2>/dev/null | cut -f1) || size='?'
    echo "WOULD-EVICT $d_real size=$size age=$((now - mt))s"
    continue
  fi
  lockfile="$d_real.lock"
  if [ -L "$lockfile" ]; then
    echo "SKIP-SYMLINK-LOCK $lockfile"
    continue
  fi
  exec 6>>"$lockfile"
  if flock -n -x 6; then
    size=$(du -sb "$d_real" 2>/dev/null | cut -f1) || size='?'
    rm -rf -- "$d_real"
    echo "EVICT $d_real size=$size age=$((now - mt))s"
  else
    echo "SKIP-LOCKED $d_real held-by-running-job"
  fi
  exec 6>&-
done
TEOF
  )
  script=${script//__ROOT__/$root}
  script=${script//__TRIGGER__/$trigger}
  script=${script//__TARGET__/$target}
  script=${script//__MINAGE__/$minage}
  script=${script//__DRYRUN__/$dryrun}
  script=${script//__SKIP__/$skip}
  printf '%s' "$script"
}

evict_remote() {
  local dryrun=${1:-0} skip=${2:-} trigger target script
  trigger=$((${CARGO_SLOT_REMOTE_TRIGGER_GB:-150} * 1073741824))
  target=$((${CARGO_SLOT_REMOTE_TARGET_GB:-250} * 1073741824))
  script=$(evict_script "$remote_cache" "$trigger" "$target" 0 "$dryrun" "$skip")
  ssh -o BatchMode=yes "$remote_host" bash -c "$(printf '%q' "$script")"
}

run_remote() {
  local slot=$1
  shift
  local target_dir root quoted envs remote_cmd unit scope rc name
  root=$(project_root)
  [ -n "$root" ] || root=$PWD
  if [ -n "${CARGO_TARGET_DIR+x}" ]; then
    target_dir="$remote_cache/${CARGO_TARGET_DIR//\//_}"
  else
    target_dir="$remote_cache/default"
  fi
  if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$remote_host" true 2>/dev/null; then
    echo "cargo-slot: $remote_host unavailable" >&2
    return 255
  fi
  evict_remote 0 "$(basename "$target_dir")" >>"$slot_dir/evict.log" 2>&1 || true
  envs=()
  for name in $forward_names; do
    if [ -n "${!name+x}" ]; then
      envs+=("$(printf '%q' "$name=${!name}")")
    fi
  done
  for name in "${!CARGO_@}"; do
    [ "$name" = CARGO_TARGET_DIR ] && continue
    envs+=("$(printf '%q' "$name=${!name}")")
  done
  if ssh -o BatchMode=yes "$remote_host" test -d "$(printf '%q' "$remote_sccache")" 2>/dev/null; then
    envs+=("SCCACHE_DIR=$(printf '%q' "$remote_sccache")")
    envs+=("RUSTC_WRAPPER=$(printf '%q' "sccache")")
  fi
  quoted=$(printf '%q ' "$@")
  remote_cmd="env ${envs[*]} CARGO_TARGET_DIR=$(printf '%q' "$target_dir") bash -c $(printf '%q' "$quoted")"
  remote_root=$root
  if ! ssh -o BatchMode=yes "$remote_host" test -d "$(printf '%q' "$root")" 2>/dev/null; then
    remote_root="$remote_sources/$(printf '%s' "$root" | sha256sum | cut -c1-16)"
    ssh -o BatchMode=yes "$remote_host" mkdir -p "$(printf '%q' "$remote_root")"
    rsync -a --delete --exclude target --exclude .git "$root/" "$remote_host:$remote_root/" || return 255
  fi
  root_head="root=\$(realpath $(printf '%q' "$remote_root")) && cd \"\$root\""
  if [ -f "$root/flake.nix" ]; then
    remote_cmd="$root_head && nix develop \"\$root#default\" -c bash -c $(printf '%q' "$remote_cmd")"
  elif [ -f "$root/shell.nix" ]; then
    remote_cmd="$root_head && nix-shell \"\$root\" --run $(printf '%q' "$remote_cmd")"
  else
    remote_cmd="$root_head && $remote_cmd"
  fi
  remote_cmd="flock -s -o $(printf '%q' "$target_dir.lock") bash -c $(printf '%q' "$remote_cmd")"
  unit="cargo-slot-remote-$$-$slot"
  scope="systemd-run --user --scope --quiet --collect --unit=$unit -p MemoryMax=${CARGO_SLOT_MEM:-11G} -p MemorySwapMax=2G -p KillMode=control-group -- bash -c"
  ssh -o BatchMode=yes "$remote_host" bash -c "$(printf '%q' "$scope $(printf '%q' "$remote_cmd")")"
  rc=$?
  ssh -o BatchMode=yes "$remote_host" systemctl --user stop "$unit" 2>/dev/null
  return "$rc"
}

run_local() {
  local root quoted
  root=$(project_root)
  [ -n "$root" ] || root=$PWD
  quoted=$(printf '%q ' "$@")
  if [ -f "$root/flake.nix" ]; then
    ( cd "$root" && nix develop "$root#default" -c bash -c "$quoted" )
  elif [ -f "$root/shell.nix" ]; then
    nix-shell "$root" --run "$quoted"
  else
    bash -c "$quoted"
  fi
}

case "${1:-}" in
  --seed-target)
    do_seed "${2:-}" "${3:-}"
    exit 0
    ;;
  --evict-remote)
    evict_remote "${2:-0}" "${3:-}"
    exit 0
    ;;
esac

sub=$(cargo_sub "$@")
if [ "$sub" = fmt ]; then
  started=$(date +%s)
  "$@"
  rc=$?
  log_run fmt "$started" "$(date +%s)" "$rc"
  exit "$rc"
fi

mode=local
if [ -n "$remote_host" ]; then
  mode=remote
fi

if [ "$mode" = local ] && [ "${CARGO_SLOT_ALLOW_LOCAL:-0}" != 1 ]; then
  echo "cargo-slot: local compilation is disabled; set CARGO_SLOT_REMOTE or CARGO_SLOT_ALLOW_LOCAL=1" >&2
  exit 255
fi

if ! mkdir -p "$slot_dir" 2>/dev/null; then
  if [ -z "${CARGO_SLOT_DIR:-}" ]; then
    slot_dir=/tmp/cargo-slots
    mkdir -p "$slot_dir" 2>/dev/null
  fi
fi
if ! mkdir -p "$slot_dir" 2>/dev/null; then
  echo "cargo-slot: cannot create slot directory $slot_dir" >&2
  exit 2
fi
probe="$slot_dir/.cargo-slot-probe.$$"
if ! ( : >"$probe" ) 2>/dev/null; then
  echo "cargo-slot: slot directory $slot_dir is not writable" >&2
  exit 2
fi
rm -f "$probe"

if [ "$mode" = remote ]; then
  slots=${CARGO_SLOT_REMOTE_SLOTS:-5}
  prefix=r
else
  slots=${CARGO_SLOT_LOCAL_SLOTS:-2}
  prefix=l
fi

while :; do
  j=1
  while [ "$j" -le "$slots" ]; do
    if ! exec 8>"$slot_dir/$prefix$j"; then
      echo "cargo-slot: cannot open slot file $slot_dir/$prefix$j" >&2
      exit 2
    fi
    if flock -n 8; then
      acquired=$(date +%s)
      if [ "$mode" = remote ]; then
        run_remote "$prefix$j" "$@"
      else
        run_local "$@"
      fi
      rc=$?
      exec 8>&-
      log_run "$prefix$j" "$acquired" "$(date +%s)" "$rc"
      exit "$rc"
    fi
    exec 8>&-
    j=$((j + 1))
  done
  sleep 5
done

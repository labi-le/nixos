{
  writeShellScriptBin,
  openrgb,
  gnugrep,
  coreutils,
}:

writeShellScriptBin "openrgb-profile" ''
  set -u
  port=6742
  orgb=${openrgb}/bin/openrgb

  wait=0
  if [ "''${1:-}" = "--wait" ]; then
    wait=1
    shift
  fi

  profile="''${1:-default}"
  case "$profile" in
    default|off) ;;
    *)
      echo "usage: openrgb-profile [--wait] default|off" >&2
      exit 2
      ;;
  esac

  devices=(
    "ENE DRAM"
    "Gigabyte AORUS Radeon RX 9070 XT Elite"
    "ASUS TUF GAMING B850M-PLUS WIFI"
    "G502 HERO Gaming Mouse"
  )

  server_devices() {
    "$orgb" --client "127.0.0.1:$port" --nodetect --list-devices 2>/dev/null \
      | while IFS= read -r line; do
          printf '%s\n' "''${line#*: }"
        done
  }

  is_present() {
    printf '%s\n' "$1" | ${gnugrep}/bin/grep -qxF -- "$2"
  }

  if [ "$wait" -eq 1 ]; then
    for ((i = 0; i < 40; i++)); do
      present=$(server_devices)
      missing=0
      for device in "''${devices[@]}"; do
        is_present "$present" "$device" || missing=1
      done
      [ "$missing" -eq 0 ] && break
      ${coreutils}/bin/sleep 1
    done
  fi

  present=$(server_devices)
  if [ -z "$present" ]; then
    echo "openrgb-profile: no devices from 127.0.0.1:$port" >&2
    exit 1
  fi

  apply() {
    device=$1
    shift
    if is_present "$present" "$device"; then
      "$orgb" --client "127.0.0.1:$port" --nodetect --device "$device" "$@"
    else
      echo "openrgb-profile: $device not detected, skipping" >&2
    fi
  }

  case "$profile" in
    default)
      apply "ENE DRAM" --mode Static --color FF0000
      apply "Gigabyte AORUS Radeon RX 9070 XT Elite" --mode Static --color FF0000
      apply "ASUS TUF GAMING B850M-PLUS WIFI" \
        --zone 0 --size 24 --zone 1 --size 24 --zone 2 --size 24 \
        --mode Static --color FF0000
      apply "G502 HERO Gaming Mouse" --mode Static --color FF0000
      ;;
    off)
      apply "ENE DRAM" --mode Off
      apply "Gigabyte AORUS Radeon RX 9070 XT Elite" --mode Static --color 000000
      apply "ASUS TUF GAMING B850M-PLUS WIFI" --mode Off
      apply "G502 HERO Gaming Mouse" --mode Off
      ;;
  esac
''

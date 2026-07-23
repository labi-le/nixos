{ writeShellScriptBin
, openrgb
, gnugrep
, coreutils
,
}:

writeShellScriptBin "openrgb-apply-off" ''
  set -u
  port=6742
  orgb=${openrgb}/bin/openrgb

  prev=""
  stable=0
  for ((i = 0; i < 40; i++)); do
    count=$("$orgb" --client "127.0.0.1:$port" --nodetect --list-devices 2>/dev/null | ${gnugrep}/bin/grep -cE '^[0-9]+: ')
    if [ "''${count:-0}" -gt 0 ] && [ "$count" = "$prev" ]; then
      stable=$((stable + 1))
      [ "$stable" -ge 2 ] && break
    else
      stable=0
    fi
    prev="$count"
    ${coreutils}/bin/sleep 1
  done

  "$orgb" --client "127.0.0.1:$port" --nodetect --device "ENE DRAM" --mode Off
  "$orgb" --client "127.0.0.1:$port" --nodetect --device "Gigabyte AORUS Radeon RX 9070 XT Elite" --mode Static --color 000000
  "$orgb" --client "127.0.0.1:$port" --nodetect --device "ASUS TUF GAMING B850M-PLUS WIFI" --mode Off
  exec "$orgb" --client "127.0.0.1:$port" --nodetect --device "G502 HERO Gaming Mouse" --mode "Spectrum Cycle" --speed 0
''

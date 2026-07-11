{ writeShellScriptBin
, openrgb
, gnugrep
, coreutils
,
}:

writeShellScriptBin "openrgb-apply-off" ''
  set -u
  port=6742
  profile=/home/labile/.config/OpenRGB/off.orp
  orgb=${openrgb}/bin/openrgb
  mouse="G502 HERO Gaming Mouse"
  mouse_mode="Spectrum Cycle"
  mouse_speed="0"

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

  "$orgb" --client "127.0.0.1:$port" --nodetect --profile "$profile"
  exec "$orgb" --client "127.0.0.1:$port" --nodetect --device "$mouse" --mode "$mouse_mode" --speed "$mouse_speed"
''

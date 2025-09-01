{ writeShellScriptBin
, stuntman
, gnugrep
, gawk
, coreutils
, runtimeShell
,
}:

writeShellScriptBin "getmyip" ''
  #!${runtimeShell}

  STUN_SERVERS="
  stun.l.google.com 19302
  stun.voip.blackberry.com 3478
  stunserver2025.stunprotocol.org 3478
  "

  OLD_IFS="$IFS"
  IFS=$'\n'
  for server_line in $STUN_SERVERS; do
    if [ -z "$server_line" ]; then
      continue
    fi

    IFS="$OLD_IFS"
    set -- $server_line
    host=$1
    port=$2
    
    my_ip=$(${coreutils}/bin/timeout 1s ${stuntman}/bin/stunclient "$host" "$port" 2>/dev/null | \
      ${gnugrep}/bin/grep 'Mapped address' | \
      ${gawk}/bin/awk '{print $3}' | \
      ${coreutils}/bin/cut -d':' -f1)

    if [ -n "$my_ip" ]; then
      echo "$my_ip"
      exit 0
    fi

    IFS=$'\n'
  done

  echo "Failed to resolve external IP from any STUN server." >&2
  exit 1
''

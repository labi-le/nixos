#!/usr/bin/env bash

chat=-1002045081420
mcp=http://127.0.0.1:8932/mcp
default_hosts="pc notebook"
hosts=
interval=2

usage() {
  printf '%s\n' "usage: clip-links [-c chat_id] [-H host]"
}

while getopts ":c:H:h" opt; do
  case "$opt" in
    c) chat=$OPTARG ;;
    H) hosts="${hosts:+$hosts }$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

if [ -z "$hosts" ]; then
  hosts=$default_hosts
fi

mcp_call() {
  curl -sS -m 30 "$mcp" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    -d "$1"
}

send() {
  local url=$1 payload reply line text
  payload=$(jq -cn \
    --arg chat "$chat" \
    --arg text "$url" \
    '{jsonrpc:"2.0",id:1,method:"tools/call",params:{name:"send_message",arguments:{chat_id:(if ($chat|test("^-?[0-9]+$")) then ($chat|tonumber) else $chat end),message:$text}}}')
  if ! reply=$(mcp_call "$payload"); then
    printf '%s\n' "error: mcp unreachable" >&2
    return 1
  fi
  line=$(printf '%s\n' "$reply" | sed -n 's/^data: //p' | head -n1)
  if [ -z "$line" ]; then
    printf '%s\n' "error: empty reply" >&2
    return 1
  fi
  if printf '%s' "$line" | jq -e '.error' >/dev/null 2>&1; then
    printf '%s\n' "error: $(printf '%s' "$line" | jq -c '.error')" >&2
    return 1
  fi
  text=$(printf '%s' "$line" | jq -r '.result.content[0].text // empty')
  if [ "$text" != "Message sent successfully." ]; then
    printf '%s\n' "error: $text" >&2
    return 1
  fi
}

display_of() {
  ssh -o BatchMode=yes -o ConnectTimeout=5 "$1" \
    "ls /run/user/1000 | grep -m1 '^wayland-[0-9]*$'" 2>/dev/null
}

read_clip() {
  ssh -o BatchMode=yes -o ConnectTimeout=5 "$1" \
    "WAYLAND_DISPLAY=$2 XDG_RUNTIME_DIR=/run/user/1000 wl-paste -n" 2>/dev/null
}

links_from() {
  printf '%s' "$1" | grep -oE "https?://[^[:space:]<>\"']+" || true
}

trim() {
  printf '%s' "$1" | sed -E 's/[).,;:!?»]+$//'
}

keep() {
  case "$1" in
    https://tiktok.com/*|https://*.tiktok.com/*) return 0 ;;
    https://youtu.be/*) return 0 ;;
    https://youtube.com/watch*|https://*.youtube.com/watch*) return 0 ;;
    https://youtube.com/shorts/*|https://*.youtube.com/shorts*) return 0 ;;
  esac
  return 1
}

declare -A display
declare -A seen

for host in $hosts; do
  display[$host]=$(display_of "$host")
done

printf '%s\n' "watching $hosts -> chat $chat"

while :; do
  for host in $hosts; do
    d=${display[$host]}
    if [ -z "$d" ]; then
      d=$(display_of "$host")
      display[$host]=$d
      [ -z "$d" ] && continue
    fi
    if ! text=$(read_clip "$host" "$d"); then
      display[$host]=
      continue
    fi
    while IFS= read -r url; do
      url=$(trim "$url")
      keep "$url" || continue
      [ -n "${seen[$url]:-}" ] && continue
      seen[$url]=1
      send "$url" && printf '%s\n' "sent $host $url"
    done <<< "$(links_from "$text")"
  done
  sleep "$interval"
done

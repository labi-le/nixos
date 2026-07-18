{ writeShellScriptBin
, fzf
, swayfx
, tmuxPlugins
,
}:

writeShellScriptBin "tmux-session-switcher" ''
  ${swayfx}/bin/swaymsg border none >/dev/null 2>&1

  # Cold start (fresh boot): no tmux server yet. Start it here — in the graphical
  # session, so it inherits WAYLAND_DISPLAY/SWAYSOCK/SSH_AUTH_SOCK — and restore
  # the last resurrect snapshot synchronously (run-shell blocks the queue until
  # it finishes) BEFORE listing sessions, so restored detached sessions show up
  # in fzf and `new-session -A` below attaches to them instead of racing a
  # background restore. Chaining in one invocation keeps the empty server from
  # exiting (exit-empty) before restore recreates the sessions.
  if ! tmux has-server 2>/dev/null; then
    tmux start-server \; run-shell "${tmuxPlugins.resurrect}/share/tmux-plugins/resurrect/scripts/restore.sh"
  fi
  sessions=$(tmux list-sessions -F '#S' 2>/dev/null || true)
  out=$(printf '%s\n' "$sessions" | ${fzf}/bin/fzf --print-query --reverse --prompt 'tmux session: ')
  [ $? -eq 130 ] && exit 0
  query=$(printf '%s\n' "$out" | sed -n '1p')
  selection=$(printf '%s\n' "$out" | sed -n '2p')
  name="''${query:-$selection}"
  [ -z "$name" ] && exit 0
  clients=$(tmux list-clients -t "=$name" 2>/dev/null | wc -l)
  if [ "$clients" -gt 0 ]; then
    ${swayfx}/bin/swaymsg "[app_id=\"tmux-switcher\" title=\"^$name$\"] focus" >/dev/null 2>&1
    exit 0
  fi
  printf '\033]2;%s\007' "$name"
  ${swayfx}/bin/swaymsg 'floating disable; border normal 2' >/dev/null 2>&1
  exec tmux new-session -A -s "$name"
''

{
  writeShellScriptBin,
  fzf,
  swayfx,
}:

writeShellScriptBin "tmux-session-switcher" ''
    sessions=$(tmux list-sessions -F '#S' 2>/dev/null || true)
    kill_bind=$(cat <<'BIND'
  bspace:transform:if [ -n "$FZF_QUERY" ]; then echo backward-delete-char; else echo "execute-silent(s={}; tmux kill-session -t \"=\$s\" 2>/dev/null)+reload(tmux list-sessions -F \"#S\" 2>/dev/null || true)"; fi
  BIND
  )
    out=$(printf '%s\n' "$sessions" | ${fzf}/bin/fzf --print-query --reverse \
      --prompt 'tmux session: ' \
      --header 'backspace on empty query: kill session' \
      --bind "$kill_bind")
    [ $? -eq 130 ] && exit 0
    query=$(printf '%s\n' "$out" | sed -n '1p')
    selection=$(printf '%s\n' "$out" | sed -n '2p')
    name="''${query:-$selection}"
    [ -z "$name" ] && exit 0
    clients=$(tmux list-clients -t "=$name" 2>/dev/null | wc -l)
    if [ "$clients" -gt 0 ]; then
      ${swayfx}/bin/swaymsg "[app_id=\"tmux.switcher\" title=\"^$name$\"] focus" >/dev/null 2>&1
      exit 0
    fi
    printf '\033]2;%s\007' "$name"
    ${swayfx}/bin/swaymsg 'floating disable; border normal 2' >/dev/null 2>&1
    exec tmux new-session -A -s "$name"
''

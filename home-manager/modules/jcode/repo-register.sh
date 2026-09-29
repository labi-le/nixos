#!/bin/sh
set -u
mode="${1:-}"
cwd="${JCODE_HOOK_CWD:-}"
[ -n "$cwd" ] || exit 0
[ -n "${CODE_INDEXER_DISABLE:-}" ] && exit 0
if [ ! -d "$cwd/.git" ] && [ ! -f "$cwd/.git" ]; then exit 0; fi
[ -e "$cwd/.no-code-index" ] && exit 0
index_repo="${REPO_REGISTER_INDEX_REPO:-@indexRepo@/bin/index-repo}"
pid="${REPO_REGISTER_PID:-$PPID}"
if [ "$mode" = "start" ]; then
  exec "$index_repo" register "$cwd" --pid "$pid"
fi
if [ "$mode" = "stop" ]; then
  exec "$index_repo" unregister "$cwd" --pid "$pid"
fi
exit 0

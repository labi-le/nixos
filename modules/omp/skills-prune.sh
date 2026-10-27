#!/usr/bin/env bash
set -euo pipefail

target=${1:?skills-prune: missing skills directory}
shift

if [ -L "$target" ]; then
  printf 'skills-prune: refusing symlinked root %s\n' "$target" >&2
  exit 1
fi

if [ ! -d "$target" ]; then
  exit 0
fi

declare -A declared=()
for name in "$@"; do
  declared[$name]=1
done

shopt -s nullglob
for entry in "$target"/*; do
  name=${entry##*/}
  if [ -z "${declared[$name]+set}" ]; then
    rm -rf -- "$entry"
  fi
done

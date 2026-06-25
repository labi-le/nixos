#!/usr/bin/env bash
set -euo pipefail

# Update the fetchFromGitHub skill pins (rev + hash) in
#   home-manager/modules/opencode/integrations.nix
# to the latest upstream default-branch HEAD.
#
# Counterpart to scripts/codegen/* (which regenerate provider model lists);
# this one refreshes the hand-maintained `programs.opencode.skills` pins.
# Idempotent: re-running while already current makes no changes.

script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
target="$script_dir/../home-manager/modules/opencode/integrations.nix"

# name | owner | repo   (owner is the unique anchor inside integrations.nix)
skills=(
  "desloppify|peteromallet|desloppify"
  "plantuml-rendering|asolfre|plantuml-rendering-skill"
  "caveman|JuliusBrussee|caveman"
)

prefetch() {
  if command -v nix-prefetch-github >/dev/null 2>&1; then
    nix-prefetch-github "$1" "$2"
  else
    nix run nixpkgs#nix-prefetch-github -- "$1" "$2"
  fi
}

changed=0
for entry in "${skills[@]}"; do
  IFS='|' read -r name owner repo <<<"$entry"

  json="$(prefetch "$owner" "$repo")"
  rev="$(jq -r '.rev' <<<"$json")"
  hash="$(jq -r '.hash // empty' <<<"$json")"
  if [ -z "$rev" ] || [ -z "$hash" ]; then
    printf 'ERROR: could not resolve rev/hash for %s/%s\n' "$owner" "$repo" >&2
    exit 1
  fi

  before="$(sha1sum "$target")"
  # Scope rev+hash substitution to this skill's fetchFromGitHub block:
  # from its unique `owner = "<owner>";` line to the next closing `}`.
  sed -i -E \
    -e "/owner = \"${owner}\";/,/\}/ s|rev = \"[^\"]*\";|rev = \"${rev}\";|" \
    -e "/owner = \"${owner}\";/,/\}/ s|hash = \"[^\"]*\";|hash = \"${hash}\";|" \
    "$target"
  after="$(sha1sum "$target")"

  if [ "$before" != "$after" ]; then
    printf 'updated  %-20s %s\n' "$name" "$rev"
    changed=1
  else
    printf 'current  %-20s %s\n' "$name" "$rev"
  fi
done

if [ "$changed" -eq 1 ]; then
  printf '\nPins updated in %s\nRun `home-manager switch` to apply.\n' "$target"
else
  printf '\nAll skill pins already at latest upstream HEAD.\n'
fi

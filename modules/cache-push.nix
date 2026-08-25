{ config
, lib
, pkgs
, ...
}:

let
  hook = pkgs.writeShellScript "cache-push-hook" ''
    set -uo pipefail

    if [ -z "''${OUT_PATHS:-}" ]; then
      exit 0
    fi

    read -r -a paths <<< "$OUT_PATHS"

    export NIX_SSHOPTS='-i /run/agenix/cache-push-key -o IdentitiesOnly=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new'
    target=''${CACHE_PUSH_TARGET:-pet}

    if ${pkgs.coreutils}/bin/timeout 600 ${pkgs.nix}/bin/nix copy --to "ssh://''${target}" "''${paths[@]}"; then
      echo "cache-push: pushed ''${#paths[@]} path(s)" >&2
    else
      echo 'cache-push: push failed, continuing' >&2
    fi
    exit 0
  '';
in
{
  config = lib.mkIf (config.networking.hostName != "server") {
    age.secrets.cache-push-key = {
      file = ../secrets/cache-push-key.age;
      mode = "0400";
    };

    nix.settings.post-build-hook = hook;
  };
}

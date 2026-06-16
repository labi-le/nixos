{
  pkgs,
  lib,
  osConfig,
  ...
}:

let
  providerDefs = [
    (import ./providers/litellm.nix)
    (import ./providers/pollinations.nix)
    (import ./providers/aigate.nix)
    (import ./providers/aerolink.nix)
  ];
  # Single source of truth for the `index-repo` binary. Consumed by
  # packages.nix (placed on $PATH) and wrappers.nix (the opencode wrapper
  # launches `index-repo --daemon $PWD` in the background and reaps it on exit).
  indexerPkg = pkgs.writeTextFile {
    name = "index-repo";
    text = builtins.readFile ./scripts/index_repo.py;
    executable = true;
    destination = "/bin/index-repo";
  };

  wrappers = import ./wrappers.nix {
    inherit
      pkgs
      lib
      osConfig
      providerDefs
      indexerPkg
      ;
  };
in

{
  _module.args.indexerPkg = indexerPkg;

  imports = [
    ./packages.nix
    # ./agents.nix
    ./integrations.nix
  ];

  programs.opencode = {
    enable = true;
    package = wrappers.opencodeWrapped;
    extraPackages = [ pkgs.rtk ];

    tui = {
      theme = lib.mkForce "opencode";
    };

    settings = {
      # default_agent = "orchestrator";
      # compaction = {
      #   auto = true;
      #   tail_turns = 14;
      # };
      # tool_output = {
      #   max_lines = 120;
      #   max_bytes = 12288;
      # };
      provider = lib.listToAttrs (
        map (item: {
          name = item.id;
          value = item.provider;
        }) providerDefs
      );
    };
  };
}

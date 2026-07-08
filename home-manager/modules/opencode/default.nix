{
  pkgs,
  lib,
  config,
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
  indexerPkg = pkgs.index-repo;
  variantConfigDirs = {
    claude = "opencode-claude";
    gpt = "opencode-gpt";
    deepseek = "opencode-deepseek";
  };

  wrappers = import ./wrappers.nix {
    inherit
      pkgs
      lib
      osConfig
      providerDefs
      variantConfigDirs
      ;
    indexHook = config.services.index-repo.opencode.hook;
  };
in

{
  _module.args.indexerPkg = indexerPkg;
  _module.args.opencodeWrappers = wrappers;
  _module.args.opencodeVariantConfigDirs = variantConfigDirs;

  imports = [
    ./packages.nix
    # ./agents.nix
    ./integrations.nix
    ./lsp
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

{ inputs, system }:

final: prev: {
  belphegor = inputs.belphegor.packages.${system}.default;
  deal = inputs.deal.packages.${system}.default;
  # accela = inputs.accela.packages.${system}.default;
  sls-steam = inputs.sls-steam.packages.${system}.sls-steam;
  sls-steam-wrapped = inputs.sls-steam.packages.${system}.wrapped;
  # ayugram-desktop = inputs.ayugram-desktop.packages.${system}.ayugram-desktop;

  # stable = import inputs.nixpkgs-stable {
  #   inherit system;
  #   config.allowUnfree = true;
  # };

  openldap = prev.openldap.overrideAttrs {
    doCheck = !prev.stdenv.hostPlatform.isi686;
  };

  libfprint-tod = prev.libfprint-tod.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./pkgs/libfprint-tod-drop-elan-0c4b.patch ];
    doInstallCheck = false;
    nativeBuildInputs = old.nativeBuildInputs ++ [
      (prev.python3.withPackages (ps: [ ps.pygobject3 ]))
    ];
  });

  fprintd-tod = prev.fprintd.override { libfprint = final.libfprint-tod; };

  getmyip = prev.callPackage ./pkgs/getmyip.nix { };
  ea-disable-overlay = prev.callPackage ./pkgs/ea-disable-overlay.nix { };
  generate-context = prev.callPackage ./pkgs/generate-context.nix { };
  tmux-session-switcher = prev.callPackage ./pkgs/tmux-session-switcher.nix { };
  openrgb-apply-off = prev.callPackage ./pkgs/openrgb-apply-off.nix { };
  agenix = inputs.agenix.packages.${system}.default;
  nur = (inputs.nur.overlays.default final prev).nur;
  apple-fonts = inputs.apple-fonts.packages.${system};
  opencode = inputs.opencode.packages.${system}.opencode;
  nix-index-with-small-db = inputs.nix-index-database.packages.${system}.nix-index-with-small-db;
  index-repo = inputs.index-repo.packages.${system}.default;
  omp = inputs.omp-flake.packages.${system}.default;
  # The upstream flake bakes in a nodejs-22.14.0 whose V8 build SIGSEGVs on this
  # host (Zen5). Rerun the upstream-built JS (deps live in bin/node_modules) with
  # our working nixpkgs node instead of the broken bundled one.
  swaywm-mcp =
    let base = inputs.swaywm-mcp.packages.${system}.default;
    in prev.writeShellScriptBin "swaywm-mcp" ''
      exec ${prev.nodejs}/bin/node ${base}/bin/main.js "$@"
    '';
}

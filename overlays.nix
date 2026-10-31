{ inputs, system }:

final: prev: {
  belphegor = inputs.belphegor.packages.${system}.default;
  deal = inputs.deal.packages.${system}.default;
  # accela = inputs.accela.packages.${system}.default;
  sls-steam = inputs.sls-steam.packages.${system}.sls-steam;
  sls-steam-wrapped = inputs.sls-steam.packages.${system}.wrapped;
  ayugram-desktop = inputs.ayugram-desktop.packages.${system}.default;

  stable = import inputs.nixpkgs-stable {
    inherit system;
    config.allowUnfree = true;
  };


  xdg-desktop-portal = prev.xdg-desktop-portal.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./pkgs/xdg-desktop-portal/remove-token-assertion.patch
    ];
  });

  # Screencast on sway 1.11 goes through xdpw's ext-image-copy backend, and the
  # stream dies with "pipewire: out of buffers": upstream asks PipeWire for a
  # pool of two buffers, while Chromium's WebRTC capturer keeps one of them
  # while it encodes. Raising the pool only buys time -- with eight the picture
  # still froze after about an hour -- so the pool goes to sixteen and upstream
  # PR #397 comes along, which re-triggers the PipeWire graph on starvation
  # instead of leaving the stream wedged forever (upstream issues #390/#395).
  xdg-desktop-portal-wlr = prev.xdg-desktop-portal-wlr.overrideAttrs (old: {
    version = "0.8.3-unstable-2026-07-09";
    src = final.fetchFromGitHub {
      owner = "emersion";
      repo = "xdg-desktop-portal-wlr";
      rev = "544e11481338a3784a11cb30561f06982fc0a158";
      hash = "sha256-qDL67snP2DFPp7Fgpru9MtC4iujWaz1A3c6ZALIoXnk=";
    };
    patches = (old.patches or [ ]) ++ [ ./pkgs/xdpw-pipewire-buffer-starvation.patch ];
    postPatch = (old.postPatch or "") + ''
      substituteInPlace include/pipewire_screencast.h \
        --replace-fail "#define XDPW_PWR_BUFFERS 2" "#define XDPW_PWR_BUFFERS 16"
    '';
    postInstall = (old.postInstall or "") + ''
      substituteInPlace $out/share/xdg-desktop-portal/portals/wlr.portal \
        --replace-fail "UseIn=wlroots;sway;Wayfire;river;phosh;Hyprland;" "UseIn=wlroots;sway;Wayfire;river;phosh;Hyprland;niri;"
    '';
  });

  equicord = prev.equicord.overrideAttrs (_: rec {
    version = "1.15.14.0";
    src = final.fetchFromGitHub {
      owner = "Equicord";
      repo = "Equicord";
      rev = "8d0ebf3549890be2ecb1e1d602b1695f584c71cc";
      hash = "sha256-ijNxC/uR3Wy4JX/6qNnNGQwS5752+vK2T26N1bsLeG4=";
    };
    pnpmDeps = final.fetchPnpmDeps {
      pname = "equicord";
      inherit version src;
      pnpm = final.pnpm_10;
      fetcherVersion = 3;
      hash = "sha256-vwGHq4chumYcdmiNcAh49bxErVv7GuxCnIyzgXO5pOE=";
    };
    env = {
      EQUICORD_REMOTE = "Equicord/Equicord";
      EQUICORD_HASH = src.rev;
    };
  });

  equibop = prev.equibop.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/main/vencordDir.ts \
        --replace-fail 'join(SESSION_DATA_DIR, "equicord.asar")' '"${final.equicord}/equibop"'
    '';
  });

  getmyip = prev.callPackage ./pkgs/getmyip.nix { };
  ea-disable-overlay = prev.callPackage ./pkgs/ea-disable-overlay.nix { };
  generate-context = prev.callPackage ./pkgs/generate-context.nix { };
  tmux-session-switcher = prev.callPackage ./pkgs/tmux-session-switcher.nix { };
  openrgb-profile = prev.callPackage ./pkgs/openrgb-profile.nix { };
  keychron-backlight = prev.callPackage ./pkgs/keychron-backlight.nix { };
  clip-links = prev.callPackage ./pkgs/clip-links.nix { };
  yam = prev.callPackage ./pkgs/yam.nix { };
  agenix = inputs.agenix.packages.${system}.default;
  nur = (inputs.nur.overlays.default final prev).nur;
  apple-fonts = inputs.apple-fonts.packages.${system};
  nix-index-with-small-db = inputs.nix-index-database.packages.${system}.nix-index-with-small-db;
  index-repo = inputs.index-repo.packages.${system}.default;
  omp = inputs.llm-agents.packages.${system}.omp;
  jcode = inputs.llm-agents.packages.${system}.jcode;
  maki = inputs.llm-agents.packages.${system}.maki;
  # langfuse still pins wrapt<2.0 while nixpkgs ships 2.2.2, so
  # pythonRuntimeDepsCheck fails and takes the whole litellm build (and with it
  # the system closure) down. That check asserts metadata, not actual
  # compatibility, and langfuse is only a transitive dep here -- nothing in
  # services.litellm enables langfuse tracing. nixos-unstable had the identical
  # failure as of 2026-07-26, so this cannot wait for an upstream bump. Relax
  # just the one bound; overrideScope keeps the rebuild to langfuse's dependents
  # instead of the whole python set.
  python3Packages = prev.python3Packages.overrideScope (
    _: pyPrev: {
      langfuse = pyPrev.langfuse.overridePythonAttrs (old: {
        pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "wrapt" ];
      });
    }
  );
}

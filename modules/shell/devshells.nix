# Per-language dev shells, callable globally via the `dev` flake registry:
#   nix develop dev#go     nix develop dev#rust   nix develop dev#python
#   nix develop dev#php    nix develop dev#jvm    nix develop dev#dotnet
#   nix develop dev        (default)
#
# Toolchains mirror the per-language `baseEnv` of the JetBrains IDE wrappers in
# modules/ide/module.nix so a language's shell and its IDE stay consistent.
{ pkgs, ... }:

{
  default = pkgs.mkShell {
    packages = with pkgs; [
      gnumake
      git
      nixpkgs-fmt
    ];
  };

  go = pkgs.mkShell {
    packages = with pkgs; [
      go
      golangci-lint
      graphviz
      gcc
      nodejs
    ];
  };

  rust = pkgs.mkShell {
    packages = with pkgs; [
      gcc
      pkg-config
      cargo
      rustup
    ];
    env = {
      PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
      LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.openssl ];
    };
  };

  python = pkgs.mkShell {
    packages = with pkgs; [
      python3
      poetry
      black
      mypy
    ];
  };

  php = pkgs.mkShell {
    packages = with pkgs; [
      php.packages.composer
      php.packages.psalm
      (php.buildEnv {
        extensions =
          { all, enabled }:
          with all;
          enabled
          ++ [
            xdebug
            redis
          ];
        extraConfig = ''
          xdebug.mode=debug
          xdebug.client_port=9003
          xdebug.start_with_request=yes
        '';
      })
    ];
  };

  jvm = pkgs.mkShell {
    packages = with pkgs; [
      jdk
      maven
      gradle
      gcc
      gdb
      lldb
    ];
  };

  dotnet = pkgs.mkShell {
    packages = with pkgs; [
      dotnet-sdk
    ];
  };
}

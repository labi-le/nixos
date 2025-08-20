{
  description = "Wrapper for Rust Rover with environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            inherit system;
            pkgs = import nixpkgs {
              inherit system;
              config.allowUnfree = true;
              overlays = [ self.overlays.default ];
            };
          }
        );
    in
    {
      overlays.default = final: prev: {
        rust-rover-with-env = prev.jetbrains.rust-rover.overrideAttrs (oldAttrs: {
          nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ prev.makeWrapper ];
          postFixup = (oldAttrs.postFixup or "") + ''
            wrapProgram $out/bin/rust-rover \
              --set PKG_CONFIG_PATH "${prev.openssl.dev}/lib/pkgconfig" \
              --set LD_LIBRARY_PATH "${prev.lib.makeLibraryPath [ prev.openssl ]}" \
              --prefix PATH : "${
                prev.lib.makeBinPath [
                  prev.gcc
                  prev.pkg-config
                  prev.cargo
                  prev.rustup
                  prev.libarchive
                ]
              }"
          '';
        });
      };

      packages = forAllSystems (
        { pkgs, system }:
        {
          inherit (pkgs) rust-rover-with-env;
        }
      );
    };
}

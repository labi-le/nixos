{
  description = "Wrapper for GoLand with environment";

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
        goland-with-env = prev.jetbrains.goland.overrideAttrs (oldAttrs: {
          nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ prev.makeWrapper ];
          postFixup = (oldAttrs.postFixup or "") + ''
            wrapProgram $out/bin/goland \
              --prefix PATH : "${
                prev.lib.makeBinPath [
                  prev.go
                  prev.golangci-lint
                  prev.graphviz
                ]
              }"
          '';
        });
      };

      packages = forAllSystems (
        { pkgs, system }:
        {
          inherit (pkgs) goland-with-env;
        }
      );
    };
}

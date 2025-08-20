{
  description = "Wrapper for PHPStorm with environment";

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
        phpstorm-with-env = prev.jetbrains.phpstorm.overrideAttrs (oldAttrs: {
          nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ prev.makeWrapper ];
          postFixup = (oldAttrs.postFixup or "") + ''
            wrapProgram $out/bin/phpstorm \
              --prefix PATH : "${
                prev.lib.makeBinPath [
                  prev.php.packages.composer
                  prev.php.packages.psalm
                  (prev.php.buildEnv {
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
                ]
              }"
          '';
        });
      };

      packages = forAllSystems (
        { pkgs, system }:
        {
          inherit (pkgs) phpstorm-with-env;
        }
      );
    };
}

{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.ide;

  plugin = ./plugin.jar;
  customVmOptions = ''
    --add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED
    --add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED
    -javaagent:${plugin}=jetbrains
  '';

  ides = with pkgs; [
    {
      name = "goland";
      packageName = "goland";
      packageWithEnv = "goland-with-env";
      executable = "goland";
      baseEnv = [
        go
        golangci-lint
        graphviz
      ];
      extraWrapperArgs = "";
    }
    {
      name = "phpstorm";
      packageName = "phpstorm";
      packageWithEnv = "phpstorm-with-env";
      executable = "phpstorm";
      baseEnv = [
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
      extraWrapperArgs = "";
    }
    {
      name = "rustrover";
      packageName = "rust-rover";
      packageWithEnv = "rust-rover-with-env";
      executable = "rust-rover";
      baseEnv = [
        gcc
        pkg-config
        cargo
        rustup
      ];
      extraWrapperArgs = ''
        --set PKG_CONFIG_PATH "${openssl.dev}/lib/pkgconfig" \
        --set LD_LIBRARY_PATH "${lib.makeLibraryPath [ openssl ]}" \
      '';
    }
  ];

  enabledIdes = builtins.filter (ide: cfg.${ide.name}.enable) ides;

in
{
  options.ide = lib.genAttrs (map (ide: ide.name) ides) (name: {
    enable = lib.mkEnableOption "Enable ${name} IDE";
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = "with pkgs; [ ranger gdb ]";
      description = "Additional packages to add to the IDE's environment PATH.";
    };
    extraVmOptions = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "-Xmx4096m -Xms256m";
      description = "Extra JVM options to pass to the IDE.";
    };
  });

  config = lib.mkIf (enabledIdes != [ ]) {
    nixpkgs.overlays = [
      (
        final: prev:
          let
            mkIdeWrapper =
              ide:
              final.jetbrains.${ide.packageName}.overrideAttrs (oldAttrs: {
                nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ prev.makeWrapper ];
                postFixup = (oldAttrs.postFixup or "") + ''
                  wrapProgram $out/bin/${ide.executable} \
                    ${ide.extraWrapperArgs} \
                    --prefix PATH : "${prev.lib.makeBinPath (ide.baseEnv ++ cfg.${ide.name}.extraPackages)}"
                '';
              });
          in
          {
            jetbrains =
              prev.jetbrains
              // lib.listToAttrs (
                map
                  (ide: {
                    name = ide.packageName;
                    value = prev.jetbrains.${ide.packageName}.override {
                      vmopts =
                        (prev.jetbrains.${ide.packageName}.vmopts or "")
                        + "\n"
                        + customVmOptions
                        + "\n"
                        + cfg.${ide.name}.extraVmOptions;
                    };
                  })
                  enabledIdes
              );
          }
          // lib.listToAttrs (
            map
              (ide: {
                name = ide.packageWithEnv;
                value = mkIdeWrapper ide;
              })
              enabledIdes
          )
      )
    ];

    environment.systemPackages = map (ide: pkgs.${ide.packageWithEnv}) enabledIdes;
  };
}

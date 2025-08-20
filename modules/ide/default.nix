{ config
, lib
, pkgs
, inputs
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

  ides = [
    {
      name = "goland";
      packageName = "goland";
      flakeOverlay = inputs.goland-flake.overlays.default;
      packageWithEnv = "goland-with-env";
    }
    {
      name = "phpstorm";
      packageName = "phpstorm";
      flakeOverlay = inputs.phpstorm-flake.overlays.default;
      packageWithEnv = "phpstorm-with-env";
    }
    {
      name = "rustrover";
      packageName = "rust-rover";
      flakeOverlay = inputs.rustrover-flake.overlays.default;
      packageWithEnv = "rust-rover-with-env";
    }
  ];

  enabledIdes = builtins.filter (ide: cfg.${ide.name}.enable) ides;

in
{
  options.ide = lib.genAttrs (map (ide: ide.name) ides) (name: {
    enable = lib.mkEnableOption "Enable ${name} IDE";
  });

  config = lib.mkIf (enabledIdes != [ ]) {

    nixpkgs.overlays = [
      (final: prev: {
        jetbrains =
          prev.jetbrains
            // lib.listToAttrs (
            map
              (ide: {
                name = ide.packageName;
                value = prev.jetbrains.${ide.packageName}.override {
                  vmopts = (prev.jetbrains.${ide.packageName}.vmopts or "") + "\n" + customVmOptions;
                };
              })
              enabledIdes
          );
      })
    ]
    ++ (map (ide: ide.flakeOverlay) enabledIdes);

    environment.systemPackages = map (ide: pkgs.${ide.packageWithEnv}) enabledIdes;
  };
}

{
  config,
  lib,
  pkgs,
  user,
  ...
}:

let
  userName = user.name;
  userCfg = config.users.users.${userName};
  homeDirectory = userCfg.home;
  jcodeDir = "${homeDirectory}/.jcode";
  configDir = "${homeDirectory}/.config/jcode";

  providers = import ./providers.nix { inherit config lib; };
  hooks = import ./hooks.nix { inherit pkgs; };
  providerEnv = import ./provider-env.nix {
    inherit pkgs configDir userName;
    group = userCfg.group;
  };

  extensionHooks = config.jcode.extensions.hooks;

  toml = pkgs.formats.toml { };
  configFile = toml.generate "jcode-config.toml" (
    import ./config.nix {
      inherit homeDirectory extensionHooks;
      inherit (providers) baseProviders extensionProviders defaultRoute;
      inherit (hooks) commitGate commentGate upstreamGate repoRegister;
    }
  );

  mcpJson = import ./mcp.nix { inherit config lib pkgs; };
  skillLinks = import ./skills.nix { inherit lib pkgs jcodeDir; };
in
{
  imports = [
    ./deepseek-web.nix
    ./space-bunny.nix
  ];

  options.jcode.extensions = {
    providers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = { };
      description = ''
        Extra jcode provider profiles, merged into the generated config.toml.
        Plug-in modules such as modules/jcode/deepseek-web.nix use this instead
        of editing the profile list inline.
      '';
    };

    hooks = lib.mkOption {
      type = lib.types.submodule {
        options = {
          session_start = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Extra session_start hook commands, appended after the built-in ones.";
          };
          turn_start = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Extra turn_start hook commands, appended after the built-in ones.";
          };
        };
      };
      default = { };
      description = "Extra jcode hook commands contributed by plug-in modules.";
    };
  };

  config = {
    assertions = [
      {
        assertion = providers.providerNameCollisions == [ ];
        message = "jcode.extensions.providers redefines built-in jcode profiles: ${
          lib.concatStringsSep ", " providers.providerNameCollisions
        }";
      }
    ];

    systemd.tmpfiles.rules = [
      "d ${jcodeDir} 0700 ${userName} ${userCfg.group} -"
      "d ${jcodeDir}/skills 0700 ${userName} ${userCfg.group} -"
      "d ${configDir} 0700 ${userName} ${userCfg.group} -"
      "f ${jcodeDir}/no_telemetry 0600 ${userName} ${userCfg.group} -"
      "L+ ${jcodeDir}/mcp.json - - - - ${mcpJson}"
      "L+ ${jcodeDir}/config.toml - - - - ${configFile}"
      "L+ ${jcodeDir}/prompt-overlay.md - - - - ${./prompt-overlay.md}"
      "L+ ${homeDirectory}/AGENTS.md - - - - ${./AGENTS.md}"
    ]
    ++ skillLinks;

    system.activationScripts.jcodeProviderEnv = lib.stringAfter [ "users" ] ''
      mkdir -p ${jcodeDir} ${configDir}
      chown ${userName}:${userCfg.group} ${jcodeDir} ${configDir}
      ${builtins.concatStringsSep "\n" (map providerEnv.writeProviderEnv providerEnv.providerEnvFiles)}
    '';
  };
}

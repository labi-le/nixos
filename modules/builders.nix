# ./hosts/modules/builders.nix
{ config
, lib
, pkgs
, ...
}:

with lib;
with types;

let
  cfg = config.builders;
  nixBuildUserDefault = "nixbuild";
  clientArchitecture = pkgs.stdenv.hostPlatform.system;

  determineEffectiveRemoteCores =
    userSpecifiedCores:
    let
      minimalDefaultCores = 8;
    in
    if userSpecifiedCores != null && builtins.isInt userSpecifiedCores then
      userSpecifiedCores
    else
      minimalDefaultCores;

  remoteBuilderType = submodule {
    options = {
      enable = mkOption {
        type = bool;
        default = true;
        description = "Enable this specific remote builder configuration.";
      };
      host = mkOption {
        type = str;
        description = "Hostname or IP address of the builder machine. REQUIRED.";
        example = "builder.local";
      };
      keyFile = mkOption {
        type = str;
        description = "Path to the SSH private key file on the client machine. REQUIRED.";
        example = "/home/user/.ssh/builder_key";
      };
      user = mkOption {
        type = str;
        default = nixBuildUserDefault;
        description = "Username on the remote builder machine.";
      };
      cores = mkOption {
        type = nullOr int;
        default = null;
        description = "Number of cores for this builder. If null, uses client's max-jobs or fallback.";
      };
      architecture = mkOption {
        type = str;
        default = clientArchitecture;
        description = "Architecture of the builder (e.g., 'x86_64-linux'). Defaults to client's architecture.";
      };
      supportedFeatures = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [
          "big-parallel"
          "kvm"
        ];
      };
    };
  };

  # --- Генерация списка строк сборщиков ---
  builderStringsList =
    let
      enabledBuilders = filterAttrs (name: builderCfg: builderCfg.enable) cfg.remoteBuilders;
    in
    mapAttrsToList
      (
        builderName: builderCfg:
          let
            user = builderCfg.user;
            host = builderCfg.host;
            keyFile = builderCfg.keyFile;
            arch = builderCfg.architecture;
            finalCores = determineEffectiveRemoteCores builderCfg.cores;
            coresStr = toString finalCores;
            supportedFeaturesStr =
              if builderCfg.supportedFeatures == [ ] then
                "-"
              else
                lib.concatStringsSep " " builderCfg.supportedFeatures;

          in
          "ssh-ng://${user}@${host} ${arch} ${keyFile} ${coresStr} - ${supportedFeaturesStr} -"
      )
      enabledBuilders;

in
{
  options.builders = {
    # --- Server-Side Options ---
    useAsBuilder = mkEnableOption "Expose this machine as a remote Nix builder";
    authorizedKeyFiles = mkOption {
      type = listOf path;
      default = [ ];
      description = "List of public key files allowed for SSH login to the build user (${nixBuildUserDefault}).";
    };

    # --- Client-Side Options ---
    enableRemoteBuilding = mkEnableOption "Enable the use of remote builders defined in 'remoteBuilders'";

    remoteBuilders = mkOption {
      type = attrsOf remoteBuilderType;
      default = { };
      description = ''
        Attribute set defining the remote builders to use.
        The key is a logical name for the builder, and the value is an attribute
        set conforming to the 'remoteBuilderType'.
        Required fields for enabled builders: 'host', 'keyFile'.
      '';
      example = {
        mainServer = {
          host = "server.local";
          keyFile = "/home/user/.ssh/id_rsa_builder";
        };
        fastLaptop = {
          enable = false;
          host = "laptop.local";
          user = "builduser";
          keyFile = "/home/user/.ssh/id_rsa_laptop";
          cores = 8;
          architecture = "aarch64-linux";
        };
      };
    };

    remoteBuilderUseSubstitutes = mkOption {
      type = bool;
      default = true;
      description = "Whether the client should ask remote builders to use binary caches (substitutes).";
    };
  };

  config = lib.mkMerge [
    # --- Configuration for Being a Builder ---
    (mkIf cfg.useAsBuilder {
      users.users.${nixBuildUserDefault} = {
        isNormalUser = true;
        createHome = true;
        home = "/var/lib/${nixBuildUserDefault}";
        group = nixBuildUserDefault;
        openssh.authorizedKeys.keyFiles = cfg.authorizedKeyFiles;
      };
      users.groups.${nixBuildUserDefault} = { };
      nix.settings.trusted-users = lib.mkBefore [
        nixBuildUserDefault
      ];
      services.openssh = {
        enable = true;
      };
    })

    # --- Configuration for Using Remote Builders ---
    (mkIf (cfg.enableRemoteBuilding && builderStringsList != [ ]) {
      nix.settings = {
        builders = lib.mkForce builderStringsList;
        builders-use-substitutes = cfg.remoteBuilderUseSubstitutes;
      };
    })
  ];
}

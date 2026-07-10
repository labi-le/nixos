{ config
, lib
, options
, ...
}:

let
  cfg = config.mySystem.user;
in
{
  options.mySystem.user = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "labile";
      description = "The main user of the system";
    };
    git = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "labi-le";
        description = "Git user name";
      };
      email = lib.mkOption {
        type = lib.types.str;
        default = "1a6i1e@gmail.com";
        description = "Git user email";
      };
    };
  };

  config = lib.mkMerge [
    {
      _module.args = {
        user = cfg;
      };

      users.users.${cfg.name} = {
        isNormalUser = true;
        description = cfg.name;
        extraGroups = [
          "networkmanager"
          "wheel"
          "docker"
          "audio"
          "video"
          "input"
          "tun"
          "fuse"
          "realtime"
        ];
      };

      services.getty.autologinUser = cfg.name;

      environment.variables = {
        EDITOR = "nvim";
        TERMINAL = "alacritty";
        NIXPKGS_ALLOW_UNFREE = "1";
      };

      environment.interactiveShellInit = ''
        alias n='nvim'
        alias nd='nix develop'
        alias m='make'
        alias rr='yazi'
        alias y='yazi'
        alias ddu='docker update --restart=no $(docker ps -qa)'
        alias dsa='docker stop $(docker ps -qa)'
        alias lz='lazygit'
        if command -v zellij >/dev/null 2>&1; then
          alias zza='zellij attach'
          zz() {
            if [ $# -eq 0 ]; then
              zellij
            else
              zellij attach -c "$1"
            fi
          }
        fi
      '';
    }
    (lib.optionalAttrs (options ? home-manager) {
      home-manager.extraSpecialArgs = {
        user = cfg;
      };
      home-manager.users.${cfg.name} = {
        imports = [ ../home-manager/home.nix ];
      };
    })
  ];
}

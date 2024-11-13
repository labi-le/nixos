{ config, ... }:

{
  users.users.labile = {
    isNormalUser = true;
    description = "labile";
    extraGroups = [ "networkmanager" "wheel" "docker" "audio" "video" "input" "tun" "fuse" ];
  };

  services.getty.autologinUser = "labile";

  environment.sessionVariables = {
    XDG_CONFIG_HOME = "${config.users.users.labile.home}/.config";
  };

  environment.variables.EDITOR = "nvim";

  environment.interactiveShellInit = ''
    alias ec='nvim ${config.users.users.labile.home}/nix/system/configuration.nix'
    alias n='nvim'
    alias sw='alacritty -e `cd ${config.users.users.labile.home}/nix && make`'
    alias up='alacritty -e `cd ${config.users.users.labile.home}/nix/ make update`'
    alias ddu='docker update --restart=no $(docker ps -qa)'
    alias dsa='docker stop $(docker ps -qa)'
  '';
}

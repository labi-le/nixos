{ config, ... }:

{
  users.users.labile = {
    isNormalUser = true;
    description = "labile";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "audio"
      "video"
      "input"
      "tun"
      "fuse"
    ];
  };

  services.getty.autologinUser = "labile";

  environment.sessionVariables = {
    XDG_CONFIG_HOME = "${config.users.users.labile.home}/.config";
  };

  environment.variables = {
    EDITOR = "nvim";
    TERMINAL = "alacritty";
    XDG_TERMINAL_EXEC = "$TERMINAL";
  };

  environment.interactiveShellInit = ''
    alias n='nvim'
    alias m='make'
    alias rr='ranger'
    alias y='yazi'
    alias ddu='docker update --restart=no $(docker ps -qa)'
    alias dsa='docker stop $(docker ps -qa)'
    alias lz='lazygit'
  '';
}

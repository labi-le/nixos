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
      "realtime"
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
    NIXPKGS_ALLOW_UNFREE = "1";
  };

  environment.interactiveShellInit = ''
    alias n='nvim'
    alias m='make'
    alias rr='yazi'
    alias y='yazi'
    alias ddu='docker update --restart=no $(docker ps -qa)'
    alias dsa='docker stop $(docker ps -qa)'
    alias lz='lazygit'
  '';
}

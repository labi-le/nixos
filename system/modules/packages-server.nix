{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    wget
    fastfetch
    gnumake
    lsof
    mpv
    unzip

    psmisc # for killall

    alacritty
    ranger
    btop
    git
    sshfs

    openssl
    dig

    gdu # disk usage
  ];
}


{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    wget
    fastfetch
    gnumake
    lsof
    unzip
    jq

    psmisc # for killall

    alacritty
    ranger
    btop
    git
    sshfs

    openssl
    dig

    gdu # disk usage
    hdparm # for smartctl

  ];
}


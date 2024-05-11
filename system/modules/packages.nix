{ pkgs, ... }:

{
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    fastfetch
    gnumake

    psmisc
    ncurses
    pavucontrol
    dconf

    go

    ipset
    gost

    xdg-utils
    wl-clipboard
    slurp
    wayshot
    grim
    brightnessctl

    (callPackage ../../pkgs/wl-uploader.nix { })

    alacritty
    ranger
    btop
    git
    home-manager
    docker
    docker-compose
    libnotify
    sshfs

    google-chrome
    vesktop

    telegram-desktop
  ];

  fonts.packages = with pkgs; [
    dejavu_fonts
    jetbrains-mono
    font-awesome
    noto-fonts
    noto-fonts-emoji
  ];
}


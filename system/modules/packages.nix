{ pkgs, ... }:

{
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    fastfetch
    gnumake
    lsof

    psmisc
    ncurses
    pavucontrol
    dconf

    go

    (php.buildEnv {
      extensions = { all, enabled }: with all; enabled ++ [ xdebug redis ];
      extraConfig = ''
        xdebug.mode=debug
        xdebug.discover_client_host=1
      '';
    })

    ipset

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

    dbeaver-bin
    notepad-next

    stable.openfortivpn

    glib
    gsettings-desktop-schemas
  ];


  fonts.packages = with pkgs; [
    dejavu_fonts
    jetbrains-mono
    font-awesome
    noto-fonts
    noto-fonts-emoji
  ];
}


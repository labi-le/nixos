# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware.nix
      ./modules
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "pc"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  #networking.proxy.default = "http://192.168.1.2:10443";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Moscow";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ru_RU.UTF-8";
    LC_IDENTIFICATION = "ru_RU.UTF-8";
    LC_MEASUREMENT = "ru_RU.UTF-8";
    LC_MONETARY = "ru_RU.UTF-8";
    LC_NAME = "ru_RU.UTF-8";
    LC_NUMERIC = "ru_RU.UTF-8";
    LC_PAPER = "ru_RU.UTF-8";
    LC_TELEPHONE = "ru_RU.UTF-8";
    LC_TIME = "ru_RU.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.labile = {
    isNormalUser = true;
    description = "labile";
    extraGroups = [ "networkmanager" "wheel" "docker" "audio" "video" "input" "tun" ];
    packages = with pkgs; [];
  };

  # Enable automatic login for the user.
  services.getty.autologinUser = "labile";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
      wget
      neovim
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
      grim

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

  environment.sessionVariables = rec {
    XDG_CONFIG_HOME = "\${HOME}/.config";
    SDL_VIDEODRIVER= "wayland";
    QT_QPA_PLATFORM= "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION= "1";
    _JAVA_AWT_WM_NONREPARENTING= "1";
    MOZ_ENABLE_WAYLAND= "1";
    WLR_NO_HARDWARE_CURSORS= "1";
    WLR_RENDERER_ALLOW_SOFTWARE= "1";
  };

  environment.variables.EDITOR = "nvim";
  hardware.opengl.enable = true;

  fonts.packages = with pkgs; [ 
    dejavu_fonts
    jetbrains-mono
    font-awesome
    noto-fonts
    noto-fonts-emoji
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

  environment.interactiveShellInit = ''
    alias ec='nvim /home/labile/nix/system/configuration.nix'
    alias rr='ranger'
    alias n='nvim'
'';

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  xdg.portal.config.common.default = "*";
  sound.enable = true;
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };
  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
  system.autoUpgrade.enable = true;
}


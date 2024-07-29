{ config, ... }:

{
  imports =
    [
      ./modules/default-server.nix
    ];

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

  users.users.labile = {
    isNormalUser = true;
    description = "labile";
    extraGroups = [ "networkmanager" "wheel" "docker" "audio" "video" "input" "tun" ];
  };

  services.getty.autologinUser = "labile";

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.sessionVariables = {
    XDG_CONFIG_HOME = "${config.users.users.labile.home}/.config";
    SDL_VIDEODRIVER = "wayland";
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    _JAVA_AWT_WM_NONREPARENTING = "1";
    MOZ_ENABLE_WAYLAND = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
    WLR_RENDERER_ALLOW_SOFTWARE = "1";
  };
  environment.etc."ppp/options".text = "ipcp-accept-remote";

  environment.variables.EDITOR = "nvim";
  hardware.graphics.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  environment.interactiveShellInit = ''
    alias ec='nvim ${config.users.users.labile.home}/nix/system/configuration.nix'
    alias rr='ranger'
    alias n='nvim'
    alias sw='alacritty -e `cd ${config.users.users.labile.home}/nix && make`'
    alias up='alacritty -e `cd ${config.users.users.labile.home}/nix/ make update`'
    alias ddu='docker update --restart=no $(docker ps -qa)'
    alias dsa='docker stop $(docker ps -qa)'
  '';

  services.openssh = {
    enable = true;
  };

  system.stateVersion = "24.11";
  system.autoUpgrade = {
    enable = false;
    flake = "${config.users.users.labile.home}/nix";
    flags = [
      "--update-input"
      "nixpkgs"
    ];
  };

  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=-1
  '';

  services.fstrim.enable = true;
  services.gnome.gnome-keyring.enable = true;

  networking.firewall.enable = false;
  boot.blacklistedKernelModules = [ "snd_pcsp" "pcspkr" ];

  nix.settings.auto-optimise-store = true;
  nix.gc.automatic = true;
  nix.gc.dates = "daily";

  systemd.extraConfig = ''
    DefaultTimeoutStopSec=10s
  '';
  services.journald.extraConfig = ''
    Storage=persistent
    SystemMaxUse=1Gystemd
  '';
}


{ ... }:

{
  imports = [
    ./../modules/base.nix
    ./../modules/nginx.nix
    ./../modules/drive.nix
    ./../modules/kernel-cachyos.nix
    ./../modules/grafana.nix
    # ./../modules/gitlab.nix
    ./../modules/syncthing/server.nix
    ./../modules/nvidia/gt210.nix
    ./../modules/vaultwarden.nix
    ./../modules/qbittorrent.nix
    ./../modules/awg
    ./../modules/network
    ./../modules/dpi.nix
  ];

  networking.firewall = {
    allowedTCPPorts = [ 6901 ]; # todo move to package (work-wm.nix)
  };
  network = {
    enableFirewall = true;
    injectHosts = true;
  };

  networking.enableIPv6 = false;

  services.xserver.xkb = {
    layout = "us";
  };

  # asusctl profile -p
  # asusctl profile -P quiet
  # asusctl profile -l
  # battery limit
  # asusctl -c 60
  # services.asusd = {
  #   enable = true;
  #   enableUserService = true;
  # };
  # systemd.tmpfiles.rules = [
  #   "w /sys/class/power_supply/BAT0/charge_control_end_threshold - - - - 60"
  # ];
  boot.kernel.sysctl = {
    "vm.dirty_background_ratio" = 15;
    "vm.dirty_ratio" = 30;
    "vm.dirty_expire_centisecs" = 30 * (60 * 100); # 1m = 60*100;
    "vm.dirty_writeback_centisecs" = 30 * (60 * 100);
  };

  hardware.graphics.enable = true;

  programs.gnupg.agent = {
    enable = true;
  };

  system.stateVersion = "24.11";

  packages = {
    server = true;
  };

  services.logind.settings.Login.HandleLidSwitch = "ignore";
  networking.interfaces.enp37s0.wakeOnLan.enable = true;
}

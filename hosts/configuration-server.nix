{ ... }:

{
  imports = [
    ./../modules/base.nix
    ./../modules/nginx.nix
    ./../modules/drive.nix
    ./../modules/kernel-zen.nix
    ./../modules/grafana.nix
    ./../modules/gitlab.nix
  ];

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
  };

  # asusctl profile -p
  # asusctl profile -P quiet
  # asusctl profile -l
  # battery limit
  # asusctl -c 60
  services.asusd = {
    enable = true;
    enableUserService = true;
  };
  systemd.tmpfiles.rules = [
    "w /sys/class/power_supply/BAT0/charge_control_end_threshold - - - - 60"
  ];
  boot.kernel.sysctl = {
    "vm.dirty_background_ratio" = 3;
    "vm.dirty_ratio" = 60;
    "vm.dirty_expire_centisecs" = 3000;
    "vm.dirty_writeback_centisecs" = 500;
  };

  hardware.graphics.enable = true;

  programs.gnupg.agent = {
    enable = true;
  };

  system.stateVersion = "24.11";

  packages = {
    server = true;
  };
}

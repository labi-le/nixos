{ ... }:

{
  imports = [
    ./modules/base.nix
    ./modules/nginx.nix
    ./modules/drive.nix
    ./modules/kernel-zen.nix
    ./modules/grafana.nix
  ];

  builders = {
    useAsBuilder = true;
    authorizedKeyFiles = [ ../keys/nixbuild-pc.pub ];
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
  };

  # asusctl profile -p
  # asusctl profile -P Balanced
  # asusctl profile -l
  # services.asusd = {
  #   enable = true;
  #   enableUserService = true;
  # };
  systemd.tmpfiles.rules = [
    "w /sys/class/power_supply/BAT0/charge_control_end_threshold - - - - 60"
  ];

  hardware.graphics.enable = true;

  programs.gnupg.agent = {
    enable = true;
  };

  system.stateVersion = "24.11";

  packages = {
    server = true;
  };
}

{ lib, pkgs, ... }:
{
  services.xserver.videoDrivers = lib.mkForce [ ];

  boot.kernelModules = [ "nouveau" ];

  boot.blacklistedKernelModules = [
    "nvidia"
    "nvidia_uvm"
    "nvidia_drm"
    "nvidia_modeset"
  ];
  boot.kernelParams = [ "nouveau.modeset=1" ];

  environment.systemPackages = with pkgs; [
    pciutils
    lm_sensors
  ];
  services.supergfxd.enable = lib.mkForce false;
  environment.etc."modprobe.d/supergfxd.conf".text = lib.mkForce ''
    # Disabled for server
  '';
}

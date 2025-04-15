{ pkgs, ... }:

{
  boot = {
    kernelParams = [
      "nvidia-drm.modeset=1"
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    ];

    initrd.availableKernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];
    initrd.kernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];
  };

  hardware.graphics.extraPackages = with pkgs; [
    linuxPackages.nvidiaPackages.vulkan_beta
  ];

  hardware.nvidia.open = false;

  hardware.nvidia.powerManagement.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];

  imports = [ ./prime.nix ];
}

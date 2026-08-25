{ lib, ... }:

{
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 32768;
      priority = 10;
    }
  ];

  boot.kernelParams = [ "zswap.enabled=0" ];

  boot.kernel.sysctl = {
    "vm.swappiness" = lib.mkForce 150;
    "vm.watermark_scale_factor" = 125;
  };
}

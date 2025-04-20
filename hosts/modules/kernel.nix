{ pkgs, ... }:
{
  boot.kernelParams = [
    "nvme_core.default_ps_max_latency_us=0"
    "mitigations=off"
  ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.blacklistedKernelModules = [
    "snd_pcsp"
    "pcspkr"
  ];
}

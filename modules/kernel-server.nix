{ pkgs, ... }:

{
  boot.kernelParams = [
    "nvme_core.default_ps_max_latency_us=0"
    "mitigations=off"
    "threadirqs"
  ];
  boot.kernelPackages = pkgs.linuxPackages;
  boot.blacklistedKernelModules = [
    "snd_pcsp"
    "pcspkr"
  ];
}

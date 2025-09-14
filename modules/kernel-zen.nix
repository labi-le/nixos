{ pkgs, ... }:

{
  boot.kernelParams = [
    "nvme_core.default_ps_max_latency_us=0"
    "mitigations=off"
  ];
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_zen;
  boot.extraModulePackages = with pkgs; [
    linuxKernel.packages.linux_zen.cpupower
  ];
  boot.blacklistedKernelModules = [
    "snd_pcsp"
    "pcspkr"
  ];
}

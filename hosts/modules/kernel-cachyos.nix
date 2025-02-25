{ pkgs, ... }:

{
  boot.kernelParams = [
    "nvme_core.default_ps_max_latency_us=0"
    "mitigations=off"
  ];
  boot.kernelPackages = pkgs.linuxPackages_cachyos;
  boot.blacklistedKernelModules = [ "snd_pcsp" "pcspkr" ];
  services.scx = {
    enable = true;
    scheduler = "scx_rusty";
  };
}

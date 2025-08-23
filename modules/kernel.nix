{ pkgs, lib, ... }:
{
  boot.kernelParams = [
    "nvme_core.default_ps_max_latency_us=0"
    "mitigations=off"
    "amd_pstate=passive"

  ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.blacklistedKernelModules = [
    "snd_pcsp"
    "pcspkr"
  ];

  boot.kernelPatches = [
    {
      name = "ryzen-4500u-optimization";
      patch = null;

      structuredExtraConfig = with lib.kernel; {
        NO_HZ_IDLE = yes;
        HZ_250 = yes;
        X86_AMD_PSTATE = yes;
        NO_HZ_FULL = lib.mkForce no;

      };
    }
  ];
}

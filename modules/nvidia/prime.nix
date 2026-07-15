{ config, lib, ... }:

let
  cfg = config.enablePrime;
in
{
  options.enablePrime = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable PRIME offloading support for NVIDIA hybrid graphics";
  };

  options.primeBusIds = {
    intel = lib.mkOption {
      type = lib.types.str;
      description = "Intel PCI bus id for PRIME offloading (set per-host).";
    };
    nvidia = lib.mkOption {
      type = lib.types.str;
      description = "NVIDIA PCI bus id for PRIME offloading (set per-host).";
    };
  };

  config = lib.mkMerge [
    {
      environment.sessionVariables = {
        LIBVA_DRIVER_NAME = "nvidia";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        __NV_PRIME_RENDER_OFFLOAD = "1";
        __VK_LAYER_NV_optimus = "NVIDIA_only";
        NVD_BACKEND = "direct";
        WLR_NO_HARDWARE_CURSORS = "1";
        # NIXOS_OZONE_WL = "1";
      };
    }

    (lib.mkIf cfg {
      hardware.nvidia = {
        prime = {
          sync.enable = false;
          intelBusId = config.primeBusIds.intel;
          nvidiaBusId = config.primeBusIds.nvidia;

          offload = {
            enable = true;
            enableOffloadCmd = true;
          };
        };
      };
    })
  ];
}

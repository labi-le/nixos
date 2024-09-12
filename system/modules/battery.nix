{ config, lib, ... }:
with lib;
{
  options.battery.control = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc "Enable battery control";
    };
  };

  config = mkIf config.battery.control.enable {
    services.auto-cpufreq = {
      enable = true;
      settings = {
        charger = {
          governor = "performance";
          turbo = "auto";
        };
        battery = {
          governor = "powersave";
          turbo = "auto";
        };
      };
    };
  };
}

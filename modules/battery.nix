{ pkgs, lib, ... }:
{
  # services.tlp = {
  #   enable = true;
  #   settings = {
  #     START_CHARGE_THRESH_BAT0 = 40;
  #     STOP_CHARGE_THRESH_BAT0 = 80;
  #
  #     PLATFORM_PROFILE_ON_AC = "balanced";
  #     # PLATFORM_PROFILE_ON_AC = "low-power";
  #     PLATFORM_PROFILE_ON_BAT = "balanced";
  #
  #     CPU_BOOST_ON_AC = 0;
  #     CPU_BOOST_ON_BAT = 0;
  #
  #     CPU_HWP_DYN_BOOST_ON_AC = 0;
  #     CPU_HWP_DYN_BOOST_ON_BAT = 0;
  #
  #     CPU_DRIVER_OPMODE_ON_AC = "active";
  #     CPU_DRIVER_OPMODE_ON_BAT = "active";
  #
  #     AMDGPU_ABM_LEVEL_ON_AC = 0;
  #     AMDGPU_ABM_LEVEL_ON_BAT = 3;
  #
  #     RUNTIME_PM_ON_AC = "auto";
  #     RUNTIME_PM_ON_BAT = "auto";
  #
  #     # CPU_SCALING_GOVERNOR_ON_AC = "powersave";
  #     CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
  #
  #   };
  # };

  services.auto-cpufreq = {
    enable = true;
    settings = {
      battery = {
        governor = "schedutil";
        # governor = "powersave";
        turbo = "never";
        platform_profile = "low-power";
        # energy_performance_preference = "balance_power";
        energy_performance_preference = "power";
      };
      charger = {
        governor = "performance";
        turbo = "auto";
      };
    };
  };

  environment.systemPackages = with pkgs; [
    powertop
    acpi
  ];
}

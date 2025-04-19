{ pkgs, lib, ... }:
{
  # services.tlp = {
  #   enable = true;
  #   settings = {
  #     CPU_SCALING_GOVERNOR_ON_AC = "performance";
  #     CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
  #     CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
  #     CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
  #     CPU_MIN_PERF_ON_AC = 0;
  #     CPU_MAX_PERF_ON_AC = 100;
  #     CPU_MIN_PERF_ON_BAT = 0;
  #     CPU_MAX_PERF_ON_BAT = 70;
  #     START_CHARGE_THRESH_BAT0 = 40;
  #     STOP_CHARGE_THRESH_BAT0 = 80;
  #   };
  # };

  services.auto-cpufreq = {
    enable = true;
    settings = {
      battery = {
        governor = "schedutil";
        turbo = "never";
        platform_profile = "low-power";
        energy_performance_preference = "balance_power";
      };
      charger = {
        governor = "performance";
        turbo = "auto";
      };
    };
  };

  powerManagement.enable = true;
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };
  services.logind = {
    lidSwitch = lib.mkForce "suspend-then-hibernate";
    lidSwitchExternalPower = lib.mkForce "suspend";
    extraConfig = ''
      HandlePowerKey=suspend-then-hibernate
      HandleSuspendKey=suspend-then-hibernate
      HandleHibernateKey=hibernate
      IdleAction=suspend-then-hibernate
      IdleActionSec=15min
    '';
  };
  systemd.sleep.extraConfig = ''
    HibernateMode=platform shutdown
    HibernateDelaySec=15min
    SuspendMode=mem standby freeze
    SuspendState=mem standby freeze
  '';
  boot.kernelParams = [
    "mem_sleep_default=deep"
    "acpi_sleep=nonvs"
  ];
  environment.systemPackages = with pkgs; [
    powertop
    acpi
  ];
}

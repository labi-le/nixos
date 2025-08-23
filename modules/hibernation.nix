{ lib, ... }:
{
  # powerManagement.enable = true;
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

}

{
  services.fstrim.enable = true;
  services.fstrim.interval = "daily";

  systemd.services.fstrim = {
    restartIfChanged = false;
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "5min";
    };
  };

  services.smartd.enable = true;
}

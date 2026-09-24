{
  systemd.settings.Manager = {
    DefaultTimeoutStopSec = "10s";
    DefaultOOMPolicy = "continue";
  };

  systemd.user.settings.Manager = {
    DefaultOOMPolicy = "continue";
  };
}

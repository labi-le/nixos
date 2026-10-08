{
  systemd.settings.Manager = {
    DefaultTimeoutStopSec = "10s";
    DefaultOOMPolicy = "continue";
  };

  systemd.user.settings.Manager = {
    DefaultOOMPolicy = "continue";
  };

  systemd.user.slices.nix-control-eval = {
    description = "Bounded nix-control evaluations";
    sliceConfig = {
      MemoryHigh = "6G";
      MemoryMax = "8G";
      MemorySwapMax = 0;
    };
  };
}

{ ... }:
{
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 10;
    extraArgs = [
      "--sort-by-rss"
    ];
  };

}

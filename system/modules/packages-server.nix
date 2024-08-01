{ pkgs }:

with pkgs;
[
  gdu # disk usage
  smartmontools
  hdparm
  nvme-cli
]


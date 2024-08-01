{
  imports = [
    ./proxy.nix
  ];

  networking.networkmanager.enable = true;
  networking.firewall.enable = false;
}

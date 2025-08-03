{ ... }:
{

  services.syncthing = {
    enable = true;
    guiAddress = "0.0.0.0:8384";
  };
  networking.firewall = {
    allowedTCPPorts = [ 22000 ];
    allowedUDPPorts = [ 22000 ];
  };

  users.users.labile.extraGroups = [ "syncthing" ];
}

{ config, lib, ... }:

let
  cfg = config.sync;
  portMatch = lib.strings.match ".*:([0-9]+)" config.services.syncthing.guiAddress;
  syncthingPort = lib.strings.toInt (lib.head portMatch);
in
{
  services.caddy = {
    enable = true;
    virtualHosts."syncthing".extraConfig = ''
      tls internal
      reverse_proxy 127.0.0.1:${toString syncthingPort}
    '';
  };

  security.pki.certificateFiles = [
    ./caddy-local.crt
  ];

  programs.firefox.policies.Certificates.Install = [
    "${./caddy-local.crt}"
  ];
}

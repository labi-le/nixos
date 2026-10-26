{ lib, ... }:

let
  version = "2.10.8";
in
{
  virtualisation.oci-containers.backend = lib.mkDefault "docker";

  virtualisation.oci-containers.containers.music-assistant = {
    image = "ghcr.io/music-assistant/server:${version}";
    extraOptions = [ "--network=host" ];
    environment = {
      LOG_LEVEL = "info";
      TZ = ":/etc/localtime-host";
    };
    volumes = [
      "/var/lib/music-assistant:/data"
      "/drive/sync/music:/media:ro"
      "/etc/localtime:/etc/localtime-host:ro"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/music-assistant 0755 root root -"
  ];

  networking.firewall.allowedTCPPorts = [
    8095
    8097
    1704
    1705
  ];

  networking.firewall.allowedTCPPortRanges = [
    {
      from = 4953;
      to = 5153;
    }
  ];
}

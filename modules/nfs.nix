{ config, ... }:
{
  fileSystems."/home/drive" = {
    device = "${config.network.serverAddress}:/drive";
    fsType = "nfs";
    options = [
      "noauto"
      "x-systemd.automount"
      "nofail"
      "noatime"
      "_netdev"
      "hard"
      "nconnect=16"
      "noresvport"
      "actimeo=60"
      "nfsvers=4.2"
      "nordirplus"
    ];
  };

  fileSystems."/hdd4tb/torrents" = {
    device = "${config.network.serverAddress}:/hdd4tb/torrents";
    fsType = "nfs";
    options = [
      "noauto"
      "x-systemd.automount"
      "nofail"
      "noatime"
      "_netdev"
      "hard"
      "nconnect=16"
      "noresvport"
      "actimeo=60"
      "nfsvers=4.2"
      "nordirplus"
    ];
  };

}

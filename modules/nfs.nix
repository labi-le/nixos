{
  # sudo ssh-copy-id labile@192.168.1.2
  # fileSystems."/home/drive" = {
  #   device = "labile@192.168.1.2:/drive";
  #   fsType = "sshfs";
  #   options = [
  #     "allow_other"
  #     "_netdev"
  #     "x-systemd.automount"
  #     # SSH options
  #     "reconnect" # handle connection drops
  #     "ServerAliveInterval=15" # keep connections alive
  #   ];
  # };

  fileSystems."/home/drive" = {
    device = "192.168.1.2:/drive";
    fsType = "nfs";
    options = [
      "auto"
      "nofail"
      "noatime"
      "_netdev"
      "hard"
      "nconnect=32"
      "noresvport"
      "actimeo=60"
      "nfsvers=4.2"
    ];
  };

}

{ user, ... }:
{
  # sudo ssh-copy-id ${user.name}@192.168.1.2
  # fileSystems."/drive" = {
  #   device = "${user.name}@192.168.1.2:/drive";

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
      "nconnect=16"
      "noresvport"
      "actimeo=60"
      "nfsvers=4.2"
      "nordirplus"
    ];
  };

}

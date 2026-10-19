{ pkgs, ... }:

{
  boot.zfs.extraPools = [ "data" ];

  fileSystems."/hdd4tb" = {
    device = "/dev/disk/by-uuid/d4cd9ea9-f656-438b-bd3f-e7bbbbd9e373";
    fsType = "ext4";
    options = [
      "x-systemd.device-timeout=30s"
      "x-systemd.mount-timeout=5min"
      "nofail"
    ];
  };

  services.nfs = {
    server = {
      enable = true;
      exports = ''
        /drive 192.168.1.0/24(rw,async,no_subtree_check,insecure)
        /drive/code 192.168.1.0/24(rw,async,no_subtree_check,insecure)
        /drive/sync 192.168.1.0/24(rw,async,no_subtree_check,insecure)
        /drive/state 192.168.1.0/24(rw,async,no_subtree_check,insecure)
        /drive/tmp 192.168.1.0/24(rw,async,no_subtree_check,insecure)
        /hdd4tb/torrents 192.168.1.0/24(rw,async,no_subtree_check,insecure)
      '';
      nproc = 16;
    };
    settings = {
      nfsd = {
        udp = false;
        vers3 = true;
        vers4 = true;
      };
      mountd.port = 20048;
    };
  };

  systemd.services.nfs-server.unitConfig = {
    RequiresMountsFor = [ "/hdd4tb/torrents" ];
    AssertPathIsMountPoint = "/hdd4tb";
    PartOf = [ "hdd4tb.mount" ];
  };

  systemd.services.drive-torrents-empty-cleanup = {
    description = "Remove the retired /drive/torrents directory when empty";
    wantedBy = [ "multi-user.target" ];
    requires = [ "zfs-mount.service" ];
    after = [ "zfs-mount.service" ];
    unitConfig = {
      ConditionPathIsDirectory = "/drive/torrents";
      ConditionDirectoryNotEmpty = "!/drive/torrents";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "drive-torrents-empty-cleanup" ''
        set -euo pipefail

        target=/drive/torrents

        if [ ! -d "$target" ]; then
          exit 0
        fi

        if [ -L "$target" ]; then
          echo "refusing to remove $target: it is a symlink" >&2
          exit 1
        fi

        if ${pkgs.util-linux}/bin/findmnt --mountpoint "$target" >/dev/null 2>&1; then
          echo "refusing to remove $target: it is a mountpoint" >&2
          exit 1
        fi

        ${pkgs.coreutils}/bin/rmdir -- "$target"
      '';
    };
  };

  networking.firewall = {
    allowedTCPPorts = [
      2049
      111
      20048
    ];
    allowedUDPPorts = [
      111
      20048
    ];
  };

}

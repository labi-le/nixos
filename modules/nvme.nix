{ config, pkgs, lib, ... }:

let
  rootNvmeById = "/dev/disk/by-id/nvme-Patriot_M.2_P300_512GB_P300WCBA25041508682";

  nvmeHctmScript = pkgs.writeShellScript "nvme-hctm-apply" ''
    set -euo pipefail

    device="${rootNvmeById}"

    if [ ! -e "$device" ]; then
      echo "nvme-hctm: $device not present, skipping" >&2
      exit 0
    fi

    nsdev="$("${pkgs.coreutils}/bin/readlink" -f "$device")"
    nsname="$("${pkgs.coreutils}/bin/basename" "$nsdev")"
    ctrlname="$("${pkgs.coreutils}/bin/basename" "$("${pkgs.coreutils}/bin/readlink" -f "/sys/class/block/$nsname/device")")"
    ctrldev="/dev/$ctrlname"

    if [ ! -e "$ctrldev" ]; then
      echo "nvme-hctm: controller device $ctrldev not present, skipping" >&2
      exit 0
    fi

    hctma="$("${pkgs.nvme-cli}/bin/nvme" id-ctrl "$ctrldev" -o json | "${pkgs.jq}/bin/jq" -r '.hctma // 0')"

    if [ -z "$hctma" ] || [ $(( hctma & 1 )) -eq 0 ]; then
      echo "nvme-hctm: controller does not support Host Controlled Thermal Management (hctma=$hctma), skipping" >&2
      exit 0
    fi

    "${pkgs.nvme-cli}/bin/nvme" set-feature "$ctrldev" -f 0x10 -V 0x01570161
  '';
in
{
  services.fstrim.enable = true;
  services.fstrim.interval = "daily";

  systemd.services.fstrim = {
    restartIfChanged = false;
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "5min";
    };
  };

  services.smartd.enable = true;

  systemd.services.nvme-hctm = {
    description = "Apply Host Controlled Thermal Management thresholds to root NVMe";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" ];
    wants = [ "systemd-udev-settle.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${nvmeHctmScript}";
    };
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="nvme", KERNEL=="nvme0", ACTION=="change", ENV{NVME_EVENT}=="connected", RUN+="${config.systemd.package}/bin/systemctl --no-block restart nvme-hctm.service"
  '';
}

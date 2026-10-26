{ lib, pkgs, ... }:

let
  version = "2.10.8";

  backgroundScanStartUtcHour = 1;
  backgroundScanStartUtcMinute = 0;

  pinBackgroundScanWindow = pkgs.writeShellApplication {
    name = "music-assistant-pin-background-scan-window";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      settings=/var/lib/music-assistant/settings.json
      [ -f "$settings" ] || exit 0
      staged="$(mktemp "$settings".XXXXXX)"
      if jq --argjson hour ${toString backgroundScanStartUtcHour} --argjson minute ${toString backgroundScanStartUtcMinute} '
        (.core.tasks?.scheduled_task_states?.audio_analysis_background_scan // null) as $task
        | if $task == null then .
          else .core.tasks.scheduled_task_states.audio_analysis_background_scan
            |= (.schedule = ((.schedule // {}) + { type: "daily", enabled: true, every: 1, hour: $hour, minute: $minute })
                | .schedule_enabled = true)
          end
      ' "$settings" > "$staged"
      then
        chmod 0644 "$staged"
        mv "$staged" "$settings"
      else
        rm -f "$staged"
        echo "music-assistant: could not pin the background analysis window" >&2
      fi
    '';
  };
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

  systemd.services."docker-music-assistant".serviceConfig.ExecStartPre = lib.mkAfter [
    "${pinBackgroundScanWindow}/bin/music-assistant-pin-background-scan-window"
  ];

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

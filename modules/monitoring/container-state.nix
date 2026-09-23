{ pkgs, ... }:

let
  textfileDir = "/var/lib/prometheus-node-textfile-collector";

  jqFilter = pkgs.writeText "docker-container-state.jq" ''
    .[] |
    (.Name | ltrimstr("/")) as $name |
    ($name | tojson) as $nameLabel |
    "docker_container_running{name=" + $nameLabel + "} " + (if .State.Running then "1" else "0" end),
    "docker_container_restart_count{name=" + $nameLabel + "} " + (.RestartCount | tostring),
    (if (.State.Running | not) or .State.Health == null or .State.Health.Status == "starting" then empty else
      "docker_container_healthy{name=" + $nameLabel + "} " + (if .State.Health.Status == "healthy" then "1" else "0" end)
    end),
    "docker_container_restart_policy_info{name=" + $nameLabel + ",policy=" + (.HostConfig.RestartPolicy.Name | tojson) + "} 1"
  '';

  script = pkgs.writeShellScript "docker-container-state-exporter" ''
    set -euo pipefail

    outFile="${textfileDir}/docker-container-state.prom"
    tmpFile="$("${pkgs.coreutils}/bin/mktemp" "${textfileDir}/.docker-container-state.prom.XXXXXX")"
    trap '"${pkgs.coreutils}/bin/rm" -f "$tmpFile"' EXIT

    {
      echo '# HELP docker_container_running Whether the Docker container is running (1) or not (0).'
      echo '# TYPE docker_container_running gauge'
      echo '# HELP docker_container_restart_count Number of times Docker has restarted the container.'
      echo '# TYPE docker_container_restart_count counter'
      echo '# HELP docker_container_healthy Docker health check status: 1 healthy, 0 unhealthy. Omitted for containers without a health check or for stopped containers.'
      echo '# TYPE docker_container_healthy gauge'
      echo '# HELP docker_container_restart_policy_info Docker restart policy configured for the container; value is always 1.'
      echo '# TYPE docker_container_restart_policy_info gauge'

      ids="$("${pkgs.docker}/bin/docker" ps -aq)"
      if [ -n "$ids" ]; then
        "${pkgs.docker}/bin/docker" inspect $ids | "${pkgs.jq}/bin/jq" -r -f "${jqFilter}"
      fi

      echo '# HELP docker_container_exporter_last_run_timestamp_seconds Unix timestamp of the last successful run of the container-state exporter.'
      echo '# TYPE docker_container_exporter_last_run_timestamp_seconds gauge'
      echo "docker_container_exporter_last_run_timestamp_seconds $("${pkgs.coreutils}/bin/date" +%s)"
    } > "$tmpFile"

    "${pkgs.coreutils}/bin/chmod" 0644 "$tmpFile"

    "${pkgs.coreutils}/bin/mv" -f "$tmpFile" "$outFile"
  '';
in
{
  systemd.tmpfiles.rules = [
    "d ${textfileDir} 0755 root root -"
  ];

  systemd.services.docker-container-state-exporter = {
    description = "Write Docker container state as a node_exporter textfile-collector metrics file";
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${script}";
    };
  };

  systemd.timers.docker-container-state-exporter = {
    description = "Run the Docker container-state exporter every 30 seconds";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "30s";
      AccuracySec = "1s";
      Unit = "docker-container-state-exporter.service";
    };
  };
}

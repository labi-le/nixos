{ config, lib, ... }:

let
  enabledHosts = [
    "pc"
    "notebook"
  ];
in
{
  config = lib.mkIf (builtins.elem config.networking.hostName enabledHosts) {
    age.secrets.opencode-jira-mcp = {
      file = ../secrets/opencode/jira-mcp.age;
      owner = "labile";
      group = "users";
      mode = "0400";
    };

    age.secrets.opencode-gitlab-mcp = {
      file = ../secrets/opencode/gitlab-work.age;
      owner = "labile";
      group = "users";
      mode = "0400";
    };

    age.secrets.opencode-grafana-mcp = {
      file = ../secrets/opencode/grafana-mcp.age;
      owner = "labile";
      group = "users";
      mode = "0400";
    };
  };
}

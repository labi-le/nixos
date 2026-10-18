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
      file = ../secrets/mcp/jira-mcp.age;
      owner = "labile";
      group = "users";
      mode = "0400";
    };

    age.secrets.opencode-gitlab-mcp = {
      file = ../secrets/mcp/gitlab-work.age;
      owner = "labile";
      group = "users";
      mode = "0400";
    };


    age.secrets.opencode-grafana-mcp = {
      file = ../secrets/mcp/grafana-mcp.age;
      owner = "labile";
      group = "users";
      mode = "0400";
    };

    age.secrets.google-docs-mcp = {
      file = ../secrets/mcp/google-docs-mcp.age;
      owner = "labile";
      group = "users";
      mode = "0400";
    };

    age.secrets.portainer-mcp = {
      file = ../secrets/portainer-mcp.age;
      owner = "labile";
      group = "users";
      mode = "0400";
    };
  };
}

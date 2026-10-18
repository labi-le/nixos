{ config, lib, ... }:

let
  enabledHosts = [
    "pc"
    "notebook"
  ];
in
{
  config = lib.mkIf (builtins.elem config.networking.hostName enabledHosts) {
    age.secrets."work/jira-mcp" = {
      file = ../secrets/work/jira-mcp.age;
      owner = "labile";
      group = "users";
      mode = "0400";
    };

    age.secrets."work/gitlab-mcp" = {
      file = ../secrets/work/gitlab-work.age;
      owner = "labile";
      group = "users";
      mode = "0400";
    };


    age.secrets."work/grafana-mcp" = {
      file = ../secrets/work/grafana-mcp.age;
      owner = "labile";
      group = "users";
      mode = "0400";
    };

    age.secrets."work/google-docs-mcp" = {
      file = ../secrets/work/google-docs-mcp.age;
      owner = "labile";
      group = "users";
      mode = "0400";
    };

    age.secrets."work/portainer-mcp" = {
      file = ../secrets/work/portainer-mcp.age;
      owner = "labile";
      group = "users";
      mode = "0400";
    };
  };
}

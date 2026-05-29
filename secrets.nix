let
  notebook = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPozMe3Gt6UIj00f/PD/vpWGnJvoF1N77GoQjeyBvZCE root@notebook";
  pc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMmj4DhtDs5bZhqTK6NiolqRgNCnGWyxty4LRixuU77Z labile@pc";
  server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIrOmpc2RqBzvSgNAIr2FFQzteuHu9JsnSocX7tFnYPA labile@server";

in
{
  "testcode.age".publicKeys = [
    notebook
    pc
    server
  ];

  "secrets/vaultwarden/env.age".publicKeys = [ server ];
  "secrets/awg/env.age".publicKeys = [ server ];
  "secrets/ngate-env.age".publicKeys = [ server ];
  "secrets/grafana.age".publicKeys = [ server ];
  "secrets/frp.age".publicKeys = [ server ];
  "secrets/opencode/grafana-mcp.age".publicKeys = [
    pc
    notebook
  ];
  "secrets/litellm-env.age".publicKeys = [
    pc
    server
  ];

}

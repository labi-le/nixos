{ config, lib, ... }:

let
  enabledHosts = [
    "pc"
    "notebook"
  ];
in
{
  config = lib.mkIf (builtins.elem config.networking.hostName enabledHosts) {
    age.secrets.opencode-litellm-master-key = {
      file = ../secrets/litellm-env.age;
      owner = "labile";
      group = "users";
      mode = "0400";
    };
  };
}

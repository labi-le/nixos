{
  config,
  lib,
  user,
  ...
}:

let
  enabledHosts = [
    "pc"
    "server"
    "notebook"
  ];
in
{
  config = lib.mkIf (builtins.elem config.networking.hostName enabledHosts) {
    age.secrets.opencode-litellm-master-key = {
      file = ../secrets/litellm-env.age;
      owner = user.name;
      group = config.users.users.${user.name}.group;
      mode = "0400";
    };

    age.secrets.llm-labile-env = {
      file = ../secrets/llm-labile-env.age;
      owner = user.name;
      group = config.users.users.${user.name}.group;
      mode = "0400";
    };

    age.secrets.byesu-env = {
      file = ../secrets/byesu-env.age;
      owner = user.name;
      group = config.users.users.${user.name}.group;
      mode = "0400";
    };

    age.secrets.plusvibe-env = {
      file = ../secrets/plusvibe-env.age;
      owner = user.name;
      group = config.users.users.${user.name}.group;
      mode = "0400";
    };

  };
}

{
  config,
  lib,
  user,
  ...
}:

{
  age.secrets = lib.optionalAttrs (config.networking.hostName != "fx516") {
    opencode-telegram-mcp = {
      file = ../../secrets/mcp/telegram-mcp.age;
      owner = user.name;
      group = config.users.users.${user.name}.group;
      mode = "0400";
    };
  };
}

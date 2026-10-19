{
  config,
  pkgs,
  user,
  ...
}:

let
  userCfg = config.users.users.${user.name};
  configDir = "${userCfg.home}/.config/maki";
in
{
  environment.systemPackages = [ pkgs.maki ];

  systemd.tmpfiles.rules = [
    "d ${configDir} 0700 ${user.name} ${userCfg.group} -"
    "d ${configDir}/lua 0700 ${user.name} ${userCfg.group} -"
    "L+ ${configDir}/init.lua - - - - ${./init.lua}"
    "L+ ${configDir}/lua/llm_labile.lua - - - - ${./lua/llm_labile.lua}"
    "L+ ${configDir}/plugin.toml - - - - ${./plugin.toml}"
    "L+ ${configDir}/providers.toml - - - - ${./providers.toml}"
  ];
}

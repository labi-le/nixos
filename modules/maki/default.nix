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
    "L+ ${configDir}/init.lua - - - - ${./init.lua}"
  ];
}

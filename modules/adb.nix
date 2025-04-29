{ ... }:
{
  programs.adb.enable = true;
  users.users.labile.extraGroups = [ "adbusers" ];
}

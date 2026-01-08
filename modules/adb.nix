{ pkgs, ... }:
{
  users.users.labile.extraGroups = [ "adbusers" ];

  environment.systemPackages = with pkgs; [
    android-tools
  ];
}

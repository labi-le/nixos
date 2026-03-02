{ pkgs, user, ... }:
{
  users.users.${user.name}.extraGroups = [ "adbusers" ];

  environment.systemPackages = with pkgs; [
    android-tools
  ];
}

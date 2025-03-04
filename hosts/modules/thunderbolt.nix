{ pkgs, ... }:

{
  boot.kernelModules = [ "thunderbolt" "thunderbolt-net" ];
  environment.systemPackages = with pkgs; [ bolt ];

  services = {
    hardware.bolt.enable = true;
  };

}

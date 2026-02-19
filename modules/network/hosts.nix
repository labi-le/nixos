{ config, lib, ... }:

lib.mkIf config.network.injectHosts {
  networking.hosts = {
    "172.16.0.11" = [ "forms.local.ru" ];
  };

}

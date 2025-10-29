{ config, ... }:

{
  age.secrets.vaultwarden-env = {
    file = ../secrets/vaultwarden/env.age;
    owner = "vaultwarden";
    group = "vaultwarden";
    mode = "0400";
  };

  services.vaultwarden = {
    enable = true;
    backupDir = "/var/local/vaultwarden/backup";
    environmentFile = config.age.secrets.vaultwarden-env.path;
  };
}

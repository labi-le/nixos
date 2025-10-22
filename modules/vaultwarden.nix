{ ... }:
{
  services.vaultwarden = {
    enable = true;
    backupDir = "/var/local/vaultwarden/backup";
    environmentFile = "/var/local/vaultwarden/.env";
  };
}

{ config, ... }:

{
  services.harmonia.cache = {
    enable = true;
    signKeyPaths = [ config.age.secrets.harmonia-key.path ];
    settings.bind = "127.0.0.1:5000";
  };
}

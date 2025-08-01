{
  networking.hosts = {
    "172.16.0.11" = [ "forms.local.ru" ];
  };

  services.resolved = {
    enable = true;
    extraConfig = ''
      [Resolve]
      DNS=192.168.1.1
      Domains=~passport.local
    '';
  };
}

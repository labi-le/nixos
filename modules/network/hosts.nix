{
  networking.hosts = {
    "172.16.0.11" = [ "forms.local.ru" ];
  };

  # services.resolved = {
  #   enable = true;
  #   extraConfig = ''
  #     [Resolve]
  #     DNS=192.168.1.1
  #     Domains=~passport.local
  #   '';
  # };

  services.resolved.enable = false;
  networking.networkmanager.dns = "default";
  environment.etc."resolv.conf".text = ''
    nameserver 192.168.1.1
  '';
}

{ ... }:
{
  age.secrets.awg-env = {
    file = ./../../secrets/awg/env.age;
    owner = "labile";
    group = "docker";
    mode = "0400";
  };

  services.dnsmasq = {
    enable = true;
    settings = {
      interface = "wg0";
      listen-address = "10.8.0.1";
      bind-interfaces = true;
      no-resolv = true;
      server = [ "192.168.1.1" ];
    };
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 51821 ];
    allowedUDPPorts = [ 51820 ];

    extraCommands = ''
      # RFC1918
      iptables -A INPUT  -i wg0 -d 10.8.0.1 -p udp --dport 53 -j ACCEPT
      iptables -A INPUT  -i wg0 -d 10.0.0.0/8     -j DROP
      iptables -A INPUT  -i wg0 -d 172.16.0.0/12  -j DROP
      iptables -A INPUT  -i wg0 -d 192.168.0.0/16 -j DROP

      iptables -A FORWARD -i wg0 -d 10.8.0.1 -p udp --dport 53 -j ACCEPT
      iptables -A FORWARD -i wg0 -d 10.0.0.0/8     -j DROP
      iptables -A FORWARD -i wg0 -d 172.16.0.0/12  -j DROP
      iptables -A FORWARD -i wg0 -d 192.168.0.0/16 -j DROP
    '';
  };

  boot.kernelModules = [ "iptable_nat" ];

  imports = [ ./compose.nix ];
}

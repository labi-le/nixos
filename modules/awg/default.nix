{ user, pkgs, ... }:
let
  awgNatApply = pkgs.writeShellScript "awg-nat-apply" ''
    set -euo pipefail

    resolve() {
      dig +short +time=2 +tries=2 "$@" external.lan \
        | grep -m1 -E '^[0-9]+(\.[0-9]+){3}$' || true
    }

    WAN_IP=$(resolve)

    if [ -z "$WAN_IP" ]; then
      ROUTER=$(ip -4 route show default | awk '{ print $3; exit }')
      if [ -n "$ROUTER" ]; then
        WAN_IP=$(resolve "@$ROUTER")
      fi
    fi

    {
      printf 'table ip awg\n'
      printf 'delete table ip awg\n'
      printf 'table ip awg {\n'
      if [ -n "$WAN_IP" ]; then
        printf '  chain prerouting {\n'
        printf '    type nat hook prerouting priority dstnat + 10; policy accept;\n'
        printf '    iifname "wg0" ip daddr %s dnat to 192.168.1.2\n' "$WAN_IP"
        printf '  }\n'
      fi
      printf '  chain postrouting {\n'
      printf '    type nat hook postrouting priority srcnat + 10; policy accept;\n'
      printf '    ip saddr 10.8.0.0/24 oifname "enp37s0" masquerade\n'
      printf '  }\n'
      printf '}\n'
    } | nft -f -

    if [ -z "$WAN_IP" ]; then
      echo "external.lan did not resolve via the local resolver or the gateway; hairpin DNAT skipped, masquerade installed" >&2
      exit 1
    fi
  '';
  awgNatTeardown = pkgs.writeShellScript "awg-nat-teardown" ''
    set -euo pipefail
    [ "''${SERVICE_RESULT:-}" = success ] || exit 0
    exec nft delete table ip awg
  '';
in
{
  age.secrets.awg-env = {
    file = ./../../secrets/awg/env.age;
    owner = user.name;
    group = "docker";
    mode = "0400";
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

  systemd.services.awg-nat = {
    description = "Install host-side NAT for the amnezia-wg-easy tunnel in a dedicated table ip awg";
    after = [
      "network-online.target"
      "dnsmasq.service"
    ];
    wants = [ "network-online.target" ];
    path = [
      pkgs.nftables
      pkgs.dnsutils
      pkgs.gnugrep
      pkgs.iproute2
      pkgs.gawk
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = 30;
      ExecStart = "${awgNatApply}";
      ExecReload = "${awgNatApply}";
      ExecStopPost = "-${awgNatTeardown}";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.awg-nat-refresh = {
    description = "Reload (or restart) awg-nat to re-resolve external.lan";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "-${pkgs.systemd}/bin/systemctl try-reload-or-restart awg-nat.service";
    };
  };

  systemd.timers.awg-nat-refresh = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };

  systemd.services."docker-amnezia-wg-easy" = {
    after = [ "awg-nat.service" ];
    wants = [ "awg-nat.service" ];
  };

  imports = [ ./compose.nix ];
}

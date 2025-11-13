{ ... }:
{
  programs.gnupg.agent.enableSSHSupport = true;
  services.openssh = {
    enable = true;
  };

  networking.firewall = {
    extraCommands = ''
      iptables -I nixos-fw -p tcp --dport 22 -s 192.168.0.0/16 -j nixos-fw-accept
    '';
  };

  security.pam.services.sshd.showMotd = true;
  security.pam.sshAgentAuth.enable = true;
}

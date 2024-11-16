{ ... }:
{
  programs.gnupg.agent.enableSSHSupport = true;
  services.openssh = { enable = true; };
  security.pam.services.sshd.showMotd = true;
  security.pam.sshAgentAuth.enable = true;
}


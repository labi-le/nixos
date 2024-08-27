{ pkgs, ... }:

let
  loginMessage = pkgs.writeScript "login_message.sh" ''
    #!/bin/sh
    echo "Welcome!"
    echo "----------------------------------------"
    ${pkgs.procps}/bin/uptime -p
    echo "----------------------------------------"
    echo "Docker containers:"
    ${pkgs.docker}/bin/docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | sed '1d' | sort
    echo "----------------------------------------"
  '';
in

{
  programs.gnupg.agent.enableSSHSupport = true;
  services.openssh = { enable = true; };
  security.pam.services.sshd.showMotd = true;
  security.pam.sshAgentAuth.enable = true;
  # Создание и настройка скрипта непосредственно в конфигурации
  environment.etc."ssh/sshrc" = {
    text = ''
      #!/bin/sh
      ${loginMessage}
    '';
    mode = "0755";
  };
  # Убедитесь, что необходимые пакеты доступны
  environment.systemPackages = with pkgs; [
    procps
    docker
  ];
}


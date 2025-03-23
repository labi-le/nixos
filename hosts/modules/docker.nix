{ pkgs, ... }:

{
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      registry-mirrors = [
        "https://mirror.gcr.io"
        "https://huecker.io"
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    ctop
    docker-compose
  ];
}

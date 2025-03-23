{ pkgs, ... }:

{
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      registry-mirrors = [
        "https://mirror.gcr.io"
        "https://huecker.io"
      ];
      default-ulimits = {
        nofile = {
          Name = "nofile";
          Soft = 65536;
          Hard = 65536;
        };
      };
    };
  };

  environment.systemPackages = with pkgs; [
    ctop
    docker-compose
  ];
}

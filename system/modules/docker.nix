{
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      registry-mirrors = [ "https://mirror.gcr.io" "https://huecker.io" ];
    };
    extraOptions = "--bridge=none";
  };
}

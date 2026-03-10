{ ... }:
{
  xdg = {
    enable = true;
    userDirs.download = "/tmp/downloads";
    terminal-exec = {
      enable = true;
    };

  };

  systemd.user.tmpfiles.rules = [
    "d /tmp/downloads 0755 - - - -"
  ];

}

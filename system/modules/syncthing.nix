{
  services.syncthing = {
    enable = true;
    settings = {
      folders = {
        "/drive/sync/media" = {
          id = "media";
        };
      };
    };
    guiAddress = "127.0.0.1:7002";
  };
}

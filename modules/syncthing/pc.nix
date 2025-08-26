{ ... }:
{
  imports = [ ./default.nix ];

  sync = {
    enable = true;
    nodeName = "pc";
    user = "labile";

    folders = {
      "/home/labile/obsidian" = {
        id = "obsidian";
        sharesWith = [
          "server"
          "phone"
        ];
      };

      "/mnt/ssd2tb/sync" = {
        id = "media";
        sharesWith = [
          "server"
          "phone"
        ];
      };
    };
  };
}

{ ... }:
{
  imports = [ ./default.nix ];

  sync = {
    enable = true;
    nodeName = "server";
    user = "labile";

    folders = {
      "/drive/sync/media" = {
        id = "media";
        sharesWith = [
          "phone"
          "pc"
        ];
      };

      "/drive/sync/obsidian" = {
        id = "obsidian";
        sharesWith = [
          "notebook"
          "phone"
          "pc"
        ];
      };
    };
  };

}

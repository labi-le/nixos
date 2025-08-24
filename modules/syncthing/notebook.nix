{ ... }:
{
  imports = [ ./default.nix ];

  sync = {
    enable = true;
    nodeName = "notebook";
    user = "labile";

    folders = {
      # "/var/sync/media" = {
      #   id = "media";
      #   sharesWith = [
      #     "server"
      #     "phone"
      #   ];
      # };

      "/home/labile/obsidian" = {
        id = "obsidian";
        sharesWith = [
          "server"
          "phone"
          "pc"
        ];
      };
    };
  };
}

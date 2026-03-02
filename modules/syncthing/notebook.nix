{ user, ... }:
{
  imports = [ ./default.nix ];

  sync = {
    enable = true;
    nodeName = "notebook";
    user = user.name;

    folders = {
      # "/var/sync/media" = {
      #   id = "media";
      #   sharesWith = [
      #     "server"
      #     "phone"
      #   ];
      # };

      "/home/${user.name}/obsidian" = {
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

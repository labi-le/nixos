{ user, ... }:
{
  imports = [ ./default.nix ];

  sync = {
    enable = true;
    enableCaddy = true;
    nodeName = "pc";
    user = user.name;

    folders = {
      "/home/${user.name}/obsidian" = {
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

{ pkgs, ... }:

{
  programs.yazi = {
    enable = true;
    package = pkgs.yazi.override { extraPackages = [ pkgs.ueberzugpp ]; };

    settings = {
      yazi = {
        preview.image_protocol = "ueberzug";
        mgr.show_hidden = true;
      };

      keymap.mgr.prepend_keymap = [
        {
          on = [ "d" ];
          run = "remove --permanently";
          desc = "Delete files permanently without confirmation";
        }
        {
          on = [ "y" ];
          run = [
            ''shell --orphan -- sh -c 'for f in "$@"; do echo "file://$f"; done | wl-copy --type text/uri-list' yazi-placeholder "$@"''
            "yank"
          ];
          desc = "Copy file URI to clipboard and yank";
        }
      ];
    };
  };
}

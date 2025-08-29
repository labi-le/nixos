{ pkgs, ... }:
# https://github.com/nix-community/home-manager/blob/master/modules/programs/yazi.nix
let
  yazi-with-ueberzugpp = pkgs.symlinkJoin {
    name = "yazi-with-ueberzugpp";
    paths = [ pkgs.yazi ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/yazi \
        --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.ueberzugpp ]}
    '';
  };

in
{
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    package = yazi-with-ueberzugpp;
    settings = {
      preview = {
        image_protocol = "ueberzug";
      };
      mgr = {
        show_hidden = true;
      };
    };
    keymap = {
      mgr.prepend_keymap = [
        {
          run = "remove --permanently";
          on = [ "d" ];
          desc = "Delete files permanently without confirmation";
        }
        {
          run = "hidden toggle";
          on = [ "h" ];
          desc = "Toggle show hidden files";
        }
      ];
    };
  };
}

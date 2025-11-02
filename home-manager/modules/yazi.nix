{ pkgs, ... }:

let
  yazi-dependencies = with pkgs; [
    ueberzugpp
    ffmpeg
    p7zip
    jq
    poppler-utils
    fd
    ripgrep
    fzf
    zoxide
    librsvg
    imagemagick
  ];

  yazi-with-deps = pkgs.symlinkJoin {
    name = "yazi-with-dependencies";
    paths = [ pkgs.yazi ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/yazi \
        --prefix PATH : ${pkgs.lib.makeBinPath yazi-dependencies}
    '';
  };

in
{
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    package = yazi-with-deps;
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
          on = [ "y" ];
          run = [
            # ''shell --block -- sh -c 'for f in "$@"; do echo "file://$f"; done | wl-copy --type text/uri-list' yazi-placeholder "$@"''
            ''shell --orphan -- sh -c 'for f in "$@"; do echo "file://$f"; done | wl-copy --type text/uri-list' yazi-placeholder "$@"''
            "yank"
          ];
          desc = "Copy file URI to clipboard and yank (blocking)";
        }
      ];
    };
  };
}

{ ... }:

{
  programs.tmux = {
    enable = true;
    shortcut = "a";
    extraConfig = ''
      # close current window with prefix + x
      bind x kill-window
    '';
  };
}

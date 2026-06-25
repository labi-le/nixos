{ ... }:

{
  programs.tmux = {
    enable = true;
    shortcut = "a";
    baseIndex = 1; # start window & pane numbering at 1 (0 is awkward to reach)
    escapeTime = 10; # NixOS default is 500ms, which makes Esc/double-Esc sluggish
    extraConfig = ''
      # close current window with prefix + x
      bind x kill-window

      # Forward the kitty keyboard protocol (CSI-u) to apps running inside tmux.
      # Lets TUIs distinguish Shift+Enter from Enter (-> newline) and receive
      # unambiguous Esc events (-> reliable double-Esc). Needs Alacritty (CSI u)
      # + tmux >= 3.5 for extended-keys-format.
      set -s extended-keys on
      set -as terminal-features '*:extkeys'
      set -s extended-keys-format csi-u
    '';
  };
}

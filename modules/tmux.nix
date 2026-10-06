{ pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    shortcut = "a";
    baseIndex = 1; # start window & pane numbering at 1 (0 is awkward to reach)
    escapeTime = 10; # NixOS default is 500ms, which makes Esc/double-Esc sluggish

    plugins = with pkgs.tmuxPlugins; [
      tmux-window-name
    ];

    # Plugin @options must precede the plugins' run-shell lines.
    extraConfigBeforePlugins = ''
      # NixOS window names: tmux-window-name names each window after the pane's
      # foreground program's full argv. On NixOS that argv is a store path
      # (/nix/store/<hash>-<pkg>/{bin,libexec}/<prog>) and, for makeWrapper'd tools, a
      # `bash /nix/store/...-<pkg>-wrapped/bin/.<prog>-wrapped` shim, so the raw
      # names are unreadable. These substitutions (applied in order as plain
      # re.sub) reduce them to clean names:
      #   1. strip any absolute /.../ executable prefix   -> `<prog> <args>`
      #   2. collapse nixvim's `nvim --cmd ...` preamble  -> `nvim`
      #   3. store wrapper shim `bash .../bin/.x-wrapped` -> `<pkg>-wrapped`
      #   4. drop the makeWrapper `-wrapped` suffix        -> `<pkg>`
      #   5. local `bash path/script args`                -> `script args`
      #   6. ipython3/ipython2 normalisation (upstream default)
      # Backslashes are doubled so they survive tmux double-quote parsing (\\ -> \).
      set -g @tmux_window_name_substitute_sets "[('^/[^ ]+/(.+)', '\\g<1>'), ('^(n?vim) --cmd .*', '\\g<1>'), ('^(?:ba)?sh /nix/store/[a-z0-9]+-([^ ]+?)-?/bin/[^ ]*', '\\g<1>'), ('^(.+)-wrapped$', '\\g<1>'), ('(bash) (.+)/(.+[ $])(.+)', '\\g<3>\\g<4>'), ('.+ipython([32])', 'ipython\\g<1>')]"
    '';

    extraConfig = ''
      # enable mouse support: scroll, click to select pane/window, drag to resize
      set -g mouse on
      set-option -g window-size latest

      # close current window with prefix + x
      bind x kill-window

      bind r command-prompt -I "#W" { rename-window "%%" }

      # Forward the kitty keyboard protocol (CSI-u) to apps running inside tmux.
      # Lets TUIs distinguish Shift+Enter from Enter (-> newline) and receive
      # unambiguous Esc events (-> reliable double-Esc). Needs a CSI u
      # terminal + tmux >= 3.5 for extended-keys-format.
      set -s extended-keys on
      set -as terminal-features '*:extkeys'
      set -s extended-keys-format csi-u
    '';
  };
}

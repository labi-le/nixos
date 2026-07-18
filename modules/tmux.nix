{ pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    shortcut = "a";
    baseIndex = 1; # start window & pane numbering at 1 (0 is awkward to reach)
    escapeTime = 10; # NixOS default is 500ms, which makes Esc/double-Esc sluggish

    # Load order = list order, and all three are order-sensitive:
    # tmux-window-name: auto-renames windows by running program / cwd. MUST come
    #   before resurrect — it registers @resurrect-hook-*restore-all to re-name
    #   windows after a restore.
    # resurrect: on-demand save/restore of the whole session (layout, cwd, panes).
    # continuum: automates resurrect — auto-saves every 15 min. Auto-restore is
    #   OFF (@continuum-restore below); restore is driven synchronously by
    #   tmux-session-switcher on cold start, so continuum's *background* restore
    #   never races the switcher. MUST come last (after resurrect, which it
    #   drives) so its status-right injection isn't clobbered.
    plugins = with pkgs.tmuxPlugins; [
      tmux-window-name
      resurrect
      continuum
    ];

    # Plugin @options must be set BEFORE the plugins' run-shell lines. The NixOS
    # tmux module emits config as: extraConfigBeforePlugins -> plugins -> extraConfig,
    # so continuum's knobs live here, not in extraConfig (which runs too late).
    extraConfigBeforePlugins = ''
      # Restore is owned by tmux-session-switcher (synchronous, on cold start) to
      # avoid racing continuum's *background* auto-restore. Keep the periodic
      # auto-save; only disable restore-on-server-start.
      set -g @continuum-restore 'off'

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

      # close current window with prefix + x
      bind x kill-window

      # Forward the kitty keyboard protocol (CSI-u) to apps running inside tmux.
      # Lets TUIs distinguish Shift+Enter from Enter (-> newline) and receive
      # unambiguous Esc events (-> reliable double-Esc). Needs foot (CSI u)
      # + tmux >= 3.5 for extended-keys-format.
      set -s extended-keys on
      set -as terminal-features '*:extkeys'
      set -s extended-keys-format csi-u

      # Keep the resurrect snapshot in sync with the *live* set of sessions, so a
      # cold-start restore only brings back sessions that were still alive — not
      # ones you explicitly closed before shutdown (continuum's 15-min periodic
      # save is too coarse for this). Save the moment a session is closed (drops
      # it from the snapshot) or a client detaches (captures exactly what remains).
      set-hook -g session-closed 'run-shell -b "${pkgs.tmuxPlugins.resurrect}/share/tmux-plugins/resurrect/scripts/save.sh quiet"'
      set-hook -g client-detached 'run-shell -b "${pkgs.tmuxPlugins.resurrect}/share/tmux-plugins/resurrect/scripts/save.sh quiet"'
    '';
  };
}

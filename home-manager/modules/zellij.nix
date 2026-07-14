{ ... }:

{
  # Zellij installed in parallel with tmux (tmux stays the default). Launch
  # manually with `zellij`. Keeps Zellij's native mode keybindings (Ctrl+p/t/s/o,
  # shown in the status bar) and layers direct single-chord shortcuts on top for
  # the frequent ops. Ctrl+n is remapped from Resize mode to NewTab (resize stays
  # on Alt+=/Alt+-). Theme comes from stylix; session restore is on by default and
  # `serialize_pane_viewport` brings back on-screen contents too.
  programs.zellij = {
    enable = true;
    extraConfig = ''
      serialize_pane_viewport true
      pane_frames false
      show_startup_tips false
      default_layout "compact"

      keybinds {
          normal {
              bind "Ctrl a" { GoToNextTab; }
              bind "Ctrl n" { NewTab; }
              bind "Ctrl d" { Detach; }
              bind "Ctrl x" { CloseFocus; }
          }
      }
    '';
  };
}

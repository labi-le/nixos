{ lib, ... }:

{
  # Minimalist Wayland terminal (C, CPU-rendered, ~21 MB). No tabs/splits/mux by
  # design — panes come from tmux/zellij. Colors (dracula), 0.5 terminal opacity
  # and the font family come from the stylix foot target (modules/stylix.nix);
  # only the size is forced to 14 to match the old alacritty setup (stylix
  # default is 12).
  #
  # foot renders sixel, but omp's inline-image renderer targets kitty graphics,
  # so images inside omp are unreliable here (partial/broken renders). foot is
  # the terminal, not the image path.
  programs.foot = {
    enable = true;
    settings.main.font = lib.mkForce "JetBrainsMono Nerd Font:size=14";
  };

  # Default terminal for xdg-terminal-exec (took over from alacritty).
  xdg.terminal-exec.settings.default = [ "foot.desktop" ];
}

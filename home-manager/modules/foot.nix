{ ... }:

{
  # Minimalist Wayland terminal (C, CPU-rendered with damage tracking, ~21 MB).
  # No tabs/splits/multiplexer by design — panes come from tmux/zellij. Font,
  # colors (dracula) and terminal opacity come from the stylix foot target
  # (modules/stylix.nix). foot supports sixel natively, so omp renders images
  # (sixel) directly in foot with no extra config; inside a multiplexer, images
  # additionally need tmux `terminal-features *:sixel` + PI_FORCE_IMAGE_PROTOCOL=sixel.
  programs.foot.enable = true;

  # Default terminal for xdg-terminal-exec (took over from alacritty).
  xdg.terminal-exec.settings.default = [ "foot.desktop" ];
}

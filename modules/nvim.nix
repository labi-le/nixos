{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    gcc
    neovim
    fd
    ripgrep
    go
    php
    nodejs
  ];

  programs.nix-ld.enable = true;
}

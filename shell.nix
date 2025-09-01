let
  # pkgs = import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") {};
  pkgs = import <nixpkgs> { };
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    gnumake
    neovim
    tree
    git
    nixpkgs-fmt
  ];
}

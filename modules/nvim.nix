{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    gcc
    neovim
    fd
    ripgrep
  ];

}

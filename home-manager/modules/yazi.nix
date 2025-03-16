{ ... }: {
  # https://github.com/nix-community/home-manager/blob/release-24.11/modules/programs/yazi.nix
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    settings = { manager = { show_hidden = true; }; };
  };
}

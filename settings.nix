{
  nix.settings = {
    auto-optimise-store = true;
    http-connections = 500;
    substituters = [
      "https://cache.nixos.org?priority=100"
      "https://cosmic.cachix.org/"
      "https://cache.garnix.io"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
    trusted-users = [ "@wheel" ];
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  chaotic.nyx.cache.enable = true;
  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };
}

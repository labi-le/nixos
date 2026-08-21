{ ... }:

{
  nix = {
    gc = {
      dates = "monthly";
      automatic = true;
    };

    settings = {
      download-buffer-size = 2 * 1024 * 1024 * 1024; # 2 GB
      auto-optimise-store = true;
      http-connections = 500;
      max-substitution-jobs = 100;
      substituters = [
        # "https://cache.labile.cc?priority=-1"
        "https://cache.nixos.org?priority=10"
        "https://nix-community.cachix.org?priority=20"
        "https://cache.numtide.com?priority=30"
        "https://ayugram-desktop.cachix.org?priority=40"
        "https://tg-owt.cachix.org?priority=50"
      ];
      trusted-public-keys = [
        # "cache.labile.cc:wsb7HUFrITCpBKIs+c4Uv3sau03Isb3CKL+5FrHZomw="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        "ayugram-desktop.cachix.org-1:AZ5EqHrJsAKL5YkZYLPEsb1FdD9QlypUwQ0REcJftgA="
        "tg-owt.cachix.org-1:lp0BukIhSK3EIyLcDhDZ5zABgT48nmNp6t4SnZ0wr8w="
      ];
      trusted-users = [ "@wheel" ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
  };

  chaotic.nyx.cache.enable = true;
}

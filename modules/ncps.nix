{ ... }:
{

  services.ncps = {
    enable = true;
    cache = {
      hostName = "cache.labile.cc";

    };
    upstream = {
      caches = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://cosmic.cachix.org"
      ];
      publicKeys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
      ];
    };
  };
}

{ pkgs, inputs, ... }:

let
  # For Flakeless:
  # spicePkgs = spicetify-nix.packages;

  # With flakes:
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.system};
in
{

  programs.spicetify = {
    enable = true;
    enabledExtensions = with spicePkgs.extensions; [
      adblockify
      hidePodcasts
      shuffle

      {
        src = (pkgs.fetchFromGitHub {
          owner = "Maskowh";
          repo = "spicetify-old-like-button-extension";
          rev = "fe6f9792ef7d3532d054c5544c79068ce68609a9";
          hash = "sha256-OM8YyA+cBfgMO4vA9bR0BHiIQ9Xz3gbDP9yyrkDb71g=";
        });

        name = "oldLikeButton.js";
      }
    ];
  };

}

{ inputs, system }:

[
  # (final: prev: {
  #   stable = import inputs.nixpkgs-stable {
  #     inherit system;
  #     config.allowUnfree = true;
  #   };
  # })
  #
  (final: prev: {
    nix-gaming = inputs.nix-gaming.packages.${system};
  })

  (final: prev: {
    belphegor = inputs.belphegor.packages.${system}.default;
  })

  (final: prev: {
    ayugram-desktop = inputs.ayugram-desktop.packages.${system}.ayugram-desktop;
  })
]

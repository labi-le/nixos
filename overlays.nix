{ inputs, system }:

final: prev: {
  nix-gaming = inputs.nix-gaming.packages.${system};
  belphegor = inputs.belphegor.packages.${system}.default;
  wl-uploader = inputs.wl-uploader.packages.${system}.default;
  deal = inputs.deal.packages.${system}.default;
  # ayugram-desktop = inputs.ayugram-desktop.packages.${system}.ayugram-desktop;

  # stable = import inputs.nixpkgs-stable {
  #   inherit system;
  #   config.allowUnfree = true;
  # };

  getmyip = prev.callPackage ./pkgs/getmyip.nix { };
  agenix = inputs.agenix.packages.${system}.default;
  nur = (inputs.nur.overlays.default final prev).nur;
}

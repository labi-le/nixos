{ inputs, system }:

final: prev: {
  nix-gaming = inputs.nix-gaming.packages.${system};
  belphegor = inputs.belphegor.packages.${system}.default;
  wl-uploader = inputs.wl-uploader.packages.${system}.default;
  deal = inputs.deal.packages.${system}.default;
  accela = inputs.accela.packages.${system}.default;
  sls-steam = inputs.sls-steam.packages.${system}.sls-steam;
  sls-steam-wrapped = inputs.sls-steam.packages.${system}.wrapped;
  # ayugram-desktop = inputs.ayugram-desktop.packages.${system}.ayugram-desktop;

  # stable = import inputs.nixpkgs-stable {
  #   inherit system;
  #   config.allowUnfree = true;
  # };

  getmyip = prev.callPackage ./pkgs/getmyip.nix { };
  ea-disable-overlay = prev.callPackage ./pkgs/ea-disable-overlay.nix { };
  agenix = inputs.agenix.packages.${system}.default;
  nur = (inputs.nur.overlays.default final prev).nur;
  apple-fonts = inputs.apple-fonts.packages.${system};
  opencode = inputs.opencode.packages.${system}.opencode;
}

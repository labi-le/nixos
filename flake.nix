{
  description = "My system configuration";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-23.05";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim.url = "github:nix-community/nixvim";
    flake-utils.url = "github:numtide/flake-utils";
    nix-gaming.url = "github:fufexan/nix-gaming";
    belphegor.url = "github:labi-le/belphegor";
    ayugram-desktop.url = "github:/ayugram-port/ayugram-desktop/release?submodules=1";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
  };

  outputs =
    { nixpkgs
    , nixpkgs-stable
    , home-manager
    , nixvim
    , nix-gaming
    , belphegor
    , ayugram-desktop
    , chaotic
    , ...
    }:
    let
      system = "x86_64-linux";
      overlay-stable = final: prev: {
        stable = import nixpkgs-stable {
          inherit system;
          config.allowUnfree = true;
        };
      };

      overlay-nix-gaming = final: prev: {
        nix-gaming = nix-gaming.packages.${system};
      };

      overlay-belphegor = final: prev: {
        belphegor = belphegor.packages.${system}.default;
      };

      overlay-ayugram-desktop = final: prev: {
        ayugram-desktop = ayugram-desktop.packages.${system}.ayugram-desktop;
      };

      defaultConfiguration = ./system/configuration.nix;

      mkSystem = hostname: configuration: nixpkgs.lib.nixosSystem {
        modules = [
          configuration
          ./system/hardware-${hostname}.nix
          { networking.hostName = hostname; }
          (
            { config, pkgs, ... }: {
              nixpkgs.overlays = [
                overlay-stable
                overlay-nix-gaming
                overlay-belphegor
                overlay-ayugram-desktop
              ];

              nixpkgs.config = {
                allowUnfree = true;
              };
            }
          )
          nixvim.nixosModules.nixvim
          chaotic.nixosModules.default
        ] ++ nixpkgs.lib.optionals (hostname != "server") [
          home-manager.nixosModules.home-manager
          {
            home-manager.users.labile = import ./home-manager/home.nix;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.sharedModules = [ ];
            home-manager.backupFileExtension = "hm-backup";
          }
        ];
      };
    in
    {
      nixosConfigurations = {
        pc = mkSystem "pc" defaultConfiguration;
        fx516 = mkSystem "fx516" ./system/configuration-fx516.nix;
        thinkbook = mkSystem "thinkbook" defaultConfiguration;
        server = mkSystem "server" ./system/configuration-server.nix;
      };
    };
}

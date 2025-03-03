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
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
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
    , spicetify-nix
    , ...
    }@inputs:
    let
      system = "x86_64-linux";

      defaultConfiguration = ./hosts/configuration.nix;

      mkSystem = hostname: configuration: nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          configuration
          ./hosts/hardware-${hostname}.nix
          { networking.hostName = hostname; }
          (
            { config, pkgs, ... }: {
              nixpkgs.overlays = import ./overlays.nix { inherit inputs system; };

              nixpkgs.config = {
                allowUnfree = true;
              };
            }
          )
          ./cache.nix
          nixvim.nixosModules.nixvim
          chaotic.nixosModules.default
          spicetify-nix.nixosModules.default

        ] ++ nixpkgs.lib.optionals (hostname != "server") [
          home-manager.nixosModules.home-manager
          {
            home-manager.users.labile = import ./home-manager/home.nix;
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
        fx516 = mkSystem "fx516" ./hosts/configuration-fx516.nix;
        thinkbook = mkSystem "thinkbook" defaultConfiguration;
        server = mkSystem "server" ./hosts/configuration-server.nix;
      };
    };
}

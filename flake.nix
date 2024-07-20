{
  description = "My system configuration";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-23.11";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { nixpkgs, nixpkgs-stable, home-manager, nixvim, ... }:
    let
      system = "x86_64-linux";
      overlay-stable = final: prev: {
        stable = import nixpkgs-stable {
          inherit system;
          config.allowUnfree = true;
        };
      };

      mkSystem = hostname: configuration: nixpkgs.lib.nixosSystem {
        modules = [
          configuration
          ./system/hardware-${hostname}.nix
          { networking.hostName = hostname; }
          ({ config, pkgs, ... }: { nixpkgs.overlays = [ overlay-stable ]; })
          nixvim.nixosModules.nixvim
        ] ++ nixpkgs.lib.optionals (hostname != "server") [
          home-manager.nixosModules.home-manager
          {
            home-manager.users.labile = import ./home-manager/home.nix;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.sharedModules = [ ];
          }
        ];
      };
    in
    {
      nixosConfigurations = {
        pc = mkSystem "pc" ./system/configuration.nix;
        fx516 = mkSystem "fx516" ./system/configuration.nix;
        thinkbook = mkSystem "thinkbook" ./system/configuration.nix;
        server = mkSystem "server" ./system/configuration-server.nix;
      };
    };
}

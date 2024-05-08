{
  description = "My system configuration";

  inputs = {
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs:

    let
      system = "x86_64-linux";
      overlay-unstable = final: prev: {
        unstable = import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
      };
    in {

    nixosConfigurations.pc = nixpkgs.lib.nixosSystem {
      specialArgs = {
        pkgs-stable = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        inherit inputs system;
      };
      modules = [
        ./system/configuration.nix
	({ config, pkgs, ... }: { nixpkgs.overlays = [ overlay-unstable ]; })
	home-manager.nixosModules.home-manager {
	  home-manager.users.labile = import ./home-manager/home.nix;
	  home-manager.useGlobalPkgs = true;
	  home-manager.useUserPackages = true;
	}
      ];
    };

    #homeConfigurations.labile = home-manager.lib.homeManagerConfiguration {
    #  pkgs = nixpkgs.legacyPackages.${system};
    #  modules = [
    #    ./home-manager/home.nix
    #	({ config, pkgs, ... }: { nixpkgs.overlays = [ overlay-unstable ]; })
    #  ];
    #};
  };
}

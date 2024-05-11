{
  description = "My system configuration";

  inputs = {
    #nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      #url = "github:nix-community/nixvim/nixos-23.05";
      url = "github:nix-community/nixvim";
    };

  };

  outputs = { nixpkgs, home-manager, nixvim, ... }@inputs:

    let
      system = "x86_64-linux";
      overlay-unstable = final: prev: {
        unstable = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      };
    in
    {

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
          ({ ... }: { nixpkgs.overlays = [ overlay-unstable ]; })
          nixvim.nixosModules.nixvim
          home-manager.nixosModules.home-manager
          {
            home-manager.users.labile = import ./home-manager/home.nix;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.sharedModules = [ ];
          }
        ];
      };
    };
}

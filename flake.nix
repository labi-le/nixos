{
  description = "My system configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim.url = "github:nix-community/nixvim";
    nix-gaming.url = "github:fufexan/nix-gaming";
    belphegor.url = "github:labi-le/belphegor";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";

    ayugram-desktop.url =
      "github:ayugram-port/ayugram-desktop/release?submodules=1";

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    inputs@{ nixpkgs, home-manager, nixvim, chaotic, spicetify-nix, ... }:
    let
      system = "x86_64-linux";

      mkSystem = hostname: configFile:
        nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            configFile
            ./hosts/hardware-${hostname}.nix
            { networking.hostName = hostname; }

            {
              nixpkgs.overlays =
                import ./overlays.nix { inherit inputs system; };
              nixpkgs.config.allowUnfree = true;
            }

            # Extra Modules
            ./cache.nix
            nixvim.nixosModules.nixvim
            chaotic.nixosModules.default
            spicetify-nix.nixosModules.default
          ] ++ nixpkgs.lib.optionals (hostname != "server") [
            home-manager.nixosModules.home-manager
            {
              home-manager.users.labile = {
                imports = [ ./home-manager/home.nix ];
              };
              home-manager.useUserPackages = true;
              home-manager.sharedModules = [ ];
              home-manager.backupFileExtension = "hm-backup";
            }
          ];
        };

    in
    {
      nixosConfigurations = {
        pc = mkSystem "pc" ./hosts/configuration.nix;
        fx516 = mkSystem "fx516" ./hosts/configuration-fx516.nix;
        thinkbook = mkSystem "thinkbook" ./hosts/configuration.nix;
        server = mkSystem "server" ./hosts/configuration-server.nix;
      };
    };
}


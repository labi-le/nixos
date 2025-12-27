{
  description = "My system configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim.url = "github:nix-community/nixvim";
    belphegor.url = "github:labi-le/belphegor";
    wl-uploader.url = "github:labi-le/wl-paste-uploader";
    deal.url = "github:labi-le/deal";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    # ayugram-desktop.url = "github:ayugram-port/ayugram-desktop/release?submodules=1";
    flake-utils.url = "github:numtide/flake-utils";
    musnix.url = "github:musnix/musnix";

    ide.url = "path:./modules/ide";
    agenix.url = "github:ryantm/agenix";

    ngate-wrapped.url = "git+ssh://git@github.com/labi-le/ngate-wrapped?dir=qcow2";
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      nixvim,
      chaotic,
      musnix,
      ide,
      agenix,
      ngate-wrapped,
      nur,
      ...
    }:
    let
      system = "x86_64-linux";

      commonModules = [
        ./settings.nix
        nixvim.nixosModules.nixvim
        chaotic.nixosModules.default
        musnix.nixosModules.musnix
        ide.nixosModules.default
        agenix.nixosModules.default
        ngate-wrapped.nixosModules.default
        nur.modules.nixos.default
      ];

      baseConfig = {
        nixpkgs.overlays = [ (import ./overlays.nix { inherit inputs system; }) ];
        nixpkgs.config.allowUnfree = true;
      };

      homeManagerConfig = {
        home-manager = {
          users.labile = {
            imports = [ ./home-manager/home.nix ];
          };
          useUserPackages = true;
          useGlobalPkgs = true;
          sharedModules = [ ];
          backupFileExtension = "hm-backup";
        };
      };

      mkSystem =
        hostname: configFile: withHomeManager:
        nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            configFile
            ./hosts/hardware-${hostname}.nix
            { networking.hostName = hostname; }
            baseConfig
          ]
          ++ commonModules
          ++ nixpkgs.lib.optionals withHomeManager [
            home-manager.nixosModules.home-manager
            homeManagerConfig
          ];
        };

    in
    {
      nixosConfigurations = {
        pc = mkSystem "pc" ./hosts/configuration.nix true;
        fx516 = mkSystem "fx516" ./hosts/configuration-fx516.nix true;
        notebook = mkSystem "notebook" ./hosts/configuration-notebook.nix true;
        server = mkSystem "server" ./hosts/configuration-server.nix false;
      };
    };
}

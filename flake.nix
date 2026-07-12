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

    sls-steam.url = "github:AceSLS/SLSsteam";
    # accela.url = "github:labi-le/enter-the-wired";

    ngate-wrapped.url = "git+ssh://git@github.com/labi-le/ngate-wrapped?dir=qcow2";
    index-repo.url = "git+ssh://git@github.com/labi-le/index-repo";
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    apple-fonts.url = "github:Lyndeno/apple-fonts.nix";
    opencode.url = "github:numtide/llm-agents.nix";
    stylix.url = "github:danth/stylix";
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    omp-flake.url = "github:labi-le/omp-flake";
  };

  outputs =
    inputs:
    let
      system = "x86_64-linux";

      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # Build index-repo from the flake source (latest main) instead of the pinned
      # release binary, wrapped with the ORT dylib + model dir exactly like the
      # flake's release package. Lets `nix flake update index-repo` deploy source
      # changes without cutting a release.
      indexRepoFromSource =
        let
          ir = inputs.index-repo.packages.${system};
        in
        pkgs.runCommand "index-repo-fromsrc" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
          makeWrapper ${ir.fromSource}/bin/index-repo $out/bin/index-repo \
            --set ORT_DYLIB_PATH ${pkgs.onnxruntime}/lib/libonnxruntime.so \
            --set INDEX_REPO_MODEL_DIR ${ir.model}
        '';

      commonModules = [
        ./settings.nix
        inputs.stylix.nixosModules.stylix
        inputs.nixvim.nixosModules.nixvim
        inputs.chaotic.nixosModules.default
        inputs.musnix.nixosModules.musnix
        inputs.ide.nixosModules.default
        inputs.agenix.nixosModules.default
        inputs.ngate-wrapped.nixosModules.default
        inputs.nur.modules.nixos.default
        inputs.belphegor.nixosModules.default
        ./modules/shell/registry.nix
      ];

      baseConfig = {
        nixpkgs.overlays = [ (import ./overlays.nix { inherit inputs system; }) ];
        nixpkgs.config.allowUnfree = true;
      };

      homeManagerConfig = {
        home-manager = {
          useUserPackages = true;
          useGlobalPkgs = true;
          sharedModules = [ inputs.index-repo.homeManagerModules.default inputs.omp-flake.homeManagerModules.default ];
          backupFileExtension = "hm-backup";
        };
      };

      mkSystem =
        hostname: configFile: withHomeManager:
        inputs.nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            configFile
            ./hosts/hardware-${hostname}.nix
            { networking.hostName = hostname; }
            baseConfig
          ]
          ++ commonModules
          ++ inputs.nixpkgs.lib.optionals withHomeManager [
            inputs.home-manager.nixosModules.home-manager
            homeManagerConfig
            inputs.index-repo.nixosModules.default
            {
              services.index-repo.enable = true;
              services.index-repo.host = "192.168.1.2";
              services.index-repo.package = indexRepoFromSource;
            }
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

      devShells.${system} = import ./modules/shell/devshells.nix {
        inherit pkgs inputs system;
      };
    };
}

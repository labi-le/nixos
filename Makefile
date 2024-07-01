.DEFAULT_GOAL := switch

HOSTNAME := $(shell hostname)
CPUS := $(shell nproc)
HARDWARE_FILE := system/hardware-$(HOSTNAME).nix

disko:
	sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./disko.nix

prepare:
	nix-shell -p git gnumake neovim

fix-flake:
	@git add --intent-to-add .

switch: fmt
	sudo nixos-rebuild switch --fast --flake ./#$(HOSTNAME) --impure --cores $(CPUS)

generate-hardware: 
	@echo "Generating hardware configuration for $(HOSTNAME)"
	@sudo nixos-generate-config --show-hardware-config > $(HARDWARE_FILE)
	@echo "Hardware configuration saved to $(HARDWARE_FILE)"

fmt:
	nix-shell -p nixpkgs-fmt --command 'nixpkgs-fmt .'

upgrade:
	sudo nixos-rebuild switch --upgrade --flake ./#$(HOSTNAME) --impure --cores $(CPUS)

boot:
	sudo nixos-rebuild boot --flake ./#$(HOSTNAME) --impure --cores $(CPUS)

cleanup: boot
	sudo nix-collect-garbage -d && make switch

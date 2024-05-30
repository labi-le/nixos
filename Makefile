
.DEFAULT_GOAL := switch

rollup: generate-hardware fix-flake switch

disko:
	sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./disko.nix

prepare:
	nix-shell -p git gnumake neovim

fix-flake:
	@git add --intent-to-add .

switch: fmt
	sudo nixos-rebuild switch --fast --flake ./#$(shell hostname) --impure --cores $(shell nproc)

generate-hardware: 
	sudo nixos-generate-config --show-hardware-config > system/hardware.nix

fmt:
	 nix-shell -p nixpkgs-fmt --command 'nixpkgs-fmt .'

upgrade:
	sudo nixos-rebuild switch --upgrade --flake ./#$(shell hostname) --impure --cores $(shell nproc)

boot:
	sudo nixos-rebuild boot --flake ./#$(shell hostname) --impure --cores $(shell nproc)

cleanup:
	sudo nix-collect-garbage -d && make switch

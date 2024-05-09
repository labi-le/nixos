
.DEFAULT_GOAL := switch

rollup: generate-hardware fix-flake switch

disko:
	sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./disko.nix

prepare:
	nix-shell -p git gnumake neovim

fix-flake:
	@git add --intent-to-add .

switch:
	sudo nixos-rebuild switch --flake ./#$(shell hostname) --impure

generate-hardware: 
	sudo nixos-generate-config --show-hardware-config > system/hardware.nix

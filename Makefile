
.DEFAULT_GOAL := switch-all

rollup: generate-hardware rebuild-all

switch-all: switch-system 

disko:
	sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./disko.nix

prepare:
	nix-shell -p git gnumake neovim

fix-flake:
	@git add --intent-to-add .

switch-system:
	sudo nixos-rebuild switch --flake ./#$(shell hostname) --impure

generate-hardware: 
	sudo nixos-generate-config --show-hardware-config > system/hardware.nix

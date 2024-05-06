
.DEFAULT_GOAL := rebuild

generate-hardware: 
	sudo nixos-generate-config --show-hardware-config > system/hardware.nix

rollup: generate-hardware rebuild

disko:
	sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./disko.nix

prepare:
	nix-shell -p git gnumake neovim

fix-flake:
	git add --intent-to-add .

rebuild: fix-flake
	sudo nixos-rebuild switch --flake ./#pc --impure && home-manager switch --flake ./#labile



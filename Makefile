.phony: rebuild-from-flake

generate-hardware: 
	sudo nixos-generate-config --show-hardware-config > system/hardware.nix && git add --intent-to-add system/hardware.nix

rebuild-from-flake: generate-hardware
	sudo nixos-rebuild switch --flake ./#pc --impure && home-manager switch --flake ./

disko:
	sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./disko.nix

prepare:
	nix-shell -p git gnumake neovim

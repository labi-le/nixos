generate-hardware:
	sudo nixos-generate-config --show-hardware-config > system/hardware.nix

rebuild-from-flake: generate-hardware
	sudo nixos-rebuild switch --impure --flake ./#pc

disko:
	sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./disko.nix

generate-hardware:
	sudo nixos-generate-config --show-hardware-config > system/hardware.nix

install-from-flake: disko generate-hardware
	sudo nixos-install --impure --flake ./#pc

disko:
	sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./disko.nix

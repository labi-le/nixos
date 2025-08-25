.DEFAULT_GOAL := switch

HOSTNAME := $(shell hostname)
CPUS := $(shell nproc)
HARDWARE_FILE := hosts/hardware-$(HOSTNAME).nix

disko:
	sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./disko.nix

prepare:
	nix-shell -p git gnumake neovim

fix-flake:
	@git add --intent-to-add .

switch:
	sudo nixos-rebuild switch --flake ./#$(HOSTNAME) --impure --cores $(CPUS) --show-trace

generate-hardware: 
	@echo "Generating hardware configuration for $(HOSTNAME)"
	@sudo nixos-generate-config --show-hardware-config > $(HARDWARE_FILE)
	@echo "Hardware configuration saved to $(HARDWARE_FILE)"

fmt:
	nix-shell -p nixpkgs-fmt --command 'nixpkgs-fmt .'

upgrade:
	nix flake update && sudo nixos-rebuild switch --upgrade --flake ./#$(HOSTNAME) --impure --cores $(CPUS)

boot:
	sudo nixos-rebuild boot --flake ./#$(HOSTNAME) --impure --cores $(CPUS) --install-bootloader

cleanup: boot
	sudo nix-collect-garbage -d && make switch

optimise:
	nix-store --optimise

.PHONY: dump
dump:
	@{ \
		echo "=== START PROJECT CODE DUMP ==="; \
		echo ""; \
		echo "=== PROJECT TREE ==="; \
		nix run nixpkgs#tree -- . || echo "(tree failed)"; \
		echo ""; \
		find . -type f \( \
			-name "*.go" -o \
			-name "*.yml" -o \
			-name "*.yaml" -o \
			-name "*.proto" -o \
			-name "*.mod" -o \
			-name "*.sum" -o \
			-name "*.nix" -o \
			-name "Makefile" \
		\) | sort | while read file; do \
			echo "=== FILE: $$file ==="; \
			echo "=== START CODE ==="; \
			cat "$$file"; \
			echo "=== END CODE ==="; \
			echo ""; \
		done; \
	} | wl-copy


.DEFAULT_GOAL := switch

HOSTNAME := $(shell hostname)
CPUS := $(shell nproc)
HARDWARE_FILE := hosts/hardware-$(HOSTNAME).nix

disko:
	sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./disko.nix

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
		find modules/nixvim -type f \( \
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
			cat "$$file"; \
			echo ""; \
		done; \
	} | wl-copy


agenix-rekey:
	@echo "Rekeying agenix secrets accessible from $(HOSTNAME)..."
	@find secrets -name '*.age' -type f ! -path 'secrets/keys/*' | while read secret; do \
		echo "Checking $$secret..."; \
		if agenix -r -i /etc/ssh/ssh_host_ed25519_key "$$secret" 2>&1 | grep -q "no identity matched"; then \
			echo "⚠️  Skipping $$secret (not accessible from $(HOSTNAME))"; \
		else \
			echo "✅ Rekeyed $$secret"; \
		fi; \
	done


restore-keys:
	@echo "decrypt ssh key for $(HOSTNAME)..."
	@if [ ! -f "secrets/keys/$(HOSTNAME)_ssh_host_ed25519_key.age" ]; then \
		echo "key not found for $(HOSTNAME) in secrets/keys/"; \
		echo "available keys:"; \
		ls -1 secrets/keys/ 2>/dev/null | grep ed25519 || echo "no keys found"; \
		exit 1; \
	fi
	@age -d secrets/keys/$(HOSTNAME)_ssh_host_ed25519_key.age | sudo tee /etc/ssh/ssh_host_ed25519_key > /dev/null
	@sudo ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key | sudo tee /etc/ssh/ssh_host_ed25519_key.pub > /dev/null
	@sudo chmod 600 /etc/ssh/ssh_host_ed25519_key
	@sudo chmod 644 /etc/ssh/ssh_host_ed25519_key.pub
	@sudo chown root:root /etc/ssh/ssh_host_ed25519_key*
	@echo "key restored for $(HOSTNAME)"

backup-keys:
	@echo "backup ssh key from $(HOSTNAME)..."
	@if [ ! -f "/etc/ssh/ssh_host_ed25519_key" ]; then \
		echo "ed25519 key not found in /etc/ssh/"; \
		exit 1; \
	fi
	@mkdir -p secrets/keys
	@sudo cat /etc/ssh/ssh_host_ed25519_key | age -p > secrets/keys/$(HOSTNAME)_ssh_host_ed25519_key.age
	@echo "key for $(HOSTNAME) encrypted and saved"
	@echo "commit: git add secrets/keys/ && git commit -m 'Backup key for $(HOSTNAME)'"

backup-root-keys:
	@echo "backing up root ssh key from /root/.ssh/id_rsa..."
	@if ! sudo test -f "/root/.ssh/id_rsa"; then \
		echo "root key not found in /root/.ssh/id_rsa"; \
		exit 1; \
	fi
	@mkdir -p secrets/keys
	@sudo cat /root/.ssh/id_rsa | age -p > secrets/keys/$(HOSTNAME)_root_id_rsa.age
	@echo "root key for $(HOSTNAME) encrypted and saved"

restore-root-keys:
	@echo "decrypting root ssh key for $(HOSTNAME)..."
	@if [ ! -f "secrets/keys/$(HOSTNAME)_root_id_rsa.age" ]; then \
		echo "root key not found in secrets/keys/"; \
		exit 1; \
	fi
	@sudo mkdir -p /root/.ssh
	@sudo chmod 700 /root/.ssh
	@age -d secrets/keys/$(HOSTNAME)_root_id_rsa.age | sudo tee /root/.ssh/id_rsa > /dev/null
	@sudo ssh-keygen -y -f /root/.ssh/id_rsa | sudo tee /root/.ssh/id_rsa.pub > /dev/null
	@sudo chmod 600 /root/.ssh/id_rsa
	@sudo chmod 644 /root/.ssh/id_rsa.pub
	@sudo chown -R root:root /root/.ssh
	@echo "root key restored for $(HOSTNAME)"


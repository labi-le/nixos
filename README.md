```sh
sudo nix \
    --extra-experimental-features 'flakes nix-command' \
    run github:nix-community/disko#disko-install -- \
    --flake "github:labie-le/nixos" \
    --write-efi-boot-entries \
    --disk main /mnt/
```

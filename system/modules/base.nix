{
  imports = [
    ./boot.nix
    ./sudo.nix
    ./systemd.nix
    ./logind.nix
    ./journald.nix
    ./shell.nix
    ./nixvim
    ./docker.nix
    ./polkit.nix
    ./nvme.nix
    ./keyring.nix
    ./locale.nix
    ./users.nix
    ./env.nix
    ./network
  ];
}


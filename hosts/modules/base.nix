{
  imports = [
    ./boot.nix
    ./sudo.nix
    ./systemd.nix
    ./logind.nix
    ./journald.nix
    ./shell.nix
    ./monitors.nix
    ./nixvim
    ./docker.nix
    ./polkit.nix
    ./nvme.nix
    ./keyring.nix
    ./locale.nix
    ./users.nix
    ./env.nix
    ./network
    ./packages.nix
    ./ssh.nix
  ];
}


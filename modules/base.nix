{ config, user, ... }:
{
  imports = [
    ./boot.nix
    ./sudo.nix
    ./systemd.nix
    ./journald.nix
    ./shell.nix
    ./tmux.nix
    ./monitors.nix
    ./backlight.nix
    ./docker.nix
    ./polkit.nix
    ./nvme.nix
    ./keyring.nix
    ./locale.nix
    ./users.nix
    ./terminal.nix
    ./env.nix
    ./network
    ./packages.nix
    ./ssh.nix
    ./builders.nix
    ./hotkeys.nix
    ./nix-search-tv.nix
    ./nix-ld.nix
    ./cache-push.nix
    ./opencode-secrets.nix
    ./omp
    ./yazi.nix
    ./nixvim
    ./stylix.nix
  ];

  age.identityPaths = [
    "/etc/ssh/ssh_host_rsa_key"
    "/etc/ssh/ssh_host_ed25519_key"
    "${config.users.users.${user.name}.home}/.ssh/id_ed25519"
  ];
}

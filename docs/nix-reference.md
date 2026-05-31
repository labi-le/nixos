# Nix Reference

## Project Structure

```text
/
├── flake.nix                  # Flake definition with inputs and outputs
├── overlays.nix               # Custom package overlays
├── settings.nix               # Common settings
├── modules/                   # NixOS modules
│   ├── base.nix               # Base modules import
│   ├── packages.nix           # System packages
│   ├── packages-desktop.nix   # Desktop packages
│   ├── packages-server.nix    # Server packages
│   ├── shell.nix              # ZSH configuration
│   ├── users.nix              # User management + Home Manager
│   └── ...
├── hosts/                     # Host-specific configurations
│   ├── configuration.nix
│   ├── configuration-fx516.nix
│   ├── configuration-notebook.nix
│   └── configuration-server.nix
└── home-manager/              # Home Manager configuration
    ├── home.nix
    └── modules/               # HM modules: sway, waybar, alacritty, etc.
```

## Adding A Package

### From A Flake Input

1. Add an input in `flake.nix`:

```nix
opencode.url = "github:numtide/llm-agents.nix";
```

2. Expose it in `overlays.nix`:

```nix
opencode = inputs.opencode.packages.${system}.opencode;
```

### From A Local Package

1. Create `pkgs/name.nix`:

```nix
{ pkgs ? import <nixpkgs> { }
,
}:

pkgs.writeShellScriptBin "my-script" ''
  #!/bin/sh
  echo "Hello"
'';
```

2. Expose it in `overlays.nix`:

```nix
my-script = prev.callPackage ./pkgs/my-script.nix { };
```

3. Add it to the relevant package list:

- `modules/packages.nix` for all hosts.
- `modules/packages-desktop.nix` for desktop hosts: `pc`, `fx516`, and
  `notebook`.
- `modules/packages-server.nix` for servers.

## Adding A Command Alias

Add aliases in `modules/users.nix` under `environment.interactiveShellInit`:

```nix
environment.interactiveShellInit = ''
  alias oo="opencode"
'';
```

## Secrets Management With agenix

Secrets live in `secrets/` as encrypted `.age` files.

### Encrypt A Secret

```bash
age -p -o secrets/mysecret.age <<< "secret content"
```

### Use A Secret

```nix
age.secrets.mysecret = {
  file = ./secrets/mysecret.age;
  owner = "labile";
  group = "users";
};
```

### SSH Keys

```bash
# SSH key management commands
```

## Monitor Configuration

Monitors are configured in the host configuration, such as
`hosts/configuration.nix`:

```nix
monitors = {
  "DP-3" = {
    mode = "2560x1440@179.999Hz";
    geometry = "1920 0";
    position = "right";
  };
  "DP-2" = {
    mode = "1920x1080@165Hz";
    geometry = "0 0";
    position = "left";
  };
};
```

Get monitor names with:

```bash
nix run nixpkgs#wlr-randr
```

## Main Hosts

- `pc`: main desktop with Home Manager.
- `fx516`: laptop with Home Manager.
- `notebook`: second laptop with Home Manager.
- `server`: server without Home Manager.

## Desktop And Server Package Configuration

Set one of these in `hosts/configuration.nix`:

```nix
packages.desktop = true;  # enable desktop packages
packages.server = true;   # enable server packages
```

## Frequently Used Commands

Run these from the project root with `make`:

```bash
make switch              # apply configuration (NixOS)
make boot                # reboot into new configuration
make upgrade             # update flake and apply configuration
make fmt                 # format nix files
make disko               # run disko for disk partitioning
make cleanup             # remove old generations and apply configuration
make optimise            # optimise nix store
```

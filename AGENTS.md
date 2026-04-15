# Nix Configuration Project

## General Rules

- **Use Context7 MCP** — Always use `context7_resolve-library-id` and `context7_query-docs` for library/framework documentation before implementing any feature or answering programming questions.
- **Use using-superpowers skill** — Always invoke the `using-superpowers` skill when available to follow relevant workflow (check for skills first).
- **Always verify dry-run before switch** — Always run `nix build .#nixosConfigurations.pc.config.system.build.toplevel --dry-run` (or the equivalent for the target host) and confirm it builds successfully before asking user to run `make switch`.

## Project Structure

```
/
├── flake.nix              # Flake definition with inputs and outputs
├── overlays.nix           # Custom package overlays
├── settings.nix           # Common settings
├── modules/               # NixOS modules
│   ├── base.nix          # Base modules import
│   ├── packages.nix      # System packages
│   ├── packages-desktop.nix  # Desktop packages
│   ├── packages-server.nix   # Server packages
│   ├── shell.nix         # ZSH configuration
│   ├── users.nix         # User management + Home Manager
│   └── ...
├── hosts/                 # Host-specific configurations
│   ├── configuration.nix
│   ├── configuration-fx516.nix
│   ├── configuration-notebook.nix
│   └── configuration-server.nix
└── home-manager/         # Home Manager configuration
    ├── home.nix
    └── modules/          # HM modules (sway, waybar, alacritty, etc.)
```

## How to Add a Package

### From flake input
1. Add input in `flake.nix`:
```nix
opencode.url = "github:numtide/llm-agents.nix";
```

2. Add in `overlays.nix`:
```nix
opencode = inputs.opencode.packages.${system}.opencode;
```

### Local package
1. Create package in `pkgs/name.nix`:
```nix
{ pkgs ? import <nixpkgs> { }
,
}:

pkgs.writeShellScriptBin "my-script" ''
  #!/bin/sh
  echo "Hello"
'';
```

2. Add in `overlays.nix`:
```nix
my-script = prev.callPackage ./pkgs/my-script.nix { };
```

3. Add to package list:
   - `modules/packages.nix` — for all hosts
   - `modules/packages-desktop.nix` — only for desktops (pc, fx516, notebook)
   - `modules/packages-server.nix` — only for servers

## How to Add a Command Alias

Add in `modules/users.nix` in section `environment.interactiveShellInit`:
```nix
environment.interactiveShellInit = ''
  alias oo="opencode"
'';
```

## Secrets Management (agenix)

Secrets are stored in `secrets/` in encrypted form (`.age` files).

### Encrypt a secret
```bash
age -p -o secrets/mysecret.age <<< "secret content"
```

### Use in configuration
```nix
age.secrets.mysecret = {
  file = ./secrets/mysecret.age;
  owner = "labile";
  group = "users";
};
```

### SSH keys
```bash
# SSH key management commands
```

## Monitor Configuration

Monitors are configured in host configuration (`hosts/configuration.nix`):
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

Get monitor names: `nix run nixpkgs#wlr-randr`

## Main Hosts

- `pc` — main desktop with home-manager
- `fx516` — laptop with home-manager
- `notebook` — second laptop with home-manager
- `server` — server without home-manager

## Desktop/Server Package Configuration

In `hosts/configuration.nix`:
```nix
packages.desktop = true;  # enable desktop packages
# or
packages.server = true;   # enable server packages
```

## Frequently Used Commands

Use `make` from project root:

```bash
make switch              # apply configuration (NixOS)
make boot                # reboot into new configuration
make upgrade             # update flake and apply configuration
make fmt                 # format nix files
make disko               # run disko for disk partitioning
make cleanup             # remove old generations and apply configuration
make optimise            # optimise nix store
```

# modules/nixvim/ — Neovim via nixvim

All config is `programs.nixvim.*` (the `nixvim` flake input), NOT raw Neovim/Lua files.
`default.nix` → `imports [ ./plugins.nix ./keymaps.nix ]`; `plugins.nix` aggregates the component files
(barbar/telescope/cmp/blink/lsp/conform/dap).

## How to add

- Plugin in nixvim → `programs.nixvim.plugins.<name>.enable = true;` in the matching component file.
- Plugin not in nixvim → `extraPlugins = with pkgs; [ vimPlugins.<name> ];`.
- Runtime binary the editor needs → `extraPackages` (ripgrep, fd, delve, go, ...).
- Raw Lua → `extraConfigLua = '' ... '';`.
- New component → create it, then add to `imports` in `plugins.nix`.

Gotcha: editor formats Nix with `nixfmt --quiet` (nil_ls), but the repo formatter is `nixpkgs-fmt` (`make fmt`).

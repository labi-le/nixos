{
  imports = [
    ./common.nix
    ./plugins.nix
    ./keymaps.nix
  ];

  programs.nixvim = {
    clipboard = {
      register = "unnamedplus";
      providers.wl-copy.enable = true;
    };
  };
}

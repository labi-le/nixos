{ ... }: {

  programs.nixvim = {
    plugins.barbar = { enable = true; };

    keymaps = [
      {
        key = "<A-,>";
        action = "<Cmd>BufferPrevious<CR>";
        mode = "n";
      }
      {
        key = "<A-.>";
        action = "<Cmd>BufferNext<CR>";
        mode = "n";
      }
      {
        key = "<A-c>";
        action = "<Cmd>BufferClose<CR>";
        mode = "n";
      }
      {
        key = "<A-x>";
        action = "<Cmd>BufferPick<CR>";
        mode = "n";
      }
    ];
  };
}

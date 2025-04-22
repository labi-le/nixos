{ ... }:
{

  programs.nixvim = {
    plugins.barbar = {
      enable = true;
    };

    keymaps = [
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

      {
        key = "<A-Left>";
        action = "<Cmd>BufferPrevious<CR>";
        mode = "n";
      }
      {
        key = "<A-Right>";
        action = "<Cmd>BufferNext<CR>";
        mode = "n";
      }
      {
        key = "<A-S-Left>";
        action = "<Cmd>BufferMovePrevious<CR>";
        mode = "n";
      }
      {
        key = "<A-S-Right>";
        action = "<Cmd>BufferMoveNext<CR>";
        mode = "n";
      }

      {
        key = "<A-1>";
        action = "<Cmd>BufferGoto 1<CR>";
        mode = "n";
      }
      {
        key = "<A-2>";
        action = "<Cmd>BufferGoto 2<CR>";
        mode = "n";
      }
      {
        key = "<A-3>";
        action = "<Cmd>BufferGoto 3<CR>";
        mode = "n";
      }
      {
        key = "<A-4>";
        action = "<Cmd>BufferGoto 4<CR>";
        mode = "n";
      }
      {
        key = "<A-5>";
        action = "<Cmd>BufferGoto 5<CR>";
        mode = "n";
      }
    ];
  };
}

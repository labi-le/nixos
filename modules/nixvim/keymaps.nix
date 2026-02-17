{
  programs.nixvim.keymaps = [
    {
      key = "//";
      action = ":noh<CR>";
    }

    {
      key = "yp";
      action = ":t.<CR>";
      mode = "n";

    }

    {
      key = "jj";
      action = "<Esc>";
      mode = [
        "i"
        "v"
      ];
    }
    {
      key = "J";
      action = "]]";
      mode = [
        "n"
        "v"
      ];
      options = {
        desc = "next code block (TreeSitter)";
      };
    }

    {
      key = "K";
      action = "[[";
      mode = [
        "n"
        "v"
      ];
      options = {
        desc = "previous code block (TreeSitter)";
      };
    }

    {
      key = "j";
      action = "]m";
      mode = [
        "n"
        "v"
      ];
      options = {
        desc = "next fn (TreeSitter)";
      };
    }

    {
      key = "k";
      action = "[m";
      mode = [
        "n"
        "v"
      ];
      options = {
        desc = "previous fn (TreeSitter)";
      };
    }
  ];
}

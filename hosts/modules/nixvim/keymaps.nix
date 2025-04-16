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
  ];
}

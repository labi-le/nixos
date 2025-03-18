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
  ];
}

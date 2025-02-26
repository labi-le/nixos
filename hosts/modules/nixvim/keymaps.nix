{
  programs.nixvim.keymaps = [
    {
      key = "ff";
      action = "<cmd>lua require('telescope.builtin').find_files()<cr>";
    }

    {
      key = "//";
      action = ":noh<CR>";
    }
  ];
}

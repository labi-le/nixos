{ ... }: {

  programs.nixvim = {
    plugins.telescope = {

      enable = true;
      settings = {
        defaults = { file_ignore_patterns = [ "vendor" "migrations" ".git" ]; };
      };
      extensions = {
        file-browser = {
          enable = true;
          settings.hijack_netrw = true;
        };
        fzf-native = {
          enable = true;
          settings.fuzzy = true;
          settings.override_generic_sorter = true;
          settings.override_file_sorter = true;
        };
      };
    };

    keymaps = [
      {
        key = "ff";
        action =
          "<cmd>lua (function() local builtin = require('telescope.builtin'); local ok = pcall(builtin.git_files, {}); if not ok then builtin.find_files({ hidden = true }) end end)()<cr>";
      }

      {
        key = "fd";
        action =
          "<cmd>lua require('telescope').extensions.file_browser.file_browser()<cr>";
      }
      {
        key = "fg";
        action = "<cmd>lua require('telescope.builtin').live_grep()<cr>";
      }

    ];
  };
}

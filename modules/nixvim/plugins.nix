{ pkgs, ... }:
{

  imports = [
    ./barbar.nix
    ./telescope.nix
    ./cmp.nix
    ./lsp.nix
    ./conform.nix
    ./dap.nix
  ];
  programs.nixvim = {
    plugins = {
      dap-ui.enable = true;
      dap-go.enable = true;
      cmp-dap.enable = true;
      dap = {
        enable = true;
        configurations = {
          # go = [
          #   {
          #     name = "Launch file";
          #     type = "go";
          #     request = "launch";
          #     program = "\${file}";
          #   }
          #   {
          #     name = "Debug test";
          #     type = "go";
          #     request = "launch";
          #     mode = "test";
          #     program = "\${file}";
          #   }
          #   # Можно добавить конфигурацию для подключения к удаленному процессу delve
          #   # {
          #   #   name = "Attach remote";
          #   #   type = "go";
          #   #   request = "attach";
          #   #   mode = "remote";
          #   #   port = 2345; # Укажите нужный порт
          #   #   host = "127.0.0.1";
          #   # }
          # ];
          php = [
            {
              name = "Listen for Xdebug";
              type = "php";
              request = "launch";
              port = 9003;
              # pathMappings может потребоваться, если ваш код PHP работает в Docker или VM
              # pathMappings = {
              #   "/path/inside/container" = "\${workspaceFolder}";
              # };
              log = false; # Установите в true для логов отладки адаптера
            }
            # Вы можете добавить конфигурацию для запуска текущего скрипта PHP
            # {
            #   name = "Launch current script";
            #   type = "php";
            #   request = "launch";
            #   program = "\${file}";
            #   cwd = "\${workspaceFolder}";
            #   runtimeExecutable = "php"; # Или укажите путь к php
            # }
          ];
        };
      };
      friendly-snippets.enable = true;
      luasnip = {
        enable = true;
      };
      lsp-format.enable = true;
      transparent = {
        enable = true;
      };
      nix.enable = true;
      auto-save.enable = true;
      auto-session.enable = true;
      comment.enable = true;
      # double shift menu
      web-devicons.enable = true;
      treesitter.enable = true;
      lsp-lines.enable = true;

      precognition.enable = true;
      nvim-autopairs = {
        enable = true;
      };

      treesitter-textobjects = {
        enable = true;

        move = {
          enable = true;
          gotoNextStart = {
            "]]" = "@block.outer";
            "]m" = "@function.outer";
          };
          gotoPreviousStart = {
            "[[" = "@block.outer";
            "[m" = "@function.outer";
          };
        };
      };

    };
    extraPlugins = with pkgs; [
      vimPlugins.vim-visual-multi
      vimPlugins.tiny-inline-diagnostic-nvim
    ];
    extraPackages = with pkgs; [
      ripgrep
      fd
      delve
      go
    ];

    extraConfigLua = ''
      vim.g.transparent_enabled = true
    '';
  };

}

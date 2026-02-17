{ pkgs, ... }:
{

  programs.nixvim = {
    plugins = {
      dap-ui.enable = true;
      dap-go.enable = true;
      cmp-dap.enable = true;
      hydra = {
        enable = true;
      };
      dap = {
        enable = true;
        configurations = {
          go = [
            {
              type = "go";
              name = "Debug Package";
              request = "launch";
              program = "\${workspaceFolder}";
            }
            {
              type = "go";
              name = "Debug Current File";
              request = "launch";
              program = "\${fileDirname}";
            }
          ];
        };
      };
    };
    extraPackages = with pkgs; [
      delve
      go
    ];

    extraConfigLua = ''
      local dap, dapui = require("dap"), require("dapui")

      dapui.setup({
        layouts = {
          {
            elements = {
              { id = "console" },
            },
            size = 2,
            position = "top",
          },
          {
            elements = {
              { id = "scopes" },
            },
            size = 15,
            position = "bottom",
          },
          {
            elements = {
              { id = "watches", size = 0.33 },
              { id = "repl", size = 0.33 },
              { id = "stacks", size = 0.34 },
            },
            size = 30,
            position = "left",
          },
        },
      })

      dap.listeners.before.attach.dapui_config = function()
        dapui.open()
      end

      dap.listeners.before.launch.dapui_config = function()
      dapui.open()
      end

      dap.listeners.before.event_terminated.dapui_config = function()
        dapui.close()
      end

      dap.listeners.before.event_exited.dapui_config = function()
        dapui.close()
      end

      vim.api.nvim_set_hl(0, "NormalFloat", {fg="NONE", bg="NONE"})

      require('hydra') {
        name = 'Debug',
        config = {
          color = 'pink',
          invoke_on_body = true,
        },
        mode = { 'n' },
        body = '<leader>d',
        heads = {
          { 'p', dap.step_back, { desc = 'prev' } },
          { '<CR>', dap.step_into, { desc = 'into' } },
          { 'N', dap.step_out, { desc = 'out' } },
          { 'n', dap.step_over, { desc = 'over' } },
          { 't', dap.toggle_breakpoint, { desc = 'toggle breakpoint' } },
          { 'T', dap.clear_breakpoints, { desc = 'clear breakpoints' } },
          { 'x', dap.terminate, { desc = 'terminate' } },
          { 'r', dap.repl.open, { exit = true, desc = 'open repl' } },
          { 'q', nil, { exit = true, nowait = true, desc = 'exit' } },
          { 'c', dap.continue, { desc = 'continue' } },
        }
      }
    '';
    globals.mapleader = " ";

  };
}

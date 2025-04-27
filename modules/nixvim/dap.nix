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

           local hint = [[
          ^ ^Step^ ^ ^      ^ ^     Action
      ----^-^-^-^--^-^----  ^-^-------------------
          ^ ^back^ ^ ^     ^_t_: toggle breakpoint
          ^ ^ _p_^ ^        _T_: clear breakpoints
      out _N_ ^ ^_<CR>_into _x_: terminate
          ^ ^ _n_ ^ ^       ^^_r_: open repl
          ^ ^over ^ ^

          ^ ^  _q_: exit
           ]]
           vim.api.nvim_set_hl(0, "NormalFloat", {fg="NONE", bg="NONE"})

           require('hydra') {
             name = 'Debug',
             --hint = hint,
             config = {
               color = 'pink',
               invoke_on_body = true,
               --hint = {
               --  type = 'window'
               --},
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

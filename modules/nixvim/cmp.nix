{ ... }:
{

  programs.nixvim.plugins = {
    cmp = {
      enable = true;
      autoEnableSources = true;
      settings = {
        sources = [
          { name = "nvim_lsp"; }
          { name = "cmp-dap"; }
          { name = "luasnip"; }
          { name = "path"; }
        ];

        mapping = {
          "<C-Space>" = ''
            cmp.mapping(function(_)
            if cmp.visible() then
            cmp.abort()
            else
            cmp.complete()
            end
            end, { 'i', 'c' })
          '';
          "<Up>" = "cmp.mapping.select_prev_item()";
          "<Down>" = "cmp.mapping.select_next_item()";
          "<CR>" = "cmp.mapping.confirm({ select = true })";
          "<Tab>" = ''
            cmp.mapping(function(fallback)
            if cmp.visible() then
            cmp.select_next_item()
            else
            fallback()
            end
            end, { 'i', 's' })'';
        };

        extraConfig = ''
          local cmp_autopairs = require('nvim-autopairs.completion.cmp')
          local cmp = require('cmp')
          cmp.event:on(
            'confirm_done',
            cmp_autopairs.on_confirm_done()
          )
        '';

      };
    };
  };

}

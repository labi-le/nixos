{ ... }:
{

  programs.nixvim.plugins = {
    cmp = {
      enable = true;
      autoEnableSources = true;

      settings = {
        sources = [
          { name = "nvim_lsp"; }
          { name = "luasnip"; }
          { name = "treesitter"; }
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

        # window = {
        #   completion = {
        #     border = "rounded";
        #     winhighlight = "Normal:Pmenu,FloatBorder:Pmenu,CursorLine:PmenuSel,Search:None";
        #   };
        #   documentation = {
        #     border = "rounded";
        #     winhighlight = "Normal:Pmenu,FloatBorder:Pmenu,Search:None";
        #     max_width = 80;
        #     max_height = 20;
        #   };
        # };
      };
    };
  };

}

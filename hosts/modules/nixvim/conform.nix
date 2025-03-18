{ pkgs, ... }: {

  programs.nixvim = {
    plugins = {
      conform-nvim = {
        enable = true;
        settings = {
          format_on_save = { lsp_format = "fallback"; };
          formatters_by_ft = { php = [ "php_cs_fixer" ]; };
          formatters = {
            # phpcbf = {
            #   command = "${pkgs.php83Packages.php-codesniffer}/bin/phpcbf";
            #   args = [ "--standard=PSR2" "$FILENAME" ];
            # };
            php_cs_fixer = {
              command = "${pkgs.php83Packages.php-cs-fixer}/bin/php-cs-fixer";
              args = [ "fix" "$FILENAME" "--rules" "@PER-CS2.0" ];
            };
          };
        };

      };
    };
  };
}

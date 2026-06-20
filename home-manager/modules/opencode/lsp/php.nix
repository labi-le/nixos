{ pkgs, ... }:

# phpactor is self-contained: its bin is a PHP script with a shebang pointing at
# its own bundled `php-with-extensions`, so it needs nothing extra on PATH.
# We prefer it over opencode's built-in `intelephense` (unfree) and disable the
# built-in to avoid two language servers racing on `.php`.
{
  home.packages = [ pkgs.phpactor ];

  programs.opencode.settings.lsp = {
    "php intelephense".disabled = true;
    phpactor = {
      command = [
        "${pkgs.phpactor}/bin/phpactor"
        "language-server"
      ];
      extensions = [ ".php" ];
    };
  };
}

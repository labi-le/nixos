{ pkgs
, ...
}:


let
  cursorTheme = {
    name = "capitaine-cursors";
    package = pkgs.capitaine-cursors;
    size = 40;
  };
in
{
  gtk = {
    enable = true;
    theme = {
      name = "Dracula";
      package = pkgs.dracula-theme;
    };
    iconTheme = {
      name = "Dracula";
      package = pkgs.dracula-icon-theme;
    };

    inherit cursorTheme;

  };

  home.pointerCursor = {
    name = cursorTheme.name;
    package = cursorTheme.package;
    size = cursorTheme.size;
    x11 = {
      enable = true;
      defaultCursor = cursorTheme.name;
    };
  };

}

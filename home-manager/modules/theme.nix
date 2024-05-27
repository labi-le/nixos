{ pkgs
, ...
}:

let
  cursorTheme = {
    name = "banana-cursor";
    package = pkgs.banana-cursor;
    size = 24;
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

  home.sessionVariables = {
    XCURSOR_THEME = cursorTheme.name;
    XCURSOR_SIZE = "${toString cursorTheme.size}";
  };
}

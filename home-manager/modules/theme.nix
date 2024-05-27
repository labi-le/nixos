{ pkgs
, ...
}:

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

    #cursorTheme = {
    #  name = "banana-cursor";
    #  package = pkgs.banana-cursor;
    #  size = 24;
    #};

  };

  home.pointerCursor = {

    gtk.enable = true;

    package = pkgs.phinger-cursors;

    name = "Phinger-cursors-light";

    size = 48;

  };

}

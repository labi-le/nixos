{ osConfig, pkgs, ... }:

{
  xfconf = {
    enable = true;
    settings.thunar = {
      "hidden-bookmarks" = [ "recent:///" ];
      "misc-change-window-icon" = true;
      "misc-date-style" = "THUNAR_DATE_STYLE_LONG";
      "misc-exec-shell-scripts-by-default" = true;
      "misc-file-size-binary" = true;
      "misc-full-path-in-tab-title" = true;
      "misc-middle-click-in-tab" = true;
      "misc-show-delete-action" = true;
      "misc-single-click" = false;
      "misc-text-beside-icons" = false;
      "misc-thumbnail-draw-frames" = false;
      "misc-thumbnail-mode" = "THUNAR_THUMBNAIL_MODE_ALWAYS";
      "misc-confirm-move-to-trash" = false;
      "misc-delete-action" = true;
    };
  };

  xdg.configFile = {
    "Thunar/accels.scm".text =
      ''(gtk_accel_path "<Actions>/ThunarActionManager/delete-2" "Delete")'';
    "xfce4/helpers.rc".text =
      "TerminalEmulator=${osConfig.environment.variables.TERMINAL}";
  };

  home.packages = with pkgs; [ xarchiver ];
}

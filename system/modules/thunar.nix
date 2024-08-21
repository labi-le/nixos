{ pkgs, ... }:
let
  customThunar = pkgs.xfce.thunar.overrideAttrs (oldAttrs: {
    # Добавляем пост-инсталляционный хук для настройки Thunar
    postInstall = (oldAttrs.postInstall or "") + ''
      # Создаем кастомный конфигурационный файл
      mkdir -p $out/share/xfce4/xfconf/xfce-perchannel-xml
      cat > $out/share/xfce4/xfconf/xfce-perchannel-xml/thunar.xml << EOF
      <?xml version="1.0" encoding="UTF-8"?>
      <channel name="thunar" version="1.0">
        <property name="last-show-hidden" type="bool" value="false"/>
        <property name="last-side-pane" type="string" value="ThunarShortcutsPane"/>
        <property name="last-sort-column" type="string" value="THUNAR_COLUMN_NAME"/>
        <property name="last-sort-order" type="string" value="GTK_SORT_ASCENDING"/>
        <property name="last-statusbar-visible" type="bool" value="true"/>
        <property name="last-view" type="string" value="ThunarIconView"/>
        <property name="last-location-bar" type="string" value="ThunarLocationEntry"/>
        <property name="last-toolbar-item" type="string" value="ThunarLocationEntry"/>
        <property name="misc-volume-management" type="bool" value="true"/>
        <property name="misc-case-sensitive" type="bool" value="false"/>
        <property name="misc-date-style" type="string" value="THUNAR_DATE_STYLE_SIMPLE"/>
        <property name="misc-folders-first" type="bool" value="true"/>
        <property name="misc-horizontal-wheel-navigates" type="bool" value="false"/>
        <property name="misc-recursive-permissions" type="string" value="THUNAR_RECURSIVE_PERMISSIONS_ALWAYS"/>
        <property name="misc-remember-geometry" type="bool" value="true"/>
        <property name="misc-show-about-templates" type="bool" value="true"/>
        <property name="misc-single-click" type="bool" value="false"/>
        <property name="misc-thumbnail-mode" type="string" value="THUNAR_THUMBNAIL_MODE_ALWAYS"/>
        <property name="misc-use-si-units" type="bool" value="false"/>
        <property name="shortcuts-icon-size" type="string" value="THUNAR_ICON_SIZE_SMALLER"/>
        <property name="tree-icon-size" type="string" value="THUNAR_ICON_SIZE_SMALLEST"/>
        <property name="trash-enabled" type="bool" value="false"/>
      </channel>
      EOF

      # Создаем глобальные закладки
      mkdir -p $out/etc/xdg/gtk-3.0
      cat > $out/etc/xdg/gtk-3.0/bookmarks << EOF
      file:///home/Documents
      file:///home/Downloads
      file:///home/Pictures
      file:///home/Videos
      file:///home/Music
      EOF
    '';
  });

  # Кастомный плагин архивирования для Thunar
  customThunarArchivePlugin = pkgs.xfce.thunar-archive-plugin.overrideAttrs (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + ''
      rm -rf $out/libexec/thunar-archive-plugin
      mkdir -p $out/libexec/thunar-archive-plugin
      ln -s ${pkgs.xarchiver}/libexec/thunar-archive-plugin/* $out/libexec/thunar-archive-plugin/
    '';
  });
in
{
  # Используем наш кастомный Thunar вместо стандартного
  environment.systemPackages = with pkgs; [
    customThunar
    customThunarArchivePlugin
    xfce.thunar-volman
    xarchiver
  ];

  programs.thunar.enable = true;

  # Включаем необходимые сервисы
  services.gvfs.enable = true;
  services.tumbler.enable = true;

  # Устанавливаем глобальные настройки для Thunar
  environment.etc."xdg/xfce4/xfconf/xfce-perchannel-xml/thunar.xml".source =
    "${customThunar}/share/xfce4/xfconf/xfce-perchannel-xml/thunar.xml";

  environment.etc."xdg/gtk-3.0/bookmarks".source =
    "${customThunar}/etc/xdg/gtk-3.0/bookmarks";
}

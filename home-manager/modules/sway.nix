{ lib
, osConfig
, pkgs
, config
, ...
}:

let
  browser = "google-chrome-stable";
  terminal = "alacritty";
  bar = "waybar";
  menu = "wofi";
  filemanager = "thunar";

  findMonitor = osConfig.monitorFinder;

  left = findMonitor "left";
  right = findMonitor "right";

  common = osConfig.hotkeys.common;
  additional = osConfig.hotkeys.additional;

  grimshot = "${pkgs.sway-contrib.grimshot}/bin/grimshot";

  workspaces = {
    terminal = "1";
    develop = "2";
    browser = "3";
    social = "4";
    game = "5";
    file = "6";
    work = "7";
    private = "8";
  };

in
{
  wayland.windowManager.sway = {
    package = pkgs.swayfx;
    checkConfig = false;
    enable = true;
    wrapperFeatures.gtk = true;
    config = {
      modifier = common;
      terminal = terminal;
      menu = menu;
      bars = [
        {
          command = bar;
          mode = "hide";
          hiddenState = "hide";
        }
      ];
      startup = [
        {
          command = "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_DATA_DIRS";
        }
        {
          command = "import-gsettings";
          always = true;
        }
        {
          command = "${pkgs.swaybg}/bin/swaybg -i ~/Pictures/bryan-goff-f7YQo-eYHdM-unsplash.jpg";
        }
      ];
      modes = {
        resize = {
          Down = "resize grow height 10 ppt";
          Left = "resize shrink width 10 ppt";
          Return = "mode default";
          Escape = "mode default";
          Right = "resize grow width 10 ppt";
          Up = "resize shrink height 10 ppt";
        };
      };
      output = lib.mapAttrs
        (
          name: monitor:
            {
              mode = monitor.mode;
              pos = monitor.geometry;
            }
            // lib.optionalAttrs (monitor.transform != null) {
              transform = monitor.transform;
            }
        )
        osConfig.monitors;
      input = {
        "type:touchpad" = {
          dwt = "enabled";
          tap = "enabled";
          drag_lock = "disabled";
          natural_scroll = "enabled";
        };
        "*" = {
          xkb_layout = "us,ru";
          xkb_options = "grp:caps_toggle";
        };
      };
      gaps = {
        inner = 2;
        outer = 0;
      };
      window = {
        border = 1;
        hideEdgeBorders = "smart";
      };
      floating = {
        modifier = common;
        criteria = [
          { app_id = "Alacritty"; }
          {
            class = "Yad";
            instance = "yad";
            app_id = "yad";
          }
          {
            class = "Bluetooth-sendto";
            instance = "bluetooth-sendto";
          }
          { window_role = "About"; }
          { window_role = "pop-up"; }
          { window_role = "bubble"; }
          { window_role = "task_dialog"; }
          { window_role = "Preferences"; }
          { window_type = "dialog"; }
          { window_type = "menu"; }
        ];
      };

      assigns = {
        ${workspaces.develop} = [
          { class = "^jetbrains-[^\\s]+$"; }
          { class = "Code"; }
          { class = "Postman"; }
        ];
        ${workspaces.game} = [
          { class = "steam"; }
          { class = "com.faforever.client.FafClientApplication"; }
          { app_id = "gamescope"; }
          { class = "steam_app_9420"; }
        ];
        ${workspaces.social} = [
          { app_id = "vesktop"; }
          { app_id = "obsidian"; }
          { app_id = "com.ayugram.desktop"; }
        ];
        ${workspaces.browser} = [
          { app_id = "google-chrome"; }
        ];
      };
      window.commands = [
        {
          command = "fullscreen enable; inhibit_idle fullscreen; border none";
          criteria = {
            class = "gamescope";
          };
        }
        {
          command = "floating disable";
          criteria = {
            app_id = "Alacritty";
            workspace = workspaces.terminal;
          };
        }
        {
          command = "move to workspace ${workspaces.browser}; inhibit_idle fullscreen";
          criteria = {
            instance = "google-chrome";
          };
        }
        {
          command = "move to workspace ${workspaces.browser}; inhibit_idle fullscreen";
          criteria = {
            app_id = "waterfox";
          };
        }
        {
          command = "move to workspace ${workspaces.browser}; inhibit_idle fullscreen";
          criteria = {
            app_id = "firefox";
          };
        }
        {
          command = "resize set width 45ppt height 60ppt; floating enable; focus";
          criteria = {
            app_id = "file-roller";
          };
        }
        {
          command = "floating enable; resize set width 45ppt height 60ppt; focus";
          criteria = {
            app_id = "thunar";
          };
        }
        {
          command = "floating enable; resize set width 65ppt height 70ppt; focus";
          criteria = {
            app_id = "com.github.wwmm.easyeffects";
          };
        }
        {
          command = "floating enable; sticky enable";
          criteria = {
            title = "\\ -\\ Sharing\\ Indicator$";
          };
        }
        {
          command = "floating enable; resize set width 40 ppt height 30 ppt";
          criteria = {
            app_id = "blueman-manager";
          };
        }
        {
          command = "floating enable; resize set width 40 ppt height 30 ppt";
          criteria = {
            app_id = "io.bassi.Amberol";
          };
        }
        {
          command = "floating enable; resize set width 40 ppt height 30 ppt";
          criteria = {
            app_id = "pavucontrol";
          };
        }
        {
          command = "floating enable; resize set width 60 ppt height 50 ppt";
          criteria = {
            class = "qt5ct";
            instance = "qt5ct";
          };
        }
        {
          command = "resize set width 60 ppt height 50 ppt; floating enable";
          criteria = {
            class = "Lxappearance";
          };
        }
        {
          command = "resize set width 45ppt height 60ppt; floating enable; focus";
          criteria = {
            app_id = "mpv";
          };
        }
        {
          command = "sticky enable; resize set width 40 ppt height 30 ppt; floating enable";
          criteria = {
            title = "File Operation Progress";
          };
        }
        {
          command = "sticky enable; resize set width 40 ppt height 30 ppt; floating enable;";
          criteria = {
            app_id = "firefox";
            title = "Library";
          };
        }
        {
          command = "floating enable; sticky enable, resize set width 30 ppt height 40 ppt";
          criteria = {
            app_id = "floating_shell_portrait";
          };
        }
        {
          command = "floating enable; sticky enable";
          criteria = {
            title = "Picture in picture";
          };
        }
        {
          command = "floating enable";
          criteria = {
            app_id = "xsensors";
          };
        }
        {
          command = "floating enable";
          criteria = {
            title = "Save File";
          };
        }
      ];
      keybindings = {
        "${common}+Return" = "exec ${terminal}";
        "${common}+Shift+e" = "exec wofi-powermenu";
        "${common}+q" = "kill";
        "BTN_MIDDLE" = "kill --border";
        "${common}+z" = "exec pkill -SIGUSR1 ${bar}";
        "${common}+x" = "mode resize";
        "${common}+d" = "exec ${menu} -c ~/.config/wofi/config -I";
        "${common}+Shift+c" = "reload";
        "${common}+Left" = "focus left";
        "${common}+Down" = "focus down";
        "${common}+Up" = "focus up";
        "${common}+Right" = "focus right";
        "${common}+Shift+Left" = "move left";
        "${common}+Shift+Down" = "move down";
        "${common}+Shift+Up" = "move up";
        "${common}+Shift+Right" = "move right";
        "${common}+b" = "splith";
        "${common}+v" = "splitv";
        "${common}+s" = "layout stacking";
        "${common}+w" = "layout tabbed";
        "${common}+e" = "layout toggle split";
        "${common}+f" = "fullscreen";
        "${common}+Shift+space" = "floating toggle";
        "${common}+Ctrl+Right" = "resize shrink width 20 ppt";
        "${common}+Ctrl+Up" = "resize grow height 20 ppt";
        "${common}+Ctrl+Down" = "resize shrink height 20 ppt";
        "${common}+Ctrl+Left" = "resize grow width 20 ppt";
        "XF86AudioLowerVolume" = "exec ${pkgs.pulseaudio}/bin/pactl set-sink-volume 0 -2%";
        "XF86AudioRaiseVolume" = "exec ${pkgs.pulseaudio}/bin/pactl set-sink-volume 0 +2%";
        "XF86AudioMute" =
          ''exec ${pkgs.alsa-utils}/bin/amixer -c $(cat /proc/asound/cards | grep "Scarlett" | head -n1 | awk '{print $1}') cset numid=10 toggle'';
        "XF86AudioPlay" = "exec playerctl play";
        "XF86AudioPause" = "exec playerctl pause";
        "XF86AudioNext" = "exec playerctl next";
        "XF86AudioPrev" = "exec playerctl previous";
        "XF86MonBrightnessUp" = "exec ${pkgs.brightnessctl}/bin/brightnessctl -c backlight set +5%";
        "XF86MonBrightnessDown" = "exec ${pkgs.brightnessctl}/bin/brightnessctl -c backlight set 5%-";
        "${common}+r" = "exec ${filemanager}";
        "${common}+o" = "exec ${browser}";
        "${additional}+s" = "exec ${grimshot} copy area";
        "${additional}+a" = "exec ${grimshot} copy active";
        "${additional}+e" = "exec ${grimshot} save area - | ${pkgs.swappy}/bin/swappy -f -";
        "${additional}+p" = "exec wl-uploader";
        "${common}+${additional}+Shift+Right" = "move workspace to output right";
        "${common}+${additional}+Shift+Left" = "move workspace to output left";
        "${common}+${additional}+Shift+Down" = "move workspace to output down";
        "${common}+${additional}+Shift+Up" = "move workspace to output up";
      }
      // builtins.listToAttrs (
        builtins.concatLists (
          map
            (n: [
              {
                name = "${common}+shift+${n}";
                value = "move container to workspace ${n}";
              }
              {
                name = "${common}+${n}";
                value = "workspace ${n}";
              }
            ])
            (
              builtins.attrValues workspaces
                ++ [
                "9"
                "0"
              ]
            )
        )
      );

      bindkeysToCode = true;
      workspaceOutputAssign = [
        {
          workspace = workspaces.terminal;
          output = left;
        }
        {
          workspace = workspaces.develop;
          output = right;
        }
        {
          workspace = workspaces.browser;
          output = left;
        }
        {
          workspace = workspaces.social;
          output = left;
        }
        {
          workspace = workspaces.game;
          output = right;
        }
        {
          workspace = workspaces.file;
          output = left;
        }
        {
          workspace = workspaces.private;
          output = right;
        }
      ];

      colors = lib.mkForce {
        focused = {
          border = "#00000000";
          background = "#${config.lib.stylix.colors.base0D}33";
          text = "#${config.lib.stylix.colors.base05}";
          indicator = "#${config.lib.stylix.colors.base0D}";
          childBorder = "#00000000";
        };
        focusedInactive = {
          border = "#${config.lib.stylix.colors.base03}44";
          background = "#${config.lib.stylix.colors.base03}11";
          text = "#${config.lib.stylix.colors.base05}";
          indicator = "#${config.lib.stylix.colors.base03}";
          childBorder = "#${config.lib.stylix.colors.base03}44";
        };
        unfocused = {
          border = "#${config.lib.stylix.colors.base01}22";
          background = "#${config.lib.stylix.colors.base00}00";
          text = "#${config.lib.stylix.colors.base04}";
          indicator = "#${config.lib.stylix.colors.base01}";
          childBorder = "#${config.lib.stylix.colors.base01}22";
        };
      };

    };
    extraConfig = ''
      workspace ${workspaces.terminal} output ${left}
      workspace ${workspaces.develop} output ${right}
      workspace ${workspaces.browser} output ${left}
      workspace ${workspaces.social} output ${left}
      workspace ${workspaces.game} output ${right}
      workspace ${workspaces.file} output ${left}
      workspace ${workspaces.private} output ${right}

      default_border none
      seat seat0 xcursor_theme "Adwaita" 26

      for_window [shell="xdg_shell"] title_format "%app_id: %title"
      for_window [shell="x_wayland"] title_format "%class - %title"


      bindgesture swipe:3:right workspace prev
      bindgesture swipe:3:left workspace next

      bindgesture pinch:3:outward fullscreen toggle

      bindgesture swipe:4:down kill

      bindgesture swipe:3:up exec ${pkgs.wtype}/bin/wtype -M ctrl -k t -m ctrl
      bindgesture swipe:3:down exec ${pkgs.wtype}/bin/wtype -M ctrl -k w -m ctrl

      title_align center
      titlebar_padding 10 5

      for_window [app_id="Alacritty"] blur enable
      layer_effects "mako" {
        blur enable;
        blur_ignore_transparent enable;
        shadows enable;
        corner_radius 15;
      }

      hide_edge_borders --i3 smart

      blur enable
      blur_xray disable
      blur_passes 3
      blur_radius 5
      corner_radius 0
      shadows disable

      default_border pixel 2
      default_floating_border normal 2
    '';

    extraSessionCommands = ''
      export SDL_VIDEODRIVER=wayland
      export QT_QPA_PLATFORM=wayland
      export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
      export _JAVA_AWT_WM_NONREPARENTING=1
      export MOZ_ENABLE_WAYLAND=1
    '';
  };

  home.packages = with pkgs; [
    swaybg
    sway-contrib.grimshot
    playerctl
    swappy
    wev
    (writeShellScriptBin "import-gsettings" ''
      #!/bin/sh
      config="$HOME/.config/gtk-3.0/settings.ini"
      if [ ! -f "$config" ]; then exit 1; fi
      gnome_schema="org.gnome.desktop.interface"
      gtk_theme="$(grep 'gtk-theme-name' "$config" | cut -d'=' -f2)"
      icon_theme="$(grep 'gtk-icon-theme-name' "$config" | cut -d'=' -f2)"
      cursor_theme="$(grep 'gtk-cursor-theme-name' "$config" | cut -d'=' -f2)"
      font_name="$(grep 'gtk-font-name' "$config" | cut -d'=' -f2)"
      gsettings set "$gnome_schema" gtk-theme "$gtk_theme"
      gsettings set "$gnome_schema" icon-theme "$icon_theme"
      gsettings set "$gnome_schema" cursor-theme "$cursor_theme"
      gsettings set "$gnome_schema" font-name "$font_name"
    '')
    wl-clipboard
    slurp
    wayshot
    grim
    brightnessctl
    wf-recorder
  ];

  home.sessionVariables = {
    SDL_VIDEODRIVER = "wayland";
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "sway";
  };
}

{ pkgs
, ...
}:

let
  browser = "google-chrome-stable --restore-last-session";
  terminal = "alacritty";
  bar = "waybar";
  menu = "wofi";
in
{
  wayland.windowManager.sway = {
    extraSessionCommands = ''
      export SDL_VIDEODRIVER=wayland
      export QT_QPA_PLATFORM=wayland
      export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
      export _JAVA_AWT_WM_NONREPARENTING=1
      export MOZ_ENABLE_WAYLAND=1
      export WLR_NO_HARDWARE_CURSORS=1
      export WLR_RENDERER_ALLOW_SOFTWARE=1
    '';

    enable = true;
    config = rec {
      inherit terminal;
      startup = [
        { command = terminal; }
        { command = "import-gsettings"; always = true; }
      ];
      bars = [{ command = bar; }];
      modifier = "Mod4";
    };
    wrapperFeatures.gtk = true;

    extraConfig = ''
      seat seat0 xcursor_theme "Adwaita" 26 
      set $mod Mod4
      set $comand Mod1

      set $terminal_workspace 1
      set $develop_workspace 2
      set $browser_workspace 3
      set $social_workspace 4
      set $file_workspace 5
      set $game_workspace 6
      set $work_workspace 7
      set $private_workspace 8

      # only enable this if every app you use is compatible with wayland
      xwayland enable

      ### Key bindings
      #
      # Basics:
      #
          # Start  terminal
          bindsym --to-code $mod+Return exec ${terminal}

          # Open the power menu
          # Button E
          bindsym --to-code $mod+Shift+e exec wofi-powermenu

          # Kill focused window
          # Button Q
          bindsym --to-code $mod+q kill

          # Kill window in border click middle mouse button
          bindcode 274 kill --border

          # Start your launcher
          # Button D
          bindsym --to-code $mod+d exec ${menu} -c ~/.config/wofi/config -I

          # VPN
          set $PRIVATE_VPN uncensored
          bindsym --to-code $mod+x exec nmcli-connection-switcher $PRIVATE_VPN

          set $WORK_VPN work
          bindsym --to-code $mod+c exec nmcli-connection-switcher $WORK_VPN

          # Drag floating windows by holding down $mod and left mouse button.
          # Resize them with right mouse button + $mod.
          # Despite the name, also works for non-floating windows.
          # Change normal to inverse to use left mouse button for resizing and right
          # mouse button for dragging.
          floating_modifier $mod normal

          # Reload the configuration file
          # Button C
          bindsym --to-code $mod+Shift+c reload

      #
      # Moving around:
      #
          # Move your focus around
          bindsym --to-code $mod+Left focus left
          bindsym --to-code $mod+Down focus down
          bindsym --to-code $mod+Up focus up
          bindsym --to-code $mod+Right focus right

          # Move the focused window with the same, but add Shift
          bindsym --to-code $mod+Shift+Left move left
          bindsym --to-code $mod+Shift+Down move down
          bindsym --to-code $mod+Shift+Up move up
          bindsym --to-code $mod+Shift+Right move right

      #
      # Workspaces:
      #

          # Switch to workspace
          bindsym --to-code $mod+1 workspace $terminal_workspace
          bindsym --to-code $mod+2 workspace $develop_workspace
          bindsym --to-code $mod+3 workspace $browser_workspace
          bindsym --to-code $mod+4 workspace $social_workspace
          bindsym --to-code $mod+5 workspace $file_workspace
          bindsym --to-code $mod+6 workspace $game_workspace
          bindsym --to-code $mod+7 workspace $work_workspace
          bindsym --to-code $mod+8 workspace $private_workspace
          bindsym --to-code $mod+9 workspace 9
          bindsym --to-code $mod+0 workspace 10
          # Move focused container to workspace
          bindsym --to-code $mod+Shift+1 move container to workspace $terminal_workspace
          bindsym --to-code $mod+Shift+2 move container to workspace $develop_workspace
          bindsym --to-code $mod+Shift+3 move container to workspace $browser_workspace
          bindsym --to-code $mod+Shift+4 move container to workspace $social_workspace
          bindsym --to-code $mod+Shift+5 move container to workspace $file_workspace
          bindsym --to-code $mod+Shift+6 move container to workspace $game_workspace
          bindsym --to-code $mod+Shift+7 move container to workspace $work_workspace
          bindsym --to-code $mod+Shift+8 move container to workspace $private_workspace
          bindsym --to-code $mod+Shift+9 move container to workspace number 9
          bindsym --to-code $mod+Shift+0 move container to workspace number 10
          # Note: workspaces can have any name you want, not just numbers.
          # We just use 1-10 as the default.

          bindsym --to-code $mod+$comand+Left workspace prev
          bindsym --to-code $mod+$comand+Up workspace prev

          bindsym --to-code $mod+$comand+Right workspace next
          bindsym --to-code $mod+$comand+Down workspace next

      #
      # Layout stuff:
      #
      # You can "split" the current object of your focus with
      # $mod+b or $mod+v, for horizontal and vertical splits
      # respectively.

      # Button B
      bindsym --to-code $mod+b splith
      # Button V
      bindsym --to-code $mod+v splitv

      # Switch the current container between different layout styles

      # Button S
      bindsym --to-code $mod+s layout stacking
      # Button W
      bindsym --to-code $mod+w layout tabbed
      # Button E
      bindsym --to-code $mod+e layout toggle split

      # Make the current focus fullscreen
      # Button F
      bindsym --to-code $mod+f fullscreen

      # Toggle the current focus between tiling and floating mode
      bindsym --to-code $mod+Shift+space floating toggle

      # Move focus to the parent container

      # Button A
      bindsym --to-code $mod+a focus parent

      # Resizing containers:
      #
      set $resizeLevel 20
      bindsym $mod+Ctrl+Right resize shrink width $resizeLevel px or $resizeLevel ppt
      bindsym $mod+Ctrl+Up resize grow height $resizeLevel px or $resizeLevel ppt
      bindsym $mod+Ctrl+Down resize shrink height $resizeLevel px or $resizeLevel ppt
      bindsym $mod+Ctrl+Left resize grow width $resizeLevel px or $resizeLevel ppt

      #
      # Resize floating windows with mouse scroll:
      #
      bindsym --whole-window --border $mod+button4 resize shrink height 5 px or 5 ppt
      bindsym --whole-window --border $mod+button5 resize grow height 5 px or 5 ppt
      bindsym --whole-window --border $mod+shift+button4 resize shrink width 5 px or 5 ppt
      bindsym --whole-window --border $mod+shift+button5 resize grow width 5 px or 5 ppt

      #
      # Volume
      #
      #bindsym --locked XF86AudioRaiseVolume exec pamixer --allow-boost -ui 2
      #bindsym --locked XF86AudioLowerVolume exec pamixer --allow-boost -ud 2
      #bindsym --locked XF86AudioMute exec pamixer -t

      bindsym --locked XF86AudioLowerVolume exec pactl set-sink-volume 0 -2%
      bindsym --locked XF86AudioRaiseVolume exec pactl set-sink-volume 0 +2%

      bindsym --locked XF86AudioMute exec pactl set-sink-mute 0 toggle

      #
      # Player
      #
      bindsym XF86AudioPlay exec playerctl play
      bindsym XF86AudioPause exec playerctl pause
      bindsym XF86AudioNext exec playerctl next
      bindsym XF86AudioPrev exec playerctl previous

      #
      # Backlight
      #
      bindsym XF86MonBrightnessUp exec brightnessctl -c backlight set +5%
      bindsym XF86MonBrightnessDown exec brightnessctl -c backlight set 5%-

      #
      # App shortcuts
      #
      bindsym --to-code $mod+r exec $file_manager
      bindsym --to-code $mod+o exec ${browser}

      #
      # Screenshots
      #
      bindsym --to-code $comand+s exec capture-area 
      bindsym --to-code $comand+a exec capture-all

      bindsym --to-code $comand+e exec capture-edit

      #
      # Import clipboard to https://0x0.st/
      #
      bindsym --to-code $mod+p exec wl-uploader

      #
      # Hide bar
      #
      bindsym --to-code $mod+z exec killall -SIGUSR1 ${bar}

      #
      # Move workspace to monitor
      #
      bindsym --to-code $mod+Control+Shift+Right move workspace to output right
      bindsym --to-code $mod+Control+Shift+Left move workspace to output left
      bindsym --to-code $mod+Control+Shift+Down move workspace to output down
      bindsym --to-code $mod+Control+Shift+Up move workspace to output up

      ### Input configuration

      input type:touchpad {
            dwt enabled
            tap enabled
            natural_scroll enabled
      }

      input * {
              xkb_layout us,ru
              xkb_options grp:caps_toggle
      }

      set $right 'DP-3'
      set $left 'DP-2'

      workspace $develop_workspace output $left

      workspace $social_workspace output $right
      workspace $terminal_workspace output $right
      workspace $browser_workspace output $right

      output $left {
          mode --custom 2560x1440@83Hz
          pos 0 0
      }

      output $right {
          mode --custom 1920x1080@165Hz
          pos 2560 0
          #bg ~/Pictures/hw-87d0bc3.jpg fill
      }

      # Apply gtk theming
      exec_always ~/.config/sway/scripts/import-gsettings

      # Set inner/outer gaps
      gaps inner 2
      gaps outer 0

      # Hide titlebar on windows:
      default_border pixel 1

      # Default Font
      font pango:Noto Sans Regular 10

      # Thin borders:
      smart_borders on


      # Set wallpaper:
      #exec swaybg -i ~/Pictures/hw-de7dc7a.jpg
      #exec hw -follow 1h -search-phrase galaxy

      # Title format for windows
      for_window [shell="xdg_shell"] title_format "%title (%app_id)"
      for_window [shell="x_wayland"] title_format "%class - %title"

      # #808080
      # 44475A
      # class                 border      bground     text        indicator      child_border
      client.focused          #000000     #FF000000   #ffffff     #6272A4        #6272A4
      client.focused_inactive #44475A     #44475A     #ffffff     #44475A        #44475A
      client.unfocused        #FF000000   #FF000000   #ffffff     #282A36        #282A36
      client.urgent           #44475A     #FF5555     #ffffff     #FF5555        #FF5555
      client.placeholder      #282A36     #282A36     #ffffff     #282A36        #282A36
      client.background       #ffffff

      #
      # Terminal workspace
      #
      for_window [app_id="Alacritty"] move to workspace $terminal_workspace; focus

      #
      # Browser workspace
      #
      for_window [class="Google-chrome"] move to workspace $browser_workspace; inhibit_idle fullscreen
      for_window [app_id="waterfox"] move to workspace $browser_workspace; inhibit_idle fullscreen
      for_window [app_id="firefox"] move to workspace $browser_workspace; inhibit_idle fullscreen
      for_window [class="Vivaldi-stable"] move to workspace $browser_workspace; inhibit_idle fullscreen


      #
      # File workspace
      #
      for_window [app_id="file-roller"] move to workspace $file_workspace; floating enable; focus


      #
      # Social workspace
      #

      for_window [app_id="org.telegram.desktop"] move to workspace $social_workspace; layout tabbed;
      for_window [class="TelegramDesktop"] move to workspace $social_workspace; layout tabbed;
      for_window [class="discord"] move to workspace $social_workspace; layout tabbed;
      for_window [class="VencordDesktop"] move to workspace $social_workspace; layout tabbed;
      for_window [app_id="de.shorsh.discord-screenaudio"] move to workspace $social_workspace; layout tabbed;
      for_window [class="Spotify"] move to workspace $social_workspace; layout tabbed;

      #
      # Dev workspace
      #
      assign [class="jetbrains-toolbox"] $develop_workspace
      assign [class="jetbrains-goland"] $develop_workspace
      assign [class="jetbrains-phpstorm"] $develop_workspace
      assign [class="jetbrains-pycharm"] $develop_workspace
      assign [class="jetbrains-studio"] $develop_workspace
      assign [class="jetbrains-idea"] $develop_workspace
      assign [class="jetbrains-clion"] $develop_workspace
      assign [class="jetbrains-webstorm"] $develop_workspace
      assign [class="jetbrains-fleet"] $develop_workspace

      assign [class="Code"] $develop_workspace
      assign [class="Postman"] $develop_workspace

      #
      # Game
      #
      assign [class="Steam"] $game_workspace

      #
      # Private
      #
      assign [app_id="thunderbird"] $private_workspace
      for_window [class="Simplenote"] move to workspace $private_workspace; layout tabbed;

      # Other
      for_window [app_id="xed"] focus
      for_window [title="\ -\ Sharing\ Indicator$"] floating enable, sticky enable
      for_window [title="Waterfox — индикатор доступа"] floating enable, sticky enable


      # set floating (nontiling)for apps needing it:
      for_window [class="Yad" instance="yad"] floating enable
      for_window [app_id="yad"] floating enable
      for_window [app_id="blueman-manager"] floating enable,  resize set width 40 ppt height 30 ppt
      for_window [app_id="io.bassi.Amberol"] floating enable,  resize set width 40 ppt height 30 ppt

      # set floating (nontiling) for special apps:
      for_window [class="Xsane" instance="xsane"] floating enable
      for_window [app_id="pavucontrol" ] floating enable, resize set width 40 ppt height 30 ppt
      for_window [class="qt5ct" instance="qt5ct"] floating enable, resize set width 60 ppt height 50 ppt
      for_window [class="Bluetooth-sendto" instance="bluetooth-sendto"] floating enable
      for_window [app_id="pamac-manager"] floating enable, resize set width 80 ppt height 70 ppt
      for_window [class="Lxappearance"] floating enable, resize set width 60 ppt height 50 ppt

      for_window [app_id="mpv"] floating enable, resize set width 50 ppt height 40 ppt

      # set floating for window roles
      for_window [window_role="pop-up"] floating enable
      for_window [window_role="bubble"] floating enable
      for_window [window_role="task_dialog"] floating enable
      for_window [window_role="Preferences"] floating enable
      for_window [window_type="dialog"] floating enable
      for_window [window_type="menu"] floating enable
      for_window [window_role="About"] floating enable
      for_window [title="File Operation Progress"] floating enable, border pixel 1, sticky enable, resize set width 40 ppt height 30 ppt
      for_window [app_id="firefox" title="Library"] floating enable, border pixel 1, sticky enable, resize set width 40 ppt height 30 ppt
      for_window [app_id="floating_shell_portrait"] floating enable, border pixel 1, sticky enable, resize set width 30 ppt height 40 ppt
      for_window [title="Picture in picture"] floating enable, sticky enable
      # for_window [title="nmtui"] floating enable,  resize set width 50 ppt height 70 ppt
      for_window [app_id="xsensors"] floating enable
      for_window [title="Save File"] floating enable
    '';
  };

  home.packages = with pkgs; [
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
  ];
}

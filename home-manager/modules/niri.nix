{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  grimshot = "${pkgs.sway-contrib.grimshot}/bin/grimshot";
  pactl = "${pkgs.pulseaudio}/bin/pactl";
  brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
  wallpaper = "Pictures/bryan-goff-f7YQo-eYHdM-unsplash.jpg";

  workspaceSlots =
    map (n: {
      key = toString n;
      name = "l${toString n}";
      output = osConfig.monitorNameByPosition "left";
    }) (lib.range 1 5)
    ++ map (n: {
      key = toString n;
      name = "r${toString n}";
      output = osConfig.monitorNameByPosition "right";
    }) (lib.range 6 9)
    ++ [
      {
        key = "0";
        name = "r0";
        output = osConfig.monitorNameByPosition "right";
      }
    ];

  workspaceNodes = map (slot: {
    workspace = {
      _args = [ slot.name ];
      open-on-output = slot.output;
    };
  }) workspaceSlots;

  spawnAtStartup = [
    { spawn-at-startup._args = [ "waybar" ]; }
    {
      spawn-at-startup._args = [
        "${pkgs.swaybg}/bin/swaybg"
        "-i"
        "${config.home.homeDirectory}/${wallpaper}"
      ];
    }
    { spawn-at-startup._args = [ "${pkgs.openrgb-profile}/bin/openrgb-profile" "--wait" "default" ]; }
    { spawn-at-startup._args = [ "${pkgs.keychron-backlight}/bin/keychron-backlight" "on" ]; }
  ];

  outputNodes = lib.mapAttrsToList (
    name: monitor:
    let
      position = lib.splitString " " monitor.geometry;
    in
    {
      output =
        {
          _args = [ name ];
          mode = lib.removeSuffix "Hz" monitor.mode;
          position._props = {
            x = lib.toInt (builtins.elemAt position 0);
            y = lib.toInt (builtins.elemAt position 1);
          };
        }
        // lib.optionalAttrs (monitor.transform != null) {
          transform = monitor.transform;
        };
    }
  ) osConfig.monitors;

  workspaceBinds = lib.listToAttrs (
    lib.concatMap (slot: [
      {
        name = "Mod+${slot.key}";
        value.focus-workspace = slot.name;
      }
      {
        name = "Mod+Shift+${slot.key}";
        value.move-column-to-workspace = slot.name;
      }
    ]) workspaceSlots
  );

  binds = workspaceBinds // {
    "Mod+Return".spawn = [ "foot" "--app-id=tmux-switcher" "tmux-session-switcher" ];
    "Mod+Shift+Return".spawn = [ "foot" ];
    "Mod+d".spawn = [ "wofi" ];
    "Mod+Shift+e".spawn = [ "wofi-powermenu" ];
    "Mod+q".close-window = { };
    "Mod+f".fullscreen-window = { };
    "Mod+Shift+f".maximize-column = { };
    "Mod+Shift+space".toggle-window-floating = { };
    "Mod+Shift+q".quit = { };
    "Mod+Tab".toggle-overview = { };
    "Mod+Shift+r".switch-preset-column-width = { };
    "Mod+bracketleft".focus-column-first = { };
    "Mod+bracketright".focus-column-last = { };
    "Mod+Left".focus-column-left = { };
    "Mod+Right".focus-column-right = { };
    "Mod+Up".focus-window-up = { };
    "Mod+Down".focus-window-down = { };
    "Mod+Ctrl+Left".focus-monitor-left = { };
    "Mod+Ctrl+Right".focus-monitor-right = { };
    "Mod+Ctrl+Up".focus-monitor-up = { };
    "Mod+Ctrl+Down".focus-monitor-down = { };
    "Mod+Ctrl+Shift+Left".move-workspace-to-monitor-previous = { };
    "Mod+Ctrl+Shift+Right".move-workspace-to-monitor-next = { };
    "Mod+Shift+Left".move-column-left = { };
    "Mod+Shift+Right".move-column-right = { };
    "Mod+Shift+Up".move-window-up = { };
    "Mod+Shift+Down".move-window-down = { };
    "Mod+comma".consume-window-into-column = { };
    "Mod+period".expel-window-from-column = { };
    "Mod+r".spawn = [ "thunar" ];
    "Mod+o".spawn = [ "google-chrome-stable" ];
    "Mod+z".spawn = [ "pkill" "-SIGUSR2" "-f" "^waybar" ];
    "Mod+Shift+i".power-off-monitors = { };
    "Print".spawn = [ grimshot "copy" "area" ];
    "Mod+Print".spawn = [ grimshot "copy" "active" ];
    "Mod+p".spawn = [ "wl-uploader" ];
    "Mod+Shift+p".spawn = [ "wl-uploader" "--ocr" ];
    "XF86AudioRaiseVolume".spawn = [ pactl "set-sink-volume" "@DEFAULT_SINK@" "+2%" ];
    "XF86AudioLowerVolume".spawn = [ pactl "set-sink-volume" "@DEFAULT_SINK@" "-2%" ];
    "XF86AudioMute".spawn = [ pactl "set-sink-mute" "@DEFAULT_SINK@" "toggle" ];
    "XF86AudioPlay".spawn = [ "playerctl" "play" ];
    "XF86AudioPause".spawn = [ "playerctl" "pause" ];
    "XF86AudioNext".spawn = [ "playerctl" "next" ];
    "XF86AudioPrev".spawn = [ "playerctl" "previous" ];
    "XF86MonBrightnessUp".spawn = [ brightnessctl "-c" "backlight" "set" "+5%" ];
    "XF86MonBrightnessDown".spawn = [ brightnessctl "-c" "backlight" "set" "5%-" ];
  };
in

{
  xdg.configFile = lib.mkIf osConfig.programs.niri.enable {
    "niri/config.kdl".force = true;
  };

  wayland.windowManager.niri = lib.mkIf osConfig.programs.niri.enable {
    enable = true;
    portalPackage = null;

    settings = {
      prefer-no-csd = { };

      hotkey-overlay.skip-at-startup = { };

      _children = spawnAtStartup ++ outputNodes ++ workspaceNodes;

      input = {
        keyboard.xkb = {
          layout = "us,ru";
          options = "grp:caps_toggle";
        };
        focus-follows-mouse._props.max-scroll-amount = "0%";
        touchpad = {
          tap = { };
          dwt = { };
          natural-scroll = { };
        };
      };

      layout = {
        gaps = 2;
        border = {
          width = 1;
          active-color = "#7b2cbf";
          inactive-color = "#7b2cbf";
        };
        focus-ring = {
          width = 1;
          active-color = "#c77dff";
          inactive-color = "#7b2cbf";
        };
      };

      binds = binds;
    };
  };
}

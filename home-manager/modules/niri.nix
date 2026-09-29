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

  windowRuleNodes = [
    {
      window-rule = {
        match._props.app-id = "^(foot|tmux-switcher)$";
        background-effect.blur = true;
      };
    }
  ];

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

  niriAutoWidth = pkgs.writers.writePython3 "niri-auto-width" { } ''
    import json
    import subprocess
    import sys
    import time

    NIRI = "${pkgs.niri}/bin/niri"
    POLL_INTERVAL = 0.1
    POLL_TIMEOUT = 1.5
    FULL_FRACTION = 0.95


    def niri_json(*args):
        proc = subprocess.run(
            [NIRI, "msg", "-j"] + list(args),
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            return None
        try:
            return json.loads(proc.stdout)
        except ValueError:
            return None


    def log(message):
        sys.stderr.write("niri-auto-width: %s\n" % message)
        sys.stderr.flush()


    def output_widths(outputs):
        widths = {}
        if not isinstance(outputs, dict):
            return widths
        for name, output in outputs.items():
            modes = output.get("modes") or []
            index = output.get("current_mode")
            if index is None or index >= len(modes):
                continue
            widths[name] = modes[index]["width"]
        return widths


    def workspace_of(window, workspaces):
        for candidate in workspaces:
            if candidate.get("id") == window.get("workspace_id"):
                return candidate
        return None


    def decide(window, windows, workspaces, widths, focused_id):
        if window.get("id") != focused_id:
            return False, "not focused"
        if window.get("is_floating"):
            return False, "floating"
        if window.get("is_fullscreen"):
            return False, "fullscreen"
        workspace_id = window.get("workspace_id")
        siblings = [
            w for w in windows if w.get("workspace_id") == workspace_id
        ]
        if len(siblings) != 1:
            return False, "workspace holds %d windows" % len(siblings)
        workspace = workspace_of(window, workspaces)
        if workspace is None:
            return False, "workspace not found"
        width = widths.get(workspace.get("output"))
        if not width:
            return False, "unknown output width"
        tile_width = window["layout"]["tile_size"][0]
        if tile_width >= FULL_FRACTION * width:
            return False, "already full width %s of %s" % (
                tile_width,
                width,
            )
        return True, "expanded %s of %s" % (tile_width, width)


    def wait_for_focus(window_id):
        deadline = time.monotonic() + POLL_TIMEOUT
        while True:
            focused = niri_json("focused-window")
            if focused and focused.get("id") == window_id:
                return True
            if time.monotonic() >= deadline:
                return False
            time.sleep(POLL_INTERVAL)


    def expand_column_width():
        subprocess.run(
            [NIRI, "msg", "action", "set-column-width", "100%"],
            capture_output=True,
            text=True,
        )


    def handle_new_windows(seen):
        windows = niri_json("windows")
        if windows is None:
            log("windows query failed")
            return
        pending = [w["id"] for w in windows if w["id"] not in seen]
        if not pending:
            return
        workspaces = niri_json("workspaces") or []
        widths = output_widths(niri_json("outputs"))
        for window_id in pending:
            seen.add(window_id)
            if not wait_for_focus(window_id):
                log("window %d skipped, not focused" % window_id)
                continue
            current = niri_json("windows") or []
            window = next(
                (w for w in current if w.get("id") == window_id), None
            )
            if window is None:
                log("window %d skipped, gone" % window_id)
                continue
            expand, reason = decide(
                window, current, workspaces, widths, window_id
            )
            if expand:
                expand_column_width()
            log("window %d %s" % (window_id, reason))


    def main():
        stream = subprocess.Popen(
            [NIRI, "msg", "--json", "event-stream"],
            stdout=subprocess.PIPE,
            text=True,
        )
        seen = set()
        for line in stream.stdout:
            line = line.strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except ValueError:
                continue
            if not isinstance(event, dict):
                continue
            if "WindowOpenedOrChanged" in event:
                handle_new_windows(seen)
            elif "WindowsChanged" in event:
                handle_new_windows(seen)
        log("event stream closed")
        return 1


    if __name__ == "__main__":
        sys.exit(main())
  '';

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
    "Mod+Left".focus-column-or-monitor-left = { };
    "Mod+Right".focus-column-or-monitor-right = { };
    "Mod+Up".focus-window-or-workspace-up = { };
    "Mod+Down".focus-window-or-workspace-down = { };
    "Mod+Ctrl+Left".focus-monitor-left = { };
    "Mod+Ctrl+Right".focus-monitor-right = { };
    "Mod+Ctrl+Up".focus-monitor-up = { };
    "Mod+Ctrl+Down".focus-monitor-down = { };
    "Mod+Alt+Shift+Left".move-workspace-to-monitor-previous = { };
    "Mod+Alt+Shift+Right".move-workspace-to-monitor-next = { };
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

  systemd.user.services.niri-auto-width = lib.mkIf osConfig.programs.niri.enable {
    Unit = {
      Description = "Expand a lone niri window to the full column width";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${niriAutoWidth}";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  wayland.windowManager.niri = lib.mkIf osConfig.programs.niri.enable {
    enable = true;
    portalPackage = null;

    settings = {
      prefer-no-csd = { };

      hotkey-overlay.skip-at-startup = { };

      _children = spawnAtStartup ++ outputNodes ++ workspaceNodes ++ windowRuleNodes;

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

      blur = {
        passes = 2;
        offset = 2.5;
        noise = 0.02;
        saturation = 1.2;
      };

      layout = {
        gaps = 2;
        default-column-width = {
          proportion = 0.5;
        };
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

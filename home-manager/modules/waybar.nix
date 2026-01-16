{ pkgs, osConfig, ... }:
let
  monitors = builtins.attrNames osConfig.monitors;
  first = builtins.elemAt monitors 0;
  second = if (builtins.length monitors) > 1 then builtins.elemAt monitors 1 else null;

  workspacesConfig = {
    all-outputs = false;
    disable-scroll = true;
    format = "{icon}";
    format-icons = builtins.listToAttrs (
      map (n: {
        name = n;
        value = n;
      }) (map toString (builtins.genList (x: x + 1) 8))
    );

  };
in
{
  programs.waybar = {
    enable = true;
    settings = [
      {
        output = first;
        height = 0;
        position = "top";
        modules-left = [ "sway/workspaces" ];
        modules-center = [
          "clock"

        ];
        modules-right = [
          "sway/language"
          "network"
          "custom/vpn"
          # "memory"
          # "cpu"
          "pulseaudio"
          "backlight"
          "battery"

          "tray"
        ];
        "sway/workspaces" = workspacesConfig;
        backlight = {
          format = "{icon} {percent}%";
          format-icons = [
            "🌑"
            "🌒"
            "🌓"
            "🌔"
            "🌕"
          ];
          on-scroll-down = "${pkgs.brightnessctl}/bin/brightnessctl -c backlight set 1%-";
          on-scroll-up = "${pkgs.brightnessctl}/bin/brightnessctl -c backlight set +1%";
        };
        battery = {
          format = "<span size='13000' foreground='#B1E3AD'>{icon}</span> {capacity}%";
          format-alt = "<span size='13000' foreground='#B1E3AD'>{icon}</span> {time}";
          format-charging = "<span size='13000' foreground='#B1E3AD'> </span> {capacity}%";
          format-critical = "<span size='13000' foreground='#E38C8F'>{icon}</span> {capacity}%";
          format-full = "<span size='13000' foreground='#B1E3AD'> </span> {capacity}%";
          format-icons = [
            " "
            " "
            " "
            " "
            " "
          ];
          format-plugged = "<span size='13000' foreground='#B1E3AD'> </span>{capacity}%";
          format-warning = "<span size='13000'><span foreground='#FFD700'>{icon}</span> <span foreground='#FFFFFF'> {capacity}%</span></span>";

          states = {
            critical = 10;
            warning = 40;
          };
          tooltip-format = "{time}";
        };
        clock = {
          format = "{:%a %d %H:%M}";
          tooltip-format = ''
            <big>{:%Y %B}</big>
            <tt><small>{calendar}</small></tt>'';
        };
        cpu = {
          format = "cpu {usage}%";
        };
        memory = {
          format = "mem {used:0.1f}/{total:0.1f}";
        };
        disk = {
          format = "nvme {free}/{total}";
        };
        network = {
          format = "";
          format-ethernet = "";
          format-wifi = "<span size='13000' foreground='#F2CECF'> </span>{signaldBm}";
          format-linked = "";
          format-disconnected = "no internet";
        };
        pulseaudio = {
          format = "<span size='13000' foreground='#EBDDAA'>{icon}</span> {volume}% {format_source}";
          format-bluetooth = "<span size='13000' foreground='#EBDDAA'>{icon} </span> {volume}%";
          format-icons = {
            default = [
              " "
              " "
            ];
          };
          format-muted = "<span size='14000' foreground='#EBDDAA'> </span> Muted";
          on-click = "${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle";
          on-click-middle = "${pkgs.pavucontrol}/bin/pavucontrol";
          on-scroll-up = "${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ +1%";
          on-scroll-down = "${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ -1%";
          on-click-right = "${pkgs.pulseaudio}/bin/pactl set-source-mute @DEFAULT_SOURCE@ toggle";
          format-source-muted = " ";
          format-source = "";
          ignored-sinks = [ "Easy Effects Sink" ];
        };
      }
    ]
    ++ pkgs.lib.optionals (second != null) [
      {
        output = second;
        height = 0;
        position = "top";
        modules-left = [ "sway/workspaces" ];
        "sway/workspaces" = workspacesConfig;
      }
    ];

    style = ''
      * {
          border-radius: 10px;
          font-family: 'SFProDisplay Nerd Font';
          font-size: 14pt;
          min-height: 0;
      }

      window#waybar {
          background-color: transparent;
          color: #DADAE8;
      }

      .modules-left, .modules-right {
          background-color: rgba(0, 0, 0, 0.6);
          padding: 2px 5px;
          border-radius: 20px;
          margin: 2px 5px;
      }

      #workspaces, #memory, #cpu, #clock, #pulseaudio, #network, #battery, #custom-vpn, #backlight, #language {
          background-color: transparent;
          padding: 0;
          margin: 0;
      }

      #workspaces button {
          padding: 0 5px;
          background-color: transparent;
          color: #DADAE8;
          margin: 0 2px;
      }

      #workspaces button.focused {
          color: #A4B9EF;
          background-color: transparent; 
      }

      #workspaces button:hover {
          background-color: transparent;
          color: #ffffff;
      }

      .modules-right > widget > label,
      #network, 
      #custom-vpn, 
      #memory, 
      #cpu, 
      #pulseaudio, 
      #backlight, 
      #language, 
      #battery, 
      #clock {
          margin-left: 5px;
          margin-right: 5px;
      }

      #clock { margin-right: 0; }
      #network { margin-left: 0; }
    '';

  };
}

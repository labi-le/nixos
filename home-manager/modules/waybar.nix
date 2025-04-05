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
    settings =
      [
        {
          output = first;
          height = 15;
          position = "bottom";
          modules-left = [ "sway/workspaces" ];
          modules-center = [ "custom/spotify" ];
          modules-right = [
            "network"
            "custom/vpn"
            "memory"
            "cpu"
            "pulseaudio"
            "backlight"
            "sway/language"
            "battery"
            "clock"
          ];
          "sway/workspaces" = workspacesConfig;
          backlight = {
            format = "{icon} {percent}%";
            format-icons = [
              " "
              " "
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
            format = "mem {}%";
          };
          disk = {
            format = "nvme {free}/{total}";
          };
          network = {
            format-disconnected = "";
            format-linked = "{ifname}";
            format-wifi = "<span size='13000' foreground='#F2CECF'> </span>{signaldBm}";
            tooltip-format-wifi = "Signal Strenght: {signalStrength}%";
            format-ethernet = "{ipaddr}";
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
          height = 10;
          position = "bottom";
          modules-left = [ "sway/workspaces" ];
          "sway/workspaces" = workspacesConfig;
        }
      ];
    style = ''
      * {
          border-radius: 0;
          font-family: 'Franklin Gothic Medium', 'Arial Narrow', Arial, sans-serif;
          font-size: 14pt;
          min-height: 0;
      }

      window#waybar {
          color: #DADAE8;
          background-color: rgba(0, 0, 0, 0.4);
      }

      #workspaces {
          margin-left: 5px;
          margin-top: 5px;
          margin-bottom: 5px;
          border-radius: 15px;
      }

      #workspaces button {
          padding-left: 10px;
          padding-right: 10px;
          min-width: 0;
          color: #DADAE8;
      }

      #workspaces button.focused {
          color: #A4B9EF;
      }

      #workspaces button.urgent {
          color: #F9C096;
      }

      #workspaces button:hover {
          background-color: rgba(0, 0, 0, 0);
          color: #A4B9EF;
      }

      #memory,
      #disk,
      #cpu,
      #clock,
      #battery,
      #pulseaudio,
      #backlight,
      #workspaces,
      #mpd,
      #network,
      #language,
      #network {
          padding-left: 15px;
          padding-right: 2px;
          border-radius: 15px 0px 0px 15px;
          margin-top: 5px;
          margin-bottom: 5px;
      }

      #custom-vpn {
          padding-right: 10px;
          margin-top: 5px;
          margin-bottom: 5px;
      }

      #clock {
          padding-right: 15px;
          margin-right: 5px;
          border-radius: 0px 15px 15px 0px;
      }

      #custom-spotify {
          background: #1DB954;
          color: black;
          margin-top: 5px;
          margin-bottom: 5px;
          padding-right: 15px;
          padding-left: 15px;
          border-radius: 15px;
      }

      #battery {
          background-color: rgba(0, 0, 0, 0);
      }

    '';
  };
}

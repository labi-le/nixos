{ pkgs, ... }:
let
  first = "DP-1";
  second = "DP-2";
in
{
  programs.waybar = {
    enable = true;

    settings.common.backlight = {
      format = "{icon} {percent}%";
      format-icons = [
        ""
        ""
      ];
      on-scroll-down = "${pkgs.brightnessctl}/bin/brightnessctl -c backlight set 1%-";
      on-scroll-up = "${pkgs.brightnessctl}/bin/brightnessctl -c backlight set +1%";
    };

    settings.common.battery = {
      format = "<span size='13000' foreground='#B1E3AD'>{icon}</span> {capacity}%";
      format-alt = "<span size='13000' foreground='#B1E3AD'>{icon}</span> {time}";
      format-charging = "<span size='13000' foreground='#B1E3AD'> </span>{capacity}%";
      format-critical = "<span size='13000' foreground='#E38C8F'>{icon}</span> {capacity}%";
      format-full = "<span size='13000' foreground='#B1E3AD'> </span>{capacity}%";
      format-icons = [
        ""
        ""
        ""
        ""
        ""
      ];
      format-plugged = "<span size='13000' foreground='#B1E3AD'> </span>{capacity}%";
      format-warning = "<span size='13000' foreground='#B1E3AD'>{icon}</span> {capacity}%";
      states = {
        critical = 15;
        warning = 30;
      };
      tooltip-format = "{time}";
    };

    settings.common.clock = {
      format = " {:%a %d %H:%M}";
      tooltip-format = ''
        <big>{:%Y %B}</big>
        <tt><small>{calendar}</small></tt>'';
    };

    settings.common.cpu = {
      format = "cpu {usage}%";
    };

    settings.common.position = "bottom";
    settings.common.output = second;
    settings.common.height = 15;
    settings.common.memory = {
      format = "mem {used:0.1f}/{total:0.1f}";
      #format = "mem {}%";
    };
    settings.common.modules-center = [ "custom/spotify" ];
    settings.common.modules-left = [ "sway/workspaces" ];
    settings.common.modules-right = [
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

    settings.common.network = {
      format-disconnected = "";
      format-linked = "{ifname}";
      format-wifi = "<span size='13000' foreground='#F2CECF'> </span>{signaldBm}";
      tooltip-format-wifi = "Signal Strenght: {signalStrength}%";
      format-ethernet = "{ipaddr}";
    };

    settings.common.pulseaudio = {
      format = "<span size='13000' foreground='#EBDDAA'>{icon}</span> {volume}% {format_source}";
      format-bluetooth = "<span size='13000' foreground='#EBDDAA'>{icon} </span> {volume}%";
      format-icons = {
        default = [ "" "" ];
      };
      format-muted = "<span size='14000' foreground='#EBDDAA'></span> Muted";

      on-click = "pactl set-sink-mute @DEFAULT_SINK@ toggle";
      on-click-middle = "${pkgs.pavucontrol}/bin/pavucontrol";

      on-click-right = "pactl set-source-mute @DEFAULT_SOURCE@ toggle";
      format-source-muted = "";
      format-source = "";
    };

    settings.second = {
      height = 10;
      wlr-workspaces = {
        all-outputs = true;
        disable-scroll = true;
        format = "{icon}";
        format-icons = {
          "1" = "1";
          "2" = "2";
          "3" = "3";
          "4" = "4";
          "5" = "5";
          "6" = "6";
          "7" = "7";
          "8" = "8";
        };
      };

      position = "bottom";
      output = first;
      modules-left = [ "sway/workspaces" ];
    };

    settings.common.wlr-workspaces = {
      all-outputs = true;
      disable-scroll = true;
      format = "{icon}";
      format-icons = {
        "1" = "1";
        "2" = "2";
        "3" = "3";
        "4" = "4";
        "5" = "5";
        "6" = "6";
        "7" = "7";
        "8" = "8";
      };
    };

    style = ''
      * {
          border-radius: 0;
          font-family: 'Franklin Gothic Medium', 'Arial Narrow', Arial, sans-serif;
          font-size: 14pt;
          min-height: 0;
      }

      window#waybar {
          color: #DADAE8;
          background-color: rgba(0, 0, 0, 0);
      }

      /* tooltip {
              border-radius: 15px;
              border-width: 2px;
          border-style: solid;
              border-color: #a4b9ef;
              } */

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
          /* background: #332e41; */
          background-color: rgba(0, 0, 0, 0);
              color: #A4B9EF;
      }
      
      #memory,
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
          /* background: #332E41; */
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
    '';
  };
}

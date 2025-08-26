{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.audio;
in
{
  options.audio = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable sound configuration";
    };

    lowLatency = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable low latency audio settings";
    };
  };

  config = lib.mkIf cfg.enable {
    security.rtkit.enable = true;

    musnix = {
      enable = true;
      rtcqs.enable = true;
    };

    services.pipewire = {
      enable = true;
      pulse.enable = true;
      jack.enable = false;

      extraConfig.pipewire = lib.mkMerge [
        {
          "99-disable-bell" = {
            "context.properties" = {
              "module.x11.bell" = false;
            };
          };
        }
        (lib.mkIf cfg.lowLatency {
          "99-lowlatency" = {
            "context.properties" = {
              "default.clock.quantum" = 64;
              "default.clock.min-quantum" = 64;
              "default.clock.max-quantum" = 128;
              "default.clock.force-quantum" = 64;
            };
          };
        })
      ];
    };

    environment.systemPackages = with pkgs; [
      pulseaudio
      alsa-utils
      qpwgraph
      alsa-scarlett-gui

      pavucontrol
    ];

    services.actkbd =
      let
        alsa-utils = pkgs.alsa-utils;
        volumeStep = "1%";
      in
      {
        enable = true;
        bindings = [
          {
            keys = [ 113 ];
            events = [ "key" ];
            command = "${alsa-utils}/bin/amixer -q set Master toggle";
          }
          {
            keys = [ 114 ];
            events = [
              "key"
              "rep"
            ];
            command = "${alsa-utils}/bin/amixer -q set Master ${volumeStep}- unmute";
          }
          {
            keys = [ 115 ];
            events = [
              "key"
              "rep"
            ];
            command = "${alsa-utils}/bin/amixer -q set Master ${volumeStep}+ unmute";
          }
          {
            keys = [ 190 ];
            events = [ "key" ];
            command = "${alsa-utils}/bin/amixer -q set Capture toggle";
          }
        ];
      };
  };
}

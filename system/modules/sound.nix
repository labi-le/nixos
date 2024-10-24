{ pkgs, ... }:

{
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    jack.enable = false;
    extraConfig.pipewire = {
      "99-disable-bell" = {
        "context.properties" = {
          "module.x11.bell" = false;
        };
      };
      "99-lowlatency" = {
        "context.properties" = {
          "default.clock.quantum" = 64;
          "default.clock.min-quantum" = 64;
          "default.clock.max-quantum" = 64;
          "default.clock.force-quantum" = 64;
        };
      };
    };
  };

  environment.systemPackages = with pkgs; [ pulseaudio pipecontrol ];

  services.actkbd =
    let
      alsa-utils = pkgs.alsa-utils;
      volumeStep = "1%";
    in
    {
      enable = true;
      bindings = [
        # "Mute" media key
        { keys = [ 113 ]; events = [ "key" ]; command = "${alsa-utils}/bin/amixer -q set Master toggle"; }
        # "Lower Volume" media key
        { keys = [ 114 ]; events = [ "key" "rep" ]; command = "${alsa-utils}/bin/amixer -q set Master ${volumeStep}- unmute"; }
        # "Raise Volume" media key
        { keys = [ 115 ]; events = [ "key" "rep" ]; command = "${alsa-utils}/bin/amixer -q set Master ${volumeStep}+ unmute"; }
        # "Mic Mute" media key
        { keys = [ 190 ]; events = [ "key" ]; command = "${alsa-utils}/bin/amixer -q set Capture toggle"; }
      ];
    };
}


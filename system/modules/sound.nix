{ pkgs, ... }:

{
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };


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


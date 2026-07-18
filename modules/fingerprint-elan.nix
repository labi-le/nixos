{ pkgs, ... }:

{
  services.fprintd = {
    enable = true;
    tod = {
      enable = true;
      driver = pkgs.libfprint-2-tod1-elan;
    };
  };

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="04f3", ATTR{idProduct}=="0c4b", ATTR{power/control}="on"
  '';
}

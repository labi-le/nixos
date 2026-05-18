{ ... }:
{
  hardware.xpadneo.enable = true;

  # https://steamcommunity.com/sharedfiles/filedetails/?id=3608372415
  services.udev.extraRules = ''
    KERNEL=="event*", SUBSYSTEM=="input", ENV{ID_VENDOR_ID}=="3434", ENV{ID_INPUT_JOYSTICK}=="*?", ENV{ID_INPUT_JOYSTICK}=""
  '';
}

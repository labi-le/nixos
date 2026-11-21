{ pkgs, ... }:

let
  mini-racer = pkgs.home-assistant.python3Packages.callPackage ./mini-racer.nix { };
  dreame-vacuum = pkgs.callPackage ./dreame-vacuum.nix {
    python3Packages = pkgs.home-assistant.python3Packages;
    inherit mini-racer;
  };
in
{
  services.home-assistant = {
    enable = true;
    configDir = "/drive/state/home-assistant";
    customComponents = [ dreame-vacuum ];
    extraComponents = [
      "default_config"
      "met"
      "esphome"
      "google_translate"
    ];

    config = {
      homeassistant = {
        name = "Home";
        unit_system = "metric";
        time_zone = "Europe/Moscow";
      };

      default_config = { };
    };
  };

  systemd.services.home-assistant.unitConfig.RequiresMountsFor = [ "/drive/state" ];

  systemd.tmpfiles.rules = [
    "d /drive/state/home-assistant 0700 hass hass -"
    "d /drive/state/home-assistant/blueprints 0755 hass hass -"
  ];
}

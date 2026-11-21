{ pkgs, ... }:

let
  mini-racer = pkgs.home-assistant.python3Packages.callPackage ./mini-racer.nix { };
  dreame-vacuum = pkgs.callPackage ./dreame-vacuum.nix {
    python3Packages = pkgs.home-assistant.python3Packages;
    inherit mini-racer;
  };
  tuya-local = pkgs.home-assistant-custom-components.tuya_local.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      install -Dm644 ${./etop-ht-7x6prg.yaml} $out/custom_components/tuya_local/devices/etop_ht_7x6prg_33cc.yaml
    '';
  });
in
{
  services.home-assistant = {
    enable = true;
    configDir = "/drive/state/home-assistant";
    customComponents = [
      dreame-vacuum
      tuya-local
    ];
    extraComponents = [
      "default_config"
      "met"
      "esphome"
      "google_translate"
      "tuya"
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

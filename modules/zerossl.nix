{
  config,
  lib,
  ...
}:

let
  certNames = builtins.attrNames config.security.acme.certs;
  acmeServiceNames = builtins.concatMap (cert: [
    "acme-${cert}"
    "acme-order-renew-${cert}"
    "acme-renew-${cert}"
  ]) certNames;
in
{
  age.secrets.zerossl = {
    file = ../secrets/zerossl.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "i@labile.cc";
      server = "https://acme.zerossl.com/v2/DV90";
      extraLegoFlags = [ "--eab" ];
    };
  };

  systemd.services = lib.mkMerge [
    (lib.genAttrs acmeServiceNames (name: {
      serviceConfig = {
        EnvironmentFile = [ config.age.secrets.zerossl.path ];
      }
      // lib.optionalAttrs (lib.hasPrefix "acme-order-renew-" name) {
        Restart = "on-failure";
      };
    }))
    (lib.listToAttrs (
      map (cert: {
        name = "acme-${cert}";
        value.restartTriggers = [
          (builtins.hashString "sha256" (
            builtins.toJSON config.systemd.services."acme-order-renew-${cert}".serviceConfig
          ))
        ];
      }) certNames
    ))
  ];
}

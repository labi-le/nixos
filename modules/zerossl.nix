{
  config,
  lib,
  ...
}:

let
  certNames = builtins.attrNames config.security.acme.certs;
  acmeServiceNames = builtins.concatMap (
    cert: [
      "acme-${cert}"
      "acme-renew-${cert}"
    ]
  ) certNames;
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

  systemd.services = lib.genAttrs acmeServiceNames (_: {
    serviceConfig.EnvironmentFile = [ config.age.secrets.zerossl.path ];
  });
}

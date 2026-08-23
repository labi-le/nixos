{
  lib,
  ...
}:

let
  host = "git.labile.cc";
  port = 3150;
in
{
  services.forgejo = {
    enable = true;
    lfs.enable = true;
    settings = {
      DEFAULT.APP_NAME = "labile forge";
      server = {
        DOMAIN = host;
        ROOT_URL = "https://${host}";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = port;
      };
      service.DISABLE_REGISTRATION = true;
      session.COOKIE_SECURE = true;
      actions.ENABLED = true;
      actions.DEFAULT_ACTIONS_URL = "github";
    };
  };

  security.acme.certs."git.labile.cc" = {
    server = "https://acme-v02.api.letsencrypt.org/directory";
    extraLegoFlags = lib.mkForce [ ];
  };
}

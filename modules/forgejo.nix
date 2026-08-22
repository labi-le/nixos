{
  config,
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

  users.groups.gitea-runner = { };
  users.users.gitea-runner = {
    isSystemUser = true;
    group = "gitea-runner";
  };

  age.secrets.forgejo-runner-token = {
    file = ../secrets/forgejo-runner-token.age;
    mode = "0440";
    group = "gitea-runner";
  };

  services.gitea-actions-runner.instances.git = {
    enable = true;
    name = "git";
    url = "https://${host}";
    tokenFile = config.age.secrets.forgejo-runner-token.path;
    labels = [
      "ubuntu-latest:docker://ghcr.io/catthehacker/ubuntu:act-latest"
      "ubuntu-22.04:docker://ghcr.io/catthehacker/ubuntu:act-latest"
      "ubuntu-24.04:docker://ghcr.io/catthehacker/ubuntu:act-24.04"
    ];
  };
}

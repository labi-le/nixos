{
  config,
  pkgs,
  ...
}:

let
  tag = "v18.8.9";
  botLogin = "int8-ptr";
  botId = "126324301";
  host = "buer.labile.cc";
  bindPort = 6543;
  dataDir = "/drive/state/buer";
  repoAllowlist = "labi-le/murmur";
  maintainerLogins = "labi-le";
  model = "llm-labile/deepseek-v4.1-flash";

  src = pkgs.fetchFromGitHub {
    owner = "can1357";
    repo = "oh-my-pi";
    tag = tag;
    hash = "sha256-t3OZP4E0mWFJU0RW3OMcGU2G52p5uasQdVPhITHnZec=";
  };

  piImage = "oh-my-pi/pi:${tag}";
  botImage = "robomp:${tag}";

  modelsYml = (pkgs.formats.yaml { }).generate "buer-models.yml" {
    providers."llm-labile" = {
      baseUrl = "http://litellm:4000/v1";
      api = "openai-completions";
      apiKey = "ROBOMP_LITELLM_KEY";
      discovery.type = "litellm";
    };
  };

  composeEnv = pkgs.writeText "buer.env" ''
    BUER_IMAGE=${botImage}
    BUER_SRC=${src}
    BUER_DATA=${dataDir}
    BUER_MODELS=${modelsYml}
    BUER_AGENTS_MD=${./agent-AGENTS.md}
    BUER_BIND_PORT=${toString bindPort}
    ROBOMP_BOT_LOGIN=${botLogin}
    ROBOMP_GIT_AUTHOR_NAME=${botLogin}
    ROBOMP_GIT_AUTHOR_EMAIL=${botId}+${botLogin}@users.noreply.github.com
    ROBOMP_REPO_ALLOWLIST=${repoAllowlist}
    ROBOMP_MAINTAINER_LOGINS=${maintainerLogins}
    ROBOMP_MODEL=${model}
    ROBOMP_THINKING=high
    ROBOMP_MAX_CONCURRENCY=2
  '';

  compose = "${pkgs.docker-compose}/bin/docker-compose --file ${./docker-compose.yml}";
in
{
  age.secrets.buer-env = {
    file = ../../secrets/buer-env.age;
    mode = "0400";
  };

  systemd.services.buer-images = {
    description = "Build the buer container images (upstream robomp ${tag})";
    after = [
      "docker.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.docker
      pkgs.coreutils
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "infinity";
      RequiresMountsFor = [ "/drive/state" ];
    };
    script = ''
      set -euo pipefail
      install -d -m 0755 ${dataDir}
      marker=${dataDir}/image-rev
      want='${src}|${piImage}|${botImage}'
      if [ -r "$marker" ] && [ "$(cat "$marker")" = "$want" ]; then
        exit 0
      fi
      docker build --tag ${piImage} --file ${src}/Dockerfile ${src}
      docker build --tag ${botImage} --file ${src}/Dockerfile.robomp --build-arg PI_BASE=${piImage} ${src}
      printf '%s' "$want" > "$marker"
    '';
  };

  systemd.services.buer = {
    description = "buer — GitHub triage and pull-request bot (upstream robomp ${tag})";
    after = [
      "docker.service"
      "docker-litellm.service"
      "docker-network-litellm.service"
      "buer-images.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    requires = [
      "docker.service"
      "docker-network-litellm.service"
      "buer-images.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "infinity";
      WorkingDirectory = dataDir;
      RequiresMountsFor = [ "/drive/state" ];
      EnvironmentFile = [
        composeEnv
        config.age.secrets.buer-env.path
      ];
      ExecStart = "${compose} up --detach --remove-orphans";
      ExecStop = "${compose} down";
    };
  };

  services.nginx.virtualHosts.${host} = {
    enableACME = true;
    forceSSL = true;
    kTLS = true;
    locations."/webhook/github" = {
      proxyPass = "http://127.0.0.1:${toString bindPort}";
      extraConfig = ''
        proxy_read_timeout 30s;
        proxy_send_timeout 30s;
      '';
    };
    locations."/".return = "404";
  };
}

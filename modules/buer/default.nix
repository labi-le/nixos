{
  config,
  pkgs,
  ...
}:

let
  tag = "v18.8.9";
  botLogin = "int8-ptr";
  botId = "126324301";
  bindPort = 6543;
  dataDir = "/drive/state/buer";
  repoAllowlist = "labi-le/murmur";
  maintainerLogins = "labi-le";
  reviewerBots = "chatgpt-codex-connector";
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
    BUER_DATA=${dataDir}
    BUER_MODELS=${modelsYml}
    BUER_AGENTS_MD=${./agent-AGENTS.md}
    BUER_BIND_PORT=${toString bindPort}
    ROBOMP_BOT_LOGIN=${botLogin}
    ROBOMP_GIT_AUTHOR_NAME=${botLogin}
    ROBOMP_GIT_AUTHOR_EMAIL=${botId}+${botLogin}@users.noreply.github.com
    ROBOMP_REPO_ALLOWLIST=${repoAllowlist}
    ROBOMP_MAINTAINER_LOGINS=${maintainerLogins}
    ROBOMP_REVIEWER_BOTS=${reviewerBots}
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

  systemd.services.buer-replay-token = {
    description = "Per-boot dashboard token for buer (trigger, cancel, replay)";
    wantedBy = [ "multi-user.target" ];
    before = [ "buer.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "buer";
      ExecStart = "${pkgs.writeShellScript "buer-replay-token" ''
        umask 077
        printf 'ROBOMP_REPLAY_TOKEN=%s\n' "$(${pkgs.openssl}/bin/openssl rand -hex 32)" > /run/buer/replay-token.env
      ''}";
    };
  };

  systemd.services.buer = {
    description = "buer — GitHub triage and pull-request bot (upstream robomp ${tag})";
    after = [
      "docker.service"
      "docker-litellm.service"
      "docker-network-litellm.service"
      "buer-images.service"
      "network-online.target"
      "buer-replay-token.service"
    ];
    wants = [ "network-online.target" ];
    requires = [
      "docker.service"
      "docker-network-litellm.service"
      "buer-images.service"
      "buer-replay-token.service"
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
        "/run/buer/replay-token.env"
      ];
      ExecStart = "${compose} up --detach --remove-orphans";
      ExecStop = "${compose} down";
    };
    restartTriggers = [
      (builtins.hashFile "sha256" ../../secrets/buer-env.age)
    ];
  };
}

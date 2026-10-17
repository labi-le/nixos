{
  config,
  lib,
  pkgs,
  ...
}:

let
  tag = "v18.10.0";
  botLogin = "int8-ptr";
  botId = "126324301";
  bindPort = 6543;
  dataDir = "/drive/state/buer";
  repoAllowlist = "labi-le/murmur,labi-le/sub-preprocessor";
  maintainerLogins = "labi-le";
  reviewerBots = "chatgpt-codex-connector";
  reviewerBotLogin = "${reviewerBots}[bot]";
  model = "llm-labile/deepseek-v4.1-flash";
  maxConcurrency = 2;
  toolchainNixpkgs = pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "9ae611a455b90cf061d8f332b977e387bda8e1ca";
    hash = "sha256-md8WlXOlfnIeHeOScMTTHFyf2d6iaTwPl2apR5EQ3P4=";
  };
  toolchainPkgs = import toolchainNixpkgs { system = pkgs.stdenv.hostPlatform.system; };
  toolchainShell = toolchainPkgs.mkShell {
    packages = with toolchainPkgs; [
      go
      gcc
      gopls
      gnumake
      golangci-lint
      goreleaser
    ];
  };
  toolchainClosure = pkgs.closureInfo {
    rootPaths = [
      toolchainNixpkgs
      toolchainShell
      toolchainPkgs.nix
      toolchainPkgs.bash
      toolchainPkgs.coreutils
      toolchainPkgs.cacert
    ];
  };
  nixConfig = pkgs.writeText "buer-nix.conf" ''
    build-users-group = nixbld
    sandbox = false
    allowed-users = root ${lib.concatMapStringsSep " " (n: "omp-${toString n}") (lib.range 1 maxConcurrency)}
    trusted-users = root
    max-jobs = 1
    cores = 2
    experimental-features = nix-command flakes
    accept-flake-config = false
    substituters = https://cache.nixos.org
    trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
  '';
  daemonPasswd = pkgs.writeText "buer-nix-passwd" (
    "root:x:0:0::/root:/bin/sh\n"
    + lib.concatMapStrings (n: "omp-${toString n}:x:${toString (2000 + n)}:${toString (2000 + n)}::/var/empty:/bin/false\n") (lib.range 1 maxConcurrency)
    + lib.concatMapStrings (n: "nixbld${toString n}:x:${toString (30000 + n)}:30000::/var/empty:/bin/false\n") (lib.range 1 2)
  );
  daemonGroup = pkgs.writeText "buer-nix-group" (
    "root:x:0:\nnixbld:x:30000:nixbld1,nixbld2\n"
    + lib.concatMapStrings (n: "omp-${toString n}:x:${toString (2000 + n)}:\n") (lib.range 1 maxConcurrency)
  );
  nixShellWrapper = pkgs.writeText "buer-nix-shell" ''
    #!/bin/bash
    set -euo pipefail
    if [ "$(id -u)" -ne 0 ]; then
      : "''${XDG_DATA_HOME:?robomp workspace environment is required}"
      : "''${XDG_CACHE_HOME:?robomp workspace environment is required}"
      export GOPATH="$XDG_DATA_HOME/go"
      export GOCACHE="$XDG_CACHE_HOME/go-build"
    fi
    exec ${toolchainPkgs.nix}/bin/nix-shell "$@"
  '';
  toolchainDockerfile = pkgs.writeText "Dockerfile.buer-toolchain" ''
    ARG ROBOMP_BASE
    FROM ''${ROBOMP_BASE} AS worker
    COPY store/ /nix/store/
    COPY registration /tmp/nix-registration
    COPY nix.conf /etc/nix/nix.conf
    COPY nix-shell /usr/local/bin/nix-shell
    COPY daemon-root/ /buer-daemon-root/
    ENV PATH=/usr/local/bin:${toolchainPkgs.nix}/bin:$PATH \
        NIX_PATH=nixpkgs=${toolchainNixpkgs} \
        NIX_REMOTE=daemon \
        NIX_SSL_CERT_FILE=${toolchainPkgs.cacert}/etc/ssl/certs/ca-bundle.crt
    RUN mkdir -p /nix/var/nix/daemon-socket /nix/var/nix/gcroots /nix/var/nix/profiles \
        && NIX_REMOTE=local nix-store --load-db < /tmp/nix-registration \
        && rm /tmp/nix-registration \
        && chown 0:30000 /nix/store \
        && chmod 1775 /nix/store \
        && chmod 0755 /nix/var/nix/daemon-socket
    RUN chmod 0755 /usr/local/bin/nix-shell \
        && chmod 1777 /buer-daemon-root/tmp
    FROM scratch AS daemon
    COPY --from=worker /nix /nix
    COPY nix.conf /etc/nix/nix.conf
    COPY passwd /etc/passwd
    COPY group /etc/group
    COPY --from=worker /buer-daemon-root/ /
    ENV PATH=${toolchainPkgs.nix}/bin:${toolchainPkgs.coreutils}/bin:${toolchainPkgs.bash}/bin \
        NIX_SSL_CERT_FILE=${toolchainPkgs.cacert}/etc/ssl/certs/ca-bundle.crt \
        HOME=/root \
        TMPDIR=/tmp
    ENTRYPOINT ["${toolchainPkgs.nix}/bin/nix-daemon"]
  '';
  toolchainContext = pkgs.runCommand "buer-toolchain-context" { } ''
    mkdir -p $out/store $out/daemon-root/bin $out/daemon-root/tmp $out/daemon-root/root $out/daemon-root/var/empty
    chmod 1777 $out/daemon-root/tmp
    while IFS= read -r storePath; do
      cp -a --no-preserve=ownership "$storePath" $out/store/
    done < ${toolchainClosure}/store-paths
    cp ${toolchainClosure}/registration $out/registration
    cp ${nixConfig} $out/nix.conf
    cp ${daemonPasswd} $out/passwd
    cp ${daemonGroup} $out/group
    cp ${nixShellWrapper} $out/nix-shell
    cp ${toolchainDockerfile} $out/Dockerfile
    ln -s ${toolchainPkgs.bash}/bin/bash $out/daemon-root/bin/sh
    ln -s ${toolchainPkgs.coreutils}/bin/false $out/daemon-root/bin/false
  '';
  toolchainRevision = builtins.substring 0 12 (builtins.hashString "sha256" "${toolchainContext}|${robompSource}");

  src = pkgs.fetchFromGitHub {
    owner = "can1357";
    repo = "oh-my-pi";
    tag = tag;
    hash = "sha256-2ql/3YrFfEycm7JrC7fshlauNYfuFo/W7gBEEMMc0XA=";
  };

  piImage = "oh-my-pi/pi:${tag}";
  upstreamBotImage = "robomp:${tag}-policy-${builtins.substring 0 12 (builtins.hashString "sha256" (toString robompSource))}";
  botImage = "robomp:${tag}-nix-${toolchainRevision}";
  daemonImage = "robomp-nix:${tag}-${toolchainRevision}";

  robompSource = pkgs.runCommand "robomp-src-${tag}-500k-local-logs" { } ''
    cp -r --no-preserve=mode,ownership ${src}/. $out/
    ${pkgs.patch}/bin/patch --directory="$out" -p1 < ${./empty-pr-body.patch}
    ${pkgs.gnused}/bin/sed -i 's/max_event_history=50_000/max_event_history=500_000/' $out/python/robomp/src/worker.py
    ${pkgs.gnugrep}/bin/grep -q 'max_event_history=500_000' $out/python/robomp/src/worker.py
    ${pkgs.gnused}/bin/sed -i 's/time\.strftime("%H:%M:%S", time\.gmtime(record\.created))/time.strftime("%H:%M:%S", time.localtime(record.created))/' $out/python/robomp/src/logging_config.py
    ${pkgs.gnugrep}/bin/grep -q 'time.strftime("%H:%M:%S", time.localtime(record.created))' $out/python/robomp/src/logging_config.py
    ${pkgs.gnugrep}/bin/grep -q 'time.gmtime(record.created)' $out/python/robomp/src/logging_config.py
  '';

  humanizerSrc = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/databasus/databasus/bda7237599756ba76401b29e9761b07206e38bd6/.agents/skills/humanizer/SKILL.md";
    hash = "sha256-fDpFzjSCLTnVs0d08TwQsU2ent9I6EJ9n7/vg/Mt7LA=";
  };
  humanizerSkill = pkgs.runCommand "humanizer-skill" { } ''
    mkdir -p $out
    cp ${humanizerSrc} $out/SKILL.md
  '';

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
    BUER_PROXY_IMAGE=${upstreamBotImage}
    BUER_NIX_IMAGE=${daemonImage}
    BUER_NIX_VOLUME=buer-nix-${toolchainRevision}
    BUER_DATA=${dataDir}
    BUER_MODELS=${modelsYml}
    BUER_AGENTS_MD=${./agent-AGENTS.md}
    BUER_HUMANIZER_SKILL=${humanizerSkill}
    BUER_BIND_PORT=${toString bindPort}
    ROBOMP_BOT_LOGIN=${botLogin}
    ROBOMP_GIT_AUTHOR_NAME=${botLogin}
    ROBOMP_GIT_AUTHOR_EMAIL=${botId}+${botLogin}@users.noreply.github.com
    ROBOMP_REPO_ALLOWLIST=${repoAllowlist}
    ROBOMP_MAINTAINER_LOGINS=${maintainerLogins}
    ROBOMP_REVIEWER_BOTS=${reviewerBots}
    ROBOMP_RATE_LIMIT_UNLIMITED=${reviewerBotLogin}
    ROBOMP_MODEL=${model}
    ROBOMP_THINKING=high
    ROBOMP_MAX_CONCURRENCY=${toString maxConcurrency}
    ROBOMP_RATE_LIMIT_DEFAULT=10
    TZ=${config.time.timeZone}
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
    unitConfig.RequiresMountsFor = [ "/drive/state" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "infinity";
    };
    script = ''
      set -euo pipefail
      install -d -m 0755 ${dataDir}
      marker=${dataDir}/image-rev
      want='${src}|${robompSource}|${piImage}|${upstreamBotImage}|${toolchainContext}|${botImage}|${daemonImage}'
      if [ -r "$marker" ] && [ "$(cat "$marker")" = "$want" ]; then
        exit 0
      fi
      docker build --tag ${piImage} --file ${src}/Dockerfile ${src}
      docker build --tag ${upstreamBotImage} --file ${robompSource}/Dockerfile.robomp --build-arg PI_BASE=${piImage} ${robompSource}
      docker build --target worker --tag ${botImage} --build-arg ROBOMP_BASE=${upstreamBotImage} ${toolchainContext}
      docker build --target daemon --tag ${daemonImage} --build-arg ROBOMP_BASE=${upstreamBotImage} ${toolchainContext}
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
    unitConfig.RequiresMountsFor = [ "/drive/state" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "infinity";
      WorkingDirectory = dataDir;
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
      (builtins.hashFile "sha256" composeEnv)
    ];
  };

  systemd.services.buer-watchdog = {
    description = "buer delivery watchdog — replay GitHub hook deliveries the webhook never received";
    after = [ "buer.service" ];
    requires = [ "buer.service" ];
    unitConfig.RequiresMountsFor = [ "/drive/state" ];
    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "buer-watch";
      StateDirectoryMode = "0700";
      EnvironmentFile = config.age.secrets.buer-env.path;
      Environment = [
        "WATCH_REPOS=${repoAllowlist}"
        "WATCH_ENDPOINT=http://127.0.0.1:${toString bindPort}/webhook/github"
        "WATCH_DB=${dataDir}/robomp.sqlite"
        "WATCH_STATE_DIR=/var/lib/buer-watch"
      ];
      ExecStart = "${pkgs.python3}/bin/python3 ${./watchdog.py} --lookback 3900 --retry-after 900";
    };
  };

  systemd.timers.buer-watchdog = {
    description = "Poll GitHub hook deliveries for transport losses every three minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "3min";
      OnUnitActiveSec = "3min";
      AccuracySec = "30s";
      Persistent = false;
    };
  };
}

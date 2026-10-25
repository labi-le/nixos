{
  config,
  lib,
  pkgs,
  telegramSecret,
}:

let
  chromaPort = 8931;
  telegramPort = 8932;
  telegramRemoteUrl = "http://192.168.1.2:${toString telegramPort}/mcp";

  chromaCommand = pkgs.writeShellScript "omp-chroma-mcp" ''
    exec ${pkgs.uv}/bin/uvx --from chroma-mcp \
      --with 'pydantic<2.14' \
      --with 'chromadb==${config.services.chromadb.package.version}' \
      python -c '
    import functools
    import sys
    import chroma_mcp.server as server

    server.print = functools.partial(print, file=sys.stderr)
    server.main()
    ' \
      --client-type http \
      --host ${config.services.index-repo.host} \
      --port ${toString config.services.index-repo.port} \
      --ssl ${lib.boolToString config.services.index-repo.ssl}
  '';

  chromaProxyCommand = pkgs.writeShellScript "omp-chroma-mcp-proxy" ''
    exec ${pkgs.mcp-proxy}/bin/mcp-proxy \
      --host 127.0.0.1 \
      --port ${toString chromaPort} \
      --transport streamablehttp \
      -- ${chromaCommand}
  '';

  telegramCommand = pkgs.writeShellScript "omp-telegram-mcp" ''
    set -euo pipefail
    set -a
    source /run/agenix/telegram-mcp
    set +a
    export TELEGRAM_SESSION_LOCK=shared
    export MCP_TRANSPORT=http
    export MCP_HOST=0.0.0.0
    export MCP_PORT=${toString telegramPort}
    export MCP_ALLOWED_HOSTS="127.0.0.1:${toString telegramPort},localhost:${toString telegramPort},192.168.1.2:${toString telegramPort}"
    exec ${pkgs.uv}/bin/uvx --from \
      'git+https://github.com/labi-le/telegram-mcp.git@f086f7a8276fa4dcf368fa7eea7d918e5cd5ed72' \
      telegram-mcp
  '';

  mcpJson = pkgs.writeText "mcp.json" (
    builtins.toJSON {
      "$schema" =
        "https://raw.githubusercontent.com/can1357/oh-my-pi/main/packages/coding-agent/src/config/mcp-schema.json";
      mcpServers = {
        chroma = {
          type = "http";
          url = "http://127.0.0.1:${toString chromaPort}/mcp";
        };
        context7 = {
          type = "http";
          url = "https://mcp.context7.com/mcp";
        };
        telegram = {
          type = "http";
          url =
            if telegramSecret != null then
              "http://127.0.0.1:${toString telegramPort}/mcp"
            else
              telegramRemoteUrl;
        };
      };
    }
  );

  services = {
    omp-mcp-chroma = {
      description = "OMP Chroma MCP server";
      wantedBy = [ "default.target" ];
      after = [ "network-online.target" ];
      unitConfig.StartLimitIntervalSec = 0;
      serviceConfig = {
        ExecStart = "${chromaProxyCommand}";
        Restart = "always";
        RestartSec = 3;
      };
    };
  }
  // lib.optionalAttrs (telegramSecret != null) {
    omp-mcp-telegram = {
      description = "OMP Telegram MCP server";
      wantedBy = [ "default.target" ];
      after = [ "network-online.target" ];
      path = [ pkgs.git ];
      unitConfig.StartLimitIntervalSec = 0;
      serviceConfig = {
        ExecStart = "${telegramCommand}";
        Restart = "always";
        RestartSec = 5;
      };
    };
  };
in
{
  inherit
    mcpJson
    telegramCommand
    telegramPort
    services
    ;
}

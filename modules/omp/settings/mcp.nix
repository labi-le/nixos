{
  config,
  lib,
  pkgs,
  telegramSecret,
}:

let
  telegramCommand = pkgs.writeShellScript "omp-telegram-mcp" ''
    set -euo pipefail
    set -a
    source /run/agenix/telegram-mcp
    set +a
    export TELEGRAM_SESSION_LOCK=shared
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
          type = "stdio";
          command = "uvx";
          args = [
            "--from"
            "chroma-mcp"
            "--with"
            "pydantic<2.14"
            "--with"
            "chromadb==${config.services.chromadb.package.version}"
            "python"
            "-c"
            ''
              import functools
              import sys
              import chroma_mcp.server as server

              server.print = functools.partial(print, file=sys.stderr)
              server.main()
            ''
            "--client-type"
            "http"
            "--host"
            config.services.index-repo.host
            "--port"
            (toString config.services.index-repo.port)
            "--ssl"
            (lib.boolToString config.services.index-repo.ssl)
          ];
        };
        context7 = {
          type = "http";
          url = "https://mcp.context7.com/mcp";
        };
      }
      // lib.optionalAttrs (telegramSecret != null) {
        telegram = {
          type = "stdio";
          command = "${telegramCommand}";
        };
      };
    }
  );
in
{
  inherit mcpJson telegramCommand;
}

{ config, lib, pkgs }:

let
  toml = pkgs.formats.toml { };

  chromaScript = ''
    import functools
    import sys
    import chroma_mcp.server as server

    server.print = functools.partial(print, file=sys.stderr)
    server.main()
  '';

  telegramSecret = config.age.secrets.telegram-mcp or null;

  servers = {
    chroma = {
      command = [
        "${pkgs.uv}/bin/uvx"
        "--from"
        "chroma-mcp"
        "--with"
        "pydantic<2.14"
        "--with"
        "chromadb==${config.services.chromadb.package.version}"
        "python"
        "-c"
        chromaScript
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
      url = "https://mcp.context7.com/mcp";
    };
  }
  // lib.optionalAttrs (telegramSecret != null) {
    telegram = {
      command = [
        "${pkgs.bash}/bin/bash"
        "-c"
        "set -a; . ${telegramSecret.path}; set +a; export TELEGRAM_SESSION_LOCK=shared; exec ${pkgs.uv}/bin/uvx --from git+https://github.com/labi-le/telegram-mcp.git@f086f7a8276fa4dcf368fa7eea7d918e5cd5ed72 telegram-mcp"
      ];
    };
  };
in
toml.generate "mcp.toml" { mcp = servers; }

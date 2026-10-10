{ config, lib, pkgs }:

pkgs.writeText "jcode-mcp.json" (
  builtins.toJSON {
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
        timeout_secs = 120;
      };
      context7 = {
        type = "stdio";
        command = "${pkgs.mcp-proxy}/bin/mcp-proxy";
        args = [
          "--transport"
          "streamablehttp"
          "https://mcp.context7.com/mcp"
        ];
        timeout_secs = 60;
      };
    };
  }
)

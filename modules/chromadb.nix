{ ... }:
{
  # ChromaDB vector database for semantic code search.
  # Used by opencode's `chroma` MCP server on client machines.
  # Runs as a DynamicUser systemd service, state under /var/lib/chromadb.
  # Bound to all interfaces — LAN clients (pc, notebook) connect at 192.168.1.2:8000.
  services.chromadb = {
    enable = true;
    host = "0.0.0.0";
    port = 8000;
    openFirewall = true;
  };
}

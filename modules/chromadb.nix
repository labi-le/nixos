{ ... }:
{
  # ChromaDB vector database for semantic code search.
  # Used by omp's `chroma` MCP server on client machines.
  # Runs as a DynamicUser systemd service, state under /var/lib/chromadb.
  # Bound to the LAN IP (not 0.0.0.0): the API is unauthenticated and must not be
  # reachable on the server's public interface. LAN clients reach 192.168.1.2:8000.
  services.chromadb = {
    enable = true;
    host = "192.168.1.2";
    port = 8000;
    openFirewall = true;
  };

  # LAN IP is DHCP-assigned; order after network-online so bind() to 192.168.1.2
  # doesn't race the lease at boot (upstream unit only waits for network.target).
  systemd.services.chromadb = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  # The index absorbs an upsert per edit from index-repo (~150 KB/s measured),
  # so its state lives on the SATA SSD rather than the system NVMe. The bind
  # mount targets the DynamicUser state dir, which keeps the upstream
  # hardening and StateDirectory ownership handling untouched.
  fileSystems."/var/lib/private/chromadb" = {
    device = "/drive/state/chromadb";
    fsType = "none";
    options = [ "bind" ];
  };
}

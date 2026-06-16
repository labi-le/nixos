{ pkgs, ... }:
{
  # System-wide dynamic loader shim for prebuilt (non-Nix) ELF binaries.
  # Required by Python wheels with C extensions installed via `uv` / `uvx`
  # (e.g. numpy, onnxruntime), the chroma-mcp MCP server, and similar
  # tools that don't come from nixpkgs.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib # libstdc++, libgcc_s, libgomp
      zlib # libz (numpy)
      zstd
      openssl
      curl
      expat
      icu
      libGL # onnxruntime
      glib
      libxcrypt
      xz
    ];
  };
}

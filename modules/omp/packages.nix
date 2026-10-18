{ pkgs }:

{
  programs = {
    enable = true;
    package = pkgs.omp;
  };

  systemPackages = [
    pkgs.uv
    pkgs.nodejs
    pkgs.bun
    pkgs.git
    pkgs.gh
    pkgs.file
    pkgs.tinyxxd
    pkgs.bc
    pkgs.binutils-unwrapped
    pkgs.yq-go
    pkgs.sqlite
    pkgs.shellcheck
    pkgs.mcp-nixos
    (pkgs.python3.withPackages (ps: [
      ps.pyyaml
      ps.pillow
      ps.requests
    ]))
  ];
}

{
  lib,
  writeShellApplication,
  coreutils,
  findutils,
  gnugrep,
  gnused,
  openssh,
  util-linux,
  nix,
  bash,
}:

writeShellApplication {
  name = "cargo-slot";
  runtimeInputs = [
    coreutils
    findutils
    gnugrep
    gnused
    openssh
    util-linux
    nix
    bash
  ];
  text =
    "set +e\n"
    + lib.replaceStrings [ "set -uo pipefail" ] [ "set -uo pipefail" ] (builtins.readFile ./cargo-slot.sh);
}

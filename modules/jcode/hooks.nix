{ pkgs }:

let
  commitGate = pkgs.writeShellScriptBin "jcode-commit-gate" ''
    exec ${pkgs.python3}/bin/python3 ${./commit-gate.py}
  '';

  commentGate = pkgs.writeShellScriptBin "jcode-comment-gate" ''
    exec ${pkgs.python3}/bin/python3 ${./comment-gate.py}
  '';

  upstreamGate = pkgs.writeShellScriptBin "jcode-upstream-gate" ''
    exec ${pkgs.python3}/bin/python3 ${./git_upstream_gate.py}
  '';

  repoRegister = pkgs.writeTextFile {
    name = "jcode-repo-register";
    executable = true;
    text = builtins.replaceStrings [ "@indexRepo@" ] [ "${pkgs.index-repo}" ] (
      builtins.readFile ./repo-register.sh
    );
  };
in
{
  inherit commitGate commentGate upstreamGate repoRegister;
}

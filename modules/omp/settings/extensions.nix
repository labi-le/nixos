{ inputs, pkgs }:

let
  repoRegisterJs = pkgs.replaceVars "${inputs.index-repo}/hooks/omp/repo-register.js" {
    index_repo_bin = "${pkgs.index-repo}/bin/index-repo";
  };

  delegationGate = pkgs.runCommand "omp-delegation-gate" { } ''
    mkdir -p $out
    cp ${../extensions/delegation-gate.ts} $out/delegation-gate.ts
    cp ${../extensions/delegation-policy.ts} $out/delegation-policy.ts
  '';
in
{
  inherit delegationGate repoRegisterJs;
}

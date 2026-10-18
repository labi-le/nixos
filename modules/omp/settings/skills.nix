{
  lib,
  pkgs,
  agentDir,
}:

let
  superpowersSrc = pkgs.fetchFromGitHub {
    owner = "obra";
    repo = "superpowers";
    rev = "8ca22dba9a94f28898bbce59f2537ff4d87c747d";
    hash = "sha256-BWPiXoXV+jePP+wn/Z+Af4iehIL7oei00plaWaTzq8s=";
  };
  humanizerSrc = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/databasus/databasus/bda7237599756ba76401b29e9761b07206e38bd6/.agents/skills/humanizer/SKILL.md";
    hash = "sha256-fDpFzjSCLTnVs0d08TwQsU2ent9I6EJ9n7/vg/Mt7LA=";
  };
  humanizerSkill = pkgs.runCommand "humanizer-skill" { } ''
    mkdir -p $out
    cp ${humanizerSrc} $out/SKILL.md
  '';

  skillsFromDir =
    dir:
    lib.mapAttrs (name: _: "${dir}/${name}") (
      lib.filterAttrs (name: type: type == "directory" && builtins.pathExists "${dir}/${name}/SKILL.md") (
        builtins.readDir dir
      )
    );

  vendoredSkills = skillsFromDir "${superpowersSrc}/skills" // {
    humanizer = "${humanizerSkill}";
  };

  skillLinks = lib.mapAttrsToList (
    name: dir: "L+ ${agentDir}/skills/${name} - - - - ${dir}"
  ) vendoredSkills;
in
skillLinks

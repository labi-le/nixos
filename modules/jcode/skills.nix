{ lib, pkgs, jcodeDir }:

let
  superpowersSrc = pkgs.fetchFromGitHub {
    owner = "obra";
    repo = "superpowers";
    rev = "8ca22dba9a94f28898bbce59f2537ff4d87c747d";
    hash = "sha256-BWPiXoXV+jePP+wn/Z+Af4iehIL7oei00plaWaTzq8s=";
  };
  agentSkillsSrc = pkgs.fetchFromGitHub {
    owner = "labi-le";
    repo = "agent-skills";
    rev = "57c9f2cf09ba23fe7962e73f0026dc545c4c6bc3";
    hash = "sha256-DUqUjWDqJk828se7ChbsZaflXfbvRNyQM+zU2psoDYU=";
  };
  plantumlSkillSrc = pkgs.fetchFromGitHub {
    owner = "asolfre";
    repo = "plantuml-rendering-skill";
    rev = "5191edd2b30b8729a3ada1b61db381f3132d6764";
    hash = "sha256-SOkpdeAkC68unov70AseGrK3GB0FK/HdR9MxgsqaNr0=";
  };
  humanizerSrc = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/databasus/databasus/bda7237599756ba76401b29e9761b07206e38bd6/.agents/skills/humanizer/SKILL.md";
    hash = "sha256-fDpFzjSCLTnVs0d08TwQsU2ent9I6EJ9n7/vg/Mt7LA=";
  };
  humanizerSkill = pkgs.runCommand "jcode-humanizer-skill" { } ''
    mkdir -p $out
    cp ${humanizerSrc} $out/SKILL.md
  '';

  skillsFromDir =
    dir:
    lib.mapAttrs (name: _: "${dir}/${name}") (
      lib.filterAttrs (
        name: type: type == "directory" && builtins.pathExists "${dir}/${name}/SKILL.md"
      ) (builtins.readDir dir)
    );

  vendoredSkills = lib.mergeAttrsList [
    (skillsFromDir "${superpowersSrc}/skills")
    (skillsFromDir "${agentSkillsSrc}/skills")
    {
      humanizer = humanizerSkill;
      plantuml-rendering = plantumlSkillSrc;
    }
  ];
in
lib.mapAttrsToList (name: dir: "L+ ${jcodeDir}/skills/${name} - - - - ${dir}") vendoredSkills

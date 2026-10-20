{
  config,
  lib,
  pkgs,
  user,
  ...
}:

let
  userCfg = config.users.users.${user.name};
  configDir = "${userCfg.home}/.config/maki";
  skillsDir = "${configDir}/skills";
  mcpToml = import ./mcp.nix { inherit config lib pkgs; };
  skillLinks = import ./skills.nix { inherit lib pkgs skillsDir; };
in
{
  environment.systemPackages = [ pkgs.maki ];

  systemd.tmpfiles.rules = [
    "d ${configDir} 0700 ${user.name} ${userCfg.group} -"
    "d ${configDir}/lua 0700 ${user.name} ${userCfg.group} -"
    "d ${skillsDir} 0700 ${user.name} ${userCfg.group} -"
    "L+ ${configDir}/init.lua - - - - ${./init.lua}"
    "L+ ${configDir}/AGENTS.md - - - - ${./AGENTS.md}"
    "L+ ${configDir}/lua/byesu.lua - - - - ${./lua/byesu.lua}"
    "L+ ${configDir}/lua/closerouter.lua - - - - ${./lua/closerouter.lua}"
    "L+ ${configDir}/lua/llm_labile.lua - - - - ${./lua/llm_labile.lua}"
    "L+ ${configDir}/lua/secret.lua - - - - ${./lua/secret.lua}"
    "L+ ${configDir}/lua/commit_gate.lua - - - - ${./lua/commit_gate.lua}"
    "L+ ${configDir}/lua/comment_gate.lua - - - - ${./lua/comment_gate.lua}"
    "L+ ${configDir}/lua/git_upstream_gate.lua - - - - ${./lua/git_upstream_gate.lua}"
    "L+ ${configDir}/plugin.toml - - - - ${./plugin.toml}"
    "L+ ${configDir}/providers.toml - - - - ${./providers.toml}"
  ]
  ++ skillLinks;

  system.activationScripts.makiMcpConfig = lib.stringAfter [ "users" ] ''
    mkdir -p ${configDir}
    rm -f ${configDir}/mcp.toml
    install -m 600 -o ${user.name} -g ${userCfg.group} ${mcpToml} ${configDir}/mcp.toml
  '';
}

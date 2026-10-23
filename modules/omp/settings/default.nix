{
  config,
  lib,
  pkgs,
  inputs,
  user,
}:

let
  userCfg = config.users.users.${user.name};
  agentDir = "${userCfg.home}/.omp/agent";
  telegramSecret = config.age.secrets.telegram-mcp or null;
  modelsYml = import ./providers.nix { inherit config lib pkgs; };
  mcp = import ./mcp.nix {
    inherit
      config
      lib
      pkgs
      telegramSecret
      ;
  };
  client = import ./client.nix { inherit lib pkgs; };
  skillLinks = import ./skills.nix { inherit lib pkgs agentDir; };
  extensions = import ./extensions.nix { inherit inputs pkgs; };
  configFile = import ./config.nix { inherit pkgs; };
in
{
  inherit
    agentDir
    userCfg
    telegramSecret
    modelsYml
    skillLinks
    configFile
    ;
  inherit (mcp) mcpJson telegramCommand;
  mcpServices = mcp.services;
  inherit (client) keybindingsYml lspJson;
  inherit (extensions) delegationGate repoRegisterJs;
}

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
  skills = import ./skills.nix { inherit lib pkgs agentDir; };
  extensions = import ./extensions.nix { inherit inputs pkgs; };
  configFile = import ./config.nix { inherit pkgs; };
in
{
  inherit
    agentDir
    userCfg
    telegramSecret
    modelsYml
    configFile
    ;
  skillLinks = skills.links;
  skillNames = skills.names;
  inherit (mcp) mcpJson telegramCommand telegramPort;
  mcpServices = mcp.services;
  inherit (client) keybindingsYml lspJson;
  inherit (extensions) delegationGate repoRegisterJs;
}

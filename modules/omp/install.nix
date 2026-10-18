{
  files,
  lib,
  user,
}:

{
  tmpfiles = [
    "d ${files.agentDir} 0700 ${user.name} ${files.userCfg.group} -"
    "d ${files.agentDir}/skills 0700 ${user.name} ${files.userCfg.group} -"
    "d ${files.agentDir}/rules 0700 ${user.name} ${files.userCfg.group} -"
    "d ${files.agentDir}/extensions 0700 ${user.name} ${files.userCfg.group} -"
    "L+ ${files.agentDir}/models.yml - - - - ${files.modelsYml}"
    "L+ ${files.agentDir}/mcp.json - - - - ${files.mcpJson}"
    "L+ ${files.agentDir}/keybindings.yml - - - - ${files.keybindingsYml}"
    "L+ ${files.agentDir}/lsp.json - - - - ${files.lspJson}"
    "L+ ${files.agentDir}/AGENTS.md - - - - ${./AGENTS.md}"
    "L+ ${files.agentDir}/RULES.md - - - - ${./RULES.md}"
    "L+ ${files.agentDir}/rules/commit-style.md - - - - ${./rules/commit-style.md}"
    "L+ ${files.agentDir}/rules/code-comments.md - - - - ${./rules/code-comments.md}"
    "L+ ${files.agentDir}/rules/project-naming.md - - - - ${./rules/project-naming.md}"
    "L+ ${files.agentDir}/extensions/commit-gate.ts - - - - ${./extensions/commit-gate.ts}"
    "L+ ${files.agentDir}/extensions/comment-gate.ts - - - - ${./extensions/comment-gate.ts}"
    "L+ ${files.agentDir}/extensions/git-upstream-gate.ts - - - - ${./extensions/git-upstream-gate.ts}"
    "L+ ${files.agentDir}/extensions/delegation-gate.ts - - - - ${files.delegationGate}/delegation-gate.ts"
    "L+ ${files.agentDir}/extensions/repo-register.js - - - - ${files.repoRegisterJs}"
  ]
  ++ lib.optional (
    files.telegramSecret != null
  ) "L+ ${files.agentDir}/telegram-mcp - - - - ${files.telegramCommand}"
  ++ files.skillLinks;

  activationScript = lib.stringAfter [ "users" ] ''
    mkdir -p ${files.agentDir}
    rm -f ${files.agentDir}/rules/chroma-first.md ${files.agentDir}/rules/chroma-first-shell.md
    install -m 600 -o ${user.name} -g ${files.userCfg.group} ${files.configFile} ${files.agentDir}/config.yml
  '';
}

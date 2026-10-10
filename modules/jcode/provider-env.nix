{
  pkgs,
  configDir,
  userName,
  group,
}:

let
  providerEnvFiles = [
    {
      secret = "byesu-env";
      variable = "BYESU_API_KEY";
      file = "byesu.env";
    }
    {
      secret = "opencode-litellm-master-key";
      variable = "LITELLM_CLOSEROUTER";
      file = "closerouter.env";
    }
    {
      secret = "tokenharbor-env";
      variable = "TOKENHARBOR_API_KEY";
      file = "tokenharbor.env";
    }
    {
      secret = "opencode-litellm-master-key";
      variable = "LITELLM_MASTER_KEY";
      file = "pool.env";
    }
  ];
in
{
  inherit providerEnvFiles;

  writeProviderEnv =
    entry:
    let
      source = "/run/agenix/${entry.secret}";
    in
    ''
      if [ -r ${source} ]; then
        value="$(${pkgs.gnused}/bin/sed -n 's/^${entry.variable}=//p' ${source} | ${pkgs.coreutils}/bin/head -n1)"
        if [ -n "$value" ]; then
          printf '%s=%s\n' '${entry.variable}' "$value" > "${configDir}/${entry.file}"
          chmod 600 "${configDir}/${entry.file}"
          chown ${userName}:${group} "${configDir}/${entry.file}"
        fi
      fi
    '';
}

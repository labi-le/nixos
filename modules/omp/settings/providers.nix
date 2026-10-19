{
  config,
  lib,
  pkgs,
}:

let
  litellmSecret = config.age.secrets.opencode-litellm-master-key or null;
  litellmKey =
    envName:
    if litellmSecret != null then
      "!${pkgs.gnused}/bin/sed -n 's/^${envName}=//p' ${litellmSecret.path}"
    else
      envName;
  closerouterApiKey = litellmKey "LITELLM_CLOSEROUTER";

  llmLabileSecret = config.age.secrets.llm-labile-env or null;
  llmLabileKey =
    if llmLabileSecret != null then
      "!${pkgs.gnused}/bin/sed -n 's/^LLM_LABILE_API_KEY=//p' ${llmLabileSecret.path}"
    else
      "LLM_LABILE_API_KEY";

  byesuSecret = config.age.secrets.byesu-env or null;
  byesuKey =
    if byesuSecret != null then
      "!${pkgs.gnused}/bin/sed -n 's/^BYESU_API_KEY=//p' ${byesuSecret.path}"
    else
      "BYESU_API_KEY";

  modelsYml = pkgs.writeText "models.yml" (
    builtins.toJSON {
      providers = {
        closerouter = {
          baseUrl = "https://api.closerouter.dev/v1";
          api = "openai-completions";
          apiKey = closerouterApiKey;
          discovery = {
            type = "openai-models-list";
          };
        };
        byesu = {
          baseUrl = "https://byesu.com/v1";
          api = "openai-completions";
          apiKey = byesuKey;
          discovery = {
            type = "proxy";
          };
        };
      }
      // lib.optionalAttrs (llmLabileSecret != null) {
        llm-labile = {
          baseUrl = "https://llm.labile.cc/v1";
          api = "openai-completions";
          apiKey = llmLabileKey;
          discovery = {
            type = "litellm";
          };
        };
      };
    }
  );
in
modelsYml

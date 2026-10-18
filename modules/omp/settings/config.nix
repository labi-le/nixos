{ pkgs }:

let
  yaml = pkgs.formats.yaml { };
  configFile = yaml.generate "omp-config.yml" {
    setupVersion = 2;
    extensions = [ ];
    advisor.enabled = false;
    defaultThinkingLevel = "auto";
    extendedContext = true;
    memory.backend = "mnemopi";
    modelRoleStorage = "project";
    modelRoles.dictation = "local/whisper-small";
    composer.tokenRate = true;
    tools = {
      xdev = true;
      xdevDocs = "catalog";
    };
    hideThinkingBlock = false;
    compaction = {
      enabled = true;
      methodOrder = [
        "snapcompact"
        "shake"
        "remote"
        "soft"
      ];
      midTurnEnabled = true;
      dropUseless = true;
      thresholdPercent = 60;
      keepRecentTokens = 40000;
      idleEnabled = true;
      idleThresholdTokens = 150000;
      idleTimeoutSeconds = 300;
    };
    mnemopi = {
      scoping = "per-project";
      embeddingVariant = "multilingual";
      polyphonicRecall = true;
      enhancedRecall = true;
      proactiveLinking = true;
    };
    autolearn.enabled = true;
    task = {
      eager = "preferred";
      enableLsp = true;
      maxRuntimeMs = 0;
      isolation.enabled = true;
    };
    secrets.enabled = true;
    lsp = {
      diagnosticsOnEdit = true;
      formatOnWrite = true;
    };
    edit.autoRepair.enabled = true;
    eval.js = false;
    providers = {
      autoThinkingMaxEffort = "max";
      streamFirstEventTimeoutSeconds = 180;
      streamIdleTimeoutSeconds = 90;
    };
    retry = {
      modelFallback = false;
      usageAwareFallback = false;
      waitForUsageReset = true;
      maxDelayMs = 0;
      maxRetries = 1000;
    };
    stt = {
      enabled = true;
      language = "ru";
      submitTrigger = "never";
    };
    spelling.autocomplete = "off";
  };
in
configFile

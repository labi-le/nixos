{ osConfig
, lib
, ...
}:

let
  # litellm-env.age is an env file (KEY=value lines); pull the aigate key out.
  litellmEnv = builtins.readFile osConfig.age.secrets.opencode-litellm-master-key.path;
  aigateKey = lib.removePrefix "LITELLM_AIGATE_API_KEY="
    (lib.head (lib.filter (s: lib.hasPrefix "LITELLM_AIGATE_API_KEY=" s)
      (lib.splitString "\n" litellmEnv)));
in
{
  programs.oh-my-pi = {
    enable = true;

    plugins = [
      "@baylarsadigov/omp-undo-redo"
    ];

    providers = {
      aigate = {
        baseUrl = "https://api.aigate.shop/v1";
        api = "openai-completions";
        apiKey = aigateKey;
        models = [
          {
            id = "deepseek/deepseek-v4-pro";
            name = "DeepSeek V4 Pro";
            contextWindow = 200000;
            maxTokens = 8192;
          }
          {
            id = "deepseek/deepseek-v4-flash";
            name = "DeepSeek V4 Flash";
            contextWindow = 200000;
            maxTokens = 8192;
          }
          # ── Anthropic ──
          {
            id = "anthropic/claude-opus-4.8";
            name = "Claude Opus 4.8";
            contextWindow = 200000;
            maxTokens = 32768;
          }
          {
            id = "anthropic/claude-opus-4.7";
            name = "Claude Opus 4.7";
            contextWindow = 200000;
            maxTokens = 32768;
          }
          {
            id = "anthropic/claude-opus-4.6";
            name = "Claude Opus 4.6";
            contextWindow = 200000;
            maxTokens = 32768;
          }
          {
            id = "anthropic/claude-sonnet-5";
            name = "Claude Sonnet 5";
            contextWindow = 200000;
            maxTokens = 16384;
          }
          {
            id = "anthropic/claude-sonnet-4.6";
            name = "Claude Sonnet 4.6";
            contextWindow = 200000;
            maxTokens = 16384;
          }
          {
            id = "anthropic/claude-haiku-4.5";
            name = "Claude Haiku 4.5";
            contextWindow = 200000;
            maxTokens = 8192;
          }
          {
            id = "anthropic/claude-fable-5";
            name = "Claude Fable 5";
            contextWindow = 200000;
            maxTokens = 16384;
          }
          # ── OpenAI ──
          {
            id = "openai/gpt-5.5";
            name = "GPT-5.5";
            contextWindow = 128000;
            maxTokens = 16384;
          }
          {
            id = "openai/gpt-5.4";
            name = "GPT-5.4";
            contextWindow = 128000;
            maxTokens = 16384;
          }
          {
            id = "openai/gpt-5.4-mini";
            name = "GPT-5.4 Mini";
            contextWindow = 128000;
            maxTokens = 16384;
          }
          {
            id = "openai/gpt-5.4-nano";
            name = "GPT-5.4 Nano";
            contextWindow = 128000;
            maxTokens = 16384;
          }
          {
            id = "openai/gpt-image-2";
            name = "GPT Image 2";
            contextWindow = 128000;
            maxTokens = 4096;
          }
          # ── Google ──
          {
            id = "google/gemini-3.5-flash";
            name = "Gemini 3.5 Flash";
            contextWindow = 1048576;
            maxTokens = 8192;
          }
          {
            id = "google/gemini-3.1-pro-preview";
            name = "Gemini 3.1 Pro";
            contextWindow = 1048576;
            maxTokens = 8192;
          }
          {
            id = "google/gemini-3.1-flash-lite";
            name = "Gemini 3.1 Flash Lite";
            contextWindow = 1048576;
            maxTokens = 8192;
          }
          {
            id = "google/gemini-3.1-flash-lite-image";
            name = "Gemini 3.1 Flash Lite (Image)";
            contextWindow = 1048576;
            maxTokens = 8192;
          }
          {
            id = "google/gemini-3.1-flash-image-preview";
            name = "Gemini 3.1 Flash Image";
            contextWindow = 1048576;
            maxTokens = 8192;
          }
          {
            id = "google/gemini-3-flash-preview";
            name = "Gemini 3 Flash";
            contextWindow = 1048576;
            maxTokens = 8192;
          }
          {
            id = "google/gemini-3-pro-image";
            name = "Gemini 3 Pro Image";
            contextWindow = 1048576;
            maxTokens = 8192;
          }
          {
            id = "google/gemma-4-31b-it";
            name = "Gemma 4 31B";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          {
            id = "google/gemma-4-26b-a4b-it";
            name = "Gemma 4 26B A4B";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          # ── xAI ──
          {
            id = "x-ai/grok-4.5";
            name = "Grok 4.5";
            contextWindow = 128000;
            maxTokens = 16384;
          }
          {
            id = "x-ai/grok-4.3";
            name = "Grok 4.3";
            contextWindow = 128000;
            maxTokens = 16384;
          }
          {
            id = "x-ai/grok-4.20";
            name = "Grok 4.20";
            contextWindow = 128000;
            maxTokens = 16384;
          }
          {
            id = "x-ai/grok-4.1-fast";
            name = "Grok 4.1 Fast";
            contextWindow = 128000;
            maxTokens = 16384;
          }
          {
            id = "x-ai/grok-build-0.1";
            name = "Grok Build 0.1";
            contextWindow = 128000;
            maxTokens = 16384;
          }
          # ── Perplexity ──
          {
            id = "perplexity/sonar-pro";
            name = "Sonar Pro";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          {
            id = "perplexity/sonar-reasoning-pro";
            name = "Sonar Reasoning Pro";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          {
            id = "perplexity/sonar";
            name = "Sonar";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          # ── Qwen ──
          {
            id = "qwen/qwen3.7-max";
            name = "Qwen 3.7 Max";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          # ── Kimi (Moonshot) ──
          {
            id = "moonshotai/kimi-k2.7-code";
            name = "Kimi K2.7 Code";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          {
            id = "moonshotai/kimi-k2.7-code-highspeed";
            name = "Kimi K2.7 Code Highspeed";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          {
            id = "moonshotai/kimi-k2.6";
            name = "Kimi K2.6";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          # ── NVIDIA ──
          {
            id = "nvidia/nemotron-3-ultra";
            name = "Nemotron 3 Ultra";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          # ── Z.AI (GLM) ──
          {
            id = "z-ai/glm-5.2";
            name = "GLM 5.2";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          {
            id = "z-ai/glm-5.1";
            name = "GLM 5.1";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          # ── MiniMax ──
          {
            id = "minimax/minimax-m3";
            name = "MiniMax M3";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          {
            id = "minimax/minimax-m2.7";
            name = "MiniMax M2.7";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          # ── Sakana ──
          {
            id = "sakana/fugu-ultra";
            name = "Fugu Ultra";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          # ── Xiaomi ──
          {
            id = "xiaomi/mimo-v2.5-pro";
            name = "MiMo V2.5 Pro";
            contextWindow = 128000;
            maxTokens = 8192;
          }
          {
            id = "xiaomi/mimo-v2.5";
            name = "MiMo V2.5";
            contextWindow = 128000;
            maxTokens = 8192;
          }
        ];
      };
    };

    models.default = "deepseek/deepseek-v4-pro";

    # On launch, resume the cwd's most-recent session in full (conversation +
    # its last model) instead of a fresh session that resets to models.default.
    settings.autoResume = true;
  };

  # Global MCP servers for omp (~/.omp/mcp.json), merged with any project-level
  # <cwd>/.omp/mcp.json. chroma = semantic code search over the ChromaDB the
  # index-repo daemon builds (same server opencode uses via chromaMcp). Needs
  # `uvx` (uv) on PATH.
  home.file.".omp/mcp.json".text = builtins.toJSON {
    "$schema" = "https://raw.githubusercontent.com/can1357/oh-my-pi/main/packages/coding-agent/src/config/mcp-schema.json";
    mcpServers.chroma = {
      type = "stdio";
      command = "uvx";
      args = [
        "chroma-mcp"
        "--client-type"
        "http"
        "--host"
        "192.168.1.2"
        "--port"
        "8000"
        "--ssl"
        "false"
      ];
    };
  };
}

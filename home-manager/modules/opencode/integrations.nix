{
  pkgs,
  lib,
  osConfig,
  ...
}:

let
  wrappers = import ./wrappers.nix { inherit pkgs lib osConfig; };
  systemPromptOverride = pkgs.writeText "system-prompt-override.ts" ''
    import type { Plugin } from "@opencode-ai/plugin"

    const DEFAULT_PREFIX = "You are OpenCode, You and the user share the same workspace and collaborate to achieve the user's goals."
    const DEFAULT_REPLACEMENT = [
      "You are OpenCode.",
      "Work with the user on software engineering tasks in the current workspace.",
      "Be accurate, concise, and pragmatic.",
      "Use tools when needed, avoid unnecessary output, and follow project instructions.",
    ].join("\n")

    const ENV_MARKER = "\nYou are powered by the model named "

    export default (async () => ({
      "experimental.chat.system.transform": async (_input, output) => {
        if (!Array.isArray(output.system) || output.system.length === 0) return
        const header = output.system[0]
        if (typeof header !== "string" || !header.startsWith(DEFAULT_PREFIX)) return

        const envIndex = header.indexOf(ENV_MARKER)
        if (envIndex === -1) {
          output.system[0] = DEFAULT_REPLACEMENT
          return
        }

        output.system[0] = DEFAULT_REPLACEMENT + header.slice(envIndex)
      },
    })) satisfies Plugin
  '';
  superpowersSrc = pkgs.fetchFromGitHub {
    owner = "obra";
    repo = "superpowers";
    rev = "v5.1.0";
    hash = "sha256-3E3rO6hR87JUfS3XV1Eaoz6SDWOftleWvN9UPNFEMjw=";
  };
  usingSuperpowersOverride = pkgs.writeText "using-superpowers-SKILL.md" ''
    ---
    name: using-superpowers
    description: Manual-only reference skill. Use only when the user explicitly asks for `using-superpowers` or asks how the skill system works. Do not auto-invoke it at conversation start.
    ---

    <MANUAL-ONLY>
    Do not invoke this skill automatically just because it exists.

    Use it only when the user explicitly asks for `using-superpowers` by name or
    asks for a direct explanation of the skill system itself.
    </MANUAL-ONLY>

    <SUBAGENT-STOP>
    If you were dispatched as a subagent to execute a specific task, skip this skill.
    </SUBAGENT-STOP>

    <EXTREMELY-IMPORTANT>
    If you think there is even a 1% chance a skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill.

    IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

    This is not negotiable. This is not optional. You cannot rationalize your way out of this.
    </EXTREMELY-IMPORTANT>

    ## Instruction Priority

    Superpowers skills override default system prompt behavior, but **user instructions always take precedence**:

    1. **User's explicit instructions** (CLAUDE.md, GEMINI.md, AGENTS.md, direct requests) - highest priority
    2. **Superpowers skills** - override default system behavior where they conflict
    3. **Default system prompt** - lowest priority

    If CLAUDE.md, GEMINI.md, or AGENTS.md says "don't use TDD" and a skill says "always use TDD," follow the user's instructions. The user is in control.

    ## How to Access Skills

    **In Claude Code:** Use the `Skill` tool. When you invoke a skill, its content is loaded and presented to you-follow it directly. Never use the Read tool on skill files.

    **In Copilot CLI:** Use the `skill` tool. Skills are auto-discovered from installed plugins. The `skill` tool works the same as Claude Code's `Skill` tool.

    **In Gemini CLI:** Skills activate via the `activate_skill` tool. Gemini loads skill metadata at session start and activates the full content on demand.

    **In other environments:** Check your platform's documentation for how skills are loaded.

    ## Platform Adaptation

    Skills use Claude Code tool names. Non-CC platforms: see `references/copilot-tools.md` (Copilot CLI), `references/codex-tools.md` (Codex) for tool equivalents. Gemini CLI users get the tool mapping loaded automatically via GEMINI.md.

    # Using Skills

    ## The Rule

    **Invoke relevant or requested skills BEFORE any response or action.** Even a 1% chance a skill might apply means that you should invoke the skill to check. If an invoked skill turns out to be wrong for the situation, you don't need to use it.

    ## Red Flags

    These thoughts mean STOP--you're rationalizing:

    | Thought | Reality |
    |---------|---------|
    | "This is just a simple question" | Questions are tasks. Check for skills. |
    | "I need more context first" | Skill check comes BEFORE clarifying questions. |
    | "Let me explore the codebase first" | Skills tell you HOW to explore. Check first. |
    | "I can check git/files quickly" | Files lack conversation context. Check for skills. |
    | "Let me gather information first" | Skills tell you HOW to gather information. |
    | "This doesn't need a formal skill" | If a skill exists, use it. |
    | "I remember this skill" | Skills evolve. Read current version. |
    | "This doesn't count as a task" | Action = task. Check for skills. |
    | "The skill is overkill" | Simple things become complex. Use it. |
    | "I'll just do this one thing first" | Check BEFORE doing anything. |
    | "This feels productive" | Undisciplined action wastes time. Skills prevent this. |
    | "I know what that means" | Knowing the concept != using the skill. Invoke it. |

    ## Skill Priority

    When multiple skills could apply, use this order:

    1. **Process skills first** (brainstorming, debugging) - these determine HOW to approach the task
    2. **Implementation skills second** (frontend-design, mcp-builder) - these guide execution

    "Let's build X" -> brainstorming first, then implementation skills.
    "Fix this bug" -> debugging first, then domain-specific skills.

    ## Skill Types

    **Rigid** (TDD, debugging): Follow exactly. Don't adapt away discipline.

    **Flexible** (patterns): Adapt principles to context.

    The skill itself tells you which.

    ## User Instructions

    Instructions say WHAT, not HOW. "Add X" or "Fix Y" doesn't mean skip workflows.
  '';
  superpowersSkills = pkgs.runCommand "opencode-superpowers-skills" { } ''
    mkdir -p "$out/skills"
    cp -RL ${superpowersSrc}/skills/. "$out/skills/"
    chmod -R u+w "$out/skills/using-superpowers"
    rm -rf "$out/skills/using-superpowers"
    mkdir -p "$out/skills/using-superpowers"
    cp ${usingSuperpowersOverride} "$out/skills/using-superpowers/SKILL.md"
  '';
in

{
  programs.opencode.settings = {
    skills = lib.mkForce {
      paths = [ "${superpowersSkills}/skills" ];
    };
    permission = {
      external_directory = {
        "/tmp/**" = "allow";
        "/nix/store/**" = "allow";
      };
      edit = {
        "/tmp/**" = "allow";
      };
      read = "allow";
      glob = "allow";
      grep = "allow";
      list = "allow";
    };
    plugin = [
      "@tarquinen/opencode-dcp@latest"
      "@darrenhinde/OpenAgentsControl@latest"
      "opencode-gemini-auth@latest"
    ];
    mcp = {
      context7 = {
        type = "remote";
        url = "https://mcp.context7.com/mcp";
      };
      gh_grep = {
        type = "remote";
        url = "https://mcp.grep.app";
      };
      opendataloader-pdf = {
        type = "local";
        command = [ "${wrappers.opencodeMcpOpendataloaderPdf}/bin/opencode-mcp-opendataloader-pdf" ];
      };
      playwright = {
        type = "local";
        command = [
          "${wrappers.opencodeMcpPlaywright}/bin/opencode-mcp-playwright"
          "--isolated"
          "--headless"
          "--executable-path"
          "${pkgs.chromium}/bin/chromium"
        ];
      };
    }
    // lib.optionalAttrs (osConfig.age.secrets ? opencode-grafana-mcp) {
      grafana = {
        type = "local";
        command = [ "${wrappers.opencodeMcpGrafana}/bin/opencode-mcp-grafana" ];
      };
    };
  };

  programs.opencode.skills = {
    plantuml-rendering = "${pkgs.fetchFromGitHub {
      owner = "asolfre";
      repo = "plantuml-rendering-skill";
      rev = "5191edd2b30b8729a3ada1b61db381f3132d6764";
      hash = "sha256-SOkpdeAkC68unov70AseGrK3GB0FK/HdR9MxgsqaNr0=";
    }}";
    caveman = "${
      pkgs.fetchFromGitHub {
        owner = "JuliusBrussee";
        repo = "caveman";
        rev = "655b7d9c5431f822264b7732e9901c5578ac84cf";
        hash = "sha256-BydREt/vai3j7kO5+e1OxsjXf6Vy+jSY1yA/yyxjHbI=";
      }
    }/skills/caveman";
  };

  xdg.configFile."opencode/plugins/system-prompt-override.ts".source = systemPromptOverride;
  xdg.configFile."opencode/plugins/rtk.ts".source = "${wrappers.rtkSource}/hooks/opencode/rtk.ts";
}

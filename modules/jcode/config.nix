{
  homeDirectory,
  baseProviders,
  extensionProviders,
  defaultRoute,
  commitGate,
  commentGate,
  upstreamGate,
  repoRegister,
  extensionHooks,
}:

{
  server = {
    wake_mode = "internal";
  };

  keybindings = {
    scroll_up = "ctrl+shift+k";
    scroll_down = "ctrl+shift+j";
    scroll_page_up = "alt+u";
    scroll_page_down = "alt+d";
    model_switch_next = "ctrl+tab";
    model_switch_prev = "ctrl+shift+tab";
    fallback_switch = "ctrl+y";
    effort_increase = "alt+right";
    effort_decrease = "alt+left";
    centered_toggle = "alt+c";
    scroll_prompt_up = "ctrl+k";
    scroll_prompt_down = "ctrl+j";
    scroll_bookmark = "ctrl+g";
    auto_poke_toggle = "ctrl+p";
    scroll_up_fallback = "";
    scroll_down_fallback = "";
    workspace_left = "alt+h";
    workspace_down = "alt+j";
    workspace_up = "alt+k";
    workspace_right = "alt+l";
    side_panel_toggle = "alt+m";
    copy_selection_toggle = "alt+y";
    diagram_pane_toggle = "alt+t";
    diagram_pane_visibility_toggle = "alt+shift+m";
    typing_scroll_lock_toggle = "alt+s";
    diff_mode_cycle = "alt+g";
    info_widget_toggle = "alt+i";
    todo_card_toggle = "alt+x";
    swarm_panel_focus = "alt+n";
    new_terminal = "alt+shift+;";
    open_resume = "alt+r";
    voice_input = "ctrl+space";
    session_picker_enter = "current-terminal";
  };

  dictation = {
    command = "";
    mode = "send";
    timeout_secs = 90;
    vocabulary = [ ];
    recorder = "";
  };

  display = {
    diff_mode = "inline";
    queue_mode = false;
    auto_server_reload = true;
    mouse_capture = true;
    debug_socket = false;
    emoji = true;
    centered = false;
    show_thinking = true;
    reasoning_display = "full";
    diagram_mode = "none";
    markdown_spacing = "compact";
    latex_rendering = "image";
    pin_images = true;
    pin_todos = true;
    idle_animation = false;
    prompt_entry_animation = true;
    disabled_animations = [ ];
    performance = "";
    animation_fps = 60;
    redraw_fps = 60;
    prompt_preview = true;
    compact_notifications = false;
    copy_badge_alt_label = "";
    show_agentgrep_output = false;
    show_bash_output = true;
    tool_call_details = true;
    keybinding_hints = true;
    theme = "";
    active_sessions_manager = false;
    external_sessions = true;
    usage_display = "left";
    native_scrollbars = {
      chat = true;
      side_panel = true;
    };
    colors = {
      user = "#8be9fd";
      ai = "#50fa7b";
      tool = "#6272a4";
      file_link = "#8be9fd";
      dim = "#6272a4";
      accent = "#bd93f9";
      system = "#ff79c6";
      queued = "#f1fa8c";
      asap = "#ff79c6";
      pending = "#6272a4";
      user_text = "#f8f8f2";
      user_bg = "#44475a";
      ai_text = "#f8f8f2";
      header_icon = "#8be9fd";
      header_name = "#bd93f9";
      header_session = "#f8f8f2";
      success = "#50fa7b";
      warning = "#ffb86c";
      error = "#ff5555";
      info = "#bd93f9";
      border = "#6272a4";
      selection_bg = "#44475a";
    };
  };

  features = {
    check_updates = false;
    memory = true;
    swarm = true;
    mermaid = true;
    auto_poke = true;
    message_timestamps = true;
    persist_memory_injections = false;
    kv_cache_miss_notices = true;
    update_channel = "stable";
  };

  websearch = {
    engine = "duckduckgo";
    fallback_engines = [ "bing" ];
    bing_api_key_env = "JCODE_BING_API_KEY";
    bing_market = "en-US";
    searxng_url_env = "JCODE_SEARXNG_URL";
  };

  tools = {
    profile = "";
    enabled = [ ];
    disabled = [ ];
    disable_base_tools = false;
    mcp_tools = "auto";
    mcp_tools_token_threshold = 8000;
  };

  acp = {
    profile = "standard";
    tool_profile = "acp";
  };

  auth = {
    trusted_external_sources = [ ];
    trusted_external_source_paths = [
      "claude_code_credentials|${homeDirectory}/.claude/.credentials.json"
      "opencode_auth_json|${homeDirectory}/.local/share/opencode/auth.json"
    ];
  };

  provider = {
    default_model = defaultRoute.model;
    default_provider = defaultRoute.provider;
    openai_reasoning_effort = "low";
    anthropic_cache_ttl_1h = true;
    openai_service_tier = "priority";
    openai_native_compaction_mode = "auto";
    openai_native_compaction_threshold_tokens = 200000;
    preserve_reasoning_context = true;
    cross_provider_failover = "countdown";
    same_provider_account_failover = true;
    gemini_force_oauth = false;
    stream_idle_timeout_secs = 180;
    max_retries = 8;
    retry_backoff_cap_secs = 30;
  };

  agents = {
    swarm_spawn_mode = "inline";
    swarm_strip_layout = "vertical";
    memory_jev_provider = "auto";
    memory_jev_threshold = 0.8;
    memory_sidecar_enabled = true;
    memory_rerank_cadence = 3;
    memory_rerank_votes = 2;
    memory_rerank_min_agree = 2;
    swarm_max_concurrent_agents = 32;
  };

  hooks = {
    pre_tool = [
      "${commitGate}/bin/jcode-commit-gate"
      "${commentGate}/bin/jcode-comment-gate"
      "${upstreamGate}/bin/jcode-upstream-gate"
    ];
    session_start = [ "${repoRegister} start" ] ++ extensionHooks.session_start;
    turn_start = [ "${repoRegister} start" ] ++ extensionHooks.turn_start;
    pre_tool_transform_timeout_ms = 500;
    pre_tool_timeout_ms = 8000;
  };

  providers = baseProviders // extensionProviders;

  ambient = {
    enabled = false;
    allow_api_keys = false;
    min_interval_minutes = 5;
    max_interval_minutes = 120;
    pause_on_active_session = true;
    proactive_work = true;
    work_branch_prefix = "ambient/";
    visible = true;
  };

  safety = {
    ntfy_server = "https://ntfy.sh";
    desktop_notifications = true;
    email_enabled = false;
    email_smtp_port = 587;
    email_imap_port = 993;
    email_reply_enabled = false;
    telegram_enabled = false;
    telegram_reply_enabled = false;
    discord_enabled = false;
    discord_reply_enabled = false;
    jade_relay_enabled = false;
    jade_relay_reply_enabled = false;
    jade_relay_launch_enabled = false;
  };

  notifications = {
    turn_complete = true;
    turn_complete_min_secs = 120;
    turn_complete_todo_min_secs = 30;
    turn_complete_only_when_unfocused = true;
    turn_complete_sound = "Glass";
  };

  gateway = {
    enabled = false;
    port = 7643;
    bind_addr = "0.0.0.0";
  };

  compaction = {
    mode = "proactive";
    lookahead_turns = 15;
    ewma_alpha = 0.3;
    proactive_floor = 0.4;
    min_samples = 3;
    stall_window = 5;
    min_turns_between_compactions = 10;
    max_context_tokens = 0;
  };

  power = {
    prevent_sleep_while_streaming = true;
    block_lid_close = true;
  };

  autoreview = {
    enabled = false;
  };

  autojudge = {
    enabled = false;
  };

  launch_hotkeys = {
    enabled = true;
    imported = true;
    entries = [
      {
        chord = "cmd+;";
        dir = "${homeDirectory}/nix";
        label = "nix";
        self_dev = false;
      }
      {
        chord = "cmd+'";
        dir = "$HOME";
        label = "home";
        self_dev = false;
      }
    ];
  };
}

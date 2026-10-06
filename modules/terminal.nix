{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.terminal;
  terminals = {
    ghostty = {
      desktop = "com.mitchellh.ghostty.desktop";
      appId = "com.mitchellh.ghostty";
      launch = [ "ghostty" ];
      launchTmuxSwitcher = [
        "ghostty"
        "--class=tmux.switcher"
        "-e"
        "tmux-session-switcher"
      ];
      imageProtocol = null;
    };
    foot = {
      desktop = "foot.desktop";
      appId = "foot";
      launch = [ "foot" ];
      launchTmuxSwitcher = [
        "foot"
        "--app-id=tmux.switcher"
        "tmux-session-switcher"
      ];
      imageProtocol = "sixel";
    };
    alacritty = {
      desktop = "Alacritty.desktop";
      appId = "alacritty";
      launch = [ "alacritty" ];
      launchTmuxSwitcher = [
        "alacritty"
        "-o"
        "window.class.general=\"tmux.switcher\""
        "-e"
        "tmux-session-switcher"
      ];
      imageProtocol = "sixel";
    };
  };
in
{
  options.terminal = {
    name = mkOption {
      type = types.enum (builtins.attrNames terminals);
      default = "ghostty";
      description = "Default terminal, wired into env, mime, keybinds and window rules.";
    };
    desktop = mkOption {
      type = types.str;
      default = terminals.${cfg.name}.desktop;
      internal = true;
      readOnly = true;
    };
    appId = mkOption {
      type = types.str;
      default = terminals.${cfg.name}.appId;
      internal = true;
      readOnly = true;
    };
    launch = mkOption {
      type = types.listOf types.str;
      default = terminals.${cfg.name}.launch;
      internal = true;
      readOnly = true;
    };
    launchTmuxSwitcher = mkOption {
      type = types.listOf types.str;
      default = terminals.${cfg.name}.launchTmuxSwitcher;
      internal = true;
      readOnly = true;
    };
    imageProtocol = mkOption {
      type = types.nullOr types.str;
      default = terminals.${cfg.name}.imageProtocol;
      internal = true;
      readOnly = true;
    };
  };

  config.environment.variables =
    {
      TERMINAL = cfg.name;
    }
    // lib.optionalAttrs (cfg.imageProtocol != null) {
      PI_FORCE_IMAGE_PROTOCOL = cfg.imageProtocol;
    };
}

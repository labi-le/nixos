{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.terminal;
  terminals = {
    foot = {
      desktop = "foot.desktop";
      appId = "foot";
      launch = [ "foot" ];
      launchTmuxSwitcher = [
        "foot"
        "--app-id=tmux-switcher"
        "tmux-session-switcher"
      ];
    };
    alacritty = {
      desktop = "Alacritty.desktop";
      appId = "alacritty";
      launch = [ "alacritty" ];
      launchTmuxSwitcher = [
        "alacritty"
        "-o"
        "window.class.general=\"tmux-switcher\""
        "-e"
        "tmux-session-switcher"
      ];
    };
  };
in
{
  options.terminal = {
    name = mkOption {
      type = types.enum (builtins.attrNames terminals);
      default = "alacritty";
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
  };

  config.environment.variables.TERMINAL = cfg.name;
}

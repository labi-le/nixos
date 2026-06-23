{ pkgs, lib, ... }:

{
  programs.alacritty = {
    enable = true;
    settings = {
      font = {
        size = lib.mkForce 15;
      };
      # Make Shift+Enter emit the kitty keyboard-protocol sequence (CSI-u:
      # ESC[13;2u) for Return+Shift, so TUI apps (e.g. opencode) receive a
      # distinct key and insert a newline instead of submitting. Nix has no
      # \u/\x string escape, so decode the ESC byte via fromJSON.
      keyboard.bindings = [
        {
          key = "Return";
          mods = "Shift";
          chars = builtins.fromJSON ''"\u001b[13;2u"'';
        }
      ];
    };
  };
  xdg.terminal-exec = {
    settings = {
      default = [ "alacritty.desktop" ];
    };
  };

}

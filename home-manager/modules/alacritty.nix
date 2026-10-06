{ osConfig, ... }:

{
  programs.alacritty = {
    enable = osConfig.terminal.name == "alacritty";
    settings = {
      window.class = {
        instance = osConfig.terminal.appId;
        general = osConfig.terminal.appId;
      };
      # Shift+Enter as CSI-u so TUIs insert a newline instead of submitting.
      keyboard.bindings = [
        {
          key = "Enter";
          mods = "Shift";
          chars = builtins.fromJSON ''"\u001b[13;2u"'';
        }
      ];
    };
  };
}

{ osConfig, ... }:

{
  programs.ghostty = {
    enable = osConfig.terminal.name == "ghostty";
    settings = {
      class = osConfig.terminal.appId;
    };
  };
}

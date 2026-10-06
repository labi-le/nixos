{ osConfig, ... }:

{
  programs.foot.enable = osConfig.terminal.name == "foot";
}

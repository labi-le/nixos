{ pkgs, ... }:

{
  programs.git = {
    enable = true;
    userName  = "labile";
    userEmail = "i@labile.cc";
    extraConfig = {
      push = { autoSetupRemote = true; };
    };
  };
}
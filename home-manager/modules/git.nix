{ ... }:

{
  programs.git = {
    enable = true;
    userName = "labi-le";
    userEmail = "1a6i1e@gmail.com";
    extraConfig = {
      push = { autoSetupRemote = true; };
      color.ui = true;
      core.editor = "nvim";
      credential.helper = "store";
    };
  };
}

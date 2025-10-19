{ ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "labi-le";
        email = "1a6i1e@gmail.com";
      };
      push = {
        autoSetupRemote = true;
      };
      color = {
        ui = true;
      };
      core = {
        editor = "nvim";
      };
      credential = {
        helper = "store";
      };
    };
  };
}

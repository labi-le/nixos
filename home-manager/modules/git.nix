{ user, ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = user.git.name;
        email = user.git.email;
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

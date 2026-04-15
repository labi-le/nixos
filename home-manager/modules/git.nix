{ user, config, ... }:

{
  programs.git = {
    enable = true;
    signing = {
      format = "ssh";
      key = "${config.home.homeDirectory}/.ssh/id_rsa.pub";
      signByDefault = true;
    };
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

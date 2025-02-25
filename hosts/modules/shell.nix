{ pkgs, ... }:

{
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  programs.zsh = {
    autosuggestions = {
      enable = true;
      strategy = [ "history" ];
      async = true;
      highlightStyle = "fg=cyan";
    };
    zsh-autoenv.enable = true;
    syntaxHighlighting.enable = true;
    ohMyZsh = {
      enable = true;
      theme = "simple";
      plugins = [
        "themes"
        "git"
        "dotenv"
        "history"
        "golang"
        "z"
        "github"
        "yii2"
        "sudo"
        "copybuffer"
        "copyfile"
        "copypath"
        "zsh-interactive-cd"
        "ssh"
        "git-auto-fetch"
        "git"
      ];
    };
    enableCompletion = true;
  };

  environment.systemPackages = with pkgs; [
    fzf
  ];

}


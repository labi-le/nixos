{ pkgs, ... }:

{
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  programs.zsh = {
    autosuggestions = {
      enable = true;
      strategy = [ "completion" ];
      async = true;
      highlightStyle = "fg=cyan";
    };
    zsh-autoenv.enable = true;
    syntaxHighlighting.enable = true;
    ohMyZsh = {
      enable = true;
      theme = "simple";
      plugins = [ "git" "dotenv" "history" "golang" "z" "github" "yii2" ];
    };
    enableCompletion = true;
    interactiveShellInit = "fastfetch";
  };
}


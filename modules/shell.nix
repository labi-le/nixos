{ lib, pkgs, ... }:

{
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  programs.command-not-found.enable = false;

  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
    package = pkgs.nix-index-with-small-db;
  };

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
        "z"
        "sudo"
        "ssh"
        "tmux"
      ];
    };
    enableCompletion = true;
    shellAliases = {
      eh = "grep -o '^[^=]*'";
    };
    interactiveShellInit = lib.mkAfter ''
      ${builtins.readFile ./zsh-command-not-found.sh}

      _keyboard_mode_reset() {
        printf '\033[>4;0m\033[<u\033[=0;1u'
      }
      autoload -Uz add-zsh-hook
      add-zsh-hook precmd _keyboard_mode_reset
    '';
  };
}

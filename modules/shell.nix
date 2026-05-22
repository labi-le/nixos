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
        "git"
      ];
    };
    enableCompletion = true;
    interactiveShellInit = lib.mkAfter ''
      command_not_found_handler() {
        local cmd="$1"
        print -u2 "zsh: command not found: $cmd"

        if command -v nix-locate >/dev/null 2>&1 && nix-locate --minimal --no-group --type x --whole-name --at-root "/bin/$cmd" >/dev/null 2>&1; then
          print -u2 "use: nix run nixpkgs#$cmd --"
        fi

        return 127
      }
    '';
  };
}

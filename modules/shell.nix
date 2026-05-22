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
      typeset -g __NIX_RUN_MISSING_STATE_FILE="''${XDG_STATE_HOME:-$HOME/.local/state}/zsh-last-missing-command"

      command_not_found_handler() {
        local cmd="$1"
        local state_file="$__NIX_RUN_MISSING_STATE_FILE"
        print -u2 "zsh: command not found: $cmd"

        mkdir -p -- "''${state_file:h}" 2>/dev/null || true
        : >| "$state_file"

        local arg
        for arg in "$@"; do
          print -r -- "''${(qqqq)arg}" >>| "$state_file"
        done

        if command -v nix-locate >/dev/null 2>&1 && nix-locate --minimal --no-group --type x --whole-name --at-root "/bin/$cmd" >/dev/null 2>&1; then
          print -u2 "use: nix run nixpkgs#$cmd --"
        fi

        return 127
      }

      nix-run-last-missing-command() {
        local state_file="$__NIX_RUN_MISSING_STATE_FILE"
        if [[ ! -r "$state_file" ]]; then
          print -u2 "no recent command-not-found entry"
          return 1
        fi

        local line
        local -a missing=()
        while IFS= read -r line; do
          missing+=("''${(Q)line}")
        done < "$state_file"

        if (( ''${#missing[@]} == 0 )); then
          print -u2 "no recent command-not-found entry"
          return 1
        fi

        local cmd="$missing[1]"
        local -a attrs=()
        attrs=("''${(@f)$(nix-locate --minimal --no-group --type x --whole-name --at-root "/bin/$cmd" 2>/dev/null)}")

        if (( ''${#attrs[@]} == 0 )); then
          print -u2 "no nixpkgs package found for: $cmd"
          return 1
        fi

        local chosen=""
        local attr
        for attr in "''${attrs[@]}"; do
          if [[ "''${attr%%.*}" == "$cmd" ]]; then
            chosen="$attr"
            break
          fi
        done

        if [[ -z "$chosen" ]]; then
          if (( ''${#attrs[@]} == 1 )); then
            chosen="$attrs[1]"
          else
            print -u2 "multiple packages provide $cmd:"
            printf '%s\n' "''${attrs[@]}" >&2
            return 1
          fi
        fi

        local run_attr="$chosen"
        if [[ "$run_attr" == *.out ]]; then
          run_attr="''${run_attr%.out}"
        fi

        local run_cmd="nix run nixpkgs#$run_attr --"
        local arg
        for arg in "''${missing[@]:1}"; do
          run_cmd+=" ''${(q)arg}"
        done
        print -r -- "$run_cmd"
      }

      nix-run-last-missing() {
        local run_cmd
        run_cmd="$(nix-run-last-missing-command)" || return
        eval "$run_cmd"
      }

      __nix_run_accept_line() {
        if [[ "$BUFFER" == '``' ]]; then
          BUFFER="$(nix-run-last-missing-command)" || return
          CURSOR=''${#BUFFER}
          return
        fi
        zle .accept-line
      }
      zle -N accept-line __nix_run_accept_line
    '';
  };
}

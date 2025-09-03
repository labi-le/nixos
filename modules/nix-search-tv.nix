{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    (buildEnv {
      name = "nix-search-tv-with-fzf";
      paths = [
        nix-search-tv
        fzf
      ];
      pathsToLink = [ "/bin" ];
    })
  ];

  environment.interactiveShellInit = ''
    alias ns="nix-search-tv print | fzf --preview 'nix-search-tv preview {}' --scheme history"
  '';
}

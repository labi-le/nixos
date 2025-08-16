{ pkgs, ... }:
{

  environment.systemPackages = with pkgs; [ nix-search-tv ];
  environment.interactiveShellInit = ''
    alias ns="nix-search-tv print | fzf --preview 'nix-search-tv preview {}' --scheme history"
  '';

}

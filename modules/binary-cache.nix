{
  pkgs,
  ...
}:

{
  services.nix-serve = {
    enable = true;
    # Просто заменяем пакет на nix-serve-ng
    package = pkgs.nix-serve-ng;
  };
}

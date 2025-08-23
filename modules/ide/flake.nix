# modules/ide/flake.nix
{
  description = "Wrapped ide with custom options";

  outputs =
    { self }:
    {
      nixosModules.default = ./module.nix;
    };
}

{
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=-1
  '';

  # Passwordless sudo for the frequent admin commands only; everything else
  # still needs the password. Lets the login password be strong without
  # prompting on every `make switch` / `make cleanup`.
  security.sudo.extraRules = [
    {
      groups = [ "wheel" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/nix-collect-garbage";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}

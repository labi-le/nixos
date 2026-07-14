{
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=-1
  '';

  # Passwordless sudo for the one frequent admin command only; everything else
  # still needs the password. Lets the login password be strong without
  # prompting on every `make switch` / nixos-rebuild.
  security.sudo.extraRules = [
    {
      groups = [ "wheel" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}

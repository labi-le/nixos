{
  inputs,
  pkgs,
  user,
  ...
}:

{
  imports = [ inputs.index-repo.nixosModules.default ];

  services.index-repo = {
    enable = true;
    host = "192.168.1.2";
    package = pkgs.index-repo;
    debounce = 15000;
  };

  users.users.${user.name}.linger = true;
}

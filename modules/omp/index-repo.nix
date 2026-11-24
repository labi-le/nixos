{
  config,
  inputs,
  pkgs,
  user,
  ...
}:

{
  imports = [ inputs.index-repo.nixosModules.default ];

  services.index-repo = {
    enable = true;
    host = config.network.serverAddress;
    debounce = 15000;
  };

  users.users.${user.name}.linger = true;
}

{ pkgs
, ...
}:

{
  hardware = {
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
      ];
    };
  };
  services.lact.enable = true;
}

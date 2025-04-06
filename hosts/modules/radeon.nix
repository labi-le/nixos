{ pkgs
, ...
}:

{
  hardware = {
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        amdvlk
      ];
    };

    amdgpu = {
      amdvlk.enable = true;
    };
  };
  environment.systemPackages = with pkgs; [
    lact
  ];

  systemd.services.lact = {
    description = "AMDGPU Control Daemon";
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.lact}/bin/lact daemon";
    };
    enable = true;
  };
}

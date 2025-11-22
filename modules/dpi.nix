let
  port = 1080;
in
{
  services.byedpi = {
    enable = true;
    extraArgs = [
      "--ip"
      "0.0.0.0"
      "--port"
      (toString port)

      "--split"
      "1"
      "--disorder"
      "3+s"
      "--mod-http=h,d"
      "--auto=torst"
      "--tlsrec"
      "1+s"
    ];
  };

  networking.firewall = {
    allowedTCPPorts = [ port ];
  };
}

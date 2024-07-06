{ ... }:

{
  #environment.systemPackages = with pkgs; [
  #  belphegor
  #];
  services.belphegor = {
    enable = true;
    useWlClipboard = true;
    user = "labile";
    debug = true;
  };
}


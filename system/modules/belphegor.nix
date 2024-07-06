{ pkgs, ... }:

{
  #environment.systemPackages = with pkgs; [
  #  belphegor
  #];
  services.belphegor = {
    enable = true;
    useWlClipboard = true;
    debug = true;
  };
}


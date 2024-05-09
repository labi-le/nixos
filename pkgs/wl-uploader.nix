{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenv.mkDerivation rec {
  name = "wl-uploader";
  src = pkgs.fetchurl {
    url = "https://github.com/labi-le/wl-paste-uploader/releases/download/v1.0.1/wl-uploader_1.0.1_linux_amd64";
    sha256 = "56fb1d5a121e0177150342ec3133ac5ae08692d16d0ff844fad1295aff3bc7f5";
  };

  phases = [ "installPhase" ];

  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/wl-uploader
    chmod +x $out/bin/wl-uploader
  '';
}

{ pkgs ? import <nixpkgs> { } }:

let
  version = "1.1.1";
  name = "belphegor";
in
pkgs.stdenv.mkDerivation {
  inherit name version;
  src = pkgs.fetchurl {
    url = "https://github.com/labi-le/belphegor/releases/download/v${version}/belphegor_${version}_linux_amd64";
    sha256 = "52d5b2690b49aa56f0f653447f097b172cac3c91868363c40eea8160cc802651";
  };

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/${name}
    chmod +x $out/bin/${name}
  '';

  meta = with pkgs.lib; {
    description = "Belphegor is a clipboard manager that allows you to share your clipboard with other devices on the network";
    homepage = "https://github.com/labi-le/belphegor";
    license = licenses.mit;
  };
}

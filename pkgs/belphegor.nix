{ pkgs ? import <nixpkgs> { } }:

let
  version = "1.1.0";
  name = "belphegor";
in
pkgs.stdenv.mkDerivation {
  inherit name version;
  src = pkgs.fetchurl {
    url = "https://github.com/labi-le/belphegor/releases/download/v${version}/belphegor_${version}_linux_amd64";
    sha256 = "52910b8dfadb30bcf9aad80081a9cf433640c09a0671e9461830a319ab967ea0";
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

{ pkgs ? import <nixpkgs> { } }:

let
  version = "1.0.2";
  name = "belphegor";
in
pkgs.stdenv.mkDerivation {
  inherit name version;
  src = pkgs.fetchurl {
    url = "https://github.com/labi-le/belphegor/releases/download/v${version}/belphegor_${version}_linux_amd64";
    sha256 = "42abb3d03b02a383743adbc82d39b38e849c191cff453b8740436038cb85b1b4";
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

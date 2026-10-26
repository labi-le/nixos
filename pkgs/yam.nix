{
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "yam";
  version = "0.1.17";

  src = fetchurl {
    url = "https://github.com/nyakokitsu/yam/releases/download/v${finalAttrs.version}/yam-x86_64-unknown-linux-musl";
    hash = "sha256-gc92BzqPhhgXENs3NWuy8uiy/hNIkx3OTFQ92GCXKXc=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/yam
    runHook postInstall
  '';

  meta = {
    description = "Package manager CLI for Yandex Station extensions";
    homepage = "https://github.com/nyakokitsu/yam";
    platforms = [ "x86_64-linux" ];
    mainProgram = "yam";
  };
})

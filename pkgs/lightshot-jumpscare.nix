{
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "lightshot-jumpscare";
  version = "unstable-2026-04-19";

  src = fetchFromGitHub {
    owner = "colouredflower";
    repo = "lightshot-jumpscare";
    rev = "f3b9415cc1ff60b2de64c6fb27099837322c1d27";
    hash = "sha256-YmRD77muqwhQyF5xa15meo99J7Ex6DVINoBL1KZfdAA=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r . $out/
    runHook postInstall
  '';

  meta = {
    description = "Static mirror of pnrtscr.com, a lightshot screenshot prank site";
    homepage = "https://github.com/colouredflower/lightshot-jumpscare";
  };
})

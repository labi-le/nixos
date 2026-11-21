{
  lib,
  fetchFromGitHub,
  buildHomeAssistantComponent,
  python3Packages,
  mini-racer,
}:

buildHomeAssistantComponent rec {
  owner = "Tasshack";
  domain = "dreame_vacuum";
  version = "2.0.3";

  src = fetchFromGitHub {
    owner = "Tasshack";
    repo = "dreame-vacuum";
    tag = "v${version}";
    hash = "sha256-CAx0vhpFybmXGERGBTGIBjzByPsX2b6WQgPBlCmpYys=";
  };

  dependencies = (with python3Packages; [
    numpy
    pycryptodome
    python-miio
    paho-mqtt
  ]) ++ [ mini-racer ];

  meta = {
    changelog = "https://github.com/Tasshack/dreame-vacuum/releases/tag/v${version}";
    description = "Home Assistant integration for Dreame, MOVA, Mijia and Trouver robot vacuums";
    homepage = "https://github.com/Tasshack/dreame-vacuum";
    license = lib.licenses.mit;
  };
}

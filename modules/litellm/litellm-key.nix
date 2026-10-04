{ writeShellApplication, python3 }:

writeShellApplication {
  name = "litellm-key";
  runtimeInputs = [ python3 ];
  text = ''
    exec python3 ${./litellm-key.py} "$@"
  '';
}

{
  writeShellApplication,
  python3,
  runCommand,
}:

let
  binary = writeShellApplication {
    name = "litellm-key";
    runtimeInputs = [ python3 ];
    text = ''
      exec python3 ${./litellm-key.py} "$@"
    '';
  };
in
runCommand "litellm-key" { } ''
  mkdir -p $out/bin $out/share/zsh/site-functions
  ln -s ${binary}/bin/litellm-key $out/bin/litellm-key
  install -m644 ${./_litellm-key} $out/share/zsh/site-functions/_litellm-key
''

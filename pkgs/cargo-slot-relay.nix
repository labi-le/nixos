{
  writeShellScript,
  writeTextFile,
  python3,
}:

{
  server = writeShellScript "cargo-slot-relay" "exec ${python3}/bin/python3 ${./cargo-slot-relay.py} --serve \"$@\"";
  client = writeTextFile {
    name = "cargo-slot";
    destination = "/bin/cargo-slot";
    executable = true;
    text = builtins.readFile ./cargo-slot-client.py;
  };
}

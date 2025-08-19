{ pkgs }:
with pkgs;
[
  postman
  (symlinkJoin {
    name = "rust-rover-wrapped";
    paths = [ jetbrains.rust-rover ];
    buildInputs = [ makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/rust-rover \
        --set PKG_CONFIG_PATH "${openssl.dev}/lib/pkgconfig" \
        --set LD_LIBRARY_PATH "${lib.makeLibraryPath [ openssl ]}" \
        --prefix PATH : "${
          lib.makeBinPath [
            pkg-config
            cargo
            rustup
          ]
        }"
    '';
  })
  jetbrains.phpstorm
  # jetbrains.clion
  # jetbrains.pycharm-professional
  jetbrains.goland
]

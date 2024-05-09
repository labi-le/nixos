{ pkgs
, ...
}:

{
  home.packages = with pkgs; [
    wayshot
    swappy

    (writeShellScriptBin "capture-area" ''
      wayshot -s "$(slurp)" --stdout | wl-copy
    '')

    (writeShellScriptBin "capture-all" ''
      wayshot --stdout | wl-copy
    '')

    (writeShellScriptBin "capture-edit" ''
      wayshot -s "$(slurp)" --stdout | swappy -f - -o -
    '')

  ];

}

{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    wayshot
    swappy

    (pkgs.writeShellScriptBin "capture-area" ''
      wayshot -s "$(slurp)" --stdout | wl-copy
    '')

    (pkgs.writeShellScriptBin "capture-all" ''
      wayshot --stdout | wl-copy
    '')

    (pkgs.writeShellScriptBin "capture-edit" ''
      wayshot -s "$(slurp)" --stdout | swappy -f - -o -
    '')

  ];

}

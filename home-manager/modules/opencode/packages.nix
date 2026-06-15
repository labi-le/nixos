{ pkgs
, ...
}:

{
  home.packages = [
    (pkgs.python3Packages.buildPythonApplication rec {
      pname = "desloppify";
      version = "1.0";
      pyproject = true;

      src = pkgs.python3Packages.fetchPypi {
        inherit pname version;
        hash = "sha256-32Q64GxBNN8fM+UpQ5YmIaFO1G+x8Jga5bokU4eTd+c=";
      };

      build-system = with pkgs.python3Packages; [ setuptools ];
      dependencies = with pkgs.python3Packages; [
        tree-sitter
        tree-sitter-language-pack
        defusedxml
        bandit
        pillow
        pyyaml
      ];
      doCheck = false;
    })
    pkgs.nodejs
    pkgs.uv
  ];
}

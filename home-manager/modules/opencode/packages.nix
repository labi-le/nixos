{ pkgs
, ...
}:

{
  home.shellAliases = {
    oo = "opencode";
  };

  home.packages = [
    (pkgs.python3Packages.buildPythonApplication rec {
      pname = "desloppify";
      version = "0.9.15";
      pyproject = true;

      src = pkgs.python3Packages.fetchPypi {
        inherit pname version;
        hash = "sha256-AXDPIBIvvRba50EQUA5iuXgdfdk/5di8GBlSjFXaPiI=";
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
  ];
}

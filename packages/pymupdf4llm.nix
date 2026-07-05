# pymupdf4llm - LLM-optimized PDF extraction, built from the PyPI wheel.
# Custom/pinned because it requires PyMuPDF >=1.26.6; nixpkgs currently ships 1.24.10.
{ lib, buildPythonPackage, fetchPypi, pymupdf, tabulate }:

buildPythonPackage rec {
  pname = "pymupdf4llm";
  version = "0.2.2";
  format = "wheel";

  src = fetchPypi {
    inherit pname version;
    format = "wheel";
    dist = "py3";
    python = "py3";
    hash = "sha256-53d9CD9ffH2qgEw0I4BMMJp+CW1oJ3PAHp3UuwYPSlY=";
  };

  propagatedBuildInputs = [ pymupdf tabulate ];

  pythonImportsCheck = [ "pymupdf4llm" ];

  meta = with lib; {
    description = "PyMuPDF extension for LLM-optimized PDF extraction";
    homepage = "https://github.com/pymupdf/pymupdf4llm";
    license = licenses.agpl3Only;
  };
}

# Overlay providing custom Python package overrides.
# Adds cvc5, pymupdf4llm, vosk, and patches httplib2/pymupdf to skip flaky tests.
# deadnix: skip
final: prev:
let
  customPythonPackages = pySelf: pySuper: {
    cvc5 = pySelf.callPackage ../packages/python-cvc5.nix { };
    pymupdf4llm = pySelf.callPackage ../packages/pymupdf4llm.nix { };
    vosk = pySelf.callPackage ../packages/python-vosk.nix { };
    # deadnix: skip
    httplib2 = pySuper.httplib2.overridePythonAttrs (old: {
      doCheck = false;
    });
    # deadnix: skip
    pymupdf = pySuper.pymupdf.overridePythonAttrs (old: {
      doCheck = false;
    });
  };
in
{
  python3 = prev.python3.override {
    packageOverrides = customPythonPackages;
  };
}

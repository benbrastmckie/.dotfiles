{ lib
, buildPythonPackage
, fetchurl
, stdenv
, autoPatchelfHook
}:

buildPythonPackage rec {
  pname = "cvc5";
  version = "1.3.3";
  format = "wheel";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/99/f5/7843b57f53001606bb0acc53af13900303814a9e7a29d798390840073c32/cvc5-1.3.3-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
    sha256 = "sha256-ekGx71KvDFuLewqP9nAAFoC3WPt5/nVwNNvp+hhhJlk=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];
  autoPatchelfIgnoreMissingDeps = true;

  postFixup = ''
    # Patch bundled .so files to find libstdc++
    for lib in $out/lib/python*/site-packages/cvc5.libs/*.so*; do
      if [ -f "$lib" ]; then
        patchelf --set-rpath ${stdenv.cc.cc.lib}/lib:$(patchelf --print-rpath "$lib") "$lib" || true
      fi
    done
  '';

  pythonImportsCheck = [ "cvc5" ];

  meta = with lib; {
    description = "Python bindings for CVC5 SMT solver";
    homepage = "https://cvc5.github.io";
    license = licenses.bsd3;
    platforms = platforms.linux;
  };
}

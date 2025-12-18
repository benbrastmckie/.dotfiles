{ lib
, buildPythonPackage
, fetchPypi
, stdenv
, autoPatchelfHook
}:

buildPythonPackage rec {
  pname = "cvc5";
  version = "1.3.2";
  format = "wheel";

  src = fetchPypi {
    inherit pname version;
    format = "wheel";
    python = "cp312";
    abi = "cp312";
    platform = "manylinux2014_x86_64.manylinux_2_17_x86_64";
    sha256 = "sha256-KdTCjjOZJEuN98nlFU8/jEf8+XINvS3TiyxZq8i0DlE=";
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

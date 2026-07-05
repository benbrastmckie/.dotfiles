# Python bindings for the CVC5 SMT solver, built from the manylinux wheel with
# autoPatchelfHook/patchelf rpath fixes for bundled .so files (libstdc++). Custom
# because nixpkgs has no Python cvc5 wheel package.
{
  lib,
  buildPythonPackage,
  fetchurl,
  stdenv,
  autoPatchelfHook,
}:

buildPythonPackage rec {
  pname = "cvc5";
  version = "1.3.3";
  format = "wheel";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/a8/0f/81d6872063607f1e1a8f3367d0ee3771a5570738aa63b7952173db159199/cvc5-1.3.3-cp313-cp313-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
    sha256 = "sha256-vV7AmnMTQsFGCNC8mfPg1k2tt/9ogSbS6k3eJpfk2yc=";
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

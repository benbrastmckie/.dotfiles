{ lib
, buildPythonPackage
, fetchPypi
, autoPatchelfHook
, stdenv
, cffi
, requests
, tqdm
, srt
, websockets
, pythonOlder
}:

buildPythonPackage rec {
  pname = "vosk";
  version = "0.3.45";
  format = "wheel";

  disabled = pythonOlder "3.8";

  src = fetchPypi {
    inherit pname version format;
    dist = "py3";
    python = "py3";
    # Platform-specific wheel for x86_64 Linux (manylinux 2.12+)
    abi = "none";
    platform = "manylinux_2_12_x86_64.manylinux2010_x86_64";
    hash = "sha256-JeAlCTxDmdcnj1Q1aO2MxUYKw6S/SMI2c6zh4l0mYZ8=";
  };

  # Native library patching for libvosk.so
  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    stdenv.cc.cc.lib  # Provides libstdc++.so.6 for C++ extensions
  ];

  propagatedBuildInputs = [
    cffi
    requests
    tqdm
    srt
    websockets
  ];

  # Skip tests since this is a binary wheel
  doCheck = false;

  # Skip imports check - it will fail in build sandbox without models
  pythonImportsCheck = [ ];

  meta = with lib; {
    description = "Offline open source speech recognition API";
    homepage = "https://alphacephei.com/vosk/";
    changelog = "https://github.com/alphacep/vosk-api/releases";
    license = licenses.asl20;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}

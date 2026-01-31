{ lib, stdenv, fetchzip }:

stdenv.mkDerivation rec {
  pname = "vosk-model-small-en-us";
  version = "0.15";

  src = fetchzip {
    url = "https://alphacephei.com/vosk/models/vosk-model-small-en-us-${version}.zip";
    hash = "sha256-7l+bc0sqDJZ8ThsU4J7tffsWClLQkVeuBV6n84zU82A=";
    stripRoot = false;
  };

  installPhase = ''
    mkdir -p $out
    cp -r vosk-model-small-en-us-${version}/* $out/
  '';

  meta = with lib; {
    description = "Vosk speech recognition model - Small English US (~50MB)";
    homepage = "https://alphacephei.com/vosk/models";
    license = licenses.asl20;
    platforms = platforms.all;
  };
}

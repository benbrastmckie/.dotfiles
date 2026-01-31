{ lib, stdenv, fetchurl }:

stdenv.mkDerivation rec {
  pname = "piper-voice-en-us-lessac-medium";
  version = "2023.11.14";

  # Download both the model and config files
  model = fetchurl {
    url = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx";
    hash = "sha256-Xv4J5pkCGHgnr2RuGm6dJp3udp+Yd9F7FrG0buqvAZ8=";
  };

  config = fetchurl {
    url = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json";
    hash = "sha256-7+GcQXvtBV8taZCCSMa6ZQ+hNbyGiw5quz2hgdq2kKA=";
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out
    cp ${model} $out/en_US-lessac-medium.onnx
    cp ${config} $out/en_US-lessac-medium.onnx.json
  '';

  meta = with lib; {
    description = "Piper TTS voice model - US English (Lessac, Medium quality)";
    homepage = "https://huggingface.co/rhasspy/piper-voices";
    license = licenses.mit;
    platforms = platforms.all;
  };
}

# piper - fast, local neural text-to-speech (rhasspy/piper), prebuilt Linux x86_64 binary.
# Fetches the official GitHub release tarball instead of building from source, avoiding
# nixpkgs' piper-tts -> onnxruntime source-compile chain (see task 70 research report).
# NOTE: upstream rhasspy/piper was archived 2025-10-06; 2023.11.14-2 is the final release.
# The tarball bundles libonnxruntime.so.1.14.1 as a precompiled blob (accepted CVE risk for
# local, non-networked TTS). To update (if a fork ships new releases):
#   nix-prefetch-url --type sha256 <new-url>
#   nix hash to-sri --type sha256 <output>
{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  stdenv,
}:
let
  version = "2023.11.14-2";
  src = fetchurl {
    url = "https://github.com/rhasspy/piper/releases/download/${version}/piper_linux_x86_64.tar.gz";
    hash = "sha256-pQy0XzVbevH211jBs2BxeHe6CjmMyMvm0qejom4iWZI=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "piper";
  inherit version src;
  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ]; # libstdc++.so.6 for bundled onnxruntime/phonemize libs
  dontBuild = true;
  dontConfigure = true;
  unpackPhase = ''
    tar -xzf $src
  '';
  # Flat install matching the tarball layout: espeak-ng-data/ resolves relative to the piper
  # binary's own path at runtime (verified with cwd != binary dir, no --espeak_data flag needed).
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp -r piper/* $out/bin/
    chmod +x $out/bin/piper $out/bin/espeak-ng $out/bin/piper_phonemize
    runHook postInstall
  '';
  meta = {
    description = "Fast, local neural text-to-speech (prebuilt binary, bundles onnxruntime)";
    homepage = "https://github.com/rhasspy/piper";
    license = lib.licenses.mit;
    mainProgram = "piper";
    platforms = [ "x86_64-linux" ];
  };
}

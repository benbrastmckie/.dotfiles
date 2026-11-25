# Whisper ggml model weights for whisper.cpp, fetched from Hugging Face. Custom because this is
# model data, not a buildable nixpkgs package -- same reasoning as vosk-models.nix and
# piper-voices.nix.
#
# Note: declaring the weights as a derivation is the point. whisper-cpp ships
# `whisper-cpp-download-ggml-model`, which fetches into a mutable directory at first use; a
# unit that depends on that has a silent network dependency on its first run and no way to
# state which weights it got. Here the store path IS the version.
#
# `rev` pins the model repository rather than tracking `main`: Hugging Face's `main` is a
# moving ref, so a hash pinned against it would be a hash against whatever that branch pointed
# at on the day it was taken.
#
# Two sizes are installed because they are the useful ends of the speed/accuracy trade for
# meeting audio, and together they cost ~630 MB:
#   base.en  (~148 MB) -- the default. Several times faster than real time on this host's 24
#                         cores, adequate for a clear single-speaker-at-a-time meeting.
#   small.en (~488 MB) -- noticeably better on crosstalk, accents and poor headset mics, at
#                         roughly 3x the decode time. Worth switching to when a transcript of a
#                         specific meeting matters.
#
# To add another size, add a fetchurl below and a `cp` line; the names are `ggml-<size>.bin`
# upstream and are kept verbatim so `whisper-cli -m` arguments match upstream documentation.
#
# To update:
#   curl -sfL https://huggingface.co/api/models/ggerganov/whisper.cpp | jq -r .sha
#   nix-prefetch-url --type sha256 https://huggingface.co/ggerganov/whisper.cpp/resolve/<rev>/ggml-<size>.bin
#   nix hash convert --hash-algo sha256 --to sri <output>
{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  rev = "5359861c739e955e79d9a303bcbc70fb988958b1";

  model =
    name: hash:
    fetchurl {
      url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/${rev}/ggml-${name}.bin";
      inherit hash;
    };

  baseEn = model "base.en" "sha256-oDd5yG3zMjB19eeWyyzlAp8A7Ihp7uP9+4l6/jbG0AI=";
  smallEn = model "small.en" "sha256-xhONbVjsyDIgl+D5h8MvG+i7ChhTKj+I9zTRu/nEHl0=";

  # Silero VAD, from a different repository and therefore its own pinned revision: the
  # transcription models above predate whisper.cpp's VAD support and that repository carries no
  # VAD weights at all.
  #
  # This is not an optional nicety. whisper HALLUCINATES over silence -- a long quiet stretch
  # reliably produces invented text like " Thank you." -- and a per-channel meeting recording is
  # mostly silence on each channel by construction, since only one side talks at a time.
  # `--vad` makes whisper skip the silence instead of inventing dialogue for it, which both
  # fixes the transcript and cuts decode time roughly in proportion to how quiet the channel is.
  sileroRev = "9ffd54a1e1ee413ddf265af9913beaf518d1639b";
  sileroVad = fetchurl {
    url = "https://huggingface.co/ggml-org/whisper-vad/resolve/${sileroRev}/ggml-silero-v5.1.2.bin";
    hash = "sha256-KZQNmNQrkfvQXOSJ8+z3xy8KQvAn5IdZGaKPtMBOos8=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "whisper-ggml-models";
  version = "0-unstable-2024-10-29"; # the pinned repository revision's own date

  dontUnpack = true;
  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/whisper-models
    cp ${baseEn} $out/share/whisper-models/ggml-base.en.bin
    cp ${smallEn} $out/share/whisper-models/ggml-small.en.bin
    cp ${sileroVad} $out/share/whisper-models/ggml-silero-v5.1.2.bin
    runHook postInstall
  '';

  meta = {
    description = "Whisper ggml model weights for whisper.cpp (base.en, small.en, silero VAD)";
    homepage = "https://huggingface.co/ggerganov/whisper.cpp";
    # Note: the weights are MIT-licensed like whisper.cpp itself, following OpenAI's release of
    # the original Whisper models under MIT.
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
}

# meetily - privacy-first AI meeting assistant (Zackriya-Solutions/meetily), repackaged from the
# official x86_64 .deb release artifact rather than built from source.
#
# Note: the upstream repository was renamed from `meeting-minutes` to `meetily`; the old name
# still appears in the binary's compiled-in updater endpoint and crate metadata. Releases are
# published under the new name.
#
# == Why the prebuilt .deb and not a source build ==
#
# Same argument as packages/piper-bin.nix (prebuilt binary to avoid an onnxruntime source
# compile), and here it is stronger -- a source build hits four separate problems, two of which
# have no reproducible fix:
#
#   1. `frontend/src-tauri/build.rs` downloads a static ffmpeg tarball from a third-party
#      re-upload (`Zackriya-Solutions/ffmpeg-binaries`) at BUILD time with NO checksum
#      verification anywhere in its `build/ffmpeg.rs` -- it merely runs the result with
#      `-version` and checks the exit status. There is no published hash to pin, so the fetch
#      cannot be turned into a fixed-output derivation honestly.
#   2. The `ort` crate is declared without `default-features = false`, so its default
#      `download-binaries` feature makes `ort-sys` fetch ONNX Runtime 1.22.0 from a vendor CDN
#      at build time. `ORT_LIB_LOCATION` can redirect it, but `ort-sys` 2.0.0-rc.10's
#      pkg-config path demands exactly 1.22.0 while nixpkgs ships 1.27.1 -- an ABI gamble on a
#      release-candidate crate, for the Parakeet transcription backend only.
#   3. whisper.cpp and llama.cpp are both fully vendored inside their -sys crates (186 and 259
#      C/C++ sources), each built through cmake + bindgen. Long, and `llama-helper` additionally
#      needs `CMAKE_DISABLE_FIND_PACKAGE_OpenSSL=TRUE` because llama.cpp's bundled cpp-httplib
#      does not compile against OpenSSL 4.
#   4. A Next.js static export via pnpm has to be staged before `tauri build`, and the two
#      sidecars have to be hand-staged at target-triple-suffixed paths first.
#
# The .deb sidesteps all four. What it costs: no aarch64 (upstream publishes x86_64 Linux only),
# and the transcription/summary engines are whatever upstream's ubuntu-22.04 CI built.
#
# == Layout, and why it is not the obvious one ==
#
# Three resolution mechanisms in the binary constrain where files may go. All three were read
# out of the shipped binary's own strings, not guessed:
#
#   - Resources: `tauri_utils::platform::resource_dir` resolves `$EXE_DIR/../lib/<product-name>`,
#     i.e. the summary templates must sit at `$out/lib/meetily/templates`. This mirrors the
#     .deb's own `/usr/bin/meetily` + `/usr/lib/meetily/templates` split, so the upstream
#     layout is preserved exactly. The product name comes from the binary's compiled-in package
#     info, NOT from the executable's filename, which is why wrapping (and the resulting
#     `.meetily-wrapped`) does not break it.
#   - llama-helper: searched for "relative to executable", with a `MEETILY_LLAMA_HELPER`
#     environment-variable override. The override is used here -- it is explicit and does not
#     require a second binary to sit in `$out/bin`.
#   - ffmpeg: a lookup chain ending in "Found ffmpeg in PATH", with a runtime auto-INSTALL step
#     ("done! installed ffmpeg version ...") if every lookup misses.
#
# Critical: the .deb installs its ffmpeg to `/usr/bin/ffmpeg`. Reproducing that here would put
# `meetily`'s ffmpeg in `$out/bin`, and because home.packages (~/.nix-profile) takes PATH
# priority over environment.systemPackages, installing this package would SHADOW the system
# `ffmpeg` declared in modules/system/packages.nix for every other consumer. So `$out/bin` holds
# the `meetily` entry point and nothing else; ffmpeg is supplied through the wrapper's own PATH.
#
# That wrapper PATH points at nixpkgs' ffmpeg rather than the 79 MB static blob the .deb carries.
# Two reasons: ffmpeg here only pre-converts container formats (mp3/m4a/ogg/aac/mkv/wma -> wav)
# before transcription, which any ffmpeg does; and ffmpeg parses untrusted media, so a
# security-supported build is worth more than bit-identity with upstream's CI. It also keeps the
# unverifiable third-party re-upload from problem 1 above out of the closure entirely. To go back
# to the bundled one, stop deleting it below and install it to `$out/lib/meetily/` instead.
#
# == Updating ==
#
#   nix-prefetch-url --type sha256 <new .deb url>
#   nix hash to-sri --type sha256 <output>
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  alsa-lib,
  cairo,
  dbus,
  ffmpeg,
  gdk-pixbuf,
  glib,
  glib-networking,
  gtk3,
  libappindicator-gtk3,
  libpulseaudio,
  libsoup_3,
  openssl,
  vulkan-loader,
  webkitgtk_4_1,
  xz,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "meetily";
  version = "0.5.0";

  src = fetchurl {
    url = "https://github.com/Zackriya-Solutions/meetily/releases/download/v${finalAttrs.version}/meetily_${finalAttrs.version}_amd64.deb";
    hash = "sha256-x8nVapv4tPe0G2TY0cBNgXTvFQ9FAEOSPigo6qiV1AQ=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    cairo
    dbus
    gdk-pixbuf
    glib
    gtk3
    libpulseaudio
    libsoup_3
    openssl
    stdenv.cc.cc.lib # libstdc++.so.6, libgomp.so.1 for llama-helper
    vulkan-loader
    webkitgtk_4_1
    xz # liblzma.so.5
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 usr/bin/meetily -t $out/bin
    install -Dm755 usr/bin/llama-helper -t $out/lib/meetily
    install -Dm644 usr/lib/meetily/templates/*.json -t $out/lib/meetily/templates

    install -Dm644 usr/share/applications/meetily.desktop -t $out/share/applications
    for icon in usr/share/icons/hicolor/*/apps/meetily.png; do
      size=$(basename "$(dirname "$(dirname "$icon")")")
      install -Dm644 "$icon" "$out/share/icons/hicolor/$size/apps/meetily.png"
    done

    runHook postInstall
  '';

  # Critical: the tray indicator is dlopen'd, so autoPatchelfHook cannot see it from the ELF
  # headers (it is absent from the binary's DT_NEEDED list but present in the .deb's Depends).
  # It has to be on LD_LIBRARY_PATH or the system-tray icon silently never appears.
  #
  # glib-networking supplies the GIO TLS backend the webview needs; without it in
  # GIO_EXTRA_MODULES, https:// requests from the webview fail with a TLS-support error.
  preFixup = ''
    gappsWrapperArgs+=(
      --set MEETILY_LLAMA_HELPER "$out/lib/meetily/llama-helper"
      --prefix PATH : "${lib.makeBinPath [ ffmpeg ]}"
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libappindicator-gtk3 ]}"
      --prefix GIO_EXTRA_MODULES : "${glib-networking}/lib/gio/modules"
    )
  '';

  # The bundled sidecars are deliberately dropped: ffmpeg comes from nixpkgs via the wrapper PATH
  # (see the header), and this static build has no .dynamic section for autoPatchelfHook to work
  # with in any case.
  postFixup = ''
    rm -f $out/bin/ffmpeg
  '';

  meta = {
    description = "Privacy-first AI meeting assistant with local transcription and summaries";
    longDescription = ''
      Records meetings, transcribes them locally with Whisper or Parakeet, and writes summaries
      with a bundled llama.cpp sidecar or a local Ollama server. Captures both the microphone and
      system audio (each playback sink's monitor source) over the PulseAudio protocol, so it
      needs PulseAudio or PipeWire's pipewire-pulse compatibility service -- PipeWire's native
      API alone is not enough. Transcription and summary models are downloaded from HuggingFace
      on first use into $XDG_DATA_HOME/com.meetily.ai; none are bundled.
    '';
    homepage = "https://meetily.ai";
    downloadPage = "https://github.com/Zackriya-Solutions/meetily/releases";
    changelog = "https://github.com/Zackriya-Solutions/meetily/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "meetily";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})

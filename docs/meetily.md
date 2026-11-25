# Meetily

Local AI meeting notes: records a call, transcribes it on-device, and writes a summary. Nothing
is uploaded and no bot joins the meeting.

## Where it is declared

| Piece | Location |
|-------|----------|
| Derivation | `packages/meetily.nix` |
| Overlay wiring | `overlays/unstable-packages.nix` (`meetily = final.callPackage ...`) |
| Installed via | `home.packages` in `modules/home/packages/media-dictation.nix` |
| Audio prerequisite | `services.pipewire.pulse.enable` in `modules/system/audio.nix` (already on) |

Not in nixpkgs, so it is a custom derivation. It repackages upstream's official x86_64 `.deb`
release artifact rather than building from source; `packages/meetily.nix`'s header comment gives
the full argument, the short version being that a source build pulls an **unchecksummed** ffmpeg
tarball and an ONNX Runtime binary from vendor CDNs at build time, neither of which can be pinned
reproducibly. Same reasoning as `packages/piper-bin.nix`.

## How it captures a meeting

There is no Zoom or Google Meet integration, and that is the point: Meetily never joins the
call. It records the two audio streams the call produces and transcribes those, so it is
indifferent to which conferencing app is running.

- **Your voice** comes from a real input source.
- **Everyone else** comes from the playback sink's *monitor* source — the loopback of what the
  speakers are playing.

Capture goes over the **PulseAudio protocol**, not PipeWire's native API. Upstream's
`docs/building_in_linux.md` is explicit that "PipeWire alone is insufficient"; without a
PulseAudio-speaking server it silently degrades to an ALSA whitelist that gets the microphone
only and **no system audio**. On this configuration that is already satisfied —
`modules/system/audio.nix` sets `services.pipewire.pulse.enable = true` (with
`pulseaudio.enable = false`), which is the compatibility server Meetily needs.

Verified on this host: Meetily's own log reports
`pulse_enumerator: connected to PulseAudio/PipeWire server`, then 5 input sources and 3 sinks —
matching `pw-dump`. The `mic_boosted` filter-chain source from
[screen-recording.md](screen-recording.md) shows up as a selectable input like any other, so the
microphone boost applies to recordings too if you pick it.

### Headphones change the answer

Monitor capture records what the sink is playing, so it works on speakers and on headphones
alike. What it cannot do is record a sink that is not being used — if the call audio is routed to
a Bluetooth headset and you select the HDMI sink's monitor, you get silence. Pick the monitor
belonging to the sink the call is actually playing through.

## Summaries

Two backends, both local:

- **Built-in** — a `llama-helper` sidecar (llama.cpp) with GGUF models it downloads on demand.
  Nothing else is needed.
- **Ollama** — Meetily looks for a server at `http://localhost:11434`, which is exactly where
  `services.ollamaModels` (`modules/home/services/ollama.nix`) puts one. That module is enabled
  with `load = [ ]`, so the daemon is running but holds no weights; pulling a model is what makes
  this path usable, either through Meetily's own model UI or with `ollama pull`.

Cloud providers (OpenAI, Anthropic, Groq, a custom OpenAI-compatible endpoint) are also offered
in the settings UI. Choosing one sends transcript text off the machine, which is the same trade
`home.nix` documents at length for Sapience's `anthropic` backend — see [sapience.md](sapience.md).

## What leaves the machine

Recordings, transcripts and summaries stay in
`$XDG_DATA_HOME/com.meetily.ai` (`~/.local/share/com.meetily.ai`): a SQLite database, per-meeting
folders, and a log under `logs/meetily.log`.

Three outbound paths exist, all verified against a first-run of the built package:

| Path | When | Status |
|------|------|--------|
| Model downloads from HuggingFace | First use of a transcription or summary model | Unavoidable; no models are bundled |
| PostHog analytics | Only if opted in | **Off by default** — first run writes `analytics.json` with `"analyticsOptedIn": false` |
| Tauri update check | Only when invoked from the UI | Pointless here; the store path is read-only, so an in-place update cannot apply |

A first run with no interaction made **no** network request at all and logged no errors.

Models land in `com.meetily.ai/models/` (`models/parakeet`, `models/summary`). Whisper
`ggml-*.bin` weights run from ~75 MB (tiny) to ~3 GB (large-v3); the Parakeet ONNX and GGUF
summary models are revision-pinned downloads of similar size. Expect a multi-gigabyte directory
once a few are fetched. This is also why the package is not usable fully offline on first run.

## Disk cost

Measured against the current home-manager generation, adding this package pulls **3 new store
paths, ~297 MiB**: Meetily itself, `webkitgtk` 4.1, and `libappindicator-gtk3`. Its total closure
reads as 1.4 GiB, but nearly all of that (GTK, ffmpeg, the Vulkan loader, glib) was already
present. The model cache under `~/.local/share/com.meetily.ai/models` will outgrow the package
itself.

## Tray icon: GNOME vs niri

Closing the window **hides Meetily to the system tray** rather than quitting it. Whether you can
get it back from there differs by session:

- **niri** — works. `modules/home/desktop/waybar.nix` enables Waybar's `tray` module.
- **GNOME** — the icon is invisible. GNOME 50 has no built-in tray, and
  `modules/home/desktop/gnome.nix` enables no appindicator extension, so a closed window leaves a
  running process with no way back to it short of relaunching.

To fix the GNOME case, add the extension to `modules/home/desktop/gnome.nix`:

```nix
# home.packages (or modules/home/packages/misc.nix)
gnomeExtensions.appindicator

# dconf.settings."org/gnome/shell".enabled-extensions
"appindicatorsupport@rgcjonas.gmail.com"
```

Until then, quit from the application menu rather than the window close button.

## Troubleshooting

**Logs.** `~/.local/share/com.meetily.ai/logs/meetily.log` holds structured, file-and-line
annotated output and is the first place to look. `MEETILY_DEBUG_LOG=1` raises verbosity.

**No system audio in a recording.** Check that a monitor source was selected rather than only a
microphone, and that `systemctl --user status pipewire-pulse` is running. `pactl list short sources`
lists the monitors available.

**Blank or black window.** Tauri apps on Wayland with webkitgtk sometimes need the DMABUF
renderer disabled. Test it without a rebuild:

```bash
WEBKIT_DISABLE_DMABUF_RENDERER=1 meetily
```

If that fixes it, make it permanent with a `--set` in `preFixup`'s `gappsWrapperArgs` in
`packages/meetily.nix`. It is deliberately not set by default — it falls back to a slower
rendering path, and this host's AMD iGPU has not needed it.

**Summaries fail with the Ollama backend.** The daemon carries no models by default
(`load = [ ]` in `home.nix`); `ollama list` will be empty. Pull one, or switch to Meetily's
built-in backend.

## Updating

```bash
nix-prefetch-url --type sha256 \
  https://github.com/Zackriya-Solutions/meetily/releases/download/vX.Y.Z/meetily_X.Y.Z_amd64.deb
nix hash to-sri --type sha256 <output>
```

Put the version and SRI hash in `packages/meetily.nix`. Upstream publishes **x86_64 only** — no
aarch64 Linux artifact exists, which is why the derivation's `meta.platforms` is a single entry
rather than `lib.platforms.linux`.

Worth re-checking on each bump: the three resolution mechanisms the derivation depends on (the
`../lib/meetily` resource directory, the `MEETILY_LLAMA_HELPER` override, and ffmpeg-on-PATH).
They were read out of the shipped binary's strings, not from documented API, so upstream can
change them without notice. The log line `Bundled templates directory set to: ...` pointing into
the Nix store is the quickest confirmation that the first one still holds.

## Removing it

Drop the `meetily` line from `modules/home/packages/media-dictation.nix` and rebuild. The
derivation and overlay entry can stay; nothing else references them. Application data under
`~/.local/share/com.meetily.ai` is not managed by Nix and has to be deleted by hand — worth
doing, since the model cache is the large part.

[← Back to documentation index](README.md)

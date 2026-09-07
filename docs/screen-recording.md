# Screen Recording

Screen capture with audio on GNOME/Wayland, and the PipeWire filter chain that makes the
microphone usable in recordings.

## Installed tools

| Tool | Declared in | Purpose |
|------|-------------|---------|
| `kooha` | `modules/system/packages.nix` | Simple GTK recorder; custom overlay adds AAC/MP4 support |
| `gpu-screen-recorder` | `modules/system/desktop.nix` (`programs.gpu-screen-recorder.enable`) | CLI recorder using VAAPI hardware encoding |
| `gpu-screen-recorder-gtk` | `modules/system/packages.nix` | GTK front-end for the above |
| `obs-studio` | `modules/home/packages/media-dictation.nix` | Full studio; live level meters and audio filters |
| GNOME built-in | (part of GNOME Shell) | Screenshot UI screencast. Video only |

`programs.gpu-screen-recorder.enable` also builds the `gsr-kms-server` setcap wrapper at
`/run/wrappers/bin/gsr-kms-server`, which is what allows recording to start without a
permission prompt each time.

### Choosing between them

- **Kooha** for quick single-track captures where you do not need to rebalance audio afterwards.
- **gpu-screen-recorder** when you want separate audio tracks, hardware encoding, or explicit
  control over quality and framerate.
- **OBS** when you need to watch a live level meter while speaking, or need per-source filters.
- **GNOME built-in** does not capture microphone audio at all. It is fine for silent clips only.

## Microphone: the "Mic (Boosted)" source

### Why it exists

The HyperX SoloCast at unity gain records correctly but far too quietly for a screencast.
Measured on normal speech, before any processing:

| Measure | Raw SoloCast | Target for speech |
|---------|--------------|-------------------|
| Mean    | -35.0 dB     | -18 to -20 dB     |
| Peak    | -13.5 dB     | -6 to -3 dB       |

That is roughly 15 dB too quiet. Flat gain cannot fix it: the gap between mean and peak is
about 21 dB, so adding the 15 dB the mean needs would push peaks past 0 dBFS and clip. The
level has to be compressed before it is raised.

Neither Kooha nor the GNOME screencast exposes any gain, compressor, or level meter, so the
correction is applied once in PipeWire where every application benefits from it.

### What it does

`modules/system/audio.nix` declares a `libpipewire-module-filter-chain` virtual source named
**Mic (Boosted)** (node name `mic_boosted`):

1. **SC4 compressor** — threshold -26 dB, ratio 4:1, RMS detection, +16 dB makeup gain.
   Peaks are pulled down before the whole signal is raised.
2. **Fast lookahead limiter** — hard ceiling at -2 dB, so nothing can clip regardless of
   how loud the input gets.

Both plugins come from `pkgs.ladspaPlugins` (the SWH set), made visible to PipeWire through
`services.pipewire.extraLadspaPackages`.

Measured result through the chain:

| Measure | Raw | Mic (Boosted) |
|---------|-----|---------------|
| Mean    | -35.0 dB | -20.0 dB |
| Peak    | -13.5 dB | -2.0 dB  |

### Critical: plugins are referenced by bare name

PipeWire resolves LADSPA plugins against `LADSPA_PATH`, not as filesystem paths. The
`plugin` field must be a bare filename with no directory and no `.so` extension
(`sc4_1882`, not `/nix/store/.../sc4_1882.so`). An absolute path is silently appended to
the search directory and fails to load, taking the whole filter chain down with it:

```
failed to load plugin '/nix/store/.../sc4_1882.so' in '/nix/store/...-pipewire-ladspa-plugins/lib/ladspa'
spa.filter-graph: can't load graph: No such file or directory
pw.conf: could not load mandatory module "libpipewire-module-filter-chain"
```

`services.pipewire.extraLadspaPackages` is what populates that search directory. Adding a
plugin package there is required before referencing any of its plugins.

### It is additive, not a replacement

The raw `alsa_input.usb-HP__Inc_HyperX_SoloCast-00.analog-stereo` device is untouched and
still available. Applications must select **Mic (Boosted)** explicitly, or the system
default input must be changed to it. This keeps A/B comparison possible and means the
filter chain cannot silently break an application that was working before.

### Adjusting the level

Change `"Makeup gain (dB)"` in `modules/system/audio.nix` and rebuild. Every application
picks up the new value. Verify with:

```bash
# Record 20 seconds while speaking normally
timeout 20 pw-record --target mic_boosted /tmp/mic.wav

# Report mean and peak level
ffmpeg -hide_banner -i /tmp/mic.wav -af volumedetect -f null - 2>&1 | grep volume
```

Aim for a mean near -20 dB and peaks between -6 and -2 dB. A peak reading of exactly
-2.0 dB means the limiter is engaging, which is expected on occasional loud syllables.

## Usage

### Kooha

Records whatever source is the system default input, and mixes microphone and desktop audio
into a **single track**. If desktop audio is playing, the voice cannot be separated from it
afterwards. To use the boosted microphone, set it as the default input in
GNOME Settings, Sound.

Kooha settings live in dconf and can be inspected with:

```bash
dconf dump /io/github/seadve/Kooha/
```

### gpu-screen-recorder

Each `-a` flag adds a **separate** audio track, so voice and desktop audio stay independent:

```bash
gpu-screen-recorder -w portal -f 10 -q ultra \
  -a mic_boosted \
  -a alsa_output.pci-0000_c1_00.6.analog-stereo.monitor \
  -o ~/Videos/capture.mp4
```

- `-w portal` is the capture path that works under GNOME's Mutter. The wlroots-based
  recorders (`wf-recorder`, `wl-screenrec`) require the `wlr-screencopy` protocol, which
  Mutter does not implement, and therefore do not work in the GNOME session.
- `-f` sets framerate. Low framerates keep files small; per-frame sharpness is controlled
  by `-q`, not by `-f`.
- List device names with `gpu-screen-recorder --list-audio-devices`.

Stop with Ctrl-C. The GTK front-end (`gpu-screen-recorder-gtk`) exposes the same options and
ships no desktop entry, so launch it from a terminal.

## Troubleshooting

### Volume keys stop working after an audio change

**Critical:** anything that restarts PipeWire, including `nixos-rebuild switch`, can leave the
GNOME volume keys dead until the media-keys daemon is cycled.

`gsd-media-keys` opens a single PulseAudio connection at login and has no reconnect logic.
When `pipewire-pulse` restarts underneath it, the connection dies silently. The keypresses
are still received and PipeWire is still healthy, but the daemon translating keypress into
volume change is writing to a closed socket.

Confirm by checking whether it appears as a client:

```bash
pactl list clients | grep -i "media keys"
```

A working system lists `GNOME Volume Control Media Keys`. If it is absent, restart it:

```bash
systemctl --user restart org.gnome.SettingsDaemon.MediaKeys.target
```

Restart the **`.target`**, not the `.service`. The service sets `RefuseManualStart=true` and
rejects a direct restart. The target only wants that one service, so this does not disturb
gnome-shell or the session.

### The Mic (Boosted) source is missing

Check that the filter chain loaded:

```bash
pactl list short sources | grep mic_boosted
journalctl --user -u pipewire.service --since -10min | grep -iE "filter|ladspa|graph"
```

A `can't load graph` error usually means a plugin name or a control port name is wrong.
Port names must match the plugin exactly; list them with:

```bash
nix shell nixpkgs#ladspa-sdk -c analyseplugin \
  "$(nix build --no-link --print-out-paths nixpkgs#ladspaPlugins)/lib/ladspa/sc4_1882.so"
```

### Restarting PipeWire hits a start-limit

Repeated restarts trip the systemd rate limiter, and the socket units then refuse to start
with `Start request repeated too quickly`. Clear it before restarting again:

```bash
systemctl --user reset-failed pipewire.socket pipewire.service wireplumber.service \
  pipewire-pulse.socket pipewire-pulse.service
systemctl --user restart pipewire.socket pipewire-pulse.socket \
  pipewire.service wireplumber.service pipewire-pulse.service
```

[← Back to docs](README.md)

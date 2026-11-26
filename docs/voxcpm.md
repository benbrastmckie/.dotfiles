# VoxCPM

Zero-shot voice cloning: give it 5-30 seconds of a voice and a sentence, get 48 kHz speech in
that voice. No training step, no transcript of the reference clip, nothing uploaded. It runs on
this laptop's Radeon 890M iGPU through ROCm.

**Read [what it costs](#what-it-costs) before planning anything around it.** A single sentence
takes about nine minutes end to end, almost all of it fixed startup. It works; it is not fast.

There is no voice-configuration step and nothing is stored in the model. Zero-shot means the
reference clip **is** the configuration, so setting up your voice amounts to curating one good
15-25 second wav and keeping it at a stable path.

## Setup

### 1. Enable it on the host

Import the module and set the flag, as `hosts/hamsa/default.nix` does. Any host with an AMD GPU
can do the same:

```nix
imports = [ ../../modules/system/optional/voxcpm.nix ];
programs.voxcpm.enable = true;
```

Then rebuild. Everything comes from the binary cache, so this fetches rather than compiles, but
it is ~5.1 GiB the first time:

```bash
sudo nixos-rebuild switch --flake ~/.dotfiles#"$(hostname)"
```

### 2. Log out and back in

The module adds you to `render` and `video`, and group membership only takes effect in a fresh
session. `newgrp render` gets a shell with the group sooner if you want to test before logging
out.

### 3. Check that the GPU is reachable

```bash
command -v voxcpm            # the CLI is on PATH
ls -ld /opt/rocm             # the tmpfiles symlink HIP resolves device code through
id -nG | tr ' ' '\n' | grep -E 'render|video'
```

All three must pass. A missing `/opt/rocm` or absent groups both mean activation has not
happened, and the symptom downstream is `torch.cuda.is_available()` returning false with no
diagnostic. A working host reports:

```
torch              2.11.0
torch.version.hip  7.2.53211
gpu                AMD Radeon 890M Graphics
gpu memory         15.3 GiB free of 15.3 GiB
```

### 4. Record a reference clip

Any format torchaudio reads will do, but 16 kHz mono is what the model wants and costs nothing
to capture directly. Target the source by node **name**: the numeric ids `wpctl status` prints
are per-session and will not survive a reboot.

```bash
pw-dump | jq -r '.[].info.props | select(."media.class" == "Audio/Source") | ."node.name"'

mkdir -p ~/.local/share/voices
pw-record --target <node.name> --rate 16000 --channels 1 --format s16 \
  ~/.local/share/voices/ref-raw.wav
# Ctrl-C to stop, or add -n 320000 for a self-terminating 20 s capture
```

Aim for 15-25 seconds. What governs the result, heaviest factor first:

- **Register and pace.** The clip sets prosody, not just timbre. Read it the way you want
  generated speech to sound, because that is what gets cloned.
- **Continuous speech.** Gaps over about a second teach it to pause.
- **A quiet room** -- no fan, no keyboard, constant distance from the mic. Noise is reproduced
  as faithfully as voice.
- **Varied phonetics** across a couple of full sentences rather than one short phrase.

Record the raw device, not a boosted or otherwise filtered source: a gain filter's noise floor
and compression both end up in the clone. On a host with the
[boosted-microphone filter chain](screen-recording.md), that means the underlying
`alsa_input.*` node rather than `mic_boosted`.

### 5. Trim and normalise

```bash
sox ~/.local/share/voices/ref-raw.wav ~/.local/share/voices/me.wav \
  silence 1 0.1 1% reverse silence 1 0.1 1% reverse \
  norm -3
sox ~/.local/share/voices/me.wav -n stats
```

That strips leading and trailing silence and normalises to -3 dBFS. Confirm 16000 Hz, 1 channel,
15-30 seconds, `Pk lev dB` at -3 and `Flat factor` at 0 (no clipping) -- then listen to the
file. Any flaw here recurs in every generation made from it.

### 6. First generation

```bash
voxcpm clone --text "This is a test of the cloned voice." \
  --reference-audio ~/.local/share/voices/me.wav \
  --output /tmp/out.wav --device cuda
play /tmp/out.wav
```

The first invocation also bootstraps the PyPI layer and fetches the checkpoint, so it needs the
network and is slower still. Then confirm nothing fell back to CPU -- `voxcpm-benchmark` refuses
to report a number unless `torch.version.hip` is set, so getting a figure at all is the check
passing:

```bash
voxcpm-benchmark ~/.local/share/voices/me.wav
```

## Usage

```bash
# One sentence. The reference clip needs no transcript.
voxcpm clone --text "Some sentence." --reference-audio me.wav --output out.wav

# Many sentences, one per line. Pays the ~8.5 min startup ONCE -- always prefer this
# over repeated `clone` calls.
voxcpm batch --input texts.txt --output-dir ./outs --reference-audio me.wav

# Measure RTF on this host, GPU then CPU.
voxcpm-benchmark me.wav
voxcpm-benchmark me.wav cpu
```

For anything beyond the CLI -- driving the model from your own script, reading the library
source, attempting fine-tuning -- use `nix develop .#voxcpm`, which puts the same interpreter on
PATH along with `rocminfo` and `rocm-smi`. It does not repeat the venv bootstrap; run `voxcpm`
once first, then `source "$VOXCPM_VENV/bin/activate"` to get the PyPI-only packages on
`sys.path`.

### If the clone disappoints

In increasing order of effort:

- **Re-record.** By far the highest-leverage fix; most poor clones are poor clips.
- **`--denoise`** runs the reference through ZipEnhancer, downloaded on first use. Worth trying
  before re-recording if the room was noisy.
- **Hi-Fi mode** -- `--prompt-audio` with an exact `--prompt-text` transcript alongside the
  reference, at the cost of typing out what you said.
- **`--cfg-value`** (default 2.0, useful 1.0-3.0). Higher tracks the reference harder, at some
  cost in naturalness.
- **`--inference-timesteps`** (default 10, upstream documents 4-30). Lowering it is the main
  lever on generation time at an unevaluated quality cost; raising it is the reverse trade.

Past those the next step is LoRA, which is [not wired up](#fine-tuning-is-not-wired-up).

## What it costs

### Time

**A one-shot `voxcpm clone` costs about nine minutes whatever the sentence length.** Measured
here, producing 2.40 s of audio:

| Stage | Wall |
|-------|------|
| Model load: AudioVAE, safetensors, denoiser | ~319 s (by subtraction) |
| `torch.compile` warmup, 10 steps -- the first alone 167 s | 189 s |
| Generation | 41 s |
| **Total** | **549 s** |

About 93% of that is setup, so **plan around the total, not the RTF** -- length only moves the
41 s. Three things act on it:

- **`voxcpm batch`** pays the startup once across every line of the input file. The only way to
  bring the amortised per-sentence cost near the RTF.
- **`--no-optimize`** skips the `torch.compile` warmup; **`--no-denoiser`** skips loading the
  denoiser, which loads by default even when no ZipEnhancer path is set. Between them they
  target most of the 508 s. Neither is measured here, and `--no-optimize` trades against
  steady-state speed.

Generation itself runs at **RTF 6-31, median ~9** -- wall-clock over audio duration, so 10
means ten seconds of compute per second of speech. Upstream reports ~0.3 on an RTX 4090. The spread is
not noise: it is **bimodal**, a fast cluster near 6-9 and a slow one near 25-31, alternating
between identical calls in one process. The iGPU is power-capped at 24-25 W and shares its
budget with 24 CPU cores, so its clock oscillates between a 600 MHz floor and ~1.8 GHz against
a 2.9 GHz ceiling, tracking inversely with CPU load. The fast cluster is the GPU clocked up;
the slow one is it at the floor, and the ~3.5x ratio between clusters matches the clock ratio.

**A measurement taken while the machine is busy is not this tool's speed.** A run competing with
a compile or a busy agent session lands in the slow cluster.

### Memory

The model allocates through GTT, which is system RAM, not a separate pool. `rocminfo` reports a
15.3 GiB pool, but it is the same 30 GB the rest of the system is using, so **do not treat that
figure as headroom**. A benchmark run here was killed by Claude Code's background-shell reaper
when the system went critically low with the model resident and an agent session running. Close
what you can before a long job: a minute of audio means 8-30 minutes of sustained 25 W load on
an already-85 °C laptop.

### Disk

~5.1 GiB downloaded and ~12.6 GiB unpacked for the ROCm closure, from the binary cache. On top
of that, first run fetches the VoxCPM2 checkpoint (~4.7 GiB, 9 files) and the PyPI layer into
`$XDG_STATE_HOME/voxcpm` (`~/.local/state/voxcpm`): weights under `hf/`, the venv under
`venv-<version>/`, the MIOpen cache under `miopen/`. `rm -rf ~/.local/state/voxcpm` is a
complete uninstall of the mutable half.

## Troubleshooting

**`Can not perform a '--user' install. User site-packages are disabled for this Python.`**
`~/.config/pip/pip.conf` here contains `[install] user = true`, which forces `--user` into every
pip invocation including inside a venv, and a Nix python has user site-packages disabled. The
wrapper runs its bootstrap with `PIP_CONFIG_FILE=/dev/null`, isolating it from that file
entirely rather than countering the one flag. Worth knowing more widely: that setting will do
the same to any other Nix-python venv.

**`torch.version.hip` is `None`.** A PyPI torch wheel has shadowed the Nix build, and the wheel
is a CUDA build, so everything would silently run on CPU. `voxcpm-benchmark` checks this and
refuses to report a number. Recover by deleting the venv:
`rm -rf "${XDG_STATE_HOME:-$HOME/.local/state}"/voxcpm/venv-*`.

**`torch.cuda.is_available()` is false but HIP is present.** `/dev/kfd` or `/dev/dri/render*`
is unreachable. The module adds the user to `render` and `video`; a rebuild plus re-login is
needed for group changes to take.

**First generation in each process is slow.** Partly MIOpen: nixpkgs ships prebuilt kernel
databases for gfx900/906/908/90a/942/1030 and none for gfx1150, so MIOpen JIT-compiles on first
use. The wrapper points `MIOPEN_USER_DB_PATH` at `$XDG_STATE_HOME/voxcpm/miopen` so that work
persists. A warm cache does **not** make the first pass fast, though -- most of the warmup cost
is `torch.compile` and the clock behaviour above.

**Everything is slow, consistently.** Check the clock:
`cat /sys/class/drm/card1/device/pp_dpm_sclk`. A `*` on the 600 MHz line means the GPU is at its
floor and the fast cluster is unreachable until whatever else is loading the CPU stops.

## Updating

```bash
curl -sfL https://pypi.org/pypi/voxcpm/json | jq -r .info.version
```

Put the version in `packages/voxcpm.nix`. The next invocation discards the old venv and
rebootstraps, so no manual cleanup is needed. Re-run `voxcpm-benchmark` after a torch or ROCm
bump -- the AOTriton flag and the gfx1150 arch list are both things upstream can change.

## Removing it

Drop the two `voxcpm` lines from `hosts/hamsa/default.nix` and rebuild. The derivation, overlay
and module can stay; nothing else references them. Weights, venv and kernel cache under
`~/.local/state/voxcpm` are not managed by Nix -- delete that directory by hand, since it is the
large part.

---

## How it is built

Reference for editing any of this. Not needed to use it.

| Piece | Location |
|-------|----------|
| Derivation | `packages/voxcpm.nix` |
| Benchmark script | `packages/voxcpm-benchmark.py` |
| Overlay wiring | `overlays/voxcpm-rocm.nix` (curried with the `rocmSupport` package set) |
| ROCm package set | `pkgs-rocm` in `flake.nix`'s `let` block |
| Installed via | `modules/system/optional/voxcpm.nix` (`programs.voxcpm.enable`) |
| Host opt-in | `hosts/hamsa/default.nix` |
| Dev shell | `devShells.voxcpm` in `flake.nix` (`nix develop .#voxcpm`) |

Not in nixpkgs, so it is a custom derivation. Opt-in per host rather than in
`modules/system/packages.nix` because the closure is large and useless without an AMD GPU. Piper
stays in the always-on package list for the opposite reason: a few MB, no GPU, lower quality.

### Why this model

Licensing was compared before performance, because the alternatives fail there regardless of
speed. **VoxCPM2** is Apache-2.0 on both code and weights -- the only candidate with no
downstream question to answer. **IndexTTS-2.5** ships under a custom bilibili agreement whose
section 3.4(c) forbids using the model "to improve any AI model" other than itself and whose
section 1.5(iii) sweeps "re-training, fine-tuning, quantizing, LoRA" into Derivative Work, so
your own fine-tune of your own voice inherits those terms. **F5-TTS** is MIT on code but CC-BY-NC
on weights, because its Emilia training corpus is scraped in-the-wild; the code licence does not
reach them.

### Why gfx1150 works

Search results will tell you ROCm does not support Strix Point. That is true of ROCm 6.x, which
fails on this iGPU with `HIP error: invalid device function`, and it is the single most
misleading thing you will read about this hardware. The pinned nixpkgs carries ROCm 7.2.3, where
`gfx1150` is a first-class target. Both halves are checkable, on whichever host of this flake
you are on:

```bash
# The ROCm runtime's target list
nix eval .#nixosConfigurations."$(hostname)".pkgs.rocmPackages.clr.gpuTargets  # has gfx1150

# The arch list torch itself was compiled for
nix eval --raw .#nixosConfigurations."$(hostname)".pkgs.python3Packages.torchWithRocm.drvPath \
  | xargs grep -ao 'gfx[0-9]*;[^\\"]*' | head -1
# -> gfx900;gfx906;...;gfx1103;gfx1150;gfx1151;gfx1200;gfx1201
```

Grep the semicolon-joined list rather than `PYTORCH_ROCM_ARCH`: the value is backslash-escaped
in the `.drv`, so matching from the variable name stops at the escape.

Because the arch is in the Hydra-built torch, nothing compiles locally. `HSA_OVERRIDE_GFX_VERSION`
is deliberately **not** set -- that override exists for an arch absent from the build, and
setting it here would describe a natively supported GPU as a different one. Community guides
reach for it because they are working around the ROCm 6.x situation above.

`TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1` *is* set by the wrapper. Without it torch declines
AOTriton's fused attention on RDNA 3.5 and falls back to the unfused math path. It is kept
because the fused path is the one upstream optimises, **not** on the strength of a measured
speedup: the apparent 3.5x win turned out to match the run-to-run clock variance exactly, so the
flag's real effect is unresolved. Upstream's naming is a warning that the path is unvetted here;
if it regresses, expect wrong audio or a crash rather than silent slowness.

`PYTORCH_HIP_ALLOC_CONF=expandable_segments:True` reads plausibly, since the GPU has 0.5 GiB of
real VRAM and reaches ~15.3 GiB through GTT. ROCm's allocator rejects it outright with
`expandable_segments not supported on this platform`. It is not set.

### The two-instance nixpkgs arrangement

This is the subtlety worth understanding before editing any of it. `torchWithRocm` is
`torch.override { rocmSupport = true; }`, so a python env containing both it and `torchaudio`
ends up with **two different torches** -- `torchaudio` is built against the default one. Only
moving the whole package set makes torch, torchaudio and torchcodec agree, which is what
`config.rocmSupport = true` does.

That flag lives on its own nixpkgs instance (`pkgs-rocm` in `flake.nix`), not in the shared
`nixpkgsConfig`. In the shared config it would change build defaults across nixpkgs: a mass
rebuild of the system closure, and the plain `torch` in `modules/home/packages/python.nix` would
silently become a 5 GiB ROCm build in every user profile, for consumers with no use for it. The
arrangement follows `overlays/himalaya-pin.nix`, which takes a whole separate package set for
the same shape of reason -- that one to pin a version, this one to move a build flag.

### The split dependency layer

voxcpm declares 22 runtime dependencies. 18 are in nixpkgs, including every compiled one, so
they come from the binary cache. Four are packaged nowhere -- `argbind`, `funasr`, `spaces`,
`wetext` -- and `datasets` is a real conflict: voxcpm requires `datasets<4`, nixpkgs ships
4.5.0.

Those five install from PyPI on first run into a venv created with `--system-site-packages`.
That flag is what makes the arrangement safe: pip sees the Nix torch already satisfying
`torch>=2.5.0` and does not pull its own CUDA wheel over the top. If it ever did, the run would
silently fall back to CPU, which is why `voxcpm-benchmark` asserts `torch.version.hip` before
reporting any number.

This half is **not a reproducible build**, a deliberate trade following the
`packages/aristotle.nix` and `packages/zot.nix` precedent. The venv is keyed on the voxcpm
version, so a `version` bump rebootstraps cleanly, but those five packages float. Closing the
gap means packaging them in `overlays/python-packages.nix`; `funasr` alone pulls a dozen further
undeclared dependencies, which is why it has not been done.

## Fine-tuning is not wired up

Zero-shot needs no training, which is why there is no fine-tuning path here. If zero-shot
quality disappoints, LoRA is the next step and it does not fit at upstream's defaults:

| Model | LoRA | Full fine-tune |
|-------|------|----------------|
| VoxCPM2 (2B) | ~20 GB VRAM | ~40 GB |
| VoxCPM1.5 (750M) | ~12 GB | ~24 GB |

Upstream's figures are at `batch_size=16`, `max_batch_tokens=8192`. This GPU reaches ~15.3 GiB,
so VoxCPM2 LoRA needs a reduced `batch_size` and raised `grad_accum_steps` to fit, while
VoxCPM1.5's fits as published. The dataset is a JSONL manifest of `{"audio", "text"}` with an
optional same-speaker `ref_audio`; upstream suggests 5-50 clips of 3-30 seconds for
single-speaker cloning, 1-3 epochs, with `ref_audio` on 30-50% of samples.

Two alternatives worth knowing about: **VoxCPM1.5** (750M against VoxCPM2's 2B) reports ~0.15
RTF on a 4090 versus VoxCPM2's ~0.3, and its LoRA fits in this GPU's memory where VoxCPM2's does
not. **VoxCPM.cpp** is a ggml/GGUF build with a **Vulkan** backend, which would drive this iGPU
without ROCm at all -- community-maintained, not OpenBMB.

[← Back to documentation index](README.md)

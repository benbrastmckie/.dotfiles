# VoxCPM

Zero-shot voice cloning: give it 5-30 seconds of a voice and a sentence, get 48 kHz speech in
that voice. No training step, no transcript of the reference clip, nothing uploaded. It runs on
this laptop's Radeon 890M iGPU through ROCm.

Read the [performance](#performance-measured-not-estimated) section before planning anything
around it. It works, and it is roughly ten times slower than real time at best.

## Where it is declared

| Piece | Location |
|-------|----------|
| Derivation | `packages/voxcpm.nix` |
| Benchmark script | `packages/voxcpm-benchmark.py` |
| Overlay wiring | `overlays/voxcpm-rocm.nix` (curried with the `rocmSupport` package set) |
| ROCm package set | `pkgs-rocm` in `flake.nix`'s `let` block |
| Installed via | `modules/system/optional/voxcpm.nix` (`programs.voxcpm.enable`) |
| Host opt-in | `hosts/hamsa/default.nix` -- hamsa only |
| Dev shell | `devShells.voxcpm` in `flake.nix` (`nix develop .#voxcpm`) |

Not in nixpkgs, so it is a custom derivation. Opt-in per host rather than in
`modules/system/packages.nix` because the closure is ~5.1 GiB downloaded and ~12.6 GiB unpacked,
and none of it is useful on a host with no AMD GPU. Piper stays in the always-on package list
for the opposite reason: a few MB, no GPU, lower quality.

## Why this model

Three candidates were compared on licensing before performance, because two of them fail there
regardless of how fast they run.

| Model | Code | Weights | Verdict |
|-------|------|---------|---------|
| **VoxCPM2** (2B) | Apache-2.0 | **Apache-2.0** | Chosen |
| IndexTTS-2.5 (0.8B) | bilibili Model Use License | same custom licence | Rejected |
| F5-TTS | MIT | CC-BY-NC | Rejected |

IndexTTS's licence is a custom agreement under PRC law whose section 3.4(c) forbids using the
model "to improve any AI model" other than itself, and whose section 1.5(iii) defines a
Derivative Work to include anything produced by "re-training, fine-tuning, quantizing, LoRA" --
so your own fine-tune of your own voice inherits those terms. F5-TTS's weights are CC-BY-NC
because its Emilia training corpus is scraped in-the-wild; the MIT on its code does not reach
them. VoxCPM2 is Apache-2.0 on both halves, which is the only one of the three with no
downstream question to answer.

Chatterbox was also considered and is retired upstream as of August 2026.

## Why the GPU path works at all

Search results will tell you ROCm does not support Strix Point. That was true of ROCm 6.x, which
fails on this iGPU with `HIP error: invalid device function`, and it is the single most
misleading thing you will read about this hardware. This repository's pinned nixpkgs carries
ROCm 7.2.3, where `gfx1150` is a first-class target. Both halves are checkable:

```bash
# The ROCm runtime's target list
nix eval .#nixosConfigurations.hamsa.pkgs.rocmPackages.clr.gpuTargets   # includes gfx1150

# The arch list torch itself was compiled for
nix eval --raw .#nixosConfigurations.hamsa.pkgs.python3Packages.torchWithRocm.drvPath \
  | xargs grep -ao 'gfx[0-9]*;[^\\"]*' | head -1
# -> gfx900;gfx906;...;gfx1103;gfx1150;gfx1151;gfx1200;gfx1201
```

Grep for the semicolon-joined list rather than for `PYTORCH_ROCM_ARCH`: the value is
backslash-escaped in the `.drv`, so matching from the variable name stops at the escape and
prints nothing useful.

Because the arch is in the Hydra-built torch, nothing compiles locally -- `nix build --dry-run`
on the python env fetches ~5.1 GiB and builds only a trivial env wrapper. Confirmed at runtime:

```
torch              2.11.0
torch.version.hip  7.2.53211
gpu                AMD Radeon 890M Graphics
gpu memory         15.3 GiB free of 15.3 GiB
```

`HSA_OVERRIDE_GFX_VERSION` is deliberately **not** set. That override exists for an arch absent
from the build; setting it here would describe a natively supported GPU as a different one.
Community guides reach for it because they are working around the ROCm 6.x situation above.

## The two-instance nixpkgs arrangement

`torchWithRocm` on its own is not enough, and this is the subtlety worth understanding before
editing any of it. `torchWithRocm` is `torch.override { rocmSupport = true; }`, so a python env
containing both it and `torchaudio` ends up with **two different torches** -- `torchaudio` is
built against the default one. Only moving the whole package set makes torch, torchaudio and
torchcodec agree, which is what `config.rocmSupport = true` does.

That flag lives on its own nixpkgs instance (`pkgs-rocm` in `flake.nix`), not in the shared
`nixpkgsConfig`. In the shared config it would change build defaults across nixpkgs: a
mass rebuild of the system closure, and the plain `torch` in `modules/home/packages/python.nix`
would silently become a 5 GiB ROCm build in every user profile, for consumers with no use for
it. The arrangement follows `overlays/himalaya-pin.nix`, which takes a whole separate package
set for the same shape of reason -- that one to pin a version, this one to move a build flag.

## The split dependency layer

voxcpm declares 22 runtime dependencies. 18 are in nixpkgs, including every compiled one
(`torch`, `torchaudio`, `torchcodec`, `librosa`, `soundfile`, `transformers`, `gradio`,
`matplotlib`, `pyarrow`), so they come from the binary cache. Four are packaged nowhere --
`argbind`, `funasr`, `spaces`, `wetext` -- and `datasets` is a real conflict: voxcpm requires
`datasets<4`, nixpkgs ships 4.5.0.

Those five install from PyPI on first run into a venv created with `--system-site-packages`.
That flag is what makes the arrangement safe: pip sees the Nix torch already satisfying
`torch>=2.5.0` and does not pull its own CUDA wheel over the top. If it ever did, the run would
silently fall back to CPU, so `voxcpm-benchmark` asserts `torch.version.hip` is set before
reporting any number.

This half is **not a reproducible build**, which is a deliberate trade following the
`packages/aristotle.nix` and `packages/zot.nix` precedent. The venv is keyed on the voxcpm
version, so a `version` bump rebootstraps cleanly, but those five packages float. Closing the
gap means packaging them in `overlays/python-packages.nix`; `funasr` alone pulls a dozen further
undeclared dependencies, which is why it has not been done.

## Usage

```bash
# Clone a voice and synthesise. The reference clip needs no transcript.
voxcpm clone --text "Some sentence." --reference-audio me.wav --output out.wav

# Measure RTF on this host, GPU then CPU. Bootstraps the venv on first run.
voxcpm-benchmark me.wav
voxcpm-benchmark me.wav cpu
```

The reference clip should be 5-30 seconds, any format torchaudio reads, ideally 16 kHz. Output
is 48 kHz. Upstream also offers a "Hi-Fi" mode that additionally takes `prompt_wav_path` plus an
exact `prompt_text` transcript alongside the reference, worth trying if plain reference mode is
close but not quite right.

For anything beyond the CLI -- driving the model from your own script, reading the library
source, attempting fine-tuning -- use `nix develop .#voxcpm`, which puts the same interpreter on
PATH along with `rocminfo` and `rocm-smi`. It does not repeat the venv bootstrap; run `voxcpm`
once first, then `source "$VOXCPM_VENV/bin/activate"` to get the PyPI-only packages on
`sys.path`.

## Performance (measured, not estimated)

**Expect RTF around 8-11 at best, and 25-31 when the GPU is down-clocked.** RTF is
wall-clock divided by audio duration, so 10 means ten seconds of compute per second of speech.
Upstream reports ~0.3 on an RTX 4090.

Measured on hamsa, six passes in one process with warm caches and the model already loaded:

| Pass | Wall | Audio | RTF |
|------|------|-------|-----|
| 0 (warmup) | 157.31 s | 6.08 s | 25.87 |
| 1 | 186.91 s | 7.36 s | 25.40 |
| 2 | 40.74 s | 6.40 s | 6.37 |
| 3 | 200.85 s | 6.56 s | 30.62 |
| 4 | 53.95 s | 6.40 s | 8.43 |
| 5 | 69.22 s | 7.52 s | 9.20 |

Median 9.20, min 6.37, max 30.62. The spread is not noise and not a warmup artefact -- it is
**bimodal**, with a fast cluster near 6-9 and a slow one near 25-31, alternating between
identical calls in a single process.

### Why it is bimodal

The iGPU is power- and thermally-capped, and shares its budget with 24 CPU cores. Sampling
`/sys/class/drm/card1/device/pp_dpm_sclk` and the hwmon nodes during a run:

```
15:32:50 sclk=600Mhz  temp=80C power=24W load=23.61
15:37:44 sclk=1611Mhz temp=86C power=25W load=14.20
```

Package power is pinned at 24-25 W and the clock oscillates between 600 MHz and ~1850 MHz
against a 2900 MHz ceiling, at 80-86 °C. The clock tracks inversely with CPU load. The fast
cluster is the GPU near 1.5-1.8 GHz; the slow cluster is it sitting at its 600 MHz floor. The
ratio between clusters (~3.5x) matches the clock ratio.

The practical consequence: **a measurement taken while the machine is busy is not this tool's
speed**, and neither is one taken while it is idle. A run competing with a compile or a busy
agent session lands in the slow cluster. One three-pass run on a quieter machine came in at
10.71 / 8.37 / 8.55, consistently fast.

A corollary worth knowing before a long job: generating a minute of audio means something
between 8 and 30 minutes of sustained 25 W load on an already-85 °C laptop.

### What the AOTriton flag is and is not worth

`TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1` is set by the wrapper. Without it torch declines
AOTriton's fused attention on RDNA 3.5 and logs:

```
Flash Efficient attention on Current AMD GPU is still experimental.
Enable it with TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1.
```

It is kept because the fused path is the one upstream optimises and the fallback is strictly
more work. It is **not** kept on the strength of a measured speedup: single runs came out 24.49
(off), 7.09 (on), 28.82 (on). That looked like a 3.5x win until the repeated run above showed
run-to-run spread of exactly that size, so the flag's real effect is unresolved and smaller than
the clock variance. Upstream's own naming is a warning that the path is unvetted on this arch;
if it regresses, the symptom is wrong audio or a crash rather than silent slowness. Re-check
with `voxcpm-benchmark` after any torch bump.

### Settings tried and rejected

`PYTORCH_HIP_ALLOC_CONF=expandable_segments:True` reads plausibly here -- the GPU has 0.5 GiB of
real VRAM and reaches ~15.3 GiB through GTT, which is system RAM handed out in pages. ROCm's
allocator rejects it outright with `expandable_segments not supported on this platform` and the
run continues unaffected. It is not set.

### Levers not yet pulled

- `inference_timesteps` defaults to 10 and upstream documents 4-30. The generation loop runs at
  roughly one second per step, so dropping it is the most direct speed lever available, at a
  quality cost that has not been evaluated here.
- **VoxCPM1.5** (750M against VoxCPM2's 2B) reports ~0.15 RTF on a 4090 versus VoxCPM2's ~0.3,
  so roughly twice as fast, and its LoRA fits in this GPU's memory where VoxCPM2's does not.
- **VoxCPM.cpp** is a ggml/GGUF build with a **Vulkan** backend, which would drive this iGPU
  without ROCm at all. Community-maintained, not OpenBMB.

## Memory, and a real failure seen

The model allocates through GTT, which is system RAM, not a separate pool. On a 30 GB machine
that competes directly with everything else: `rocminfo` reports a 15.3 GiB pool, but it is the
same 30 GB the rest of the system is using. During this work a benchmark run was killed by
Claude Code's background-shell reaper because the system went critically low on memory with the
model resident and an agent session running.

Plan for it: close what you can before a long job, and do not assume the 15.3 GiB figure is
headroom.

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

## Troubleshooting

**`Can not perform a '--user' install. User site-packages are disabled for this Python.`**
This was hit on the first real run. `~/.config/pip/pip.conf` here contains `[install] user =
true`, which forces `--user` into every pip invocation including inside a venv, and a Nix python
has user site-packages disabled. The wrapper now runs its bootstrap with
`PIP_CONFIG_FILE=/dev/null`, isolating it from that file entirely rather than countering the one
flag. Worth knowing more widely: that setting will do the same to any other Nix-python venv.

**`torch.version.hip` is `None`.** A PyPI torch wheel has shadowed the Nix build, and the wheel
is a CUDA build, so everything would silently run on CPU. `voxcpm-benchmark` checks this and
refuses to report a number. Recover by deleting the venv:
`rm -rf "${XDG_STATE_HOME:-$HOME/.local/state}"/voxcpm/venv-*`.

**`torch.cuda.is_available()` is false but HIP is present.** `/dev/kfd` or
`/dev/dri/render*` is unreachable. `modules/system/optional/voxcpm.nix` adds the user to
`render` and `video`; a rebuild plus re-login is needed for group changes to take.

**First generation in each process is slow.** Partly MIOpen: nixpkgs ships prebuilt kernel
databases for gfx900/906/908/90a/942/1030 and none for gfx1150, so MIOpen JIT-compiles on first
use. The wrapper points `MIOPEN_USER_DB_PATH` at `$XDG_STATE_HOME/voxcpm/miopen` so that work
persists -- confirmed populated, it fills with `gfx1150_8.ukdb` and a `gfx1150_8.HIP` ufdb.
Note that a warm cache did **not** make the first pass fast across runs, so the warmup cost is
not only MIOpen; the clock behaviour above accounts for more of it.

**Everything is slow, consistently.** Check the clock:
`cat /sys/class/drm/card1/device/pp_dpm_sclk`. A `*` on the 600 MHz line means the GPU is at its
floor and the fast cluster is unreachable until whatever else is loading the CPU stops.

## Disk cost

~5.1 GiB downloaded, ~12.6 GiB unpacked for the ROCm closure, from the binary cache. On top of
that, first run fetches the VoxCPM2 checkpoint (9 files) and the PyPI layer into
`$XDG_STATE_HOME/voxcpm` (`~/.local/state/voxcpm`): weights under `hf/`, the venv under
`venv-<version>/`, the MIOpen cache under `miopen/`. `rm -rf ~/.local/state/voxcpm` is a
complete uninstall of the mutable half.

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

[← Back to documentation index](README.md)

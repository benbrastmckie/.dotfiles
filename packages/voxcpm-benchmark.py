"""Measure VoxCPM2's real-time factor on this host, and prove the ROCm build is the one running.

Invoked by `voxcpm-benchmark` (packages/voxcpm.nix), which supplies the venv interpreter and
the environment. Inputs arrive as environment variables rather than argv so the wrapper can
pass them through a single exec without quoting games:

    VOXCPM_REF     path to a 5-30s reference clip of the voice to clone
    VOXCPM_DEVICE  "cuda" (ROCm) or "cpu"
    VOXCPM_TEXT    the sentence to synthesise

RTF is reported as wall-clock / audio-duration, matching upstream's convention: lower is
faster, 1.0 is exactly real time. Upstream's published figure for VoxCPM2 is ~0.3 on an
RTX 4090.
"""

import os
import sys
import time
import wave


def fail(msg):
    print(f"voxcpm-benchmark: {msg}", file=sys.stderr)
    sys.exit(1)


ref = os.environ.get("VOXCPM_REF")
device = os.environ.get("VOXCPM_DEVICE", "cuda")
text = os.environ.get("VOXCPM_TEXT", "")

if not ref or not os.path.isfile(ref):
    fail(f"reference clip not found: {ref!r}")

import torch  # noqa: E402  (imported after the argument check so a typo fails in milliseconds)

# The whole point of the check. The venv is built with --system-site-packages precisely so pip
# treats the Nix ROCm torch as satisfying `torch>=2.5.0`; if a dependency resolution ever pulls
# a PyPI torch over the top, that wheel is a CUDA build, torch.version.hip goes None, and every
# number below would silently describe a CPU run instead.
print(f"torch         {torch.__version__}")
print(f"torch.version.hip  {torch.version.hip}")

if torch.version.hip is None:
    fail(
        "this torch has no HIP/ROCm support -- a PyPI wheel has shadowed the Nix build.\n"
        "  Remove the venv and let it rebootstrap:\n"
        "    rm -rf ${XDG_STATE_HOME:-$HOME/.local/state}/voxcpm/venv-*"
    )

if device != "cpu":
    if not torch.cuda.is_available():
        fail(
            "torch has ROCm support but no GPU is visible. Check that /dev/kfd exists and that\n"
            "  your user is in the `render` and `video` groups."
        )
    print(f"gpu           {torch.cuda.get_device_name(0)}")
    free, total = torch.cuda.mem_get_info()
    print(f"gpu memory    {free / 2**30:.1f} GiB free of {total / 2**30:.1f} GiB")

from voxcpm import VoxCPM  # noqa: E402

print(f"device        {device}")
print(f"reference     {ref}")
print("loading model (first run downloads ~GBs from Hugging Face)...", flush=True)

load_start = time.perf_counter()
# optimize=False: upstream documents torch.compile as "primarily useful on CUDA", and on this
# iGPU the compile cost is not repaid. load_denoiser=False keeps funasr's denoiser out of the
# measurement -- it is a separate model and would inflate both load time and RTF.
model = VoxCPM.from_pretrained(
    "openbmb/VoxCPM2",
    load_denoiser=False,
    device=device,
    optimize=False,
)
print(f"load          {time.perf_counter() - load_start:.1f} s")

out = "/tmp/voxcpm-benchmark.wav"

# Two passes, with only the second reported as the RTF. The first pays MIOpen's JIT kernel
# compilation for gfx1150, for which nixpkgs ships no prebuilt kernel database.
#
# Be careful reading either number. A warm MIOpen cache did NOT make the first pass fast across
# runs on this host, so warmup is not only JIT, and the steady-state figure itself is bimodal:
# the iGPU is power-capped and its clock tracks inversely with CPU load, so the same call varies
# by ~3.5x depending on what else the machine is doing. Two passes cannot separate those, and a
# single run of this script is not a benchmark of the model. See docs/voxcpm.md.
for label in ("warmup", "measured"):
    start = time.perf_counter()
    wav = model.generate(
        text=text,
        reference_wav_path=ref,
        cfg_value=2.0,
        inference_timesteps=10,
    )
    elapsed = time.perf_counter() - start

    import soundfile as sf

    sf.write(out, wav, model.tts_model.sample_rate)

    with wave.open(out) as w:
        audio_seconds = w.getnframes() / w.getframerate()

    rtf = elapsed / audio_seconds
    print(
        f"{label:9s}     {elapsed:6.2f} s wall / {audio_seconds:5.2f} s audio"
        f"  ->  RTF {rtf:.2f}"
    )

print(f"wrote         {out}")
print()
print("RTF below 1.0 is faster than real time. Upstream reports ~0.3 for VoxCPM2 on an")
print("RTX 4090; this GPU has roughly an eighth of that memory bandwidth.")

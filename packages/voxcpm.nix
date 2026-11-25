# voxcpm - zero-shot voice cloning TTS (OpenBMB/VoxCPM2), running on this host's Radeon 890M
# through ROCm. Apache-2.0 on both the code and the model weights, which is why it is here
# rather than one of the alternatives: IndexTTS ships under a custom bilibili agreement that
# forbids using it to improve any other model and sweeps your own LoRA fine-tunes into the same
# terms, and F5-TTS's weights are CC-BY-NC because its Emilia training set is scraped.
#
# == Why the GPU path works here at all ==
#
# The web's standing advice is that ROCm does not support Strix Point. That was true of ROCm
# 6.x, which fails on this iGPU with `HIP error: invalid device function`. It is not true of the
# 7.2.3 that this repo's pinned nixpkgs carries. Two facts, both checkable:
#
#   nix eval .#nixosConfigurations."$(hostname)".pkgs.rocmPackages.clr.gpuTargets
#       -> the ROCm runtime's target list, which includes gfx1150
#   the torch .drv, grepped for its semicolon-joined arch list -- NOT for PYTORCH_ROCM_ARCH,
#   whose value is backslash-escaped there, so a match from the variable name stops at the
#   escape; docs/voxcpm.md has the working one-liner
#       -> the list torch was compiled for, which also includes gfx1150
#
# So the Radeon 890M (gfx1150) is a first-class target in a torch that Hydra already built:
# `nix build --dry-run` on this derivation's python env fetches ~5.1 GiB and compiles nothing.
# HSA_OVERRIDE_GFX_VERSION is deliberately NOT set below -- the override is what you reach for
# when your arch is absent from the build, and setting it here would mis-describe a natively
# supported GPU as a different one.
#
# == Why the caller must pass a rocmSupport package set ==
#
# `torchWithRocm` alone is not enough. It is `torch.override { rocmSupport = true; }`, so an
# env containing both it and `torchaudio` gets two different torches -- torchaudio is built
# against the DEFAULT torch. The fix is to move the whole package set, which is what
# overlays/voxcpm-rocm.nix does by importing nixpkgs with `config.rocmSupport = true` and
# calling this file from there. That flag is scoped to that one nixpkgs instance on purpose:
# setting it in flake.nix's shared nixpkgsConfig would mass-rebuild the system closure, and
# modules/home/packages/python.nix's plain `torch` would silently become a 5 GiB ROCm build in
# every user profile.
#
# == Why the dependency layer is split, and not all Nix ==
#
# voxcpm declares 22 runtime dependencies. 18 are in nixpkgs and all of the compiled ones are
# among them, so they come from the binary cache via `pythonEnv` below. Four are not packaged
# anywhere in nixpkgs (argbind, funasr, spaces, wetext) and `datasets` is a genuine conflict --
# voxcpm requires `datasets<4`, nixpkgs ships 4.5.0. Those five come from PyPI at first run into
# a venv built with `--system-site-packages`, so pip sees the Nix torch as already satisfying
# `torch>=2.5.0` and does NOT pull its own CUDA wheel over the top. That shadowing is the single
# failure mode worth watching for, so `voxcpm-benchmark` asserts `torch.version.hip` is set
# before it measures anything.
#
# The runtime-PyPI half follows the precedent of packages/aristotle.nix and packages/zot.nix.
# It is a real trade-off and not a reproducible build: the venv is keyed on the voxcpm version
# below, so bumping `version` forces a clean rebootstrap, but the five pip packages float.
# Packaging them properly in overlays/python-packages.nix is the way to close that gap; funasr
# alone pulls a dozen further undeclared deps, which is why it is not done here.
#
# == Model weights ==
#
# Not vendored. `openbmb/VoxCPM2` is fetched from Hugging Face on first use into
# $XDG_STATE_HOME/voxcpm/hf (several GB). This is the opposite choice from
# packages/whisper-ggml-models.nix, which declares its weights as a derivation so the store
# path IS the version -- correct there because a systemd unit depends on those weights, and not
# worth it here because voxcpm resolves checkpoints through huggingface-hub's own cache layout
# and revision pinning, which a store path would have to reimplement.
#
# == Updating ==
#
#   curl -sfL https://pypi.org/pypi/voxcpm/json | jq -r .info.version
#
# Bump `version`; the next invocation discards the old venv and rebootstraps. Re-run
# `voxcpm-benchmark` after a torch or ROCm bump -- the AOTriton flag below and the gfx1150 arch
# list are both things upstream can change.
#
# See docs/voxcpm.md.
{
  lib,
  python3,
  ffmpeg,
  symlinkJoin,
  writeShellApplication,
}:

let
  version = "2.0.3";

  # Every compiled dependency lives here, from the binary cache. `ps.torch` is the ROCm build
  # because the calling package set has config.rocmSupport = true (see the header); torchaudio
  # and torchcodec are then built against that same torch rather than the default one.
  pythonEnv = python3.withPackages (ps: [
    ps.torch
    ps.torchaudio
    ps.torchcodec
    ps.transformers
    ps.gradio
    ps.librosa
    ps.soundfile
    ps.matplotlib
    ps.modelscope
    ps.huggingface-hub
    ps.safetensors
    ps.einops
    ps.inflect
    ps.addict
    ps.pydantic
    ps.simplejson
    ps.sortedcontainers
    ps.tqdm
    ps.numpy
    ps.scipy
    ps.pandas
    ps.pyarrow # datasets' only compiled dep, so pip gets a pure-python wheel below
    ps.pip
    ps.setuptools
    ps.wheel
  ]);

  # The five that cannot come from nixpkgs. See the header for why each one is here.
  pipDeps = [
    "voxcpm==${version}"
    "argbind"
    "funasr"
    "spaces"
    "wetext"
    "datasets<4"
  ];

  # Shared by both entry points. Each setting below was kept or dropped on the strength of a
  # measurement from `voxcpm-benchmark` on this host, not on plausibility:
  #
  #   TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL
  #                 Without it torch declines AOTriton's fused attention on RDNA 3.5 ("Flash
  #                 Efficient attention on Current AMD GPU is still experimental") and falls
  #                 back to the unfused math path. Kept because the fused path is the one
  #                 upstream optimises and the fallback is strictly more work, NOT because a
  #                 speedup was established here: single-run RTFs on this host came out 24.49
  #                 (off), 7.09 (on), 28.82 (on), i.e. run-to-run spread swamps the flag.
  #                 See docs/voxcpm.md for the repeated measurement. The name is upstream's
  #                 own warning that the path is unvetted on this arch; re-check with
  #                 `voxcpm-benchmark` after a torch bump.
  #   MIOPEN_*      nixpkgs ships prebuilt MIOpen kernel databases for gfx900/906/908/90a/942/
  #                 1030 and none for gfx1150, so MIOpen JIT-compiles its kernels on first use.
  #                 Without a writable cache that recompilation is paid on EVERY run, and
  #                 MIOpen's default path is inside the read-only store. Confirmed in use: the
  #                 directory fills with gfx1150_8.ukdb and a gfx1150_8.HIP ufdb.
  #   HF_HOME       Pins the multi-GB checkpoint download next to the venv instead of ~/.cache,
  #                 so `rm -rf $state` is a complete uninstall.
  #
  # Not set, having been tried and measured useless: PYTORCH_HIP_ALLOC_CONF=expandable_segments.
  # It reads plausibly -- this GPU has 0.5 GiB of real VRAM and reaches ~15.3 GiB through GTT,
  # which is system RAM in pages -- but ROCm's allocator rejects it outright with
  # "expandable_segments not supported on this platform" and the run continues unaffected.
  prelude = ''
    state="''${XDG_STATE_HOME:-$HOME/.local/state}/voxcpm"
    venv="$state/venv-${version}"

    export HF_HOME="$state/hf"
    export MIOPEN_USER_DB_PATH="$state/miopen"
    export MIOPEN_CUSTOM_CACHE_DIR="$state/miopen"
    export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1
    mkdir -p "$MIOPEN_USER_DB_PATH"

    # Keyed on the voxcpm version, so a `version` bump rebootstraps rather than upgrading in
    # place. The marker is written only after pip succeeds: a half-installed venv from an
    # interrupted first run must not be mistaken for a complete one.
    if [ ! -f "$venv/.bootstrapped" ]; then
      echo "voxcpm: bootstrapping PyPI layer for ${version} (first run only)..." >&2
      rm -rf "$venv"
      ${pythonEnv}/bin/python -m venv --system-site-packages "$venv"
      # This venv is the wrapper's private business, so it is installed into with pip's own
      # defaults and none of the user's. Isolation rather than one counter-flag because any
      # setting in ~/.config/pip/pip.conf can break a managed venv, not just the one that did:
      # `user = true` there forces --user into every install, and a Nix python has user
      # site-packages disabled, so the bootstrap dies on "Can not perform a '--user' install".
      # Env beats config file in pip's precedence; /dev/null reads as an empty config.
      PIP_CONFIG_FILE=/dev/null \
        "$venv/bin/pip" install --quiet --disable-pip-version-check ${lib.escapeShellArgs pipDeps} || {
        echo "voxcpm: PyPI bootstrap failed; not caching a partial venv" >&2
        rm -rf "$venv"
        exit 1
      }
      touch "$venv/.bootstrapped"
    fi
  '';

  voxcpm-cli = writeShellApplication {
    name = "voxcpm";
    runtimeInputs = [ ffmpeg ];
    text = ''
      ${prelude}
      exec "$venv/bin/voxcpm" "$@"
    '';
  };

  # Lives in this derivation rather than in scripts/ because it is useless without the env the
  # prelude above sets up, and because writeShellApplication shellchecks it at build time.
  # scripts/ in this repo is for repository maintenance (update.sh, install.sh), not app tooling.
  voxcpm-benchmark = writeShellApplication {
    name = "voxcpm-benchmark";
    runtimeInputs = [ ffmpeg ];
    text = ''
      ${prelude}

      if [ "$#" -lt 1 ]; then
        echo "usage: voxcpm-benchmark <reference.wav> [device] [text]" >&2
        echo "  reference.wav  5-30s of the voice to clone; no transcript needed" >&2
        echo "  device         cuda (ROCm, default) | cpu" >&2
        exit 2
      fi

      VOXCPM_REF="$1" \
      VOXCPM_DEVICE="''${2:-cuda}" \
      VOXCPM_TEXT="''${3:-The quick brown fox jumps over the lazy dog, and then it does so again to make the sample long enough to time honestly.}" \
      exec "$venv/bin/python" ${./voxcpm-benchmark.py}
    '';
  };
in
symlinkJoin {
  name = "voxcpm-${version}";
  inherit version;
  paths = [
    voxcpm-cli
    voxcpm-benchmark
  ];

  # Exposed so `nix develop .#voxcpm` can put the same interpreter on PATH without restating
  # the dependency list, and so the shell and the CLI cannot drift apart.
  passthru = { inherit pythonEnv; };

  meta = {
    description = "Zero-shot voice cloning TTS (VoxCPM2) on ROCm, with an RTF benchmark";
    longDescription = ''
      Clones a voice from a 5-30 second reference clip with no transcript and no training step,
      and synthesises 48 kHz speech from it. Runs on this host's Radeon 890M via ROCm; pass
      `cpu` to compare. Model weights are downloaded from Hugging Face on first use into
      $XDG_STATE_HOME/voxcpm, as are the five dependencies that nixpkgs does not package.

      LoRA fine-tuning is a separate path that this wrapper does not cover: upstream documents
      it as needing ~20 GB of VRAM at the default batch size, above what this GPU reaches
      through GTT, so it needs a reduced batch_size and raised grad_accum_steps to fit.
    '';
    homepage = "https://github.com/OpenBMB/VoxCPM";
    downloadPage = "https://pypi.org/project/voxcpm/";
    license = lib.licenses.asl20;
    mainProgram = "voxcpm";
    platforms = [ "x86_64-linux" ];
  };
}

# VoxCPM2 voice-cloning TTS — GPU access and the `voxcpm` CLI.
# Optional/host-toggled module: opt in explicitly per host via programs.voxcpm.enable, which
# any host with an AMD GPU can do by importing this file -- hosts/hamsa/default.nix does so
# today (see also flake.nix extraModules). Follows the same arrangement as
# optional/discord-bot.nix.
#
# It is opt-in rather than part of modules/system/packages.nix because of what it weighs. The
# ROCm torch closure is ~5.1 GiB downloaded and ~12.6 GiB in the store, every byte of it from
# the binary cache but none of it useful to a host without an AMD GPU. piper (packages/
# piper-bin.nix) stays in the always-on package list precisely because it is the opposite
# trade: a few MB, no GPU, lower quality.
#
# What this module does NOT do: give the model its weights. Those are fetched from Hugging Face
# on first use into $XDG_STATE_HOME/voxcpm/hf, along with the five PyPI-only dependencies.
# See packages/voxcpm.nix for why that is a deliberate departure from whisper-ggml-models.nix.
#
# See docs/voxcpm.md.
{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  cfg = config.programs.voxcpm;
in
{
  options.programs.voxcpm.enable = lib.mkEnableOption "VoxCPM2 voice-cloning TTS with ROCm GPU access";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.voxcpm ];

    # ROCm reaches the GPU through /dev/kfd and /dev/dri/render*, which are owned by `render`
    # and `video`. Without both, torch.cuda.is_available() returns false with no diagnostic --
    # the benchmark's own error message names this as the thing to check.
    users.users.${username}.extraGroups = [
      "render"
      "video"
    ];

    # The HIP runtime resolves its device code through this path at runtime rather than from a
    # DT_NEEDED entry, so the ELF-based wrapping that works for an ordinary dynamic binary does
    # not cover it.
    systemd.tmpfiles.rules = [
      "L+ /opt/rocm - - - - ${pkgs.rocmPackages.clr}"
    ];
  };
}

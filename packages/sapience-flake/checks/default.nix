# The flake's `checks.<system>.*` outputs: hermetic, reproducible evidence that the generated
# wrappers behave, runnable by anyone with Nix via `nix flake check`.
#
# WHY these live in `checks` rather than in a CI workflow: a green badge is evidence only the
# badge's owner can reproduce. A `checks` derivation is evidence a skeptic reproduces with one
# command on their own machine, which is the whole point of shipping a flake. CI here does
# nothing a consumer cannot do themselves -- it just runs `nix flake check`.
#
# WHAT THESE DO NOT COVER, deliberately and permanently:
#
#   - The vendor. Sapience is an invite-only private beta with no CI-accessible credentials and a
#     self-updating payload carrying no hashes (see ../README.md's "The payload is deliberately
#     mutable"). Nothing here can prove `sapience sync` really extracts, redacts and uploads;
#     these checks stop at the boundary of code this flake owns.
#   - A timer actually firing. That needs a live systemd user manager, which a Nix build sandbox
#     does not have. ./hm-module.nix covers unit GENERATION -- that the timer exists, with the
#     configured OnCalendar -- and stops there; proving one FIRES needs a VM test or a real
#     machine.
#   - WSL2 end to end. The WSL code paths are exercised here by forcing detection, which is a
#     test of this flake's logic, not of WSL. See ../README.md's "Platforms" section for what is
#     verified how.
{
  pkgs,
  lib,
  home-manager,
  module,
}:
let
  # Every check builds its wrappers from the same defaults as the flake's own
  # `packages.<system>.*` output set, so what is tested is what a consumer installs.
  mkWrappers =
    args:
    import ../lib/wrappers.nix (
      {
        inherit pkgs lib;
        stateDir = "$HOME/.sapience";
        host = "https://app.spnc.ai";
        backend = "relay";
        model = "";
        memoryFiles = true;
        tokenFile = null;
        backgroundSync = false;
        syncInterval = "hourly";
      }
      // args
    );

  # Both scheduling configurations, because they generate materially different scripts: the
  # backgroundSync branch is chosen at EVAL time, so a check against only one of them leaves
  # half the help text and the entire bootstrap summary branch untested.
  syncOff = mkWrappers { };
  syncOn = mkWrappers { backgroundSync = true; };
in
{
  shellcheck = import ./shellcheck.nix { inherit pkgs syncOff syncOn; };
  help-output = import ./help-output.nix { inherit pkgs syncOff syncOn; };
  token-functions = import ./token-functions.nix { inherit pkgs syncOff; };
  wsl-probe = import ./wsl-probe.nix { inherit pkgs syncOff; };
  hm-module = import ./hm-module.nix {
    inherit
      pkgs
      lib
      home-manager
      module
      ;
  };
}

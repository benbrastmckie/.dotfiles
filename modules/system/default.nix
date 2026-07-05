# Always-on system module aggregator.
# Imports the modules every host should apply. Optional/host-toggled modules
# (e.g. optional/discord-bot.nix) are deliberately NOT imported here — they are
# opt-in per host via hosts/<name>/default.nix + extraModules in flake.nix.
# See .claude/rules/nix.md "Module Patterns" for the always-on vs optional distinction.
{ ... }:
{
  imports = [
    ./boot.nix
    ./networking.nix
    ./locale.nix
    ./desktop.nix
    ./services.nix
    ./audio.nix
    ./power.nix
    ./users.nix
    ./nix.nix
    ./display.nix
    ./packages.nix
    ./shell.nix

    # Optional modules are intentionally excluded here (opt-in per host).
  ];
}

# NixOS system configuration — thin import list.
# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ ... }:
{
  imports = [
    # Hardware configuration is imported in flake.nix (via mkHost)

    # Core system modules
    ./modules/system/boot.nix
    ./modules/system/networking.nix
    ./modules/system/locale.nix
    ./modules/system/desktop.nix
    ./modules/system/services.nix
    ./modules/system/audio.nix
    ./modules/system/power.nix
    ./modules/system/users.nix
    ./modules/system/nix.nix
    ./modules/system/display.nix
    ./modules/system/packages.nix
    ./modules/system/shell.nix

    # Optional modules — enabled for nandi; may be removed for other hosts
    ./modules/system/optional/discord-bot.nix
  ];

  # Do not change this value after initial installation
  system.stateVersion = "24.11";
}

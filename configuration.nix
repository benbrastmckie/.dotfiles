# NixOS system configuration — thin import list.
# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ ... }:
{
  imports = [
    # Hardware configuration is imported in flake.nix (via mkHost)

    # Always-on system modules (see modules/system/default.nix). Optional/
    # host-toggled modules (e.g. discord-bot) are wired per-host instead —
    # see hosts/nandi/default.nix + extraModules in flake.nix.
    ./modules/system
  ];

  # Do not change this value after initial installation
  system.stateVersion = "24.11";
}

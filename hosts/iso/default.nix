# ISO installer-specific NixOS configuration.
# Wired directly into the `iso` nixosSystem call in flake.nix (NOT via mkHost) because an
# installer image has no hosts/iso/hardware-configuration.nix, which mkHost unconditionally
# requires. Mirrors the shape of hosts/usb-installer/default.nix.
{
  pkgs,
  lib,
  system,
  ...
}:
{
  # ISO-specific configurations
  isoImage = {
    edition = lib.mkForce "nandi";
    compressImage = true;
    # Enable copy-on-write for the ISO
    squashfsCompression = "zstd";
  };
  # Make the ISO compatible with most systems.
  # NOTE: `system` is passed in via specialArgs (see flake.nix's `iso` nixosSystem call) rather
  # than closed over lexically, since this module now lives in its own file. Do NOT use
  # `pkgs.system` here: `pkgs` is itself constructed from `config.nixpkgs.hostPlatform`, so
  # assigning `nixpkgs.hostPlatform = pkgs.system;` is a circular fixpoint that Nix reports as
  # "infinite recursion encountered".
  nixpkgs.hostPlatform = system;
  # Configure networking for ISO with NetworkManager only
  networking = {
    networkmanager = {
      enable = true;
      wifi.backend = "iwd"; # Use iwd backend for better performance
    };
    # Explicitly disable wpa_supplicant
    wireless.enable = false;
  };
  # Enable basic system utilities for the live environment
  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    curl
    # Add networking tools that might be helpful during installation
    iw
    wirelesstools
    networkmanager
  ];
}

# Nix daemon settings, GC, nix-ld, and nixpkgs configuration.
# deadnix: skip
{ pkgs, lib, ... }:
{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.input-fonts.acceptLicense = true;

  # Enable useful Nix features
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true; # Optimize the Nix store automatically
      # Resource limits to prevent OOM on heavy C++ builds (24-core / 30GB box).
      # max-jobs * cores caps concurrent compile units at 12, within the ~26GB
      # build budget (~2GB/unit for onnxruntime-class packages).
      max-jobs = 2;
      cores = 6;
      # HACL*/Aeneas project cache; serves the pinned aeneas/charon outputs so they are
      # fetched instead of compiled from source (see the aeneas flake input comment).
      substituters = [ "https://hacl.cachix.org" ];
      trusted-public-keys = [ "hacl.cachix.org-1:FzsZ2xsByOwKwIWNPII7yMOelJNDZ12mDAj3d1eGX0c=" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Enable nix-ld for running unpatched dynamic binaries
  # (required for elan/Lean toolchains, Playwright/Chromium, and other foreign binaries)
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      # Core C/C++ runtime
      stdenv.cc.cc.lib
      zlib
      gmp
      # Chromium/Playwright dependencies
      glib
      nss
      nspr
      atk
      at-spi2-atk
      cups
      dbus
      libdrm
      gtk3
      pango
      cairo
      libx11
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrandr
      libxcb
      libgbm
      expat
      alsa-lib
      libxkbcommon
    ];
  };
}

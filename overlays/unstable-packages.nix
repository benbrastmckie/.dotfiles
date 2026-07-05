# Overlay providing packages sourced from nixpkgs-unstable or custom derivations.
# pkgs-unstable must be passed in by the caller (injected via flake.nix let block).
# Add packages here that require unstable versions or custom builds.
pkgs-unstable: final: prev: {
  # Window Manager - ENABLED (dual-session with GNOME)
  inherit (pkgs-unstable) niri; # Active development with frequent improvements

  # Applications
  claude-code = final.callPackage ../packages/claude-code.nix { }; # Latest AI capabilities (custom build)
  # opencode = pkgs-unstable.opencode; # AI coding agent built for the terminal (sst/opencode)
  opencode = final.callPackage ../packages/opencode.nix { }; # Latest release (custom build, bypasses nixpkgs lag)
  inherit (pkgs-unstable) gemini-cli; # Google Gemini AI CLI tool
  loogle = final.callPackage ../packages/loogle.nix { }; # Lean 4 Mathlib search tool (wrapper)
  aristotle = final.callPackage ../packages/aristotle.nix { }; # AI theorem prover with Lean
  slidev = final.callPackage ../packages/slidev.nix { }; # Presentation slides from Markdown
  kooha = import ../packages/kooha.nix prev.kooha final.gst_all_1; # Screen recorder with full GStreamer plugin support

  # Custom wrappers extracted from modules/system/packages.nix (task 97).
  # zathura/sioyek are self-referential (wrapper name == wrapped package name), so use
  # positional import with prev.X — NOT callPackage — to avoid infinite recursion (kooha pattern).
  zathura = import ../packages/zathura-x11.nix prev.zathura final.writeShellScriptBin;
  sioyek = import ../packages/sioyek-wayland.nix prev.sioyek final.writeShellScriptBin;
  polkit-gnome-authentication-agent-1 =
    final.callPackage ../packages/polkit-gnome-agent-wrapper.nix
      { };

  # TTS/STT Models
  piper = final.callPackage ../packages/piper-bin.nix { }; # Piper TTS prebuilt binary (no onnxruntime compile)
  piper-voice-en-us-lessac-medium = final.callPackage ../packages/piper-voices.nix { }; # Piper TTS voice model
  vosk-model-small-en-us = final.callPackage ../packages/vosk-models.nix { }; # Vosk STT language model

  # Add other packages that benefit from using unstable below
  # Format: package-name = pkgs-unstable.package-name; # Reason for using unstable
}

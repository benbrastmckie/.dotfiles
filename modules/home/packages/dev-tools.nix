# Development tools: editors, formatters, web, git, system monitoring
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    stylua # Lua formatter for Neovim
    wezterm # GPU-accelerated terminal emulator
    zulip-term # Terminal UI client for Zulip chat
    slidev # Presentation slides from Markdown (sli.dev)
    # sioyek is installed via configuration.nix (Wayland wrapper, CSD disabled)

    # GNOME Shell Extensions
    gnomeExtensions.activate-window-by-title # For cross-window WezTerm tab navigation
    gnomeExtensions.mouse-follows-focus-2 # Warp pointer to keyboard-focused window (focus-follows-mouse vs keyboard fix)

    # Web Development & API Tools
    httpie # User-friendly HTTP client (better than curl for APIs)
    fx # Interactive JSON viewer

    # Git Enhancement Tools
    glab # GitLab CLI
    delta # Better git diff viewer

    # System Monitoring
    btop # Modern, beautiful system monitor
    htop # Interactive process viewer
    bandwhich # Network bandwidth monitor

    # Documentation Tools
    vale # Prose linting for documentation
    marksman # Markdown language server (LSP)
    mdl # Markdown linter
    prettier # Code formatter (JS/TS/JSON/MD/YAML/CSS)

    # Image Optimization
    imagemagick # Image manipulation
    optipng # PNG optimizer
    jpegoptim # JPEG optimizer

    # Digital Hardware Simulation (Verilog/SystemVerilog + waveform viewing)
    iverilog # Icarus Verilog simulator (provides iverilog + vvp; writes VCD traces)
    verilator # Fast compiled Verilog/SystemVerilog simulator
    gtkwave # GTKWave VCD/waveform viewer
    surfer # Modern VCD/waveform viewer

    # Digital Hardware Synthesis, Formal Verification & Linting
    yosys # RTL synthesis suite (also drives formal flows)
    sby # SymbiYosys front-end for Yosys formal verification
    boolector # SMT solver (bit-vectors + arrays), used as a formal backend
    bitwuzla # SMT solver (bit-vectors/arrays/FP), Boolector successor
    yices # Yices 2 SMT solver
    verible # SystemVerilog linter/formatter (verible-verilog-lint et al.)
    nusmv # NuSMV symbolic model checker
    python3Packages.cocotb # Python cosimulation testbench framework

    nodejs # Required runtime dependency

    # Comparator Lean proof-verification toolchain (landrun, comparator, and the
    # per-project lean4export resolver). See packages/README.md for the full decision
    # record (landrun v0.1.17-vs-nixpkgs-0.1.15 evidence, lean4export version-matching
    # design, real-derivation-vs-wrapper argument for comparator, nanoda deferral, and the
    # systemd-run sandbox-escape wrapper caveat).
    landrun
    comparator
    comparator-lean4export-resolve
  ];

  # COMPARATOR_LANDRUN is safe as a fixed global path: landrun itself is not
  # per-project-versioned (unlike lean4export, which must match each checked project's own
  # Lean toolchain -- see the COMPARATOR_LEAN4EXPORT comment below).
  home.sessionVariables.COMPARATOR_LANDRUN = "${pkgs.landrun}/bin/landrun";

  # COMPARATOR_LEAN4EXPORT is deliberately NOT set here. A fixed global value would be
  # silently WRONG for any checked project whose Lean toolchain differs from whatever
  # `comparator-lean4export-resolve` last cached -- lean4export's binary format is tied to
  # the exact Lean version that produced the .olean files it reads (see
  # packages/lean4export.nix's header). The calling harness must resolve and export this
  # per invocation, e.g.:
  #   export COMPARATOR_LEAN4EXPORT=$(comparator-lean4export-resolve "$project_dir")
  # before invoking comparator.

  # COMPARATOR_NANODA is deliberately NOT set here. nanoda (a second, independent Lean
  # kernel implementation) is explicitly deferred -- see packages/README.md's decision
  # record. Comparator's own fallback for an unset override is a bare `nanoda_bin` looked
  # up on PATH; since nanoda is not packaged here, `enable_nanoda: true` in any config will
  # fail LOUDLY (binary-not-found) rather than silently skip the check, which is the
  # correct "degrade loudly, not silently" behavior for a trust-critical checker.
}

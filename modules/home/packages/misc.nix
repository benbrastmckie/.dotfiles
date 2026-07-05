# Miscellaneous small package groups: fonts, Lean 4/formal-math tools, AI coding assistants.
# Merged (task 88) from fonts.nix + lean-math.nix + ai-tools.nix, each too small to justify its
# own file. NOTE: this is unrelated to the top-level `../misc.nix` (home.activation/autoExpire/
# sessionVariables/startServices settings) — the basename collision is deliberate (see
# design/target-layout.md); do not confuse the two files when editing.
{ pkgs, lectic, ... }:
{
  home.packages = with pkgs; [
    # Fonts
    nerd-fonts.roboto-mono # Nerd Fonts with Roboto Mono (nixos-unstable uses new nerd-fonts structure)
    jetbrains-mono

    # Lean 4 and formal mathematics tools
    lectic # Formal logic and proof tool
    loogle # Lean 4 Mathlib search tool (wrapper script)

    # AI and coding assistant tools
    claude-code # Using overlaid unstable package
    claude-squad # Terminal app for managing multiple AI agents
    gemini-cli # Google Gemini AI CLI tool
    gh # GitHub CLI (required by claude-squad)
  ];
}

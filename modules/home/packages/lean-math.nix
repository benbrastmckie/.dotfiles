# Lean 4 and formal mathematics tools
{ pkgs, lectic, ... }:
{
  home.packages = with pkgs; [
    lectic # Formal logic and proof tool
    loogle # Lean 4 Mathlib search tool (wrapper script)
  ];
}

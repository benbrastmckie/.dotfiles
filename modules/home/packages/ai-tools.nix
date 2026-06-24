# AI and coding assistant tools
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    claude-code # Using overlaid unstable package
    claude-squad # Terminal app for managing multiple AI agents
    gemini-cli # Google Gemini AI CLI tool
    gh # GitHub CLI (required by claude-squad)
  ];
}

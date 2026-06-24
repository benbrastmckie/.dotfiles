# Fonts
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nerd-fonts.roboto-mono # Nerd Fonts with Roboto Mono (nixos-unstable uses new nerd-fonts structure)
    jetbrains-mono
  ];
}

# unstable-packages.nix
# This file defines all packages that should come from the unstable channel.
# Add packages here with a brief comment explaining why unstable is preferred.

{ pkgs-unstable }:

final: prev: {
  # Development tools
  neovim-unwrapped = pkgs-unstable.neovim-unwrapped; # Get latest Neovim features and bug fixes
  
  # Window Manager
  niri = pkgs-unstable.niri; # Active development with frequent improvements
  
  # Applications
  claude-code = pkgs-unstable.claude-code; # Latest AI capabilities
  
  # Add other packages that benefit from using unstable below
  # Format: package-name = pkgs-unstable.package-name; # Reason for using unstable
}
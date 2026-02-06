# OpenCode Global Configuration
#
# This file manages the global opencode config file location and symlinks it
# from the dotfiles repository to ~/.config/opencode/
#
# Usage in your home.nix:
#   imports = [ ./modules/opencode.nix ];
#
# Or inline in home.nix:
#   xdg.configFile."opencode/opencode.json".source = ../../config/opencode.json;

{ config, lib, pkgs, ... }:

{
  # Option to enable opencode configuration
  options.programs.opencode = {
    enable = lib.mkEnableOption "OpenCode AI coding agent";
    
    dotfilesPath = lib.mkOption {
      type = lib.types.path;
      default = ../../config/opencode.json;
      description = "Path to the opencode.json config in your dotfiles repo";
    };
  };

  # Configuration
  config = lib.mkIf config.programs.opencode.enable {
    # Ensure opencode is installed
    home.packages = [ pkgs.opencode ];

    # Symlink the global config from dotfiles to ~/.config/opencode/opencode.json
    xdg.configFile."opencode/opencode.json".source = config.programs.opencode.dotfilesPath;
  };
}

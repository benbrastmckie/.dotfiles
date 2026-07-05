{ config, pkgs, pkgs-unstable, lectic, ... }:

{
  # Import our custom modules (see modules/home/default.nix for the full list)
  imports = [
    ./modules/home
  ];

  # Note: Python packages overlay (including cvc5) is defined in flake.nix

  home.username = "benjamin";
  home.homeDirectory = "/home/benjamin";

  # Fish shell configuration is managed through home.file below
  # OMF has been removed - fish greeting disabled in config.fish

  home.stateVersion = "24.11"; # Please read the comment before changing.
  # History, do not restore — active stateVersion is frozen (see modules/README.md Verified
  # Health Notes). Kept as a record of prior values, not a rollback option.
  # home.stateVersion = "24.05"; # Please read the comment before changing.
  # home.stateVersion = "23.11"; # Please read the comment before changing.
}

{ config, pkgs, pkgs-unstable, lectic, ... }:

{
  # Import our custom modules
  imports = [
    # Core modules
    ./modules/home/core/git.nix
    ./modules/home/core/neovim.nix
    ./modules/home/core/shell.nix
    ./modules/home/core/xdg.nix

    # Desktop modules
    ./modules/home/desktop/gnome.nix
    ./modules/home/desktop/waybar.nix
    ./modules/home/desktop/mako.nix
    ./modules/home/desktop/kanshi.nix
    ./modules/home/desktop/swaylock.nix

    # Email modules
    ./modules/home/email/mbsync.nix
    ./modules/home/email/protonmail.nix
    ./modules/home/email/notmuch.nix
    ./modules/home/email/aerc.nix
    ./modules/home/email/agent-tools.nix

    # Package modules
    ./modules/home/packages/ai-tools.nix
    ./modules/home/packages/lean-math.nix
    ./modules/home/packages/dev-tools.nix
    ./modules/home/packages/media-dictation.nix
    ./modules/home/packages/email-tools.nix
    ./modules/home/packages/python.nix
    ./modules/home/packages/fonts.nix

    # Script modules (inline shell scripts)
    ./modules/home/scripts/sioyek-theme.nix
    ./modules/home/scripts/gmail-oauth2.nix
    ./modules/home/scripts/whisper.nix
    ./modules/home/scripts/memory-monitor.nix

    # Service modules (systemd user services and timers)
    ./modules/home/services/screenshot.nix
    ./modules/home/services/ydotool.nix
    ./modules/home/services/gmail-oauth2.nix
    ./modules/home/services/memory-services.nix
    ./modules/home/services/cache-cleanup.nix

    # Miscellaneous settings (activation, autoExpire, sessionVariables, startServices)
    ./modules/home/misc.nix
  ];

  # Note: Python packages overlay (including cvc5) is defined in flake.nix

  home.username = "benjamin";
  home.homeDirectory = "/home/benjamin";

  # Fish shell configuration is managed through home.file below
  # OMF has been removed - fish greeting disabled in config.fish

  home.stateVersion = "24.11"; # Please read the comment before changing.
  # home.stateVersion = "24.05"; # Please read the comment before changing.
  # home.stateVersion = "23.11"; # Please read the comment before changing.
}

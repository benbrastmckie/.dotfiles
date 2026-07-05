# Home Manager module aggregator.
# Imports all home-manager modules used by the benjamin profile.
{ ... }:
{
  imports = [
    # Core modules
    ./core/git.nix
    ./core/neovim.nix
    ./core/shell.nix
    ./core/xdg.nix

    # Desktop modules
    ./desktop/gnome.nix
    ./desktop/waybar.nix
    ./desktop/mako.nix
    ./desktop/kanshi.nix
    ./desktop/swaylock.nix

    # Email modules
    ./email/mbsync.nix
    ./email/protonmail.nix
    ./email/notmuch.nix
    ./email/aerc.nix
    ./email/agent-tools

    # Package modules
    ./packages/dev-tools.nix
    ./packages/media-dictation.nix
    ./packages/email-tools.nix
    ./packages/python.nix
    ./packages/misc.nix

    # Script modules (inline shell scripts)
    ./scripts/sioyek-theme.nix
    ./scripts/gmail-oauth2.nix
    ./scripts/whisper.nix

    # Service modules (systemd user services and timers)
    ./services/screenshot.nix
    ./services/ydotool.nix
    ./services/gmail-oauth2.nix
    ./services/cache-cleanup.nix

    # Memory monitoring (co-located: scripts + systemd services, three-tier system)
    ./memory/monitor.nix
    ./memory/services.nix

    # Miscellaneous settings (activation, autoExpire, sessionVariables, startServices)
    ./misc.nix
  ];
}

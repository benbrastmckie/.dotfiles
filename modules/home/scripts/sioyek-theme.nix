# Sioyek theme toggle script - toggles between Nord (dark) and Gruvbox (light).
#
# Sioyek opens in Nord dark: `startup_commands` enables custom color mode and the
# `custom_*` colors in prefs_user.config carry the Nord palette. The state file records
# which palette is live so `w` is a true toggle; the sioyek launcher wrapper
# (packages/sioyek-wayland.nix) resets it to `nord` on every launch, keeping the tracked
# state in step with the colors sioyek actually started with.
{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellScriptBin "sioyek-theme-toggle" ''
      STATE_FILE="''${XDG_CACHE_HOME:-$HOME/.cache}/sioyek-theme-state"
      mkdir -p "$(dirname "$STATE_FILE")"

      # Default to nord, matching the startup palette in prefs_user.config
      if [ ! -f "$STATE_FILE" ]; then
        echo "nord" > "$STATE_FILE"
      fi

      CURRENT_THEME=$(cat "$STATE_FILE")

      if [ "$CURRENT_THEME" = "nord" ]; then
        # Switch to Gruvbox light
        sioyek --execute-command setconfig_custom_background_color --execute-command-data "0.922 0.859 0.698"
        sioyek --execute-command setconfig_custom_text_color --execute-command-data "0.235 0.220 0.212"
        echo "gruvbox" > "$STATE_FILE"
      else
        # Switch to Nord dark
        sioyek --execute-command setconfig_custom_background_color --execute-command-data "0.180 0.204 0.251"
        sioyek --execute-command setconfig_custom_text_color --execute-command-data "0.847 0.871 0.914"
        echo "nord" > "$STATE_FILE"
      fi
    '')
  ];
}

# Sioyek theme toggle script - toggles between Gruvbox (light) and Nord (dark)
{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellScriptBin "sioyek-theme-toggle" ''
      STATE_FILE="$HOME/.cache/sioyek-theme-state"
      mkdir -p "$(dirname "$STATE_FILE")"

      # Default to gruvbox if state file doesn't exist
      if [ ! -f "$STATE_FILE" ]; then
        echo "gruvbox" > "$STATE_FILE"
      fi

      CURRENT_THEME=$(cat "$STATE_FILE")

      if [ "$CURRENT_THEME" = "gruvbox" ]; then
        # Switch to Nord
        sioyek --execute-command setconfig_custom_background_color --execute-command-data "0.180 0.204 0.251"
        sioyek --execute-command setconfig_custom_text_color --execute-command-data "0.847 0.871 0.914"
        echo "nord" > "$STATE_FILE"
      else
        # Switch to Gruvbox
        sioyek --execute-command setconfig_custom_background_color --execute-command-data "0.922 0.859 0.698"
        sioyek --execute-command setconfig_custom_text_color --execute-command-data "0.235 0.220 0.212"
        echo "gruvbox" > "$STATE_FILE"
      fi
    '')
  ];
}

# Screenshot path copy service: watches Screenshots dir and copies new file paths to clipboard
{ pkgs, ... }:
{
  systemd.user.services.screenshot-path-copy = {
    Unit = {
      Description = "Copy screenshot file path to clipboard on creation";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = toString (
        pkgs.writeShellScript "screenshot-path-copy" ''
          DIR="$HOME/Pictures/Screenshots"
          mkdir -p "$DIR"
          ${pkgs.inotify-tools}/bin/inotifywait -m -e close_write --format '%f' "$DIR" | while read -r filename; do
            filepath="$DIR/$filename"
            printf '%s' "$filepath" | ${pkgs.wl-clipboard}/bin/wl-copy
          done
        ''
      );
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}

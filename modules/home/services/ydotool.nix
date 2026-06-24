# ydotool daemon: universal input automation tool required for dictation
{ pkgs, ... }:
{
  systemd.user.services.ydotool = {
    Unit = {
      Description = "ydotool daemon for input automation";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.ydotool}/bin/ydotoold";
      Restart = "on-failure";
      # Allow access to /dev/uinput
      Environment = "PATH=/run/current-system/sw/bin";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}

# Swaylock screen locker configuration.
# swayidle is DISABLED — see inline comment for rationale.
_: {
  programs.swaylock = {
    enable = true;
    settings = {
      color = "2e3440";
      font-size = 24;
      indicator-idle-visible = false;
      indicator-radius = 100;
      line-color = "5e81ac";
    };
  };

  # swayidle - DISABLED (using spawn-at-startup in config.kdl instead)
  # Reason: systemd service tries to start in GNOME session where the
  # ext-idle-notify-v1 protocol doesn't exist, causing "Display doesn't
  # support idle protocol" error. Using spawn-at-startup ensures swayidle
  # only runs in niri session.
  # services.swayidle = {
  #   enable = true;
  #   events = [
  #     { event = "before-sleep"; command = "${pkgs.swaylock}/bin/swaylock -f"; }
  #     { event = "lock"; command = "${pkgs.swaylock}/bin/swaylock -f"; }
  #   ];
  #   timeouts = [
  #     { timeout = 300; command = "${pkgs.swaylock}/bin/swaylock -f"; }
  #     { timeout = 600; command = "${pkgs.systemd}/bin/systemctl suspend"; }
  #   ];
  # };
}

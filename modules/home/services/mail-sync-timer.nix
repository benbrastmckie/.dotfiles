# Periodic "Gmail stays in sync occasionally" mechanism -- runs `mail-sync both` on
# an interval even when aerc is closed. This is the PRIMARY sync trigger;
# the `[gmail]` accounts.conf `check-mail-cmd` in aerc.nix is a secondary,
# while-aerc-is-open convenience only.
#
# Locking: `mail-sync` holds its own flock, so this timer-triggered run
# and any aerc-triggered `check-mail`/`$` run are already mutually safe -- no new
# locking is needed here.
#
# Interval: deliberately coarse (every 15 minutes) -- "occasional" sync is the
# explicit goal, not real-time push. Trivially adjustable via OnCalendar below.
#
# Failure visibility: modeled on the proven `cache-cleanup.nix` shape (oneshot
# service + calendar timer + Persistent = true). `mail-sync` is expected-success,
# and its transient failures (offline laptop, Bridge down) self-clear on the next
# run rather than latching -- which matters because a unit that fails every run
# degrades the whole systemd --user session. The user should still occasionally check
# `systemctl --user status mail-sync-timer.service` / `journalctl --user -u
# mail-sync-timer` if Gmail ever appears stale.
{ config, pkgs, ... }:
{
  systemd.user.services.mail-sync-timer = {
    Unit = {
      Description = "Periodic mail-sync (both accounts) so Gmail/Logos stay in sync while aerc is closed";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart =
        let
          script = pkgs.writeShellScript "mail-sync-timer" ''
            export PATH="${config.home.homeDirectory}/.nix-profile/bin:/run/current-system/sw/bin:$PATH"
            echo "mail-sync-timer: starting"
            mail-sync both
            echo "mail-sync-timer: done"
          '';
        in
        "${script}";
    };
  };

  systemd.user.timers.mail-sync-timer = {
    Unit = {
      Description = "Timer for periodic mail-sync (every 15 minutes)";
      # Note: no `Requires = [ "mail-sync-timer.service" ]` here. Requires= stop-propagates, so
      # `systemctl --user stop mail-sync-timer.service` would also deactivate this timer and
      # silently end the schedule. A timer activates its same-named service through
      # Timer.Unit by default, so the dependency only ever cost us that footgun.
    };
    Timer = {
      OnCalendar = "*:0/15";
      Persistent = true;
      RandomizedDelaySec = 120;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}

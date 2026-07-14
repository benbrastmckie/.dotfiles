# Periodic "Gmail stays in sync occasionally" mechanism -- runs `mail-sync both` on
# an interval even when aerc is closed. This is the PRIMARY sync trigger (task 113);
# the `[gmail]` accounts.conf `check-mail-cmd` in aerc.nix is a secondary,
# while-aerc-is-open convenience only.
#
# Locking: `mail-sync` (task 109) holds its own flock, so this timer-triggered run
# and any aerc-triggered `check-mail`/`$` run are already mutually safe -- no new
# locking is needed here.
#
# Interval: deliberately coarse (every 15 minutes) -- "occasional" sync is the
# explicit goal, not real-time push. Trivially adjustable via OnCalendar below.
#
# Failure-visibility precedent: modeled on the proven `cache-cleanup.nix` shape
# (oneshot service + calendar timer + Persistent = true). Unlike `gmail-oauth2.nix`
# (a guaranteed-every-run failure that once degraded the systemd --user session),
# `mail-sync` is expected-success and transient failures (offline laptop, Bridge
# down) self-clear on the next run -- but the user should still occasionally check
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
      Requires = [ "mail-sync-timer.service" ];
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

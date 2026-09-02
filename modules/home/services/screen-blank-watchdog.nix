# Guarantees the screen blanks after the configured idle delay, regardless of idle inhibitors.
#
# The problem this solves: GNOME's automatic blank is vetoed by any GNOME SessionManager
# inhibitor carrying flag 8 (idle). Any application can register one -- a page calling
# `navigator.wakeLock` makes Chromium hold one for as long as the tab is open, and mutter
# registers a matching entry for any Wayland client using `zwp_idle_inhibitor_v1`. A single
# forgotten browser tab therefore disables screen blanking indefinitely, with no user-visible
# indication. On a machine running unattended agent workloads, browsers are open constantly and
# this is a matter of when, not if.
#
# The fix relies on a specific asymmetry in GNOME's behaviour: inhibitors block only the
# *automatic*, idle-triggered activation of the screensaver. An *explicit*
# `org.gnome.ScreenSaver.SetActive(true)` call is honoured even while flag-8 inhibitors are held
# (verified on this host: activation succeeded with two inhibitors outstanding). So this watchdog
# reimplements the idle trigger in the one way inhibitors cannot veto.
#
# Idle is read from mutter's own idle monitor, which counts *real input* -- keyboard and pointer
# only. Background activity does not reset it: sampling on this host showed `GetIdletime` climbing
# monotonically straight through bursts of agent-driven Playwright browsers. So "five minutes
# without moving the mouse or touching the keyboard" is exactly what this measures.
#
# Deliberately NOT a sleep inhibitor concern: blanking the display is unrelated to suspending the
# machine, and this unit never suspends anything. The no-sleep guarantees in
# docs/no-sleep-agents.md (mechanisms 1-4) are unaffected -- agents keep running with the screen
# dark, which is the entire point.
#
# The threshold is read from `org.gnome.desktop.session idle-delay` at each tick rather than being
# hardcoded, so changing the blank timeout in GNOME Settings changes this too, with no rebuild. A
# value of 0 means "never blank" in GNOME's schema and is honoured as such (the watchdog no-ops).
#
# On non-GNOME sessions (niri) the DBus names below are absent, every call fails, and the script
# exits 0 without acting -- niri's swayidle handles its own locking (mechanism 3).
{ pkgs, ... }:
{
  systemd.user.services.screen-blank-watchdog = {
    Unit = {
      Description = "Blank the screen after the GNOME idle delay, ignoring idle inhibitors";
      # Only meaningful once a graphical session owns the bus.
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart =
        let
          script = pkgs.writeShellScript "screen-blank-watchdog" ''
            set -u
            busctl=${pkgs.systemd}/bin/busctl
            gsettings=${pkgs.glib}/bin/gsettings

            # GNOME's blank timeout, in seconds. 0 means "never" -- respect that and do nothing.
            delay_s=$("$gsettings" get org.gnome.desktop.session idle-delay 2>/dev/null \
              | ${pkgs.gnused}/bin/sed 's/^uint32 //') || exit 0
            case "$delay_s" in
              ''' | *[!0-9]*) exit 0 ;;
              0) exit 0 ;;
            esac

            # Real-input idle time in milliseconds, straight from mutter's idle monitor.
            idle_ms=$("$busctl" --user call org.gnome.Mutter.IdleMonitor \
              /org/gnome/Mutter/IdleMonitor/Core org.gnome.Mutter.IdleMonitor GetIdletime \
              2>/dev/null | ${pkgs.gnused}/bin/sed 's/^t //') || exit 0
            case "$idle_ms" in
              ''' | *[!0-9]*) exit 0 ;;
            esac

            [ "$idle_ms" -ge $(( delay_s * 1000 )) ] || exit 0

            # Already blanked: nothing to do, and re-asserting would be pointless churn.
            active=$("$busctl" --user call org.gnome.ScreenSaver /org/gnome/ScreenSaver \
              org.gnome.ScreenSaver GetActive 2>/dev/null | ${pkgs.gnused}/bin/sed 's/^b //') || exit 0
            [ "$active" = "false" ] || exit 0

            echo "screen-blank-watchdog: idle ''${idle_ms}ms >= ''${delay_s}s, blanking (inhibitors ignored)"
            "$busctl" --user call org.gnome.ScreenSaver /org/gnome/ScreenSaver \
              org.gnome.ScreenSaver SetActive b true >/dev/null 2>&1 || true
          '';
        in
        "${script}";
    };
  };

  systemd.user.timers.screen-blank-watchdog = {
    Unit = {
      Description = "Periodic check that the screen blanks despite idle inhibitors";
      Requires = [ "screen-blank-watchdog.service" ];
    };
    Timer = {
      # 30s granularity: the blank lands within 30s of the configured delay, which is well
      # inside the noise of a 5-minute timeout and costs two cheap DBus calls per tick.
      OnBootSec = "2min";
      OnUnitActiveSec = "30s";
      AccuracySec = "5s";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}

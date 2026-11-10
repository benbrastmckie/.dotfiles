# Keeps the screen lit and the machine awake for the duration of a video call (Zoom, Google
# Meet, Jitsi, or anything else that captures the microphone).
#
# This is the deliberate carve-out from the "the screen always blanks" guarantee documented as
# mechanism 5 in docs/no-sleep-agents.md. That guarantee is enforced by
# services/screen-blank-watchdog.nix, which blanks the display on the idle delay *regardless of
# any idle inhibitor* -- which is correct for a forgotten browser tab holding a wake lock, and
# wrong for a call in progress, where it blanks the screen in the middle of a meeting. Note that
# a conferencing app cannot fix this for itself: Zoom already registers a perfectly good
# "in a meeting" idle inhibitor, and the watchdog overrides it by design. So the carve-out has to
# live on this side.
#
# Two units, because holding an inhibitor needs a live process while deciding whether to hold one
# does not:
#
#   video-call-inhibit.service   Holds the inhibitors for as long as it is active. Never started
#                                by a target -- only by the monitor below.
#   video-call-monitor.service   A oneshot, fired by a timer, that starts or stops the inhibit
#                                unit to match the current call state.
#
# Letting systemd own the inhibitor's lifetime (rather than the monitor forking and tracking PIDs
# itself) is what makes release reliable: `systemctl --user stop` tears down the whole control
# group, so the wrapped `gnome-session-inhibit` child cannot be orphaned and leak a flag-8
# inhibitor that outlives the call -- the exact failure mode mechanism 5 is about.
{ pkgs, ... }:
let
  videoCallActive = import ./lib/video-call-active.nix { inherit pkgs; };
in
{
  # One `systemd` attribute rather than three dotted paths: statix's repeated-keys check
  # rejects re-opening the same top-level key three times.
  systemd.user = {
    services.video-call-inhibit = {
      Unit = {
        Description = "Hold idle/sleep inhibitors while a video call is in progress";
        # Tear down with the session rather than surviving a logout holding an inhibitor.
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart =
          let
            script = pkgs.writeShellScript "video-call-inhibit" ''
              set -u

              # The logind `sleep` block inhibitor is the half that guarantees "no suspend". It is
              # taken explicitly rather than relying on the conferencing app's own flag-8 idle
              # inhibitor to keep the session non-idle: GNOME's idle-suspend path and GNOME's
              # blank path consume different inhibitor flags, and the no-suspend half of the user's
              # ask should not rest on reasoning about which one gsd-power happens to check.
              # Mirrors the Claude Code session inhibitor (mechanism 1, docs/no-sleep-agents.md).
              #
              # Note this does NOT defeat the battery backstop (mechanism 4): that calls
              # `systemctl suspend -i`, which skips every ordinary inhibitor including this one. A
              # call does not get to run the battery to zero.
              # A function, not a string variable: an unquoted variable holding these arguments
              # would word-split "Video call in progress" into four separate arguments.
              hold_sleep_inhibitor_and_exec() {
                exec ${pkgs.systemd}/bin/systemd-inhibit \
                  --what=sleep \
                  --who=video-call \
                  --why="Video call in progress" \
                  --mode=block \
                  "$@"
              }

              # The GNOME half, which is what actually keeps the panel lit: flag 8 (idle) stops
              # mutter's automatic idle blank, flag 4 (suspend) stops gsd-power's idle suspend.
              # Absent on niri, where these DBus names do not exist -- there the sleep inhibitor is
              # held on its own and swayidle keeps owning locking (mechanism 3).
              has_gnome_session=$("${pkgs.systemd}/bin/busctl" --user call \
                org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus \
                NameHasOwner s org.gnome.SessionManager 2>/dev/null \
                | ${pkgs.gnused}/bin/sed 's/^b //') || has_gnome_session="false"

              if [ "$has_gnome_session" = "true" ]; then
                echo "video-call-inhibit: holding sleep + GNOME idle/suspend inhibitors"
                hold_sleep_inhibitor_and_exec \
                  ${pkgs.gnome-session}/bin/gnome-session-inhibit \
                    --app-id=video-call-keepalive \
                    --reason="Video call in progress" \
                    --inhibit idle \
                    --inhibit suspend \
                    --inhibit-only
              fi

              echo "video-call-inhibit: no GNOME session; holding the sleep inhibitor only"
              hold_sleep_inhibitor_and_exec ${pkgs.coreutils}/bin/sleep infinity
            '';
          in
          "${script}";
      };
    };

    services.video-call-monitor = {
      Unit = {
        Description = "Start/stop the video-call inhibitors to match the current call state";
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart =
          let
            script = pkgs.writeShellScript "video-call-monitor" ''
              set -u
              systemctl=${pkgs.systemd}/bin/systemctl

              # start/stop are idempotent and silent on a no-op, so this runs every tick without
              # logging churn -- systemd only records an actual state transition.
              if ${videoCallActive}; then
                exec "$systemctl" --user start video-call-inhibit.service
              fi
              exec "$systemctl" --user stop video-call-inhibit.service
            '';
          in
          "${script}";
      };
    };

    timers.video-call-monitor = {
      Unit = {
        Description = "Periodic check for a video call in progress";
        # No Requires= on the service: Requires= stop-propagates, so stopping the service by hand
        # would silently deactivate this timer too. Timer.Unit already pulls in the same-named
        # service. (Same reasoning as services/screen-blank-watchdog.nix.)
      };
      Timer = {
        # 15s: a call must be covered well before the 5-minute blank, and the probe is one
        # `pw-dump` plus one DBus call. Deliberately tighter than the watchdog's 30s so the
        # inhibitor is in place before the watchdog's first post-call-start tick.
        OnBootSec = "1min";
        OnUnitActiveSec = "15s";
        AccuracySec = "5s";
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
  };

  # Expose the predicate for debugging: `video-call-active --explain` prints which application is
  # holding the microphone and how the idle cap was evaluated, which is the quickest way to tell a
  # detection problem apart from an inhibitor problem.
  home.packages = [
    (pkgs.writeShellScriptBin "video-call-active" ''
      exec ${videoCallActive} "$@"
    '')
  ];
}

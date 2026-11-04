# Stops abandoned `claude-*.scope` user scopes (see packages/claude-code.nix) whose owning
# claude session is provably gone, so a detached/double-forked child can never outlive the
# session that spawned it -- see docs/claude-session-scopes.md for the full mechanism.
#
# BINDING SAFETY CONSTRAINT (do not "optimize" this away in a future edit): the reap predicate
# is liveness-based ONLY -- "zero claude-signature processes remain among this scope's own
# cgroup.procs". CPU-time, memory/RSS, and wall-clock/age thresholds (CPUUsageNSec,
# ActiveEnterTimestamp, process start time, `etimes`, "has been running more than N hours") are
# PERMANENTLY FORBIDDEN as kill criteria here, in any future tuning pass. A child that has run
# for ten hours at 100% CPU must survive untouched as long as its owning session lives. On any
# ambiguity -- unreadable cgroup, unparsable PID list, a systemctl error, a PID that vanished
# mid-read -- the reaper skips the unit; "skip on ambiguity" is the mandated failure mode, never
# "reap on uncertainty". The reaper acts *only* on units matching `claude-*.scope` (the glob
# passed to `systemctl --user list-units` is the hard boundary) and only via that unit's own
# `cgroup.procs` -- never a system-wide `pgrep`/`ps aux` scan, never anything reached any other
# way.
#
# Failure discipline: a user unit that fails on every run degrades the whole systemd --user
# session, which surfaces as a warning on each `home-manager switch`. Every external call here
# is therefore guarded (`|| true` / existence checks) and the script always exits 0, so it can
# never end up `failed`.
#
# Opt-out for deliberately-detached work: launch it as its own top-level transient unit whose
# name does not match `claude-*.scope`, e.g. `systemd-run --user --unit=my-long-job -- <cmd>` --
# never touched by this reaper and outlives the session by design.
#
# Module shape modeled on the proven services/cache-cleanup.nix and services/mail-sync-timer.nix
# precedent: oneshot service + calendar timer, PATH export, `starting`/`done` echo bracketing.
{ config, pkgs, ... }:
{
  systemd.user.services.claude-session-reaper = {
    Unit = {
      Description = "Stop claude-*.scope units whose owning claude session is gone (liveness-only)";
    };
    Service = {
      Type = "oneshot";
      ExecStart =
        let
          script = pkgs.writeShellScript "claude-session-reaper" ''
            export PATH="${config.home.homeDirectory}/.nix-profile/bin:/run/current-system/sw/bin:$PATH"
            # Deliberately no `set -e`: every external call below is individually guarded so a
            # single race (unit disappearing mid-inspection) can never trip the whole script into
            # a `failed` unit state. The script always reaches `exit 0`.

            echo "claude-session-reaper: starting"

            DRY_RUN="''${CLAUDE_REAPER_DRY_RUN:-}"

            # Sole enumeration surface: only claude-*.scope units, never anything broader.
            units=$(systemctl --user list-units --type=scope --all --no-legend --plain 'claude-*.scope' 2>/dev/null \
              | awk '{print $1}')

            for unit in $units; do
              [ -n "$unit" ] || continue

              if ! cgpath=$(systemctl --user show "$unit" -p ControlGroup --value 2>/dev/null); then
                echo "claude-session-reaper: $unit systemctl show failed, skipping"
                continue
              fi
              if [ -z "$cgpath" ]; then
                echo "claude-session-reaper: $unit ambiguous (no ControlGroup), skipping"
                continue
              fi

              procs_file="/sys/fs/cgroup''${cgpath}/cgroup.procs"
              if [ ! -r "$procs_file" ]; then
                # Race: unit's cgroup vanished between list-units and this read (session ended
                # in between). Nothing to reap, never an error.
                systemctl --user reset-failed "$unit" >/dev/null 2>&1 || true
                continue
              fi

              pids=$(cat "$procs_file" 2>/dev/null) || true

              if [ -z "$pids" ]; then
                echo "claude-session-reaper: $unit empty cgroup.procs, nothing to kill"
                systemctl --user reset-failed "$unit" >/dev/null 2>&1 || true
                continue
              fi

              # Reject anything that isn't a clean PID list outright -- unparsable is ambiguous.
              unparsable=0
              for pid in $pids; do
                case "$pid" in
                  ''' | *[!0-9]*)
                    unparsable=1
                    break
                    ;;
                esac
              done
              if [ "$unparsable" -eq 1 ]; then
                echo "claude-session-reaper: $unit unparsable PID list, skipping"
                continue
              fi

              # Inspect only the PIDs this scope's own cgroup.procs actually listed -- never any
              # broader enumeration.
              ambiguous=0
              alive=0
              for pid in $pids; do
                if [ ! -d "/proc/$pid" ]; then
                  # PID vanished mid-read -- ambiguous, do not act on this unit.
                  ambiguous=1
                  break
                fi
                cmdline=""
                if [ -r "/proc/$pid/cmdline" ]; then
                  cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null) || true
                fi
                if [ -z "$cmdline" ] && [ -r "/proc/$pid/comm" ]; then
                  cmdline=$(cat "/proc/$pid/comm" 2>/dev/null) || true
                fi
                case "$cmdline" in
                  *claude* | *@anthropic* | *opencode*)
                    alive=1
                    break
                    ;;
                esac
              done

              if [ "$ambiguous" -eq 1 ]; then
                echo "claude-session-reaper: $unit ambiguous (pid vanished mid-read), skipping"
                continue
              fi

              if [ "$alive" -eq 1 ]; then
                echo "claude-session-reaper: $unit alive, skipping"
                continue
              fi

              # Zero matches among this scope's own PIDs -- the owning session is gone.
              if [ -n "$DRY_RUN" ]; then
                echo "claude-session-reaper: DRY-RUN would stop $unit (pids: $pids)"
                continue
              fi

              echo "claude-session-reaper: stopping abandoned $unit (pids: $pids)"
              systemctl --user stop "$unit" >/dev/null 2>&1 || true
              systemctl --user reset-failed "$unit" >/dev/null 2>&1 || true
            done

            echo "claude-session-reaper: done"
            exit 0
          '';
        in
        "${script}";
    };
  };

  systemd.user.timers.claude-session-reaper = {
    Unit = {
      Description = "Timer for periodic claude-*.scope reaping (liveness-only)";
      # Note: no `Requires = [ "claude-session-reaper.service" ]` here. Requires= stop-propagates, so
      # `systemctl --user stop claude-session-reaper.service` would also deactivate this timer and
      # silently end the schedule. A timer activates its same-named service through
      # Timer.Unit by default, so the dependency only ever cost us that footgun.
    };
    Timer = {
      OnCalendar = "*:0/10";
      Persistent = true;
      RandomizedDelaySec = 60;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}

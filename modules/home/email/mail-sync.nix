# mail-sync -- single canonical, serialized, group-scoped mail sync wrapper (task 109).
#
# Sanctioned non-wrapper index/sync exception, alongside email-reindex (mbsync.nix) -- NOT a
# sixth member of the frozen 5-binary agent contract (census/classify/archive-confirmed/
# delete-confirmed/unsubscribe-extract in agent-tools/); `mail-guard.sh`'s allowlist is
# untouched by this module.
#
# Motivation: prior to task 109 there were TWO independent, unsynchronized entry points into
# mbsync -- the notmuch preNew hook (`mbsync gmail logos || true`) and aerc's `$` keybind
# (`mbsync gmail && notmuch new --no-hooks`) -- with no lock between them, so a preNew-triggered
# reindex could race a manual aerc sync against the same Maildir. `mail-sync` is the single
# choke point both triggers now call through: it takes one blocking flock before EVER invoking
# mbsync, so at most one mbsync run is in flight system-wide regardless of which trigger fired.
#
# Structurally incapable of `mbsync -a`: the allowlist `case` below branches only to hardcoded
# `mbsync gmail` / `mbsync logos` -- mirroring the `--account {gmail,logos}` allowlist `case` in
# agent-tools/lib.nix (lines 106-124). There is no `mbsync "$@"` passthrough anywhere in this
# script and the literal `mbsync -a` does not appear.
{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellScriptBin "mail-sync" ''
      set -euo pipefail

      print_help() {
        cat <<'HELPEOF'
      mail-sync <gmail|logos|both> [--no-wait]

      Serialized, group-scoped mbsync + notmuch reindex wrapper (task 109).

      Structurally incapable of `mbsync -a`: only hardcoded `mbsync gmail` / `mbsync logos`
      are ever run (never -a, never an arbitrary passthrough channel). `both` runs gmail then
      logos sequentially inside the SAME lock acquisition.

      Takes a blocking flock (default: wait up to 300s; --no-wait fails fast instead) on
      $XDG_RUNTIME_DIR/mail-sync.lock (falls back to $HOME/.cache if XDG_RUNTIME_DIR is unset)
      so no two mail-sync invocations run concurrently, regardless of trigger (notmuch preNew
      hook, aerc's $ keybind, or manual use).

      After a successful mbsync run, reindexes via 'notmuch new --no-hooks' (skips preNew, so
      there is no reentrant call back into mail-sync/mbsync).

      On the known 'Maildir error: duplicate UID' mbsync failure, prints actionable remediation
      guidance only -- no automatic repair.
      HELPEOF
      }

      # --- argument parsing: single optional --no-wait flag, then a required allowlisted mode ---
      NO_WAIT=0
      if [ "''${1:-}" = "--no-wait" ]; then
        NO_WAIT=1
        shift
      fi

      if [ "''${1:-}" = "--help" ] || [ "''${1:-}" = "-h" ]; then
        print_help
        exit 0
      fi

      MODE="''${1:-}"

      case "$MODE" in
        gmail | logos | both)
          ;;
        *)
          echo "[mail-sync] ERROR: unrecognized mode '$MODE' (expected: gmail|logos|both)" >&2
          echo "[mail-sync] Run 'mail-sync --help' for usage." >&2
          exit 1
          ;;
      esac

      # --- blocking flock: acquired BEFORE any mbsync invocation, held across the whole run ---
      LOCKDIR="''${XDG_RUNTIME_DIR:-$HOME/.cache}"
      mkdir -p "$LOCKDIR"
      LOCKFILE="$LOCKDIR/mail-sync.lock"

      exec {LOCK_FD}>"$LOCKFILE"
      if [ "$NO_WAIT" -eq 1 ]; then
        flock -n "$LOCK_FD" || {
          echo "[mail-sync] ERROR: lock held by another mail-sync run (--no-wait given up immediately)" >&2
          exit 1
        }
      else
        flock -w 300 "$LOCK_FD" || {
          echo "[mail-sync] ERROR: lock not acquired within 300s (another mail-sync run appears stuck)" >&2
          exit 1
        }
      fi

      is_auth_failure() {
        printf '%s' "$1" | grep -qE 'invalid_grant|\[AUTHENTICATIONFAILED\] Invalid credentials'
      }

      is_duplicate_uid() {
        printf '%s' "$1" | grep -qE 'Maildir error: duplicate UID [0-9]+ in'
      }

      # run_group <gmail|logos> -- the ONLY place mbsync is ever invoked; always group-scoped,
      # never -a, never with a passed-through argument vector.
      run_group() {
        local group="$1" out status dup_lines
        echo "[mail-sync] Running 'mbsync $group' (group-scoped; NEVER mbsync -a)..." >&2
        set +e
        out=$(mbsync "$group" 2>&1)
        status=$?
        set -e
        echo "$out" >&2

        if [ "$status" -ne 0 ]; then
          if is_duplicate_uid "$out"; then
            dup_lines=$(printf '%s\n' "$out" | grep -E 'Maildir error: duplicate UID [0-9]+ in' || true)
            echo "" >&2
            echo "[mail-sync] DUPLICATE UID detected in 'mbsync $group' output:" >&2
            printf '%s\n' "$dup_lines" | sed 's/^/[mail-sync]   /' >&2
            echo "[mail-sync] This is a KNOWN pre-existing Maildir corruption class (~Mail task 34" >&2
            echo "[mail-sync] baseline; tracked separately as .dotfiles task 852/853)." >&2
            echo "[mail-sync] Remediation (MANUAL -- no automatic repair is performed here):" >&2
            echo "[mail-sync]   1. Identify the colliding folder from the line(s) above." >&2
            echo "[mail-sync]   2. Inspect that folder's colliding ',U=N:' files for near-duplicates." >&2
            echo "[mail-sync]   3. If confirmed spurious, reset that folder's .mbsyncstate entry and" >&2
            echo "[mail-sync]      re-run mail-sync to force a clean re-pull." >&2
            echo "[mail-sync] NOTE: other channels in this group may have already synced successfully" >&2
            echo "[mail-sync] before this failure; partial progress from this run is not rolled back." >&2
          elif is_auth_failure "$out"; then
            echo "" >&2
            echo "[mail-sync] AUTH FAILURE detected (invalid_grant or [AUTHENTICATIONFAILED]) for" >&2
            echo "[mail-sync] group '$group'. Fix credentials, then re-run mail-sync." >&2
          else
            echo "" >&2
            echo "[mail-sync] mbsync $group exited non-zero for a reason OTHER than a known" >&2
            echo "[mail-sync] duplicate-UID or auth failure (exit $status) -- inspect output above." >&2
          fi
          return 1
        fi

        echo "[mail-sync] mbsync $group: reconcile OK" >&2
        return 0
      }

      OVERALL_STATUS=0
      case "$MODE" in
        gmail)
          run_group gmail || OVERALL_STATUS=1
          ;;
        logos)
          run_group logos || OVERALL_STATUS=1
          ;;
        both)
          run_group gmail || OVERALL_STATUS=1
          run_group logos || OVERALL_STATUS=1
          ;;
      esac

      echo "[mail-sync] Reindexing via 'notmuch new --no-hooks' (skips preNew -- no reentrant" >&2
      echo "[mail-sync] call back into mail-sync/mbsync)..." >&2
      notmuch new --no-hooks

      exit "$OVERALL_STATUS"
    '')
  ];
}

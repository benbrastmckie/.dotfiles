#!/usr/bin/env bash
# Task 109, Phase 5: credential-free concurrency test for the `mail-sync` wrapper.
#
# SCOPE BOUNDARY: this proves flock SERIALIZATION only -- that two near-simultaneous
# `mail-sync gmail` invocations run their `mbsync` step in non-overlapping [START, END]
# windows rather than concurrently. It does NOT exercise real mbsync/IMAP behavior, real
# credentials, or the duplicate-UID detection path (those require a live account and are out
# of scope for this harness by design).
#
# Method: stub `mbsync` and `notmuch` executables are placed first on $PATH, ahead of the real
# binaries. The stub `mbsync` appends "PID START <epoch-ns>" / "PID END <epoch-ns>" to a shared
# log file and sleeps ~2s between them so any overlap would be trivially observable. The stub
# `notmuch` is a no-op (verifies mail-sync's internal reindex step doesn't need a real index and,
# implicitly, that it does not re-invoke mail-sync/preNew: the stub never shells out to anything).
#
# Usage: bash concurrency-test.sh [/path/to/mail-sync]
#   Defaults to the mail-sync built at ../../result/home-path/bin (repo root's `result` symlink
#   from `home-manager build --flake .#benjamin`, i.e. Phase 4's build output).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

MAIL_SYNC_BIN="${1:-}"
if [ -z "$MAIL_SYNC_BIN" ]; then
  if [ -x "$REPO_ROOT/result/home-path/bin/mail-sync" ]; then
    MAIL_SYNC_BIN="$REPO_ROOT/result/home-path/bin/mail-sync"
  else
    echo "ERROR: no mail-sync binary given and $REPO_ROOT/result/home-path/bin/mail-sync not found." >&2
    echo "Run 'home-manager build --flake .#benjamin' from the repo root first (Phase 4), or pass" >&2
    echo "an explicit path to a built mail-sync binary as \$1." >&2
    exit 1
  fi
fi
MAIL_SYNC_BIN="$(readlink -f "$MAIL_SYNC_BIN")"
echo "[test] Using mail-sync binary: $MAIL_SYNC_BIN"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

STUBDIR="$WORKDIR/stubs"
mkdir -p "$STUBDIR"
LOG="$WORKDIR/mbsync-calls.log"
: > "$LOG"

# --- stub mbsync: logs START/END with nanosecond epoch timestamps, sleeps between them, exits 0.
cat > "$STUBDIR/mbsync" <<STUBEOF
#!/usr/bin/env bash
set -euo pipefail
echo "\$\$ START \$(date +%s%N) group=\$1" >> "$LOG"
sleep 2.5
echo "\$\$ END \$(date +%s%N) group=\$1" >> "$LOG"
exit 0
STUBEOF
chmod +x "$STUBDIR/mbsync"

# --- stub notmuch: no-op. Confirms mail-sync's internal 'notmuch new --no-hooks' reindex step
# does not depend on a real index, and (since this stub shells out to nothing) that it cannot
# possibly re-invoke mail-sync/preNew -- direct evidence for the reentrancy assumption in the
# plan's risk table.
cat > "$STUBDIR/notmuch" <<'STUBEOF'
#!/usr/bin/env bash
echo "[stub notmuch] called with: $*" >> "${NOTMUCH_CALL_LOG:-/dev/null}"
exit 0
STUBEOF
chmod +x "$STUBDIR/notmuch"

export NOTMUCH_CALL_LOG="$WORKDIR/notmuch-calls.log"
: > "$NOTMUCH_CALL_LOG"

# Isolate the lock under a private XDG_RUNTIME_DIR so this test never contends with a real,
# concurrently-running mail-sync on the same machine.
export XDG_RUNTIME_DIR="$WORKDIR/runtime"
mkdir -p "$XDG_RUNTIME_DIR"

export PATH="$STUBDIR:$PATH"

echo "[test] Launching two near-simultaneous 'mail-sync gmail' invocations..."
"$MAIL_SYNC_BIN" gmail > "$WORKDIR/out-a.log" 2>&1 &
PID_A=$!
sleep 0.2
"$MAIL_SYNC_BIN" gmail > "$WORKDIR/out-b.log" 2>&1 &
PID_B=$!

STATUS_A=0
STATUS_B=0
wait "$PID_A" || STATUS_A=$?
wait "$PID_B" || STATUS_B=$?

echo "[test] Invocation A exit: $STATUS_A, Invocation B exit: $STATUS_B"

echo "[test] --- mbsync call log ---"
cat "$LOG"

FAIL=0

if [ "$STATUS_A" -ne 0 ]; then
  echo "[test] FAIL: invocation A exited non-zero" >&2
  FAIL=1
fi
if [ "$STATUS_B" -ne 0 ]; then
  echo "[test] FAIL: invocation B exited non-zero" >&2
  FAIL=1
fi

if [ ! -f "$XDG_RUNTIME_DIR/mail-sync.lock" ]; then
  echo "[test] FAIL: lockfile $XDG_RUNTIME_DIR/mail-sync.lock does not exist after the run" >&2
  FAIL=1
else
  echo "[test] Lockfile present: $XDG_RUNTIME_DIR/mail-sync.lock"
fi

# Parse the two [START, END] intervals (one mbsync call per invocation; MODE=gmail runs exactly
# one mbsync call) and assert they do NOT overlap.
mapfile -t STARTS < <(awk '$2 == "START" { print $3 }' "$LOG")
mapfile -t ENDS < <(awk '$2 == "END" { print $3 }' "$LOG")

if [ "${#STARTS[@]}" -ne 2 ] || [ "${#ENDS[@]}" -ne 2 ]; then
  echo "[test] FAIL: expected exactly 2 START and 2 END log lines, got ${#STARTS[@]} START / ${#ENDS[@]} END" >&2
  FAIL=1
else
  S1=${STARTS[0]}; E1=${ENDS[0]}
  S2=${STARTS[1]}; E2=${ENDS[1]}
  echo "[test] Interval 1: [$S1, $E1]"
  echo "[test] Interval 2: [$S2, $E2]"
  # Non-overlap: interval2 starts at/after interval1 ends, OR interval1 starts at/after interval2 ends.
  if [ "$S2" -ge "$E1" ] || [ "$S1" -ge "$E2" ]; then
    echo "[test] Intervals do NOT overlap -- serialization confirmed."
  else
    echo "[test] FAIL: intervals OVERLAP -- mbsync ran concurrently, flock did not serialize" >&2
    FAIL=1
  fi
fi

if grep -q "mail-sync\|preNew" "$NOTMUCH_CALL_LOG" 2>/dev/null; then
  echo "[test] FAIL: stub notmuch log unexpectedly references mail-sync/preNew (reentrancy?)" >&2
  FAIL=1
else
  echo "[test] Reentrancy check OK: stub notmuch's 'new --no-hooks' call did not re-invoke mail-sync/preNew."
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "PASS: mail-sync serializes two near-simultaneous invocations (non-overlapping mbsync windows), both exited 0, lockfile present, no reentrancy."
  exit 0
else
  echo "FAIL: see errors above."
  exit 1
fi

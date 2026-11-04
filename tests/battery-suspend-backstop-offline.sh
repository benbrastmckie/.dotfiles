#!/usr/bin/env bash
# ============================================================================
# battery-suspend-backstop-offline.sh -- offline decision-logic exercise
# ============================================================================
# CAVEAT, read before trusting a green run: every case below stubs
# BACKSTOP_SYSTEMCTL_BIN and BACKSTOP_NOTIFY_BIN with recording scripts, so
# this suite exercises the backstop script's DECISION LOGIC ONLY. It CANNOT
# detect an authorization failure on the real `systemctl suspend -i` (the
# session-less-root polkit denial fixed by the
# security.polkit.extraConfig rule in modules/system/power.nix), nor a
# failure in the real root-to-session notify path (the `runuser` defect
# fixed in a later revision). Both of those defects passed this exact suite
# before their respective fixes. A green run here is NOT evidence the
# backstop works end to end -- see the known-gap footer this script prints,
# and Phase 4 of
# specs/123_fix_backstop_polkit_denial_live_verification/plans/01_backstop-polkit-fix.md
# for the checks that actually prove it (they require sudo and a real
# suspend cycle; this script never uses sudo and never suspends anything).
# ============================================================================
set -u

pass=0
fail=0

script="$(systemctl cat battery-suspend-backstop.service 2>/dev/null | sed -n 's/^ExecStart=//p')"
[ -n "$script" ] && [ -x "$script" ] || { echo "FAIL: could not resolve built backstop script" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
state="$work/state"; bat="$work/bat/BAT0"
mkdir -p "$state" "$bat"
sysctl_log="$work/systemctl.log"; notify_log="$work/notify.log"

# The single-quoted format strings below are the SOURCE TEXT of the two stub scripts being
# written, so $@ and ${NOTIFY_EXIT:-0} must reach the file unexpanded -- that is the point,
# not an oversight.
# shellcheck disable=SC2016
printf '#!/usr/bin/env bash\necho "$@" >> %q\n' "$sysctl_log" > "$work/systemctl"
# shellcheck disable=SC2016
printf '#!/usr/bin/env bash\necho "$@" >> %q\nexit "${NOTIFY_EXIT:-0}"\n' "$notify_log" > "$work/notify"
chmod +x "$work/systemctl" "$work/notify"

check() { # check DESC ACTUAL EXPECTED
  if [ "$2" = "$3" ]; then pass=$((pass+1)); else
    fail=$((fail+1)); echo "FAIL: $1 -- got [$2] want [$3]" >&2
  fi
}
run() { # run CAP STATUS -- writes battery state, resets logs, invokes script
  echo "$2" > "$bat/status"; echo "$1" > "$bat/capacity"
  : > "$sysctl_log"; : > "$notify_log"
  BACKSTOP_BATTERY_GLOB="$work/bat/BAT*" STATE_DIRECTORY="$state" \
    BACKSTOP_SYSTEMCTL_BIN="$work/systemctl" BACKSTOP_NOTIFY_BIN="$work/notify" "$script"
}
wake() { # wake SECS_AGO CAP -- fake wake-mark SECS_AGO seconds in the past
  echo "$(( $(date +%s) - $1 )) $2" > "$state/wake-mark"; rm -f "$state/notified"
}

run 5 "Not charging"; check "AC not-charging silent"    "$(cat "$sysctl_log")" ""
run 5 "Charging";     check "AC charging silent"        "$(cat "$sysctl_log")" ""
run 11 Discharging;   check "above threshold silent"    "$(cat "$sysctl_log")" ""

rm -f "$state/wake-mark" "$state/notified"
run 9 Discharging; check "no wake-mark fires"            "$(cat "$sysctl_log")" "suspend -i"

wake 60 9;  run 9 Discharging
check "in-grace skips suspend"     "$(cat "$sysctl_log")" ""
check "in-grace notifies once"     "$(wc -l < "$notify_log")" "1"
run 9 Discharging
check "in-grace suppresses repeat notify" "$(wc -l < "$notify_log")" "0"

wake 400 9; run 9 Discharging; check "expired grace fires"     "$(cat "$sysctl_log")" "suspend -i"
wake 60 11; run 9 Discharging; check "2pt drop voids grace"    "$(cat "$sysctl_log")" "suspend -i"
wake 10 4;  run 4 Discharging; check "below grace_floor fires" "$(cat "$sysctl_log")" "suspend -i"

rm -f "$state/wake-mark" "$state/notified"
export NOTIFY_EXIT=1
run 9 Discharging
unset NOTIFY_EXIT
check "notify failure still suspends" "$(cat "$sysctl_log")" "suspend -i"
check "notify failure still invoked"  "$(wc -l < "$notify_log")" "1"

: > "$notify_log"
BACKSTOP_NOTIFY_BIN="$work/notify" "$script" --test-notify
check "--test-notify exits 0"      "$?" "0"
check "--test-notify invokes notify" "$(wc -l < "$notify_log")" "1"

# --- Non-stubbed: authorization non-regression for the CALLING identity.
# This CANNOT confirm root is granted -- polkit refuses cross-identity
# CheckAuthorization() for untrusted callers (see known-gap footer). Skips
# (not fails) if pkcheck is absent. This is the one assertion in this file
# with no stub between it and the real system.
if command -v pkcheck >/dev/null 2>&1; then
  out=$(pkcheck --action-id org.freedesktop.login1.suspend-ignore-inhibit --process "$$" 2>&1)
  rc=$?
  check "pkcheck: unprivileged caller still auth_admin_keep (exit)" "$rc" "2"
  case "$out" in
    *auth_admin_keep*) pass=$((pass+1)) ;;
    *) fail=$((fail+1)); echo "FAIL: pkcheck output missing auth_admin_keep: $out" >&2 ;;
  esac
else
  echo "SKIP: pkcheck not on PATH -- authorization non-regression assertion skipped"
fi

echo
echo "== $pass passed, $fail failed =="
echo
echo "KNOWN GAP: this suite proves decision logic only. It does NOT prove (1)"
echo "the real 'systemctl suspend -i' is polkit-authorized for a session-less"
echo "root caller, or (2) the real root-to-session notify helper delivers a"
echo "notification. Both require sudo -- see Phase 4 USER CHECKLIST in"
echo "specs/123_fix_backstop_polkit_denial_live_verification/plans/01_backstop-polkit-fix.md"

[ "$fail" -eq 0 ]

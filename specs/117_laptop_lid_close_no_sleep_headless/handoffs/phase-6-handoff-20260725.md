# Phase 6 Handoff — Task 117 (Round 3, Plan v3)

**Immediate Next Action**: Proceed to Phase 7 (docs delta in `docs/gnome-settings.md` and the
`modules/system/power.nix` banner cross-check), then Phase 8 (agent-runnable live checks +
reduced user checklist).

**Current State**: Phase 6 COMPLETED and committed (`fa061c3`, `task 117 phase 6: battery
backstop wake-grace and notification`). Plan file `plans/05_backstop-grace-and-live-verification.md`
is current — Phase 6 heading marked `[COMPLETED]`, all task checkboxes checked with deviation
annotations, verification section filled with actual command output, and the two round-3
Testing & Validation rows for Phase 6 checked.

**Key Decisions Made**:
- Notify helper implemented as a separate `pkgs.writeShellScript "battery-backstop-notify"`
  derivation invoked by path (not an inline shell function), so `timeout` can bound it directly.
- Both `battery-suspend-backstop` and `battery-backstop-wake-mark` share
  `StateDirectory = "battery-suspend-backstop"` (`/var/lib/battery-suspend-backstop/`), matching the
  plan's shared-directory design.
- Added test-only override env vars (`BACKSTOP_BATTERY_GLOB`, `BACKSTOP_SYSTEMCTL_BIN`,
  `BACKSTOP_NOTIFY_BIN`, plus reliance on the standard `STATE_DIRECTORY`) so the offline logic
  exercise runs against a fake sysfs tree / fake state dir / stubbed systemctl+notify-send with no
  `sudo`. All default to the real production paths, so an unmodified systemd invocation is
  unaffected.

**Deviations from Plan**:
- Notify helper as separate script vs. inline function (see Phase 6 task checklist annotation) —
  functionally identical, implementation-detail only.
- Added test-only env-var override hooks not explicitly named in the plan's design section, needed
  to satisfy the plan's own requirement that the offline exercise use "a fake sysfs tree, a fake
  state directory, and a stubbed systemctl."

**What NOT to Try**:
- Do not attempt to test the grace logic by writing to the real `/sys/class/power_supply/BAT*` or
  the real `/var/lib/battery-suspend-backstop/` — use the env-var overrides against a scratch
  directory instead (see `run-backstop-tests.sh` pattern used this round, in the session
  scratchpad — not committed to the repo).
- Do not re-run Phase 1/2/3/5 verification (already complete, live-confirmed 2026-07-25 per Phase 4's
  round-3 status correction).
- Do not edit `docs/no-sleep-agents.md` in Phase 7 (out of `file_scope` — see plan's Scope boundary
  section).

**References**: Plan `specs/117_laptop_lid_close_no_sleep_headless/plans/05_backstop-grace-and-live-verification.md`,
current phase 6 (complete), next phase 7.

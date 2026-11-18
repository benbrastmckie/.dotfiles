# Implementation Summary: Guard fail-closed stall — config, visibility, upstream defect

**Completed**: 2026-11-17
**Duration**: ~1.5 hours

## Overview

Brought the oliver-ben guard's three network knobs (`coalesce_s`, `net_timeout_s`, `deadline_s`)
under declarative control via a `home.activation` step, added a systemd-user watch surface that
makes a fail-closed marker visible without reading `log.jsonl`, applied and converged both
attached checkouts, wrote up the two-surface upstream no-retry defect for Oliver (not patched
locally — the vendor file is sha256-pinned), and documented the config surface and remediation
procedures in `docs/sf1-hub.md`.

## What Changed

- `modules/home/services/sf1-hub-ben.nix` — three `let` constants (`guardCoalesceS = 300`,
  `guardNetTimeoutS = 15`, `guardDeadlineS = 20`) with rationale; a
  `home.activation.sf1HubBenGuardConfig` block that force-sets those three keys in every
  attached checkout's `config.json` on every switch, preserving every other key; a
  `sf1-hub-ben-guard-watch` oneshot service plus a 2-minute timer that notifies on a new
  `stopped.json`/`breaker.json` marker without a one-click action (D7).
- `docs/sf1-hub.md` — a new config-surface section (the three knobs, why these values, the
  freshness cost), a watch-timer section, extended `## Known gaps` (attached-mode-with-empty-
  ruleset stance, the sender-breaker surface), and a remediation subsection under
  `## Stopping it` naming both `unstop` and `send --reset`.
- `specs/143_guard_fail_closed_stall_config_and_upstream_retry/records/01_upstream-defect-and-attach-question.md`
  (new) — the self-contained, sendable write-up for Oliver: both no-retry surfaces, corrected
  measurements, two proposed fixes, and the one open question about future rule acceptance.
- `specs/143_guard_fail_closed_stall_config_and_upstream_retry/records/02_convergence-and-breaker-state.md`
  (new) — pre/post config values per checkout, stranded-outbox counts, breaker details, and the
  reset commands deliberately left unrun.
- Live state: both attached checkouts (`sapience-app`, `sf1-engine`) converged to
  `coalesce_s=300`/`net_timeout_s=15`/`deadline_s=20`; the watch timer is active and has already
  fired real notifications for both checkouts' open sender breakers.

## Decisions

- Declared the knobs via a `home.activation` step (D1) rather than a documented manual step or
  an `attach`-wrapper, since both of those leave an already-attached checkout unfixed — exactly
  the split state (`sapience-app` hand-fixed, `sf1-engine` untouched) found at plan time.
- `coalesce_s=300`/`net_timeout_s=15`/`deadline_s=20` (D2), justified against the measured
  failure pattern (transient `TimeoutError`s against a 2s timeout) and against
  `MIN_PULL_GAP_S`/the Claude Code hook's 30s timeout.
- Stayed attached in both checkouts (D6): an attached guard with an empty rule set enforces
  nothing, so there is no false-positive cost to staying attached, and detaching would also stop
  the consented commit-event reporting.
- Declined a one-click "Unstop" notification action (D7): mako's single-default-action idiom
  needs `notify-send --wait -t 0`, which would hold a timer-driven oneshot active indefinitely.

## Plan Deviations

- **Phase 3** — `sudo nixos-rebuild switch --flake .#hamsa` could not run: `sudo` is
  categorically denied by this dispatch's own permission system. Only
  `home-manager switch --flake .#benjamin` ran — the generation that actually owns
  `~/.nix-profile` and runs `home.activation` — and fully achieved the phase's functional goal
  (both checkouts converged, watch timer active and not failed). Recorded as a Reasoned
  Exclusion in the plan and in `records/02_convergence-and-breaker-state.md`. The user should
  run the sudo command by hand to keep the NixOS-integrated generation in sync too.
- **Phase 5** — `bash .claude/scripts/verify-deploy.sh` (the plan's named "full" tier discharge)
  was deferred to the end-of-batch sweep per this dispatch's own Batch Gate Deferral directive,
  rather than run independently here. `nix flake check` (the one check that directive could not
  narrow) was run directly, detached with a bounded wait, and passed cleanly (`all checks
  passed!`) after fixing a real `statix` `repeated_keys` finding the narrower per-phase checks in
  Phases 1-2 never exercised.

## Verification

- `nix build --no-link .#checks.x86_64-linux.{nixfmt,deadnix,home-eval}`: success, after each
  module edit.
- `nix flake check`: success (`all checks passed!`), including `statix` and `shellcheck` across
  every host (`hamsa`, `garuda`, `iso`, `usb-installer`).
- `shellcheck --external-sources` on the generated watch script: zero findings.
- Dry run against live state with a temporary watch dir: two findings (both checkouts'
  `breaker.json`) on the first run, zero on an immediate second run — mtime dedupe confirmed.
- `home-manager switch --flake .#benjamin`: success, both checkouts converged
  (`coalesce_s=300`/`net_timeout_s=15`/`deadline_s=20`, every other key byte-identical to the
  pre-switch capture); a second switch left both files unchanged (idempotence); `-n` only
  echoed.
- `systemctl --user is-active sf1-hub-ben-guard-watch.timer`: `active`; a manual service start
  exited 0 and produced two real notifications for the live open breakers.
- `bash .claude/scripts/check-task-references.sh`: 0 occurrences, both new record files and
  `docs/sf1-hub.md`.
- `bash .claude/scripts/check-record-versioning.sh docs/sf1-hub.md`: 0 blocking findings.
- `bash .claude/scripts/verify-deploy.sh`: deferred to the batch-level sweep (see Plan
  Deviations above).

## Notes

Both attached checkouts' sender breakers (`send()`'s `breaker.json`) are open, with 86 and 113
events respectively stranded in each checkout's `outbox/`. The exact `guard.py send --reset
--root <checkout>` commands are recorded in `records/02_convergence-and-breaker-state.md` but
deliberately not run — resetting either breaker immediately delivers that checkout's full queued
backlog to the hosted sink, which is an outward-facing, irreversible action left to the user (see
the non-blocking `user_decision` carried on this task's `.return-meta.json`).

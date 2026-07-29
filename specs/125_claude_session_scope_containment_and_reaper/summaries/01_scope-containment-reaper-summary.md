# Implementation Summary: Task #125

**Completed (agent-executable phases only)**: 2026-07-29
**Duration**: ~75 minutes (Phases 1-3)

## Overview

This task wraps the `claude` launcher in a per-invocation `systemd-run --user --scope` and adds a
home-manager timer + oneshot service that stops abandoned `claude-*.scope` units using a
liveness-only predicate. The plan splits into 3 AGENT-EXECUTED phases (1-3, all complete) and 5
USER-EXECUTED phases (4-8) requiring `sudo`, a real interactive wezterm session, and live process
manipulation on host `hamsa`. **Only Phases 1-3 are reported complete here.** Phases 4-7 have not
been run at all, and Phase 8 (docs + rollback path) is blocked on their output — it is not
started. This implementation is **not yet deployed and not yet behaviorally accepted**; the
binding release gate (Phase 7's negative test) has not been executed.

## What Changed

- `packages/claude-code.nix` — rewrote the `writeShellScriptBin "claude"` body to guard-wrap the
  launcher in `systemd-run --user --scope --unit="claude-$$-$(date +%s)" --quiet`, with a
  `CLAUDE_NO_SCOPE=1` escape hatch and a fallback to bare `exec` when `systemd-run` or
  `XDG_RUNTIME_DIR` is unavailable. `--collect` was evaluated empirically (see Decisions) and
  omitted.
- `modules/home/services/claude-session-reaper.nix` — new file. `systemd.user.services.
  claude-session-reaper` (oneshot) implements the liveness-only reap predicate: enumerate
  `claude-*.scope` units only, read each unit's own `cgroup.procs`, test only those PIDs'
  `/proc/<pid>/cmdline` against `(claude|@anthropic|opencode)`, skip on any match or any
  ambiguity, stop only on zero matches. `CLAUDE_REAPER_DRY_RUN` support included.
  `systemd.user.timers.claude-session-reaper` runs it every 10 minutes.
- `modules/home/default.nix` — added `./services/claude-session-reaper.nix` to the service-module
  import block.

## Decisions

- `--collect` omitted from the `systemd-run` invocation: tested live on hamsa (clean and
  non-zero exit, with and without `--collect`) — transient scope units already auto-unload from
  `systemctl --user list-units` on this systemd version regardless of the flag, so it is not
  load-bearing here.
- Reaper script adds two ambiguity checks beyond the plan's numbered steps (unparsable PID list,
  PID vanished mid-read) to satisfy the binding constraint's "any ambiguity ... skip the unit"
  clause literally for those named cases, rather than letting them silently fall through to a
  match/no-match decision.
- Decoy construction for the Phase 2 live-session behavioral test required
  `bash -c 'sleep 600; true' claude-decoy-marker` rather than `exec -a claude-decoy sleep 600`:
  `exec -a` fails under this host's multi-call coreutils wrapper
  (`coreutils: unknown program 'claude-decoy'`), and a bare `bash -c 'sleep 600'` gets
  tail-call exec-optimized by bash into a bare `sleep` process that loses any argv0 marker.

## Plan Deviations

- None — the two added ambiguity checks are additive strengthening within the letter and spirit
  of the binding safety constraint, not a deviation from it, and are documented inline on the
  Phase 2 checklist in the plan file.

## Verification

**Phase 1** (behavioral, live on hamsa — not merely `nix eval`):
- `nix build .#nixosConfigurations.hamsa.pkgs.claude-code --no-link` succeeded.
- Built script confirmed to contain `--scope` (1 match), `UNIT="claude-$$-$(date +%s)"` naming,
  and no `--pty`.
- Standalone equivalent script exercised from `/tmp/scopetest`: cwd propagated
  (`/tmp/scopetest`), exported `TESTVAR` visible inside the scoped child, `exit 37` propagated as
  `$? == 37`, unit name observed as `<name>.scope` in `systemctl --user list-units` while the
  child ran, and `CLAUDE_NO_SCOPE=1` created zero scope units.
- `nix fmt` left `packages/claude-code.nix` unchanged.

**Phase 2** (behavioral, live on hamsa, extracted script run directly via `bash`):
- No `claude-*.scope` units present → reaper exited 0, logged `starting`/`done`, killed nothing.
- Hand-made live decoy → reaper logged `alive, skipping`; decoy scope and its `sleep` child both
  confirmed still running afterward via `systemctl --user list-units` and `cgroup.procs`.
- Hand-made abandoned decoy (no claude signature) → reaper stopped it; scope gone from
  `list-units`, `sleep` process gone from `cgroup.procs`/`ps`.
- `bash -n` passed. `shellcheck` was not available on `$PATH` in this environment (documented,
  not silently skipped).
- Reviewer-checklist grep (`CPUUsage|MemoryCurrent|ActiveEnterTimestamp|etimes|pgrep|ps aux|
  --older|Timestamp`) over the extracted script: no violations.
- `nix fmt` made no further changes to either touched file.

**Phase 3** (evaluation/build gate — explicitly NOT behavioral acceptance):
- `nix flake check --no-build`: all checks passed (nixosConfigurations nandi, hamsa, garuda, iso,
  usb-installer; homeConfigurations; formatter; devShells).
- `nixos-rebuild build --flake .#hamsa`: succeeded, produced
  `/nix/store/9rcrffh091dzwfwfazwd1bg451y6sl6p-nixos-system-hamsa-26.05.20260710.8f0500b`.
- `home-manager build --flake .#benjamin`: succeeded, no `error:` lines.
- Confirmed present in the built home-manager generation:
  `.config/systemd/user/claude-session-reaper.service`,
  `.config/systemd/user/claude-session-reaper.timer`,
  `.config/systemd/user/timers.target.wants/claude-session-reaper.timer`.
- Confirmed the built `claude` wrapper (`home-manager-path/bin/claude`) contains `--scope`.

**Explicitly NOT verified by this implementation pass** (per the plan's own "Testing &
Validation" section and this task's binding safety-verification discipline): nothing here
substitutes for live, behavioral acceptance. Unit-file inspection, `nix eval`, and
`systemd-analyze verify` never count toward acceptance of the behavioral phases, and none were
used as a substitute for them above — every phase-1/phase-2 claim above was backed by an actual
process/cgroup observation on the live host, not an inference from static analysis.

## What Remains (USER-EXECUTED, not started)

- **Phase 4 — Deploy**: `sudo nixos-rebuild switch --flake .#hamsa`,
  `home-manager switch --flake .#benjamin`, confirm the timer is registered
  (`systemctl --user list-timers 'claude-session-reaper*'`), confirm the wrapper on `PATH`
  contains `--scope`.
- **Phase 5 — Live containment + interactive smoke test**: launch a real `claude
  --dangerously-skip-permissions` session in wezterm, confirm its children land in a distinct
  `claude-<pid>-<epoch>.scope` cgroup (not the wezterm scope), and confirm cwd/Ctrl-C/Ctrl-Z/
  resize/exit-code behave unchanged.
- **Phase 6 — Positive reap test**: spawn a `setsid`-detached child inside a live session, kill
  the session, run the reaper on demand, confirm the orphan is actually dead (`ps` — not
  inferred).
- **Phase 7 — RELEASE GATE, negative test**: a long-running, CPU-burning child of a *live*
  session must survive repeated reaper runs untouched (dry-run and real), including a two-live-
  sessions-plus-one-abandoned-scope isolation check. **If this fails, the change does not
  ship** — revert per the plan's Rollback/Contingency section.
- **Phase 8 — Documentation**: write `docs/claude-session-scopes.md` (or extend
  `docs/no-sleep-agents.md`) covering the mechanism, the liveness-only guarantee, the opt-out,
  the escape hatch, and inspection recipes — using the verbatim Phase 5-7 observed output, which
  does not exist yet.

## Notes

This is a live host (`hamsa`) with a working `systemd --user` session, which is why Phases 1-2's
"behavioral, not eyeballed" verification requirements could be satisfied here directly via
`Bash` (standalone script exercises and hand-made decoy scopes) without needing the actual
interactive `claude` launcher or a real session kill — those remain genuinely user-executed
because they require `sudo` for the system-level rebuild and a real interactive wezterm terminal
that only the user can drive.

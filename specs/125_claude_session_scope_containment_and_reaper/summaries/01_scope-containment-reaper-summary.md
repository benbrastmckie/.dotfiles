# Implementation Summary: Task #125

**Agent-executed phases (1-3)**: 2026-07-29
**Deploy + live verification (4-8)**: 2026-08-05
**Status**: Phases 1-4, 6, 8 complete. Phases 5 and 7 PARTIAL — the **release gate passed**;
what remains is interactive-terminal confirmation only.

## Overview

The `claude` launcher is wrapped in a per-invocation `systemd-run --user --scope`, and a
home-manager timer stops abandoned `claude-*.scope` units using a liveness-only predicate. The
mechanism is now **deployed on hamsa and behaviorally accepted**: the orphan scenario from the
task description was reproduced and killed, and the binding safety constraint — never kill a
long-running child while its session lives — was tested to its release-gate criteria and held.

## What Changed

- `packages/claude-code.nix` — the `writeShellScriptBin "claude"` body guard-wraps the launcher
  in `systemd-run --user --scope --unit="claude-$$-$(date +%s)" --quiet`, with a
  `CLAUDE_NO_SCOPE=1` escape hatch and a fallback to bare `exec` when `systemd-run` or
  `XDG_RUNTIME_DIR` is unavailable. `--collect` was evaluated empirically and omitted.
- `modules/home/services/claude-session-reaper.nix` — new. Oneshot service implementing the
  liveness-only predicate: enumerate `claude-*.scope` units only, read each unit's own
  `cgroup.procs`, test only those PIDs' `/proc/<pid>/cmdline` against
  `(claude|@anthropic|opencode)`, skip on any match or any ambiguity, stop only on zero matches.
  `CLAUDE_REAPER_DRY_RUN` supported. Timer runs it every 10 minutes.
- `modules/home/default.nix` — imports the reaper module.
- `docs/claude-session-scopes.md` — new user-facing documentation (Phase 8).
- `docs/README.md` — index entry for the above.

## Decisions

- `--collect` omitted: tested live on hamsa — transient scopes already auto-unload on this
  systemd version regardless of the flag.
- Reaper adds two ambiguity checks beyond the plan's numbered steps (unparsable PID list, PID
  vanished mid-read) to satisfy the binding constraint's "any ambiguity … skip the unit" clause
  literally.
- Phase 7's live sessions were real `claude` invocations in non-interactive (`-p`) mode rather
  than interactive wezterm panes. The gate tests the reaper's predicate, which keys on process
  cmdline and cgroup membership — identical either way. This is a deviation from the written
  commands and is called out as such, not glossed.

## Verification

### Phase 4 — Deploy [COMPLETED]

User ran `sudo nixos-rebuild switch --flake .#hamsa` and `home-manager switch --flake .#benjamin`.

- `/run/current-system` → `9rcrffh091dzwfwfazwd1bg451y6sl6p-nixos-system-hamsa-…`, matching the
  Phase 3 build output.
- `systemctl --user list-timers 'claude-session-reaper*'` → 1 timer, next/last populated.
- `~/.config/systemd/user/claude-session-reaper.{service,timer}` present as store symlinks.
- Deployed wrapper `/etc/profiles/per-user/benjamin/bin/claude` →
  `/nix/store/zijrqv7sdgbpp9gpsqc0axm52wd1l5pk-claude/bin/claude`, contains `--scope`.
- Two scheduled reaper runs observed with no `claude-*.scope` present: `Result=success`,
  `ExecMainStatus=0`, `NRestarts=0`, nothing killed. This retires the "reaper fails every run and
  degrades the user systemd session" risk with live evidence.

### Phase 5 — Live containment [PARTIAL: containment verified, TTY behavior NOT verified]

A real `claude -p` invocation through the deployed wrapper:

```
unit: claude-1026815-1785950586.scope   loaded active running
ControlGroup: /user.slice/user-1000.slice/user@1000.service/app.slice/claude-1026815-1785950586.scope
1026815  npm exec @anthr  0::/user.slice/…/claude-1026815-1785950586.scope
1026946  claude           0::/user.slice/…/claude-1026815-1785950586.scope
exit=0
```

Both the npx parent and the real `claude` process are in the per-session scope, **not**
`app-gnome-wezterm-5459.scope`. Exit code propagated. No `Running as unit:` banner leaked.

**Not verified**: cwd preservation in an interactive launch, Ctrl-C mid-turn, Ctrl-Z, terminal
resize, scrollback, normal exit to a shell prompt. These require a real wezterm session and
remain USER-EXECUTED.

### Phase 6 — Positive reap [COMPLETED]

The exact scenario from the task description, reproduced end to end:

```
session exit=0                       (real claude -p session, spawned setsid nohup sleep 900)
scope AFTER the session exited: claude-1035589-1785950639.scope  loaded active running
survivors in scope: 1035865  sleep   (the detached orphan)

DRY RUN:  claude-session-reaper: DRY-RUN would stop claude-1035589-1785950639.scope (pids: 1035865)
          alive-after-dryrun: 1035865 sleep        (dry run killed nothing)
REAL RUN: claude-session-reaper: stopping abandoned claude-1035589-1785950639.scope (pids: 1035865)
VERDICT:  ORPHAN DEAD (PASS)         (by ps, not inferred from logs)
          scope gone from list-units
```

### Phase 7 — NEGATIVE test / RELEASE GATE [PARTIAL — GATE PASSED]

Live session A = `claude-1041456-1785950741.scope`, CPU-burning child `LONGPID=1042424`
(`setsid nohup bash -c 'while :; do :; done'`) inside the scope.

Soak — a full core, so any accidental CPU or age threshold would have fired:

```
soak t=20s:  1042424   22  00:00:22 bash
…
soak t=240s: 1042424  242  00:04:01 bash
live claude signature present in scope A: yes
```

Dry run, then three real runs:

```
claude-session-reaper: claude-1041456-1785950741.scope alive, skipping
after dry-run: LONGPID ALIVE
1042424 243 00:04:02 bash    run 1: LONGPID survived
1042424 244 00:04:03 bash    run 2: LONGPID survived
1042424 245 00:04:04 bash    run 3: LONGPID survived
```

Zero occurrences of `FAIL: long-running child was killed`. `TIME` climbs across runs.

**Two-live-session isolation** — one reaper pass discriminating three scopes correctly:

```
BEFORE: claude-1117540-1785951078.scope active running
        claude-1117541-1785951078.scope active running
        claude-decoy-iso-1117537.scope  active running   (abandoned, pid 1135923)

journal: claude-1117540-1785951078.scope alive, skipping
         claude-1117541-1785951078.scope alive, skipping
         stopping abandoned claude-decoy-iso-1117537.scope (pids: 1135923)

AFTER:  claude-1117540-1785951078.scope active running
        claude-1117541-1785951078.scope active running
        decoy pid 1135923 GONE (expected)
        burners alive: 1121756 27 00:00:27 / 1121041 29 00:00:28
```

Post-test state: no residual `claude-*.scope`, no stray burner or `sleep 3000` processes,
reaper `Result=success` / `ExecMainStatus=0` / `NRestarts=0`.

**Honest note on the first attempt**: the isolation check inside the main Phase 7 script did not
actually establish a second live session — the inner session's command was rejected by an
unrelated environment policy hook, so it exited before creating a scope. That run therefore
proved only one-live-plus-one-abandoned discrimination. The two-live-session variant was re-run
separately (output above) and is the result being claimed.

**Not verified**: "the live session is still fully interactive afterwards" — folded into the
Phase 5 user smoke test.

### Phase 8 — Documentation [COMPLETED]

`docs/claude-session-scopes.md` covers the mechanism, the liveness-only guarantee stated as a
promise to the reader, the `systemd-run --user --unit=` opt-out for deliberately-detached work,
the `CLAUDE_NO_SCOPE=1` escape hatch, inspection recipes, the nested-session note, independence
from the sleep inhibitors, and the rollback ladder. Both "how do I stop this killing my job"
answers are reachable from the first screen. `docs/README.md` gained an index entry. Every
command shown was actually run during Phases 4-7. No task-number references
(`.claude/rules/no-task-references-in-deliverables.md`).

## What Remains (USER-EXECUTED)

Interactive terminal confirmation only — the safety properties are already proven:

1. Launch `claude --dangerously-skip-permissions` in a wezterm pane from a project directory.
2. Confirm cwd is preserved and no `Running as unit:` banner appears.
3. Exercise Ctrl-C mid-turn, Ctrl-Z, terminal resize, scrollback.
4. Exit normally; confirm exit code and shell prompt behave.

If any of that regresses: `export CLAUDE_NO_SCOPE=1` restores the old behavior instantly with no
rebuild, and the full rollback ladder is in `docs/claude-session-scopes.md`.

## Notes

- Follow-up, out of scope here: `docs/discord-bot.md` carries pre-existing task-number
  references (lines 269, 409) that violate
  `.claude/rules/no-task-references-in-deliverables.md`. Not introduced by this work and left
  untouched; worth a separate cleanup.

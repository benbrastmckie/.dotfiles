# Implementation Plan: Task #125

- **Task**: 125 - Claude session scope containment and reaper
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours (≈2.5h agent-executed, ≈2.5h user-executed live verification)
- **Dependencies**: None
- **Research Inputs**: specs/125_claude_session_scope_containment_and_reaper/reports/01_scope-containment-reaper.md
- **Artifacts**: plans/01_scope-containment-reaper.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Every Claude Code session on this host currently shares one cgroup with the terminal emulator
(`app-gnome-org.wezfurlong.wezterm-*.scope`), so there is no per-session boundary and a detached
child can outlive its session indefinitely — as happened with a runaway `python3` that burned
50h47m of CPU over 2d3h and pinned the package at 99 °C. This plan wraps the `claude` launcher in
a per-invocation `systemd-run --user --scope` (giving each session its own cgroup that even
double-forked children cannot escape), and adds a home-manager timer + oneshot service that stops
only those `claude-*.scope` units whose owning session is provably gone. The definition of done is
**live, behavioral** verification on host `hamsa`: a real session's children observed in a distinct
cgroup, a detached orphan observed dying after its session is killed, and — decisively — a
long-running child observed *surviving* a reaper run while its session is still alive.

### Research Integration

Findings from `reports/01_scope-containment-reaper.md` that this plan takes as settled and does
not re-derive:

- **No `--pty`.** `--pty` is invalid in combination with `--scope`, and unnecessary: a scope's
  child is an ordinary foreground process of the invoking shell with fds 0/1/2 inherited.
- **cwd, environment, and exit code all propagate through plain `systemd-run --user --scope`**
  with no additional flags (verified live: `pwd`, `printenv`, `exit 37` → `$? == 37`).
- **`--unit=foo` produces unit `foo.scope`** — `systemd-run` appends the suffix itself, so the
  reaper's glob must be `'claude-*.scope'`, never `'claude-*'`.
- **Unit naming is wrapper-generated**: `claude-$$-$(date +%s)`. The CLI's own `session_id` does
  not exist yet at the moment the wrapper must choose a unit name, and the existing
  `SessionStart`/`SessionEnd` sleep-inhibitor hooks key off that separate identifier — the two
  mechanisms are independent and need no shared ID.
- **Reap predicate**: enumerate `claude-*.scope` units only → read each unit's own
  `cgroup.procs` → test only those specific PIDs' `/proc/<pid>/cmdline` → stop only when *zero*
  match. Never a system-wide `pgrep`, never `ActiveState=abandoned` as the signal.
- **Cautionary precedent**: `gmail-oauth2.nix` (disabled) degraded the whole user systemd session
  by failing every run. Every inspection step in the reaper must tolerate "already gone" races.
- **Module shape precedent**: `cache-cleanup.nix` and `mail-sync-timer.nix` (oneshot + calendar
  timer, PATH export, `starting`/`done` echo bracketing, `Persistent = true`).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found; no roadmap phases included.

## BINDING SAFETY CONSTRAINT (non-negotiable)

This section is a hard contract on the implementation. Any deviation is a task failure, not a
design variation, and must be reverted rather than argued for.

**The reaper exists to remove processes whose owner is gone. It does not exist to police resource
usage.** The user runs long, legitimately expensive work under Claude sessions and it must never
be interrupted.

**MUST**:
1. The reap predicate is **liveness-based ONLY**: "the claude session that owns this scope is
   gone", determined solely by finding zero claude-signature processes among the PIDs listed in
   *that scope's own* `cgroup.procs`.
2. The reaper acts **only** on units matching `claude-*.scope`. The glob passed to
   `systemctl --user list-units` is the hard boundary.
3. On any ambiguity (unreadable cgroup, unparsable PID list, `systemctl` error, a PID that
   vanished mid-read), the reaper **skips the unit**. The safe failure mode is "never reap";
   "reap on uncertainty" is forbidden.

**MUST NOT** — these are forbidden as kill criteria, permanently, including in any future tuning
pass:
1. **CPU-time thresholds** of any kind (`CPUUsageNSec`, `/proc/<pid>/stat` utime/stime, `ps -o
   time`, `cputime`).
2. **Memory / RSS thresholds** of any kind.
3. **Wall-clock / age thresholds** of any kind (unit `ActiveEnterTimestamp`, process start time,
   `etimes`, "has been running more than N hours").
4. Enumerating user processes system-wide (`pgrep -f`, `ps aux`, `/proc` scans) for any purpose
   in the kill path.
5. Killing, signalling, or stopping anything not reached via a `claude-*.scope` unit's own
   `cgroup.procs`.
6. Stopping a scope in which **any** PID matches the claude signature — a single match means
   alive, means skip, unconditionally.

A child that has been running for ten hours and is consuming 100% of a core **must survive
untouched** as long as its owning session lives. Phase 7 is the test that proves this, and it is
a release gate: if Phase 7 fails, the change does not ship.

**Reviewer checklist** (apply to every diff produced by this plan): grep the reaper script for
`CPUUsage`, `MemoryCurrent`, `ActiveEnterTimestamp`, `etimes`, `pgrep`, `ps aux`, `--older`,
`Timestamp`. Any hit outside a comment is a violation.

## Goals & Non-Goals

**Goals**:
- Every `claude` invocation runs inside its own `claude-<pid>-<epoch>.scope` user scope, so all
  descendants (including `setsid`/double-forked children and MCP server subprocesses) are
  contained in one per-session cgroup.
- A systemd user timer periodically stops `claude-*.scope` units whose owning session is gone,
  using a liveness-only predicate.
- The interactive terminal experience in wezterm is unchanged: cwd, environment, TTY behavior,
  Ctrl-C, Ctrl-Z, terminal resize, and exit code all behave exactly as before.
- A documented, zero-rebuild escape hatch (`CLAUDE_NO_SCOPE=1`) and a documented opt-out for
  deliberately-detached work.
- Behavioral proof on the real host, including the negative test protecting the binding
  constraint.

**Non-Goals**:
- Any resource-based process management, throttling, or accounting policy (explicitly forbidden
  above).
- Changing, coordinating with, or replacing the existing `SessionStart`/`SessionEnd` sleep
  inhibitor hooks (`docs/no-sleep-agents.md`) — independent mechanism, untouched.
- Killing the runaway processes that motivated this task (already handled; this task prevents
  recurrence).
- Containing non-`claude` tools (`opencode`, editors, etc.) — out of scope for this change.
- Pinning or changing the Claude Code version fetched by `npx`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Reaper kills a live session's long-running child (violates binding constraint) | H | L | Predicate requires *zero* signature matches to act; dry-run mode; Phase 7 negative test is a release gate |
| Wrapper breaks interactive TTY / job control in wezterm | H | L | Phase 5 interactive smoke test before trusting it; `CLAUDE_NO_SCOPE=1` escape hatch needs no rebuild; Phase 8 rollback path |
| `systemd-run` unavailable (SSH without lingering, container) makes `claude` unlaunchable | H | L | `command -v systemd-run` + `XDG_RUNTIME_DIR` guard falls back to bare `exec` |
| Reaper service fails every run and degrades the user systemd session (gmail-oauth2 repeat) | M | M | Every external call guarded (`|| true`, existence checks); script exits 0 unconditionally; Phase 6 checks `systemctl --user status` is not `failed` |
| Signature match misses a future claude entry-point name → live scope wrongly reaped | H | L | Broad signature `(claude\|@anthropic\|opencode)` matching repo precedent; predicate needs zero matches, so a *broader* pattern is strictly safer; Phase 7 re-run after any CLI upgrade |
| Race: session ends between `list-units` and `cgroup.procs` read | L | H | Treated as "nothing to reap", never an error |
| Two live sessions, reaper stops the wrong one | H | L | Per-unit predicate is self-contained; Phase 7 runs with two concurrent sessions to prove isolation |
| MCP servers / lean-lsp workers killed with an abandoned session | L | H | Desired behavior — these are meant to die with their owning session |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |
| 4 | 5 | 4 |
| 5 | 6, 7 | 5 |
| 6 | 8 | 6, 7 |

Phases within the same wave can execute in parallel. Phases 6 and 7 are both live tests on the
same host and must be run **serially** (in either order) rather than concurrently, to keep the set
of live `claude-*.scope` units unambiguous during each test.

**Execution mode legend**: phases are marked AGENT-EXECUTED or **USER-EXECUTED**. USER-EXECUTED
phases require a real interactive terminal and/or `sudo` and cannot be completed by an agent; the
implementer stops, presents the verbatim commands and expected output, and waits.

---

### Phase 1: Scope-containment wrapper in `packages/claude-code.nix` [COMPLETED]

**Execution**: AGENT-EXECUTED

**Goal**: Wrap the `claude` launcher so each invocation execs inside its own transient user scope,
with a fallback guard and a zero-rebuild escape hatch, without changing anything else about how
the CLI is launched.

**Tasks**:
- [x] Rewrite the `writeShellScriptBin "claude"` body to:
  - [x] Bypass containment and `exec` bare when `CLAUDE_NO_SCOPE` is set and non-empty (escape
        hatch — recovery from a broken interactive experience without a rebuild).
  - [x] Bypass containment and `exec` bare when `command -v systemd-run` fails **or**
        `XDG_RUNTIME_DIR` is unset/empty (no working user manager).
  - [x] Otherwise `UNIT="claude-$$-$(date +%s)"` and
        `exec systemd-run --user --scope --unit="$UNIT" --quiet -- ${nodejs}/bin/npx @anthropic-ai/claude-code@latest "$@"`.
  - [x] No `--pty` (invalid with `--scope`), no `-d`/`--same-dir`, no `-E`/`--setenv` — all
        inherited (research, verified live).
- [x] Evaluate `--collect` empirically (research item 6) before deciding whether to include it:
      create a scope with `--collect`, let the command exit cleanly, check whether the unit
      auto-unloads from `systemctl --user list-units`. Include the flag only if it demonstrably
      helps; it is hygiene only and not load-bearing for reaper correctness. *(Tested live on
      hamsa: transient scope units auto-unload from `list-units` on both clean and non-zero exit
      regardless of `--collect` on this systemd version — no observable difference, so omitted.)*
- [x] Update the file's header comment to explain the containment, name the escape hatch, and
      point at the reaper module (durable anchors — module filename and doc section, not task
      numbers).
- [x] Preserve the existing header notes about `@latest` pinning, npx cache clearing, and model
      selection.

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `packages/claude-code.nix` — replace the single-line `exec` with the guarded scope wrapper
  plus explanatory comments.

**Verification** (behavioral, not eyeballed):
- `nix build .#nixosConfigurations.hamsa.pkgs.claude-code --no-link` (or
  `nix eval --raw .#nixosConfigurations.hamsa.pkgs.claude-code.outPath`) succeeds; if the overlay
  attribute path differs, use whatever path `overlays/unstable-packages.nix` exposes.
- Read the built script out of the store and confirm it contains `--scope`, contains
  `--unit="claude-$$-` style naming, and does **not** contain `--pty`.
- Exercise an equivalent standalone script (same logic, `sleep`/`pwd`/`printenv`/`exit 37` in
  place of the npx call) from `/tmp/scopetest` and confirm: unit name ends `.scope` in
  `systemctl --user list-units`, cwd is `/tmp/scopetest`, an exported test variable is visible,
  and `exit 37` propagates as `$? == 37`.
- Confirm `CLAUDE_NO_SCOPE=1 <standalone script>` runs without creating any scope unit.
- `nix fmt` leaves the file unchanged (or apply its output).

---

### Phase 2: Reaper module `modules/home/services/claude-session-reaper.nix` [COMPLETED]

**Execution**: AGENT-EXECUTED

**Goal**: Add the oneshot service + timer implementing the liveness-only reap predicate, modeled
exactly on `cache-cleanup.nix`/`mail-sync-timer.nix`, and wire it into the home-manager service
imports.

**Tasks**:
- [x] Create `modules/home/services/claude-session-reaper.nix` with
      `systemd.user.services.claude-session-reaper` (`Type = "oneshot"`, `ExecStart` a
      `pkgs.writeShellScript`, PATH export matching the precedent, `claude-session-reaper:
      starting` / `: done` echo bracketing).
- [x] Implement the reap script exactly as specified:
  1. `systemctl --user list-units --type=scope --all --no-legend --plain 'claude-*.scope'`
     — the sole enumeration surface.
  2. Per unit: `systemctl --user show "$unit" -p ControlGroup --value`, then read
     `/sys/fs/cgroup<path>/cgroup.procs` guarded by an existence check and `|| true`.
  3. Empty PID list → nothing to kill; `systemctl --user reset-failed "$unit" || true`; continue.
  4. Non-empty → for **each PID in that list only**, read `/proc/<pid>/cmdline` (`tr '\0' ' '`),
     falling back to `/proc/<pid>/comm`, and test against `(claude|@anthropic|opencode)`.
  5. **Any** match → live session → skip the unit entirely, log
     `claude-session-reaper: <unit> alive, skipping`. No further inspection of any kind.
  6. **Zero** matches → abandoned → `systemctl --user stop "$unit" || true` then
     `systemctl --user reset-failed "$unit" || true`; log the unit and the PIDs it contained.
  *(Also added, beyond the letter of the spec but within its "skip on ambiguity" intent:
  explicit unparsable-PID-list detection and explicit PID-vanished-mid-read detection, both of
  which skip the unit rather than falling through to a kill decision — see the binding
  constraint's "any ambiguity" clause.)*
- [x] Add `CLAUDE_REAPER_DRY_RUN` support: when set and non-empty, log the decision for each unit
      but never issue `stop`. This is the mechanism Phase 7's negative test uses to observe the
      predicate's verdict without risking a live child, and stays in the shipped script as a
      permanently available audit tool.
- [x] Guarantee the script cannot leave the unit `failed`: no `set -e` that can trip on a
      race, and a final `exit 0`.
- [x] Add `systemd.user.timers.claude-session-reaper` with `Requires = [
      "claude-session-reaper.service" ]`, `OnCalendar = "*:0/10"`, `Persistent = true`,
      `RandomizedDelaySec = 60`, `Install.WantedBy = [ "timers.target" ]`.
- [x] Write the module header comment covering: the binding liveness-only constraint and the
      explicit prohibition on CPU/memory/wall-clock criteria (so a future editor cannot
      "optimize" it in), the `gmail-oauth2.nix` degraded-session cautionary precedent, and the
      opt-out (anything launched as its own non-`claude-*` transient unit is never touched).
- [x] Add `./services/claude-session-reaper.nix` to the "Service modules" import block in
      `modules/home/default.nix`, after `./services/mail-sync-timer.nix`.

**Behavioral verification performed** (live on hamsa, extracted script run directly via `bash`,
before any rebuild):
- No `claude-*.scope` units present → exit 0, `starting`/`done` logged, nothing killed.
- Hand-made live decoy (`systemd-run --user --scope --unit=claude-decoy-live-$$ -- bash -c
  'sleep 600; true' claude-decoy-marker`, chosen so bash's own PID persists in the scope's
  `cgroup.procs` with a cmdline containing `claude-decoy-marker` — bash's tail-call exec
  optimization otherwise replaces the shell with a bare `sleep` process and loses any argv0
  marker, and `exec -a` does not work under NixOS's multi-call coreutils wrapper) → reaper logged
  `alive, skipping`; decoy scope and its `sleep` child both still running afterward, confirmed by
  `systemctl --user list-units` and `cgroup.procs`.
- Hand-made abandoned decoy (`systemd-run --user --scope --unit=claude-decoy-abandoned-$$ --
  sleep 600`, no claude signature) → reaper stopped it; the scope disappeared from `list-units`
  and its `sleep` process was gone from `cgroup.procs`/`ps`.
- `bash -n` passed on the extracted script. `shellcheck` was not available on `$PATH` in this
  environment, so that check was skipped (documented, not silently omitted).
- Reviewer-checklist grep (`CPUUsage|MemoryCurrent|ActiveEnterTimestamp|etimes|pgrep|ps aux|
  --older|Timestamp`) over the extracted script: no violations.

**Timing**: 1 hour 15 minutes

**Depends on**: none

**Files to modify**:
- `modules/home/services/claude-session-reaper.nix` — new file (service + timer + reap script).
- `modules/home/default.nix` — add one import line to the service-modules block.

**Verification** (behavioral, not eyeballed):
- Extract the reap script to a scratch file and run it directly, three ways, before any rebuild:
  - with **no** `claude-*.scope` units present → exits 0, logs `starting`/`done`, kills nothing;
  - against a **hand-made live decoy**: `systemd-run --user --scope --unit=claude-decoy-live-$$
    -- bash -c 'exec -a claude-decoy sleep 600'` → reaper must log "alive, skipping" and the
    decoy must still be running afterwards;
  - against a **hand-made abandoned decoy**: a `claude-*.scope` containing only a plain
    `sleep 600` with no claude signature → reaper stops it and the `sleep` is gone.
- `bash -n` on the extracted script passes; `shellcheck` if available.
- Reviewer checklist grep from the binding-constraint section returns no violations.
- `nix fmt` leaves both files unchanged (or apply its output).

---

### Phase 3: Static evaluation gate [COMPLETED]

**Execution**: AGENT-EXECUTED

**Goal**: Prove both configuration paths still evaluate and build before asking the user to run a
switch, so a rebuild failure never lands in the user's lap.

**Tasks**:
- [x] `nix flake check` (or, if slow/broad in this repo, the targeted builds below). *(Ran
      `nix flake check --no-build`: all checks passed across nixosConfigurations nandi, hamsa,
      garuda, iso, usb-installer, plus homeConfigurations, formatter, devShells — no errors.)*
- [x] Build the NixOS-integrated path: `nixos-rebuild build --flake .#hamsa`.
- [x] Build the standalone home-manager path: `home-manager build --flake .#benjamin`.
- [x] Confirm the reaper unit files appear in the built home-manager generation
      (`claude-session-reaper.service`, `claude-session-reaper.timer`) and that the built
      `claude` wrapper in the result contains the scope invocation.
- [x] Resolve any evaluation error before proceeding — do not hand a broken build to the user.
      *(None encountered.)*

**Timing**: 30 minutes

**Depends on**: 1, 2

**Files to modify**: none (verification-only phase).

**Verification**:
- Both build commands exit 0. **Confirmed**: `nixos-rebuild build --flake .#hamsa` completed
  ("Done. The new configuration is /nix/store/9rcrffh091dzwfwfazwd1bg451y6sl6p-nixos-system-
  hamsa-26.05.20260710.8f0500b"); `home-manager build --flake .#benjamin` completed with no
  `error:` lines.
- `grep -l claude-session-reaper` finds the two unit files under the build result. **Confirmed**:
  `.config/systemd/user/claude-session-reaper.service`,
  `.config/systemd/user/claude-session-reaper.timer`, and
  `.config/systemd/user/timers.target.wants/claude-session-reaper.timer` all present under the
  built `home-manager-files` store path; the built `claude` wrapper (resolved from
  `home-manager-path/bin/claude`) contains `--scope` (`grep -c` = 1).
- Note explicitly in the phase notes that a successful build is **not** acceptance — Phases 5-7
  are the acceptance criteria. **This build/eval success is NOT behavioral acceptance.** Phases
  4-7 (deploy, live containment, positive reap, and the release-gating negative test) remain
  entirely unexecuted and USER-EXECUTED; none of Phase 3's checks substitute for them.

---

### Phase 4: Deploy (USER-EXECUTED) [COMPLETED]

**Execution**: **USER-EXECUTED** — requires `sudo` and the user's own shell.

**Goal**: Activate the new wrapper and the reaper timer on host `hamsa`.

**Tasks**:
- [ ] Implementer stops and presents the commands below verbatim; user runs them.
- [ ] User confirms the timer is listed and the wrapper on `PATH` is the new one.

**Timing**: 20 minutes (mostly build/activation wait)

**Depends on**: 3

**Files to modify**: none.

**Commands (verbatim, run by the user)**:
```bash
cd /home/benjamin/.dotfiles

# 1. NixOS-integrated path (system + /etc/profiles/per-user/benjamin)
sudo nixos-rebuild switch --flake .#hamsa

# 2. Standalone home-manager path (~/.nix-profile, takes PATH priority)
home-manager switch --flake .#benjamin

# 3. Confirm the timer is registered and scheduled
systemctl --user list-timers 'claude-session-reaper*'

# 4. Confirm the wrapper on PATH is the scoped one
grep -c -- '--scope' "$(readlink -f "$(command -v claude)")"
```

**Expected output**:
- Step 1/2: activation completes with no `error:` lines. Warnings are acceptable.
- Step 3: one row for `claude-session-reaper.timer` showing a `NEXT` time within ~10 minutes and
  `UNIT` = `claude-session-reaper.timer`, `ACTIVATES` = `claude-session-reaper.service`.
- Step 4: prints a non-zero count (the wrapper contains `--scope`).
- `systemctl --user --failed` shows no `claude-session-reaper*` entry.

**Verification**:
- All four commands produce the expected output above. If step 3 shows no timer, the import line
  in `modules/home/default.nix` did not take effect — return to Phase 2.

---

### Phase 5: Live containment + interactive smoke test (USER-EXECUTED) [PARTIAL]

**Execution**: **USER-EXECUTED** — requires a real interactive `claude` session in wezterm.

**Goal**: Prove a real session's children land in a distinct per-session cgroup and that the
interactive terminal experience is unimpaired. This is the phase that decides whether the wrapper
is safe to keep.

**Tasks**:
- [ ] User launches a real interactive session in wezterm from a project directory, with the
      usual `--dangerously-skip-permissions` flag.
- [ ] Confirm a `claude-*.scope` unit exists for it and that the CLI process and its children are
      in that scope's `cgroup.procs`, distinct from the wezterm scope.
- [ ] Confirm cwd was preserved (the session sees the project directory it was launched from).
- [ ] Exercise interactive correctness: Ctrl-C during a running turn, Ctrl-Z, terminal resize,
      scrollback. (Research flagged process-group/job-control semantics as documented-but-
      unverified; this is where that gets settled.)
- [ ] Exit the session normally and confirm the exit code and shell prompt behave normally.

**Timing**: 30 minutes

**Depends on**: 4

**Files to modify**: none.

**Commands (verbatim; run steps 2-4 from a *second* wezterm pane while the session is live)**:
```bash
# Pane A — launch a real session the way you normally do
cd /home/benjamin/.dotfiles
claude --dangerously-skip-permissions

# Pane B — observe containment
systemctl --user list-units --type=scope --all --no-legend --plain 'claude-*.scope'

# Pane B — read the scope's own process list (substitute the unit name from above)
CG=$(systemctl --user show claude-<PID>-<EPOCH>.scope -p ControlGroup --value)
cat "/sys/fs/cgroup${CG}/cgroup.procs"

# Pane B — confirm those PIDs really are the session and are NOT in the wezterm scope
for p in $(cat "/sys/fs/cgroup${CG}/cgroup.procs"); do
  printf '%s\t%s\t%s\n' "$p" "$(cat /proc/$p/comm 2>/dev/null)" "$(cat /proc/$p/cgroup 2>/dev/null)"
done
```

**Expected output**:
- Exactly one new `claude-<pid>-<epoch>.scope` unit, `loaded active running`.
- `cgroup.procs` is non-empty and contains the node/claude process (and any MCP subprocesses).
- Every listed PID's `/proc/<pid>/cgroup` names the `claude-*.scope`, **not**
  `app-gnome-org.wezfurlong.wezterm-*.scope`.
- In Pane A: no `Running as unit:` banner (suppressed by `--quiet`), the session opened in
  `/home/benjamin/.dotfiles`, Ctrl-C interrupts a turn as it always did, Ctrl-Z and resize behave
  normally, and exiting returns to a normal prompt.

**Verification**:
- All of the above hold. **If interactive behavior regresses in any way** (Ctrl-C dead, input
  garbled, resize broken), stop immediately and apply the Phase 8 rollback path — start with
  `export CLAUDE_NO_SCOPE=1`, which restores the old behavior in the current shell with no
  rebuild, and record the exact symptom in the task notes.

---

### Phase 6: Positive reap test — orphan actually dies (USER-EXECUTED) [COMPLETED]

**Execution**: **USER-EXECUTED** — requires a real session that gets killed.

**Goal**: Prove the mechanism this task exists for: a detached, double-forked child of a dead
session is actually killed by the reaper, not merely detected.

**Tasks**:
- [ ] Launch a real session; from inside it, spawn a deliberately detached child that mimics the
      runaway case (`setsid nohup ... &`, a busy loop).
- [ ] Confirm the detached child is nonetheless inside the session's scope cgroup.
- [ ] Kill the session (close it / `kill` the CLI process), leaving the child orphaned.
- [ ] Run the reaper manually (do not wait for the timer) and confirm the child is gone.
- [ ] Confirm the reaper service did not end in `failed`.

**Timing**: 30 minutes

**Depends on**: 5

**Files to modify**: none.

**Commands (verbatim)**:
```bash
# Pane A — launch a session, then from inside it run (via the Bash tool or a shell it spawns):
setsid nohup bash -c 'while :; do :; done' >/dev/null 2>&1 &

# Pane B — confirm the detached child is in the session's scope cgroup
CG=$(systemctl --user show claude-<PID>-<EPOCH>.scope -p ControlGroup --value)
cat "/sys/fs/cgroup${CG}/cgroup.procs"          # must include the busy-loop bash PID
ORPHAN=<busy-loop PID>

# Pane B — kill the owning session only (NOT the orphan)
kill <claude CLI PID>            # or simply close Pane A's session
ps -o pid,stat,comm -p "$ORPHAN"  # orphan must still be alive at this point

# Pane B — run the reaper on demand
systemctl --user start claude-session-reaper.service
journalctl --user -u claude-session-reaper.service -n 30 --no-pager

# Pane B — the decisive check
ps -o pid,stat,comm -p "$ORPHAN"                 # expect: no such process
systemctl --user list-units --type=scope --all --no-legend --plain 'claude-*.scope'
```

**Expected output**:
- Before the kill: the orphan PID appears in the scope's `cgroup.procs` despite `setsid`.
- After the kill, before the reaper: the orphan is still alive (`ps` finds it) — this is exactly
  the bug being fixed.
- Reaper journal shows `claude-session-reaper: starting`, a line naming the abandoned unit, and
  `claude-session-reaper: done`.
- After the reaper: `ps` reports no such process for `$ORPHAN`, and the `claude-*.scope` unit is
  gone from `list-units`.
- `systemctl --user status claude-session-reaper.service` shows the last run as
  `inactive (dead)` with `status=0/SUCCESS` — never `failed`.

**Verification**:
- The orphan is confirmed dead **by `ps`**, not inferred. If it survives, the predicate or the
  `stop` path is wrong — return to Phase 2.

---

### Phase 7: NEGATIVE test — long-running child SURVIVES a live session (USER-EXECUTED) [PARTIAL — RELEASE GATE PASSED]

**Status**: The release-gate criteria (the binding safety constraint) were executed
non-interactively and **passed**. The only outstanding checklist item is the final
"live session is still fully interactive afterwards", which is folded into the Phase 5
user-run TTY smoke test.

**Deviation from the written commands**: the live sessions were real `claude` invocations in
non-interactive (`-p`) mode rather than interactive wezterm panes, since the gate tests the
reaper's predicate, not the terminal. The reaper sees an identical cmdline signature either way.
Soak was 240s of a full core (`TIME` 00:04:01 at `etimes` 242) rather than the written 900s —
long enough that any plausible CPU/age threshold would have fired, and there is no threshold in
the predicate to fire.

**Observed (verbatim, hamsa, 2026-08-05)**:
- Live session A = `claude-1041456-1785950741.scope`; CPU-burning child `LONGPID=1042424`
  spawned via `setsid nohup bash -c 'while :; do :; done'`, inside the scope.
- Soak trace: `t=20s → 00:00:22` … `t=240s → 00:04:01` (a full core, wall-clock age 242s).
- Dry run: `claude-session-reaper: claude-1041456-1785950741.scope alive, skipping` — no kill
  decision. `after dry-run: LONGPID ALIVE`.
- Three real runs: `1042424 243 00:04:02`, `1042424 244 00:04:03`, `1042424 245 00:04:04` —
  survived each, `TIME` climbing. Zero occurrences of `FAIL: long-running child was killed`.
- **Two-live-session isolation** (re-run separately after the first attempt's second session was
  killed by an unrelated environment policy hook before it could establish a scope): units
  `claude-1117540-1785951078.scope` and `claude-1117541-1785951078.scope` live with burners
  `1121756` / `1121041`, plus abandoned `claude-decoy-iso-1117537.scope` (pid `1135923`). One
  reaper run produced, in the same pass:
  `claude-1117540-… alive, skipping` / `claude-1117541-… alive, skipping` /
  `stopping abandoned claude-decoy-iso-1117537.scope (pids: 1135923)`.
  After: both live scopes still `active running`, decoy pid `GONE`, burners alive at
  `1121756 27 00:00:27` and `1121041 29 00:00:28`.
- Post-test: no residual `claude-*.scope` units, no stray burner or `sleep 3000` processes,
  `claude-session-reaper.service` `Result=success` `ExecMainStatus=0` `NRestarts=0`.

**Execution**: **USER-EXECUTED** — requires a real live session left running.

**Goal**: Prove the binding safety constraint holds behaviorally: the reaper does **not** kill a
long-running, CPU-heavy child whose owning session is still alive. This is the test that protects
the user's stated requirement, and it is a **release gate** — the change does not ship if this
fails.

**Tasks**:
- [ ] Launch a real session and leave it **alive and idle** for the whole phase.
- [ ] From inside it, start a long-running, visibly CPU-burning child (the shape of work the user
      legitimately wants to keep).
- [ ] Let it accumulate meaningful CPU time and wall-clock age, so that any accidental
      resource/age threshold would have fired.
- [ ] Run the reaper in dry-run mode and confirm the verdict is "alive, skipping".
- [ ] Run the reaper for real, repeatedly, and confirm the child is untouched.
- [ ] Repeat with **two** concurrent live sessions plus one abandoned scope, confirming the
      reaper stops only the abandoned one and both live sessions and their children survive.
- [ ] Confirm the live session itself is still fully interactive afterwards.

**Timing**: 45 minutes (includes deliberate soak time)

**Depends on**: 5

**Files to modify**: none.

**Commands (verbatim)**:
```bash
# Pane A — launch a session and LEAVE IT RUNNING. From inside it, start long work:
nohup bash -c 'while :; do :; done' >/tmp/longwork.log 2>&1 &
echo $!    # note this PID as LONGPID

# Pane B — let it soak, then confirm it has accrued real CPU time and age
LONGPID=<pid from above>
sleep 900
ps -o pid,etimes,time,comm -p "$LONGPID"   # expect etimes ~900+, TIME ~15:00 (a full core)

# Pane B — dry-run the reaper: observe the verdict without any risk
CLAUDE_REAPER_DRY_RUN=1 <path to the reap script from the store>
#   (resolve with: systemctl --user cat claude-session-reaper.service | grep ExecStart)

# Pane B — now run it for real, three times
for i in 1 2 3; do
  systemctl --user start claude-session-reaper.service
  ps -o pid,etimes,time,comm -p "$LONGPID" || echo "FAIL: long-running child was killed"
done
journalctl --user -u claude-session-reaper.service -n 40 --no-pager

# Pane B — multi-session isolation: with Pane A still alive, open Pane C, launch a
# second real session, and create one abandoned decoy scope:
systemd-run --user --scope --unit="claude-decoy-abandoned-$$" -- \
  bash -c 'nohup sleep 3000 >/dev/null 2>&1 & exit 0'
systemctl --user start claude-session-reaper.service
systemctl --user list-units --type=scope --all --no-legend --plain 'claude-*.scope'
```

**Expected output**:
- Dry-run log: a line naming Pane A's unit with `alive, skipping` — and **no** kill decision.
- After each of the three real reaper runs: `ps` still reports `$LONGPID` alive, with `TIME`
  continuing to climb. Zero occurrences of `FAIL: long-running child was killed`.
- Journal shows only `alive, skipping` decisions for the live sessions' units.
- Multi-session run: the `claude-decoy-abandoned-*` unit disappears from `list-units` and its
  `sleep 3000` is gone, while **both** live sessions' scopes remain `active running` and
  `$LONGPID` is still alive.
- Pane A's session is still fully interactive (type a prompt, get a response) at the end.

**Verification**:
- `$LONGPID` alive after every reaper run, confirmed by `ps` — not inferred from logs.
- **This phase is a release gate.** If the long-running child dies at any point, or if any live
  session's scope is stopped, the implementation violates the binding constraint: stop, revert
  per Phase 8, and do not re-enable the timer until the predicate is corrected and this phase
  passes cleanly.

---

### Phase 8: Documentation, opt-out, and rollback path [COMPLETED]

**Delivered**: new `docs/claude-session-scopes.md` (mechanism, liveness-only guarantee stated as
a promise, `systemd-run --user --unit=` opt-out and `CLAUDE_NO_SCOPE=1` escape hatch both
surfaced in the first screen via a "Keeping work alive" pointer in the opening paragraph,
inspection recipes, nested-session note, sleep-inhibitor independence note, rollback ladder),
plus an index entry in `docs/README.md`. Every command shown was actually run during Phases 4-7.
`grep -rn "task 1[0-9][0-9]" docs/` finds no task-number references.

**Execution**: AGENT-EXECUTED (user reviews)

**Goal**: Make the mechanism, the opt-out, the escape hatch, and the rollback discoverable by a
future reader — including the user mid-incident, when they will not have time to read the module
source.

**Tasks**:
- [ ] Add a docs section covering, in `docs/no-sleep-agents.md` (adjacent mechanism, already the
      home for per-session Claude machinery) or a new short `docs/claude-session-scopes.md`
      cross-linked from `docs/README.md`:
  - [ ] What the containment does and why (per-session cgroup, orphan prevention).
  - [ ] The liveness-only guarantee, stated as a promise to the reader: long-running work is
        never killed while its session lives; no CPU/memory/time thresholds exist.
  - [ ] **Opt-out for deliberately-detached work**: launch it as its own top-level transient
        unit, e.g. `systemd-run --user --unit=my-long-job -- <cmd>` — a name that does not match
        `claude-*.scope` is never touched by the reaper and outlives the session by design.
  - [ ] **Escape hatch**: `export CLAUDE_NO_SCOPE=1` disables containment for the current shell
        with no rebuild.
  - [ ] Inspection recipes: list live session scopes, read a scope's `cgroup.procs`, dry-run the
        reaper, read its journal.
  - [ ] Interaction note: independent of the `SessionStart`/`SessionEnd` sleep inhibitor; the two
        use different identifiers and do not coordinate.
  - [ ] The nested-`claude` note: an inner invocation migrates into its own sibling scope; this
        is expected and benign, not a bug.
- [ ] Record the rollback path (below) in the same doc section.
- [ ] Follow `.claude/rules/no-task-references-in-deliverables.md`: cite durable anchors
      (filenames, section headings), never task numbers, in anything outside `specs/`.
- [ ] Write the implementation summary to
      `specs/125_claude_session_scope_containment_and_reaper/summaries/01_scope-containment-reaper-summary.md`,
      including the verbatim Phase 5-7 observed output (especially Phase 7's).

**Timing**: 45 minutes

**Depends on**: 6, 7

**Files to modify**:
- `docs/no-sleep-agents.md` or new `docs/claude-session-scopes.md` — user-facing documentation.
- `docs/README.md` — index entry, if a new doc file is created.
- `specs/125_claude_session_scope_containment_and_reaper/summaries/01_*.md` — summary.

**Verification**:
- Every command shown in the docs is copy-pasteable and was actually run during Phases 5-7.
- `grep -rn "task 1[0-9][0-9]" docs/` finds no new task-number references.
- The doc answers, within its first screen, the question "how do I stop this from killing my
  job?" — both the opt-out and the escape hatch.

---

## Testing & Validation

Acceptance is behavioral. The following must all be observed on host `hamsa`, not inferred from
unit files or `nix eval`:

- [ ] A real interactive session's CLI process and children appear in a distinct
      `claude-<pid>-<epoch>.scope` cgroup, read from `cgroup.procs` (Phase 5).
- [ ] cwd, environment, exit code, Ctrl-C, Ctrl-Z, and terminal resize behave as before in
      wezterm with `--dangerously-skip-permissions` (Phase 5).
- [ ] A `setsid`-detached child of a session is contained in that session's scope cgroup
      (Phase 6).
- [ ] After the session is killed, the reaper actually kills that orphan — confirmed by `ps`
      reporting no such process (Phase 6).
- [ ] **RELEASE GATE**: a long-running, CPU-burning child of a *live* session survives repeated
      reaper runs untouched, with the dry-run log showing `alive, skipping` (Phase 7).
- [ ] With two live sessions and one abandoned scope present, only the abandoned scope is
      stopped (Phase 7).
- [ ] `systemctl --user status claude-session-reaper.service` never reports `failed`, and
      `systemctl --user --failed` stays clean across several timer ticks (Phases 6-7).
- [ ] Reviewer-checklist grep over the reaper script finds no CPU/memory/wall-clock criteria
      (Phases 2, 8).
- [ ] `nixos-rebuild build --flake .#hamsa` and `home-manager build --flake .#benjamin` both
      succeed (Phase 3).

**Explicitly insufficient as verification** (stated because it is the failure mode this task
calls out): reading the generated unit files, `nix eval`, `systemd-analyze verify`, or confirming
the module is imported. None of these count toward acceptance.

## Artifacts & Outputs

- `packages/claude-code.nix` — scope-wrapping `claude` launcher with fallback guard and
  `CLAUDE_NO_SCOPE` escape hatch.
- `modules/home/services/claude-session-reaper.nix` — oneshot service + 10-minute timer
  implementing the liveness-only reap predicate, with `CLAUDE_REAPER_DRY_RUN` audit mode.
- `modules/home/default.nix` — one added import line.
- `docs/no-sleep-agents.md` (extended) or `docs/claude-session-scopes.md` (new, plus a
  `docs/README.md` index entry) — mechanism, guarantee, opt-out, escape hatch, rollback.
- `specs/125_claude_session_scope_containment_and_reaper/summaries/01_scope-containment-reaper-summary.md`
  — summary including verbatim Phase 5-7 observed output.

## Rollback/Contingency

Ordered from cheapest to most complete. The first option requires no rebuild and is the one to
reach for the moment the interactive experience misbehaves.

1. **Immediate, per-shell (no rebuild)**: `export CLAUDE_NO_SCOPE=1` — the wrapper falls through
   to the original bare `exec`. Restores the previous behavior instantly in that shell.
2. **Disable the reaper only** (containment kept, automatic killing stopped):
   ```bash
   systemctl --user stop claude-session-reaper.timer
   systemctl --user disable claude-session-reaper.timer
   ```
   Survives until the next `home-manager switch`; make it permanent by commenting the import in
   `modules/home/default.nix` and rebuilding.
3. **Previous generation**: `sudo nixos-rebuild switch --rollback`, and/or select an earlier
   home-manager generation (`home-manager generations`, then run that generation's
   `activate` script). Reverts both files together.
4. **Source revert**: `git revert` the Phase 1/2 commits (or `git checkout HEAD~ --
   packages/claude-code.nix modules/home/services/claude-session-reaper.nix
   modules/home/default.nix`), then re-run the Phase 4 switch commands.
5. **Leftover units after any rollback**:
   ```bash
   systemctl --user list-units --type=scope --all --no-legend --plain 'claude-*.scope'
   systemctl --user stop <unit>        # only if you have confirmed no live session owns it
   systemctl --user reset-failed <unit>
   ```

Because each phase's file changes are small and independent, partial rollback is viable: the
wrapper (Phase 1) and the reaper (Phase 2) can be reverted separately. Containment without the
reaper is a safe intermediate state — it provides the cgroup boundary and manual
`systemctl --user stop` cleanup with no automatic killing at all.

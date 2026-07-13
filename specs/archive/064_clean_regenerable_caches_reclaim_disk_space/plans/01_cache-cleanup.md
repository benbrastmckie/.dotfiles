# Implementation Plan: Clean Regenerable Caches + Add Periodic Automation

- **Task**: 64 - Clean regenerable caches and reclaim disk space
- **Status**: [NOT STARTED]
- **Effort**: 3 hours (active work), plus a 1-2 hour gated window after Lean sessions close
- **Dependencies**: Active Lean build on shared `/nix/store` blocks Phases 3-4. Coordination (not blocking) with task 63 for the `nix.gc`/GC ownership boundary (see Phase 5).
- **Research Inputs**: specs/064_clean_regenerable_caches_reclaim_disk_space/reports/01_cache-cleanup.md
- **Artifacts**: plans/01_cache-cleanup.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: nix

## Overview

The root filesystem (`/dev/nvme0n1p2`, 457 GB) is at 94% used; a ~6 GB first pass (Trash + memory-monitor rotated logs) is already done. This plan reclaims the remaining regenerable caches in `~benjamin/` and adds declarative weekly automation so the safe caches stay trimmed. Work is split into three independent concerns with explicit gating: (a) **safe-now** deletions (~14.7 GB, runnable immediately), (b) **deferred** deletions of the live loogle/nix caches (~9.4 GB, gated until Lean sessions close), and (c) **declarative automation** (a `systemd.user` timer in `home.nix` + `nix.gc` in `configuration.nix`). A conditional, clearly-flagged optional phase covers the 13 GB Proton Mail gluon store that is regenerable only via a multi-hour Bridge resync. Definition of done for this plan is: the plan exists and is approved. **The task is NOT marked complete until the full cleanup (safe-now + deferred) has actually run after Lean work finishes** — per explicit user direction.

### Research Integration

Integrates `reports/01_cache-cleanup.md` (round 1): per-target size breakdowns, regenerability/active-use classification, exact deletion commands, and the systemd-service vs systemd-tmpfiles trade-off (the report recommends the service/timer approach and warns against `systemd.user.tmpfiles.rules` due to HM regression issue #8125). Already-done items (Trash, memory-monitor rotated logs, ~6 GB) are recorded as complete and not re-planned.

### Prior Plan Reference

No prior plan for task 64.

### Roadmap Alignment

No ROADMAP.md consulted for this task (planning-only, disk-maintenance scope).

## Goals & Non-Goals

**Goals**:
- Reclaim ~14.7 GB of losslessly regenerable cache that is NOT in active use, safely and immediately.
- Reclaim a further ~9.4 GB from the live loogle/nix caches once Lean work is complete (gated).
- Add declarative weekly automation: `systemd.user.services/timers.cache-cleanup` in `home.nix` (pip/uv/npm) following the existing `gmail-oauth2-refresh` / `memory-monitor` pattern, plus `nix.gc.automatic` weekly/30d in `configuration.nix`.
- Keep the boundary with task 63 clean: 64 owns the regenerable-cache timer; 63 owns home-manager `autoExpire` + manual generation GC.

**Non-Goals**:
- Deleting any irreplaceable user data: `~/.local/share/opencode/opencode.db`, `storage/`, `session_diff/`, `snapshot/` are OUT OF SCOPE for deletion.
- Triggering the 13 GB Proton gluon-store resync as part of the default flow (optional, deliberate-only phase).
- Running `nix-collect-garbage` / store GC as part of cache cleanup (store GC is task 63's manual concern; this plan only *declares* `nix.gc` automation).
- Using `systemd.user.tmpfiles.rules` for cache aging (rejected per report: HM issue #8125 regression + mtime unreliable for nested caches).
- Marking task 64 complete before the full cleanup has actually executed post-Lean.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Deleting loogle/nix cache mid-Lean-session breaks the active build | H | M | Phases 3-4 are hard-gated behind a Lean-idle check (Phase 3 gate verification); do not run until Lean sessions confirmed closed |
| Accidentally deleting opencode irreplaceable DB/storage | H | L | Phase 2 deletes only `log/` files older than 7 days; explicit DO-NOT-DELETE list for db/storage/snapshot |
| Proton gluon-store deletion forces multi-hour ~13 GB resync at a bad time | M | M | Isolated as optional Phase 6, Bridge-stopped precondition, flagged "deliberate only", excluded from default reclaim total |
| `nix.gc` automation in 64 conflicts/overlaps with task 63's autoExpire + manual GC | M | M | Phase 5 scopes 64 to the *regenerable-cache timer* only; `nix.gc` (store GC, weekly/30d) is coordinated with 63 — see overlap note. If 63 lands store-level GC first, Phase 5 nix.gc becomes a no-op confirmation |
| HM `systemd.user.tmpfiles.rules` regression if used | M | L | Rejected by design; use service/timer approach only |
| npm cache clean removing `_npx` that is mid-use | L | L | `_npx` removal is the manual variant; automation clears only `_cacache` via `npm cache clean --force` |
| Disk at 94% during build; deletions must be additive-safe | M | L | All Phase 1-4 operations are deletions of regenerable data only; no writes to active stores |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 5 | -- |
| 3 | 3 | Lean-idle gate (external), 1 |
| 4 | 4 | 3 |
| 5 | 6 | -- (optional, deliberate-only) |

Phases within the same wave can execute in parallel. Phases 1, 2, and 5 have no inter-phase blockers and can proceed immediately once the plan is approved. Phases 3-4 are gated on the external Lean-idle condition. Phase 6 is optional and independent.

> **GATING LEGEND**: `[SAFE-NOW]` = run immediately, regenerable, not in active use. `[GATED]` = run ONLY after Lean sessions are confirmed closed. `[DECLARATIVE]` = edits Nix config, applied via rebuild. `[OPTIONAL-RISKY]` = deliberate decision only, multi-hour penalty. `[ALREADY DONE]` = completed in first pass, recorded for completeness.

---

### Phase 0: Already-Done First Pass [COMPLETED]

**Goal**: Record the ~6 GB already reclaimed so it is not re-planned or re-run.

**Tasks**:
- [x] `~/.local/share/Trash` deleted (~4.2 GB) — DONE in first pass.
- [x] `~/.local/share/memory-monitor/` rotated logs (`system.log.old`, `claude.csv.old`) deleted (~1.8 GB) — DONE in first pass.

**Timing**: 0 (historical record).

**Depends on**: none

**Files to modify**: none.

**Verification**: `du -sh ~/.local/share/Trash 2>/dev/null` returns empty/small; no `*.old` files under `~/.local/share/memory-monitor/`.

**Reclaim**: ~6 GB (already counted, not re-claimed here).

---

### Phase 1: Safe-Now Cache Purge — pip / uv / npm [SAFE-NOW] [NOT STARTED]

**Goal**: Reclaim ~13.8 GB from package-manager download caches that are losslessly regenerable and never locked by running processes.

**Tasks**:
- [ ] Purge pip HTTP cache (~3.0 GB):
  ```bash
  pip cache purge
  ```
- [ ] Clean uv cache (~2.0 GB):
  ```bash
  uv cache clean
  ```
- [ ] Clean npm content cache and npx run-once installs (~8.8 GB):
  ```bash
  npm cache clean --force && rm -rf ~/.npm/_npx
  ```
- [ ] Record before/after free space.

**Timing**: ~15 min.

**Depends on**: none

**Files to modify**: none (filesystem cache only).

**Verification**:
- `du -sh ~/.cache/pip ~/.cache/uv ~/.npm` each drops to a few MB or less.
- `df -h /` shows increased free space (~13-14 GB).

**Reclaim**: ~13.8 GB.

**Note**: This is what the Phase 5 automation will perform on a weekly schedule; running it manually here is the immediate one-shot.

---

### Phase 2: Safe-Now Log Pruning — opencode / protonmail [SAFE-NOW] [NOT STARTED]

**Goal**: Reclaim ~0.9 GB by trimming stale logs and a stale update binary, WITHOUT touching any irreplaceable session/mail data.

**DO NOT DELETE (irreplaceable, explicit)**:
- `~/.local/share/opencode/opencode.db` (3.3 GB session history)
- `~/.local/share/opencode/storage/` (part/, message/, session_diff/, session/ — pre-SQLite JSON layer)
- `~/.local/share/opencode/snapshot/` (per-project undo git history)
- `~/.local/share/protonmail/.../gluon/backend/store/` and `db/` (mail mirror — see Phase 6 only)

**Tasks**:
- [ ] Prune opencode logs older than 7 days, keeping the active session log (~525 MB):
  ```bash
  # Confirm the current/active log first:
  ls -t ~/.local/share/opencode/log/ | head -1
  # Then delete logs older than 7 days:
  find ~/.local/share/opencode/log/ -name "*.log" -mtime +7 -delete
  ```
- [ ] Delete protonmail bridge debug logs (~201 MB) — Bridge recreates them:
  ```bash
  rm -f ~/.local/share/protonmail/bridge-v3/logs/*.log
  ```
- [ ] Delete the stale protonmail update binary (~207 MB) — Nix manages the running binary, not this path:
  ```bash
  rm -rf ~/.local/share/protonmail/bridge-v3/updates/
  ```
- [ ] (OPTIONAL, only if `opencode.db` confirmed complete) remove `opencode-stable.db` snapshot (~754 MB). Leave undone unless explicitly confirmed.

**Timing**: ~15 min.

**Depends on**: none

**Files to modify**: none (log/binary files only).

**Verification**:
- `opencode.db`, `storage/`, `snapshot/` all still present and unchanged in size.
- `du -sh ~/.local/share/opencode/log/` drops to a few MB.
- `~/.local/share/protonmail/bridge-v3/updates/` no longer exists; `logs/` is empty or freshly minimal.

**Reclaim**: ~0.9 GB (≈525 MB opencode logs + 201 MB proton logs + 207 MB update binary). Combined with Phase 1, the **safe-now subtotal is ~14.7 GB**.

---

### Phase 3: GATED Deferred Cache — loogle [GATED] [NOT STARTED]

**Goal**: Reclaim ~7.2 GB from the loogle Lake build cache — ONLY after Lean sessions are confirmed closed.

**GATE (must pass before running any command in this phase)**:
- [ ] Confirm no active Lean proof session is running.
- [ ] Confirm the loogle server is not actively serving (no live mathlib search in progress).
- [ ] Confirm no `nixos-rebuild` / `nix flake` evaluation in flight.

**Tasks** (run only after the gate passes):
- [ ] Delete the loogle Lake packages and build (~7.2 GB):
  ```bash
  rm -rf ~/.cache/loogle/.lake/packages ~/.cache/loogle/.lake/build
  # Full clean reinstall variant (optional):
  # rm -rf ~/.cache/loogle
  ```

**Timing**: ~10 min to delete; note loogle rebuild on next start takes 1-2 hours.

**Depends on**: Phase 1 (ordering convenience), external Lean-idle gate.

**Files to modify**: none.

**Verification**:
- `du -sh ~/.cache/loogle` drops from 7.4 GB to <1 MB (or just top-level sources).
- Loogle still launches later and rebuilds cleanly (deferred verification, not blocking).

**Reclaim**: ~7.2 GB.

---

### Phase 4: GATED Deferred Cache — nix user cache [GATED] [NOT STARTED]

**Goal**: Reclaim ~2.2 GB from the nix user-level fetch/eval cache — ONLY after Lean work and any in-flight flake evaluation are complete.

**GATE**:
- [ ] Same Lean-idle gate as Phase 3.
- [ ] Confirm no `nix flake update` / `nixos-rebuild` / `home-manager switch` running.

**Tasks** (run only after the gate passes):
- [ ] Delete the nix user tarball/eval/fetcher caches (~2.2 GB):
  ```bash
  rm -rf ~/.cache/nix/tarball-cache ~/.cache/nix/tarball-cache-v2 \
         ~/.cache/nix/eval-cache-v6 \
         ~/.cache/nix/fetcher-cache-v4.sqlite \
         ~/.cache/nix/binary-cache-v7.sqlite
  ```
- [ ] **DO NOT** run `nix-collect-garbage` here — that operates on `/nix/store`, not `~/.cache/nix`, and store GC belongs to task 63.

**Timing**: ~5 min; nix re-fetches flake inputs on next eval (~one tarball download).

**Depends on**: Phase 3 (same gate; sequence after loogle).

**Files to modify**: none.

**Verification**:
- `du -sh ~/.cache/nix` drops from 2.2 GB to a few MB.
- Next `nixos-rebuild`/`home-manager switch` succeeds (re-fetches inputs).

**Reclaim**: ~2.2 GB. Combined with Phase 3, the **deferred subtotal is ~9.4 GB**.

---

### Phase 5: Declarative Automation — home.nix timer + configuration.nix nix.gc [DECLARATIVE] [NOT STARTED]

**Goal**: Add a weekly `systemd.user` cache-cleanup timer to `home.nix` (pip/uv/npm) and `nix.gc.automatic` to `configuration.nix`, so the safe caches stay trimmed without manual intervention.

**Pattern to follow** (existing, verified):
- `home.nix:777` `systemd.user.services.gmail-oauth2-refresh` (oneshot service shape)
- `home.nix:789` `systemd.user.timers.gmail-oauth2-refresh` (`Timer.OnCalendar`, `Unit.Requires`, `Install.WantedBy = [ "timers.target" ]`)
- `home.nix:816` `systemd.user.services.memory-monitor` (writeShellScript ExecStart shape)

**Tasks**:
- [ ] Add to `home.nix` a `systemd.user.services.cache-cleanup` (Type = oneshot) whose ExecStart is a `pkgs.writeShellScript` running, each guarded with `|| true`:
  - `${pkgs.python3Packages.pip}/bin/pip cache purge`
  - `${pkgs.uv}/bin/uv cache clean`
  - `${pkgs.nodejs}/bin/npm cache clean --force`  (clears `_cacache`; do NOT auto-`rm` `_npx` since it can be mid-use)
- [ ] Add `systemd.user.timers.cache-cleanup` with `Timer.OnCalendar = "weekly"`, `Persistent = true`, `RandomizedDelaySec = "1h"`, `Install.WantedBy = [ "timers.target" ]`.
- [ ] **Do NOT** use `systemd.user.tmpfiles.rules` (HM issue #8125 regression; mtime unreliable for nested caches).
- [ ] Add to `configuration.nix` a `nix.gc` block: `automatic = true; dates = "weekly"; options = "--delete-older-than 30d";` — see overlap coordination below before writing.
- [ ] Build-check, then rebuild:
  ```bash
  nix flake check
  sudo nixos-rebuild build --flake .#<host>     # configuration.nix changes
  home-manager build --flake .#benjamin         # home.nix changes
  # then switch when satisfied
  ```
- [ ] Verify timer is registered:
  ```bash
  systemctl --user list-timers | grep cache-cleanup
  ```

**TASK 63 OVERLAP COORDINATION (read before editing nix.gc)**:
- **Task 64 owns**: the regenerable-cache timer (`systemd.user.services/timers.cache-cleanup` for pip/uv/npm) in `home.nix`.
- **Task 63 owns**: home-manager `services.home-manager.autoExpire` (generation expiry) + the one-time `home-manager expire-generations` and manual user/root `nix-collect-garbage`.
- **Shared surface — `nix.gc` (store-level GC)**: 63's research summary is "Use `services.home-manager.autoExpire`; expire-generations before nix-collect-garbage". The system-level `nix.gc.automatic` in `configuration.nix` is store GC for root-owned roots. To avoid a double-owner conflict: if task 63 lands store/profile GC declarations first, this Phase 5 `nix.gc` step becomes a **confirm-only no-op** (verify the block exists, do not duplicate). If 64 lands first, add the `nix.gc` block here and note it in the task-63 plan as already-present. Neither task should add a *second* `nix.gc` block; the user/root GC overlap is owned by 63's manual GC, the weekly cache timer is owned by 64. There is no conflict at the `home.nix` timer level (distinct unit name `cache-cleanup` vs none in 63).

**Timing**: ~45 min (write + build-check; rebuild/switch may be deferred to a low-disk-pressure window since `/nix/store` is shared with the active Lean build).

**Depends on**: none (config edit is independent of the deletions). Apply via rebuild at a convenient window.

**Files to modify**:
- `home.nix` — add `systemd.user.services.cache-cleanup` + `systemd.user.timers.cache-cleanup` (near existing timers, ~line 789+).
- `configuration.nix` — add `nix.gc` block (only if not already present from task 63).

**Verification**:
- `nix flake check` passes.
- `systemctl --user list-timers` shows `cache-cleanup.timer` with a next-run time.
- Manually trigger once: `systemctl --user start cache-cleanup.service` then check the three caches shrank.
- `nix.gc` block present exactly once across configuration.nix (no duplicate with task 63).

**Reclaim**: ongoing (prevents re-accumulation); no one-shot figure.

---

### Phase 6: OPTIONAL — Proton Mail gluon store reset [OPTIONAL-RISKY] [NOT STARTED]

**Goal**: Reclaim up to ~13 GB from the regenerable Proton Bridge gluon store. **Deliberate decision only** — forces a multi-hour, ~13 GB re-download resync. NOT part of the default reclaim total.

**Preconditions / flags**:
- [ ] Bridge MUST be stopped first (never delete store files while Bridge is running).
- [ ] Sustained uptime + network available for the hours-long resync.
- [ ] User explicitly chooses to do this (otherwise skip entirely).

**Tasks** (only on deliberate decision):
- [ ] Stop Bridge:
  ```bash
  systemctl --user stop protonmail-bridge
  ```
- [ ] Clear the gluon store:
  ```bash
  rm -rf ~/.local/share/protonmail/bridge-v3/gluon/backend/store/*
  ```
- [ ] Restart Bridge and allow full resync (hours). Optionally use Bridge's built-in "Repair" instead of manual deletion.

**Timing**: ~10 min of action + several hours of unattended resync.

**Depends on**: none (independent, optional).

**Files to modify**: none.

**Verification**:
- After resync completes, local IMAP clients (Thunderbird) see all mail again.
- `du -sh ~/.local/share/protonmail/.../gluon/backend/store` shrinks then regrows as resync proceeds.

**Reclaim**: up to ~13 GB transiently; net depends on mailbox size after resync. Documented, not counted in the plan's reclaim totals.

---

## Testing & Validation

- [ ] After Phase 1: `df -h /` free space increased by ~13-14 GB; pip/uv/npm caches near-empty.
- [ ] After Phase 2: opencode `opencode.db`/`storage/`/`snapshot/` unchanged; logs trimmed; proton `updates/` gone.
- [ ] After Phases 3-4 (post-Lean): loogle + nix user caches near-empty; loogle rebuilds on next start; `nixos-rebuild` re-fetches inputs successfully.
- [ ] After Phase 5: `nix flake check` passes; `cache-cleanup.timer` listed in `systemctl --user list-timers`; manual `start` of the service shrinks the three caches; exactly one `nix.gc` block exists.
- [ ] Cross-check task 63: confirm no duplicate `nix.gc` / GC ownership collision.
- [ ] FULL-CLEANUP GATE for task completion: Phases 1-4 have all actually executed post-Lean before task 64 is marked complete (per user direction).

## Artifacts & Outputs

- plans/01_cache-cleanup.md (this file)
- summaries/01_cache-cleanup-summary.md (on implementation completion)
- Edited: `home.nix` (cache-cleanup service + timer), `configuration.nix` (nix.gc) — Phase 5 only.

## Rollback/Contingency

- **Cache deletions (Phases 1-4)**: no rollback needed or possible — caches are regenerable; the tools re-download/rebuild on next use. The only cost is rebuild time (loogle 1-2 h, nix one tarball fetch).
- **Phase 5 config edits**: revert via `git checkout home.nix configuration.nix` and re-run `home-manager switch` / `nixos-rebuild switch`; or roll back to the previous generation (`home-manager generations` / `nixos-rebuild --rollback`). Because `/nix/store` is shared with the active Lean build at 94% disk, defer the rebuild/switch to a low-pressure window.
- **Phase 6 (proton)**: if resync is interrupted, the local mail cache is in a partial state until resync completes; re-run Bridge "Repair" to finish. All mail is safe on Proton servers.

# Implementation Plan: Task #63

- **Task**: 63 - Enable user-level Nix GC + expire old home-manager generations
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours (≈30 min declarative edit; remainder is gated, hands-off store reclamation + verification after the Lean build finishes)
- **Dependencies**: External — the user's active Lean build on the shared `/nix/store` MUST complete before any store-mutating step runs (Phases 3-5)
- **Research Inputs**: specs/063_user_level_nix_gc_expire_home_manager_generations/reports/01_user-nix-gc.md
- **Artifacts**: plans/01_user-nix-gc.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-formats.md; state-management.md; nix.md
- **Type**: nix

## Overview

The root-level `nix.gc` timer (weekly, `--delete-older-than 30d`) runs as root and never scans the
user's home-manager generations under `~/.local/state/nix/profiles/`. 69 HM generations (IDs 109–177,
Mar 13 – Jun 23 2026) act as GC roots pinning ~3 months of unstable closures in a 92 GB `/nix/store`
(root disk at ~94%). This plan (a) adds the declarative `services.home-manager.autoExpire` block to
`home.nix` so future expiry+GC happen automatically on a weekly user timer, and (b) documents the
GATED one-time reclamation sequence (`expire-generations` BEFORE `nix-collect-garbage`) plus the
activation switch — both of which must NOT run until the Lean build completes and releases the Nix
store locks.

**Definition of done**: `home.nix` contains the autoExpire block; after the gated phases run, the
new HM generation is active, ≥60 old HM generations are expired, store size is measurably reduced,
and a weekly user timer (`home-manager-auto-expire.timer`) exists and is enabled.

### Research Integration

Report `01_user-nix-gc.md` drives this plan. Key integrated findings:
- Use `services.home-manager.autoExpire` (not bare `nix.gc`) — it expires generation symlinks AND
  runs `nix-collect-garbage` in the correct order on one timer (report Decision 1, 5).
- Mirror the root policy: `timestamp = "-30 days"`, `frequency = "weekly"` (report Decision 2).
- One-time order is critical: `expire-generations` removes the GC-root symlinks FIRST; only then can
  `nix-collect-garbage` free the pinned closures. Reversing the order makes the GC a no-op for HM
  closures (report "Why order matters").
- HM protects the current generation via `~/.local/state/home-manager/gcroots/current-home`, so
  expiring old generations cannot delete the running config (report Risks).
- Do NOT also add `nix.gc` to `home.nix` — it would create a redundant second user GC timer
  (report Decision 5).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` exists but `roadmap_flag` was not set for this invocation, so no roadmap
review/update phases are added. This task advances general NixOS maintenance/disk-hygiene; no
specific roadmap item is tied to it.

## Goals & Non-Goals

**Goals**:
- Add `services.home-manager.autoExpire` to `home.nix` so user-level expiry + GC run weekly,
  matching the root policy.
- Document and (in a gated phase) execute the one-time reclamation sequence in the correct order.
- Measurably reduce `/nix/store` size and the count of HM generations.
- Leave a self-maintaining weekly timer in place so the problem does not recur.

**Non-Goals**:
- Changing the root `nix.gc` policy in `configuration.nix` (already weekly/30d; out of scope).
- Adding a bare `nix.gc` block to `home.nix` (redundant with autoExpire — explicitly avoided).
- Touching `flake.nix` or `configuration.nix`.
- Running ANY store-mutating command before the Lean build finishes.
- Deleting generations newer than 30 days or otherwise deviating from the 30d retention window.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Running GC/switch while the Lean build holds `/nix/store` locks (hang or build corruption; disk at 94%) | H | H | Phases 3-5 are GATED. Confirm the Lean build is finished (Phase 3 gate check) before any store mutation. Do nothing store-touching in Phases 1-2. |
| Wrong order (`nix-collect-garbage` before `expire-generations`) frees nothing | M | M | Phase 4 hard-orders the steps and the plan repeatedly emphasizes expire-FIRST. Verification in Phase 4 checks the HM-root count dropped. |
| Activation `switch` needs free space but disk is full | M | M | Run the one-time reclamation (Phase 4) BEFORE the activation switch (Phase 5) so space is available for the new generation. |
| `expire-generations` removes the current generation | H | L | HM pins current via `~/.local/state/home-manager/gcroots/current-home`; the store path stays a GC root even if a numbered symlink is removed (report-confirmed). |
| autoExpire option names/types wrong for this HM version | M | L | Phase 2 validates names against the HM module by reading `home-manager-auto-expire.nix` docs / `man home-configuration.nix`; dry-run build in Phase 5 (gated) catches eval errors before activation. |
| Redundant double GC timer if `nix.gc` also added | L | L | Plan explicitly forbids adding `nix.gc`; only `autoExpire` is written. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 (GATED) | 3 | 2 + Lean build complete |
| 4 (GATED) | 4 | 3 |
| 5 (GATED) | 5 | 4 |
| 6 (GATED) | 6 | 5 |

Phases within the same wave can execute in parallel. Phases 3-6 are GATED: they MUST NOT begin
until the user's Lean build on `/nix/store` has fully completed and released all Nix locks. Phases
1-2 are safe to perform at any time (no store mutation, no activation).

---

### Phase 1: Capture baseline store/generation state (read-only) [NOT STARTED]

**Goal**: Record before-state for later comparison. Read-only — no store mutation, no locks taken.

**Tasks**:
- [ ] Record `/nix/store` size: `du -sh /nix/store` (expected ≈92 GB per research).
- [ ] Record disk usage: `df -h /` (expected ≈94%).
- [ ] Record HM generation count: `home-manager generations | wc -l` (expected ≈69).
- [ ] Record HM profile links: `ls -1 ~/.local/state/nix/profiles/ | grep -c home-manager`.
- [ ] Confirm no user GC timer exists yet: `systemctl --user list-timers | grep -E 'auto-expire|nix-gc'` (expected empty).
- [ ] Save these numbers into the eventual summary's "before" column (note them in the implement summary).

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**: none (read-only commands)

**Verification**:
- Baseline numbers captured (store size, disk %, generation count) and written down for Phase 6 comparison.

**Safety note**: All commands here are read-only (`du`, `df`, `ls`, `systemctl --user list-timers`,
`home-manager generations`). None mutate the store or take write locks. Safe during the Lean build.

---

### Phase 2: Add `services.home-manager.autoExpire` to home.nix (declarative, no activation) [NOT STARTED]

**Goal**: Write the declarative GC config into `home.nix`. This edits a text file only — it does NOT
build, switch, or touch the store, so it is safe to do now (per the task constraints, the declarative
edit itself is allowed anytime; activation is gated to Phase 5).

**Tasks**:
- [ ] (Optional, read-only) Verify option names for the installed HM version via
      `man home-configuration.nix | grep -A2 autoExpire` or the HM source `home-manager-auto-expire.nix`.
      Do NOT run `home-manager build`/`nix flake check` here (gated).
- [ ] Insert the `autoExpire` block into `home.nix` immediately after the systemd integration line
      (`systemd.user.startServices = "sd-switch";`, currently line 887), before the
      `home.pointerCursor` block. This keeps it next to the other user-service config.
- [ ] Use 2-space indentation per nix.md; no `with`/`rec`; keep lines ≤100 cols.

**Exact edit** — insert after line 887 (`  systemd.user.startServices = "sd-switch";`) and its
trailing blank line:

```nix
  # User-level Nix garbage collection (mirrors the root nix.gc weekly/30d policy).
  # The system nix.gc runs as root and never scans ~/.local/state/nix/profiles/,
  # so home-manager generations accumulate as GC roots. autoExpire runs
  # `home-manager expire-generations` then `nix-collect-garbage` on a weekly user
  # timer, in the correct order. See specs/063_.../reports/01_user-nix-gc.md.
  services.home-manager.autoExpire = {
    enable = true;
    timestamp = "-30 days";
    frequency = "weekly";
    store = {
      cleanup = true;
      options = "--delete-older-than 30d";
    };
  };
```

Note: the research wrote `store.cleanup` / `store.options` in dotted form; the equivalent nested
`store = { cleanup = ...; options = ...; };` attrset above is identical and matches nix.md layout
guidance. Either form is acceptable; prefer the nested form for readability.

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `home.nix` — insert the `services.home-manager.autoExpire` block after the systemd integration
  line (~line 887). No other lines changed. Do NOT add a separate `nix.gc` block.

**Verification**:
- `home.nix` contains exactly one `services.home-manager.autoExpire` block and zero `nix.gc` blocks
  (`grep -n 'autoExpire\|nix.gc' home.nix`).
- File still parses as text (visual review); formal eval is deferred to the gated Phase 5 dry-run.

**Safety note**: This phase only edits a text file. It does NOT run `home-manager build`,
`home-manager switch`, `nixos-rebuild`, or `nix flake check`. No store access. Safe during the Lean build.

---

### Phase 3: GATE — confirm Lean build complete; capture pre-reclamation snapshot [NOT STARTED]

**Goal**: Verify the blocking condition has cleared before ANY store-mutating command. This is the
gate that authorizes Phases 4-6.

**Tasks**:
- [ ] Confirm the user's Lean build has fully finished (no `lake build` / `lean` process active;
      `ps aux | grep -E 'lake|lean'` shows nothing relevant) — ASK THE USER to confirm if uncertain.
- [ ] Confirm no Nix store lock is held: `ls -l /nix/var/nix/gc.lock` exists is normal, but ensure no
      build is running (`ps aux | grep nix-daemon` is fine; an active `nix build`/`nix-build` is not).
- [ ] Re-capture the immediate pre-reclamation snapshot (so before/after brackets the GC tightly):
      `du -sh /nix/store`, `df -h /`, `home-manager generations | wc -l`.

**Timing**: 10 minutes (plus indefinite wait for the Lean build to finish)

**Depends on**: 2 (and the external Lean build must be complete)

**Files to modify**: none

**Verification**:
- Explicit confirmation (user-stated or process-checked) that the Lean build is done and no Nix
  build/locks are active. Do NOT proceed to Phase 4 otherwise.

**GATED**: This phase is the gate. Phases 4-6 must not start until this gate passes.

---

### Phase 4: GATED one-time reclamation — expire FIRST, then collect garbage [NOT STARTED]

**Goal**: Reclaim the space pinned by ~65 of 69 old HM generations using the correct ordering.

**ORDERING IS CRITICAL — run the steps strictly in this sequence:**

**Tasks**:
- [ ] **Step 1 (user, FIRST)** — expire old HM generation symlinks (removes the GC roots):
      ```bash
      home-manager expire-generations '-30 days'
      ```
- [ ] **Step 2 (user, SECOND)** — collect store paths now unreachable. Running as the user lets Nix
      traverse the XDG profile dir `~/.local/state/nix/profiles/`:
      ```bash
      nix-collect-garbage --delete-older-than 30d
      ```
- [ ] **Step 3 (root, THIRD)** — collect the system-side profiles:
      ```bash
      sudo nix-collect-garbage --delete-older-than 30d
      ```

**WHY ORDER MATTERS**: If `nix-collect-garbage` (Step 2) runs before `expire-generations` (Step 1),
the old numbered generation symlinks still exist as GC roots, so the closures they pin cannot be
freed — the GC becomes a no-op for the home-manager closures. Always expire BEFORE collecting.

**Timing**: 20-40 minutes (GC duration depends on store size; can be long)

**Depends on**: 3

**Files to modify**: none (these mutate the Nix store, not the repo)

**Verification**:
- HM generation count dropped substantially (e.g., from ≈69 toward ≤4-5):
  `home-manager generations | wc -l`.
- HM GC-root count dropped: `nix-store --gc --print-roots 2>/dev/null | grep -c home-manager`.
- `du -sh /nix/store` is smaller than the Phase 3 snapshot.

**GATED**: Store-mutating. Only run after Phase 3 gate passes (Lean build complete, no locks).

---

### Phase 5: GATED — dry-run, then activate the new home.nix (autoExpire timer) [NOT STARTED]

**Goal**: Validate the edited `home.nix` evaluates, then activate it so the weekly autoExpire timer
is installed. Done AFTER reclamation (Phase 4) so disk space is available for the new generation.

**Tasks**:
- [ ] Dry-run build first (now safe — Lean build done):
      ```bash
      home-manager build --dry-run --flake .#benjamin
      ```
      Resolve any eval error (e.g., option-name mismatch) by adjusting the Phase 2 block, then re-run.
- [ ] Activate:
      ```bash
      home-manager switch --flake .#benjamin
      ```
      (Confirm the exact flake attribute name — `.#benjamin` per research; adjust if the flake uses a
      different homeConfiguration/username attribute.)

**Timing**: 15-20 minutes

**Depends on**: 4

**Files to modify**: none (activation writes a new generation; the repo edit was Phase 2)

**Verification**:
- `home-manager switch` exits 0 and reports a new generation activated.

**GATED**: Activation touches the store and takes locks. Only after Phase 4.

---

### Phase 6: GATED — verify timer installed and space reclaimed (before/after) [NOT STARTED]

**Goal**: Confirm the self-maintaining timer exists and quantify the space recovered.

**Tasks**:
- [ ] Confirm the weekly user timer now exists and is active:
      `systemctl --user list-timers | grep auto-expire` and
      `systemctl --user status home-manager-auto-expire.timer`.
- [ ] Inspect the generated service runs expire then GC:
      `systemctl --user cat home-manager-auto-expire.service`.
- [ ] Capture the after-state and compute deltas vs. Phase 1/Phase 3 baselines:
      `du -sh /nix/store`, `df -h /`, `home-manager generations | wc -l`.
- [ ] Record before→after numbers (store GB, disk %, generation count) in the implementation summary.

**Timing**: 10 minutes

**Depends on**: 5

**Files to modify**: none

**Verification**:
- `home-manager-auto-expire.timer` is listed and enabled under `systemctl --user list-timers`.
- `/nix/store` size and disk % are lower than the Phase 1 baseline; generation count is much lower.

**GATED**: Read-only, but conceptually part of the gated sequence (runs after activation).

---

## Testing & Validation

- [ ] `home.nix` contains exactly one `services.home-manager.autoExpire` block and no `nix.gc` block.
- [ ] (Gated) `home-manager build --dry-run --flake .#benjamin` evaluates without error.
- [ ] (Gated) `home-manager switch` activates a new generation successfully.
- [ ] (Gated) `systemctl --user list-timers` shows `home-manager-auto-expire.timer` enabled.
- [ ] (Gated) `home-manager-auto-expire.service` runs `expire-generations` then `nix-collect-garbage`.
- [ ] (Gated) `/nix/store` size measurably reduced vs. the Phase 1 baseline.
- [ ] (Gated) HM generation count reduced from ≈69 to ≤ a handful within the 30-day window.

## Artifacts & Outputs

- `home.nix` — new `services.home-manager.autoExpire` block (the only repo change).
- A new home-manager generation (after gated activation).
- `home-manager-auto-expire.{service,timer}` user units (generated by activation).
- plans/01_user-nix-gc.md (this file).
- summaries/01_user-nix-gc-summary.md (to be written by /implement, with before/after store metrics).

## Rollback/Contingency

- **Revert the declarative change**: remove the `services.home-manager.autoExpire` block from
  `home.nix` and run `home-manager switch` again (after the Lean build) to drop the timer. The
  edit is isolated to one contiguous block, so `git checkout -- home.nix` (if uncommitted) or a
  single-block deletion fully reverts it.
- **GC already performed is not reversible**: deleted store paths and expired generations cannot be
  restored, but the current/active generation is always preserved via
  `~/.local/state/home-manager/gcroots/current-home`, so the running config is never lost.
- **If the dry-run (Phase 5) fails on option names**: adjust the `autoExpire` attribute set in Phase
  2 to match the installed HM version (consult `man home-configuration.nix`) and re-run the dry-run;
  no store damage occurs because activation only proceeds after a clean dry-run.
- **If the Lean build is still running when reclamation is attempted**: abort immediately; do not
  force GC. Wait and retry from Phase 3.

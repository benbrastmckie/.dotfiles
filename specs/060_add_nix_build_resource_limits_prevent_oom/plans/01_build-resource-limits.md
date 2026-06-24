# Implementation Plan: Task #60

- **Task**: 60 - Add Nix build resource limits to prevent OOM during rebuilds
- **Status**: [NOT STARTED]
- **Effort**: 0.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/060_add_nix_build_resource_limits_prevent_oom/reports/01_build-resource-limits.md
- **Artifacts**: plans/01_build-resource-limits.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Add explicit `max-jobs = 2` and `cores = 6` to the `nix.settings` block in `configuration.nix` so the nix daemon caps concurrent build parallelism at 12 simultaneous compile units (≤ ~26 GB RAM budget), preventing the OOM cascade seen with heavy C++ packages (onnxruntime). Add a configurable `--max-jobs` override to the `nixos-rebuild` and `home-manager` invocations in `update.sh` as an interactive safety net. This is a ~10-line declarative config change with no logic.

### Research Integration

The research report (01_build-resource-limits.md) establishes that the machine has 32 GB RAM / 24 logical cores, and the current `nix.settings` block (configuration.nix:736-739) has no `max-jobs` or `cores` constraints — defaulting to `max-jobs="auto"` (24) and `cores=0` (all 24), a worst case of 576 concurrent compiler processes. The report's **Decision** section selects Option B (`max-jobs = 2`, `cores = 6`, product 12) as the permanent baseline and recommends a `--max-jobs` override (default 4, env-overridable to 1 for onnxruntime-class builds) in `update.sh`. This plan implements exactly that decision.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (no roadmap_path provided).

## Goals & Non-Goals

**Goals**:
- Add `max-jobs = 2` and `cores = 6` to `nix.settings` in `configuration.nix`.
- Add a configurable `--max-jobs` override (default 4, env var `NIX_MAX_JOBS`) to both rebuild invocations in `update.sh`.
- Document the rationale inline via comments so the values are self-explaining.

**Non-Goals**:
- No changes to `home.nix` or `flake.nix`.
- No tuning of earlyoom, zram, or swap (already configured; out of scope).
- No per-package `enableParallelBuilding` overrides.
- No running of any build or flake-check during implementation (deferred verification — see Testing section).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `max-jobs=2`/`cores=6` slows total rebuild time | L | M | Acceptable trade-off (correctness > speed); `update.sh` override allows raising jobs interactively |
| onnxruntime still OOMs at product 12 | M | L | `NIX_MAX_JOBS=1 ./update.sh` override documented in plan; earlyoom is the backstop |
| Editing config while Lean build runs on /nix/store | H | L | Edits are to text files only; settings take effect only on next `nixos-rebuild switch`. No build/eval commands run during implementation |
| Syntax error in nix block breaks rebuild | M | L | Deferred `nix flake check` (post-Lean) catches it before switch; change is a 2-line addition inside an existing attrset |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel. Phases 1 and 2 edit independent files; Phase 3 is deferred verification gated on the user's Lean build completing.

### Phase 1: Add max-jobs and cores to nix.settings [NOT STARTED]

**Goal**: Cap nix daemon build parallelism declaratively in the system configuration.

**Tasks**:
- [ ] In `configuration.nix`, inside the existing `nix.settings` attrset (currently lines 736-739), add two settings after `auto-optimise-store = true;`:
  - `max-jobs = 2;` with a comment noting "max 2 parallel derivations"
  - `cores = 6;` with a comment noting "6 build threads each; 2x6=12 ≤ RAM budget, prevents OOM on heavy C++ (onnxruntime)"
- [ ] Confirm the block reads as valid Nix (matching braces, trailing semicolons).

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `configuration.nix:736-739` - Add `max-jobs` and `cores` keys inside the `settings = { ... }` attrset of the `nix` block. Target end state:
  ```nix
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;  # Optimize the Nix store automatically
      max-jobs = 2;  # Max 2 parallel derivations (prevents OOM during rebuilds)
      cores = 6;     # 6 build threads per derivation; 2x6=12 concurrent units <= RAM budget
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
  ```

**Verification**:
- Visual inspection: both new keys are inside `settings`, each terminated by `;`, braces balanced.
- (Deferred to Phase 3) `nix flake check` confirms the configuration still evaluates.

---

### Phase 2: Add --max-jobs override to update.sh [NOT STARTED]

**Goal**: Provide an interactive safety net and an env-overridable job cap for `update.sh` rebuilds.

**Tasks**:
- [ ] In `update.sh`, after the `HOSTNAME` detection block (around line 25) and before the rebuild section, add a `MAX_JOBS="${NIX_MAX_JOBS:-4}"` line with a comment explaining `NIX_MAX_JOBS=1 ./update.sh` for onnxruntime-class rebuilds.
- [ ] Append `--max-jobs "$MAX_JOBS"` to the `nixos-rebuild switch` invocation (currently line 36).
- [ ] Append `--max-jobs "$MAX_JOBS"` to the `home-manager switch` invocation (currently line 41).
- [ ] Keep the existing `--option allow-import-from-derivation false` flags intact.

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `update.sh` (after line 25) - Add the override variable:
  ```bash
  # Cap build parallelism to avoid OOM on heavy C++ packages.
  # Override per-run, e.g. NIX_MAX_JOBS=1 ./update.sh for onnxruntime-class builds.
  MAX_JOBS="${NIX_MAX_JOBS:-4}"
  ```
- `update.sh:36` - Change to:
  ```bash
  sudo nixos-rebuild switch --flake .#$HOSTNAME --option allow-import-from-derivation false --max-jobs "$MAX_JOBS"
  ```
- `update.sh:41` - Change to:
  ```bash
  home-manager switch --flake .#benjamin --option allow-import-from-derivation false --max-jobs "$MAX_JOBS"
  ```

**Verification**:
- `bash -n update.sh` (syntax-only, does NOT execute the script or touch nix) confirms no shell syntax errors.
- Visual inspection: `MAX_JOBS` is defined before first use; both invocations reference `"$MAX_JOBS"`.

---

### Phase 3: Deferred build verification (run AFTER Lean build completes) [NOT STARTED]

**Goal**: Confirm the configuration evaluates and rebuilds cleanly under the new resource limits.

> **GATE — DO NOT RUN UNTIL THE USER'S ACTIVE LEAN BUILD HAS FINISHED AND /nix/store IS IDLE.**
> All commands below touch the nix daemon / /nix/store and MUST be deferred. Disk was at 94% during planning; confirm headroom before building. None of these commands are run during implementation of Phases 1-2.

**Tasks**:
- [ ] (Deferred) Run `nix flake check` to confirm the configuration evaluates with the new `nix.settings` keys.
- [ ] (Deferred) Run `nixos-rebuild build --flake .#$(hostname)` (build, not switch) to confirm a dry build succeeds under the limits.
- [ ] (Deferred) Optionally run `nix eval .#nixosConfigurations.$(hostname).config.nix.settings.max-jobs` and `.cores` to confirm the values resolve to `2` and `6`.
- [ ] (Deferred) When ready to apply: run `./update.sh` (or `NIX_MAX_JOBS=1 ./update.sh` if onnxruntime is in scope) and observe that parallelism is capped and no OOM occurs.

**Timing**: 0.25 hours (deferred, not counted against implementation effort)

**Depends on**: 1, 2 (and external: Lean build completion)

**Files to modify**: none (verification only)

**Verification**:
- `nix flake check` exits 0.
- `nix eval` reports `max-jobs = 2` and `cores = 6`.
- A subsequent rebuild completes without an OOM-kill cascade or multi-minute freeze.

---

## Testing & Validation

- [ ] Phase 1: `nix.settings` block has `max-jobs = 2;` and `cores = 6;` with balanced braces.
- [ ] Phase 2: `bash -n update.sh` passes; `MAX_JOBS` defined before use; both rebuild lines pass `--max-jobs "$MAX_JOBS"`.
- [ ] Phase 3 (DEFERRED, post-Lean): `nix flake check` passes; `nix eval` confirms values; rebuild completes without OOM.

## Artifacts & Outputs

- Modified `configuration.nix` (2 lines added to `nix.settings`).
- Modified `update.sh` (1 variable + 2 invocation edits).
- No new files created.

## Rollback/Contingency

- Revert is trivial: `git checkout configuration.nix update.sh` restores the prior state (no rebuild is applied during implementation, so reverting the text fully restores behavior).
- If the new limits prove too conservative after deferred verification, raise to Option A (`max-jobs = 4`, `cores = 6`) per the research report, or raise `NIX_MAX_JOBS` per-run without touching `configuration.nix`.
- If a syntax error is found during deferred `nix flake check`, fix the offending line; no `switch` has been applied so the running system is unaffected.

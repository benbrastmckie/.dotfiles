# Implementation Plan: Task #69

- **Task**: 69 - Consolidate dual home-manager config (unify lectic extraSpecialArgs)
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours (mostly nix eval/build wait time)
- **Dependencies**: 86 (completed)
- **Research Inputs**: reports/01_verify-task-86-fold-in.md
- **Artifacts**: plans/01_unify-lectic-specialargs.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md; nix.md; git-workflow.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Task 86 (commit `9946058`) touched only `docs/dual-home-manager.md` — no `.nix` changes — and
documented the `lectic` `extraSpecialArgs` asymmetry as an "intentional divergence, not a bug".
Live `nix eval` (research report 01) disproves that framing: the NixOS-integrated home-manager
path passes the RAW `lectic` flake input (an attrset with `outPath` but no `name`/`bin/lectic`)
straight into `home.packages`, so `nandi`/`hamsa`/`garuda`/`usb-installer` install a
silently-inert `lectic` reference. This is the same defect class task 66 phase 9 fixed for the
standalone path only. The resolution expression already exists verbatim three lines away in the
same file. This plan applies the trivial, Option-A-scoped alignment so both paths resolve `lectic`
to the built `lectic-0.0.0` derivation, corrects the inaccurate doc paragraph, and verifies via
`nix eval` + `nix flake check` + affected-config builds. Definition of done: every
NixOS-integrated and the standalone home path's `home.packages` `lectic` entry resolves to a real
derivation, the flake checks green, and the doc reflects the now-unified state.

### Research Integration

- Report `01_verify-task-86-fold-in.md` is the sole input. Its outcome (B) — "not a
  verification-only close-out; minimal documentation-scoped resolution plus trivial one-line
  specialArgs alignment still needed" — is the direct basis for this plan.
- Report-confirmed facts used verbatim: the resolution idiom
  `lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic` already
  appears in `lib/mkHost.nix`'s top-level `specialArgs` (line 56), in the `iso` block's
  `specialArgs` (`flake.nix:173`), and in the standalone override (`flake.nix:206`).
- **Planning-time discovery beyond the report**: the report enumerated only the four `mkHost`
  hosts and named `lib/mkHost.nix:48` as the single fix site. Reading `flake.nix` during planning
  found a SECOND raw-`lectic` site: `hmExtraSpecialArgs` (`flake.nix:85-89`, `inherit lectic;`) is
  consumed RAW by the inline `iso` NixOS config at `flake.nix:136`
  (`home-manager.extraSpecialArgs = hmExtraSpecialArgs;`). The `iso` config therefore carries the
  identical defect and is not covered by the report's single-line recommendation. Phase 2 covers
  both sites so the unification is actually complete. This is still trivial (same one-line
  expression) and is NOT task 86's aggregator/wiring surface.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path`/`roadmap_flag` supplied to this planning run; ROADMAP.md not consulted. Task 69
advances the task-66 lineage (parent_task 66) of eliminating the dual-home-manager `lectic`
regression across all evaluation paths.

## Goals & Non-Goals

**Goals**:
- Make the NixOS-integrated home-manager path resolve `lectic` to the built derivation on all
  affected hosts (`nandi`, `hamsa`, `garuda`, `usb-installer`) via a one-line change in
  `lib/mkHost.nix`.
- Complete the unification by resolving `lectic` for the `iso` config's home path
  (`flake.nix` `hmExtraSpecialArgs`), which consumes the raw input.
- Correct `docs/dual-home-manager.md` to describe the paths as now unified on the resolved
  `lectic` package, removing the inaccurate "deliberate divergence, not a bug" claim.
- Verify with `nix eval` (both paths + iso), `nix flake check`, and affected-config builds.
- Commit with narrowly-scoped `git add <specific paths>` (never `-A`).

**Non-Goals**:
- Do NOT redo or touch task 86's aggregator/opt-in wiring (`hosts/nandi/default.nix`,
  `modules/system/default.nix`, `modules/home/default.nix`).
- Do NOT touch `home-manager.useGlobalPkgs` / `useUserPackages`.
- Do NOT collapse or remove either home-manager path (Option B/C is out of scope; "keep both
  paths — Option A" is already the decided answer).
- Do NOT introduce new abstractions, options, modules, or files.
- Do NOT change `pkgs-unstable` / `nix-ai-tools` arg passing.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Closure growth: NixOS-integrated profiles gain the real ~280 MiB `lectic` + node_modules where nothing usable was linked before | M | H (expected) | This is a correctness fix, not a regression; call it out in the commit body; confirm via `nix eval` that the entry is `lectic-0.0.0` and that `nix flake check` stays green |
| Scope creep into task 86's aggregator/wiring surface | M | L | Explicit Non-Goals; git staging restricted to `lib/mkHost.nix`, `flake.nix`, `docs/dual-home-manager.md`, plan/state artifacts only |
| `iso` fix perceived as beyond the mandated one-line minimal | L | M | Phase 2 keeps the `lib/mkHost.nix` edit as the mandatory core and treats the `flake.nix` `hmExtraSpecialArgs` edit as a clearly-flagged completion of the same defect; both use the identical pre-existing expression |
| Doc line-number reference (`flake.nix:199-207`) goes stale after edits | L | M | Rewrite the doc to reference the resolution expression by name, not by brittle line numbers |
| `nix flake check` / builds slow or fail on unrelated pre-existing issues | M | L | Baseline eval in Phase 1 establishes the pre-change state so any new failure is attributable; fix forward, never discard uncommitted work |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Baseline verification and snapshot [COMPLETED]

**Goal**: Record the pre-change `home.packages` `lectic` resolution for every affected path so the
fix's effect is provable and any new failure is attributable.

**Tasks**:
- [x] Confirm working directory is clean or note pre-existing changes (`git status --short`).
      *(pre-existing unrelated changes noted: specs/086.../plans/01... modified, specs/TODO.md,
      specs/state.json modified by other in-flight tasks 86-93; not touched by this task)*
- [x] Eval NixOS-integrated path for each mkHost host and record the `lectic` entry (expect raw
      attrset / `NO-NAME`):
      `nix eval .#nixosConfigurations.nandi.config.home-manager.users.benjamin.home.packages --apply 'map (p: (p.name or "NO-NAME"))'`
      (repeat for `hamsa`, `garuda`; `usb-installer` if evaluable).
      *(confirmed: nandi/hamsa/garuda each show exactly one "NO-NAME" entry)*
- [x] Eval the `iso` config's home path and record the `lectic` entry (expect raw attrset):
      `nix eval .#nixosConfigurations.iso.config.home-manager.users.benjamin.home.packages --apply 'map (p: (p.name or "NO-NAME"))'`.
      *(confirmed: one "NO-NAME" entry)*
- [x] Eval the standalone path and record the `lectic` entry (expect `lectic-0.0.0`, already
      correct): `nix eval .#homeConfigurations.benjamin.config.home.packages --apply 'map (p: (p.name or "NO-NAME"))'`.
      *(confirmed: "lectic-0.0.0" present)*
- [x] Note the before-state (which paths show `NO-NAME`/raw input) in the eventual summary.

**Timing**: 20 min (dominated by evaluation time)

**Depends on**: none

**Files to modify**: none (read-only verification).

**Verification**:
- At least the `mkHost` hosts and `iso` show a `NO-NAME`/raw-attrset `lectic` entry; standalone
  shows `lectic-0.0.0`. This reproduces the report's finding and defines the target end state.

---

### Phase 2: Unify lectic resolution in extraSpecialArgs [COMPLETED]

**Goal**: Resolve `lectic` to the built package on every NixOS-integrated home path, using the
resolution expression already present in the same files.

**Tasks**:
- [x] **(Mandatory core)** In `lib/mkHost.nix`, inside `home-manager.extraSpecialArgs`
      (currently line 48), replace `inherit lectic;` with
      `lectic = lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic;`
      — identical to the expression already at line 56 of the same file.
      *(actual line was 47, not 48 — repo shifted slightly since report; applied verbatim)*
- [x] **(Completion of same defect — iso path)** In `flake.nix`, inside `hmExtraSpecialArgs`
      (currently lines 85-89), replace `inherit lectic;` with
      `lectic = lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic;`.
      This fixes the `iso` config, which consumes `hmExtraSpecialArgs` raw at `flake.nix:136`.
- [x] Update the "so do not unify these" inline comment in the standalone override block
      (`flake.nix`, currently lines 203-206): the standalone `lectic` override now equals the
      base value in `hmExtraSpecialArgs`. Either keep the explicit override with a corrected
      comment ("both paths resolve lectic to the built package; kept explicit for clarity") OR
      remove the now-redundant `// { lectic = ...; }` override (leaving `... // hmExtraSpecialArgs`)
      — choose the smaller diff; do not change the resulting value.
      *(chose removal of the redundant override — smaller diff — with a corrected comment noting
      both paths now share the resolved value via hmExtraSpecialArgs)*
- [x] Do not touch `pkgs-unstable`, `nix-ai-tools`, `useGlobalPkgs`, or `useUserPackages`.

**Timing**: 20 min

**Depends on**: 1

**Files to modify**:
- `lib/mkHost.nix` — resolve `lectic` in `home-manager.extraSpecialArgs`.
- `flake.nix` — resolve `lectic` in `hmExtraSpecialArgs`; correct/prune the "do not unify" comment
  in the standalone override.

**Verification**:
- `nix eval` of an affected NixOS-integrated host's `home.packages` now shows `lectic-0.0.0`
  (full green confirmation deferred to Phase 4).
- No edits outside the two files above.

---

### Phase 3: Correct docs/dual-home-manager.md [COMPLETED]

**Goal**: Replace the inaccurate "intentional divergence, not a bug" paragraph with a note that
both paths now resolve `lectic` identically to the built package.

**Tasks**:
- [x] Rewrite the `extraSpecialArgs divergence (intentional)` bullet (currently lines 31-39):
      state that both the NixOS-integrated and standalone paths now pass the resolved `lectic`
      package via `lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic`,
      that this was a real asymmetry (the task-66-phase-9 `lectic` regression) now unified across
      all paths — not an intentional design.
- [x] Reference the resolution expression by name rather than brittle `flake.nix:199-207` line
      numbers (which shift after Phase 2).
- [x] Leave the separate "QUESTION for User: Which Path to Keep?" (Option A/B/C) section
      untouched — it concerns whether to keep both paths and is already answered ("Keep both —
      Option A").

**Timing**: 15 min

**Depends on**: 1

**Files to modify**:
- `docs/dual-home-manager.md` — replace the divergence paragraph (lines 31-39).

**Verification**:
- The doc no longer contains "deliberate divergence, not a bug" or "do not unify"; it describes a
  unified resolved-package state and cites the expression by name.

---

### Phase 4: Full verification and scoped commit [COMPLETED]

**Goal**: Prove both paths resolve to the built derivation, the flake is green, affected configs
build, and commit with narrowly-scoped staging.

**Tasks**:
- [x] Re-run the Phase 1 evals; confirm `nandi`/`hamsa`/`garuda`/`iso` (and `usb-installer` if
      evaluable) `home.packages` now show `lectic-0.0.0`, and standalone still shows
      `lectic-0.0.0`.
      *(confirmed: all four NixOS-integrated hosts + standalone now show `lectic-0.0.0`)*
- [x] `nix flake check` — must be green.
      *(confirmed green both before and after builds)*
- [x] Build affected configs (at least one representative NixOS host and the standalone home):
      `nix build .#nixosConfigurations.nandi.config.system.build.toplevel` and
      `nix build .#homeConfigurations.benjamin.activationPackage` (or
      `home-manager build --flake .#benjamin`).
      *(both succeeded: nandi toplevel built to
      /nix/store/n3zqk0yqwg838lxvfw5jqxml2vrm679r-nixos-system-nandi-...; standalone activation
      built to /nix/store/fx21pk2pqqiqk46ai9ig2wvmjrdlk2hd-home-manager-generation)*
- [x] Stage ONLY the specific paths (never `git add -A` / `git commit -am`):
      `git add lib/mkHost.nix flake.nix docs/dual-home-manager.md specs/069_consolidate_dual_home_manager_config/ specs/state.json specs/TODO.md`.
      *(deviation: altered — specs/state.json and specs/TODO.md excluded from staging because
      they currently carry unrelated in-flight modifications from other concurrent tasks
      (86/88/89/93); staging them would bundle unrelated work into this commit. State.json/TODO.md
      updates for task 69 are left to the invoking skill's postflight step, consistent with the
      nix-implementation-agent's documented division of responsibility.)*
- [x] Review with `git status --short` and `git diff --staged` before committing.
- [x] Commit: `task 69: complete implementation` (body notes the intentional closure growth from
      linking the real ~280 MiB `lectic` on the NixOS-integrated paths, plus the session id).

**Timing**: 35 min (dominated by build time)

**Depends on**: 2, 3

**Files to modify**: none (verification + commit only).

**Verification**:
- Every affected path's `lectic` entry is `lectic-0.0.0`; `nix flake check` green; builds succeed;
  staged diff contains only the four content files plus task-state artifacts.

## Testing & Validation

- [ ] `nix eval .#nixosConfigurations.{nandi,hamsa,garuda,iso}.config.home-manager.users.benjamin.home.packages --apply 'map (p: (p.name or "NO-NAME"))'` shows `lectic-0.0.0` (no `NO-NAME`).
- [ ] `nix eval .#homeConfigurations.benjamin.config.home.packages --apply 'map (p: (p.name or "NO-NAME"))'` shows `lectic-0.0.0`.
- [ ] `nix flake check` exits green.
- [ ] `nix build .#nixosConfigurations.nandi.config.system.build.toplevel` succeeds.
- [ ] Standalone home builds (`home-manager build --flake .#benjamin` or activationPackage build).
- [ ] `git diff --staged` shows only `lib/mkHost.nix`, `flake.nix`, `docs/dual-home-manager.md`,
      and `specs/` task-state artifacts.

## Artifacts & Outputs

- `plans/01_unify-lectic-specialargs.md` (this plan)
- `lib/mkHost.nix` (edited — resolved `lectic`)
- `flake.nix` (edited — resolved `lectic` in `hmExtraSpecialArgs`; corrected comment)
- `docs/dual-home-manager.md` (edited — corrected divergence paragraph)
- `summaries/01_unify-lectic-specialargs-summary.md` (produced at implementation completion)

## Rollback/Contingency

- All changes are on tracked files; revert with `git checkout -- lib/mkHost.nix flake.nix docs/dual-home-manager.md` BEFORE committing, or `git revert <sha>` after.
- If `nix flake check` or a build fails after the edits: fix forward (the change is a one-line
  value swap using a pre-existing, proven expression); never discard uncommitted work to reach a
  passing build. If the failure is unrelated/pre-existing (compare against the Phase 1 baseline),
  record it and proceed.
- If the closure-growth build is prohibitively slow in the working environment, the `nix eval`
  resolution check (entry == `lectic-0.0.0`) plus `nix flake check` is the minimum acceptable
  gate; note the deferred full build in the summary.

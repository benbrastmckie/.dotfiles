# Implementation Plan: Task #88 - Module granularity pass over modules/home/

- **Task**: 88 - Module granularity pass over modules/home/
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: Task 86 (module convention + aggregators) — landed at commit `add7cae`
- **Research Inputs**: specs/088_module_granularity_pass/reports/01_module-granularity-boundaries.md
- **Artifacts**: plans/01_module-granularity-refactor.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md; nix.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Pure structural refactor of `modules/home/`: split the 761-line `email/agent-tools.nix` into a
per-binary directory, merge three tiny package fragments into `packages/misc.nix`, co-locate the
split memory system under a new `memory/` directory, and fix the `core/shell.nix` misnomer via
`git mv` to `core/dotfiles.nix`. The single hand-edit registration point is the task-86
aggregator `modules/home/default.nix` (31 manually-maintained `imports` entries, no
auto-discovery); every rename/split/merge gets a corresponding one-line edit there. Definition of
done: `nix build .#homeConfigurations.benjamin.activationPackage` succeeds and
`nix store diff-closures` against a pre-change baseline is EMPTY (no behavior/closure change).

### Research Integration

The plan operationalizes report `01_module-granularity-boundaries.md` verbatim:
- **agent-tools split** along existing `let`-bound helpers: a plain (non-module) `lib.nix`
  carrying `mkPreamble`/`mkMutationPreamble`/`lower`/`manifestDirDefault` (all verified pure, no
  `pkgs`/`config` dependency), five per-binary HM modules importing from it, and a `default.nix`
  listing the five. No file exceeds ~290 lines post-split (vs. 761).
- **package merge** into `packages/misc.nix` declaring `{ pkgs, lectic, ... }:` (`lectic` is a
  global `extraSpecialArgs`, already wired) with comment sub-groups preserving provenance.
- **memory co-location** into new `memory/{monitor.nix,services.nix}`.
- **rename** `core/shell.nix` → `core/dotfiles.nix` plus a header-comment reword.
- The exact aggregator diff (report §"Recommended Aggregator Diff") is the authoritative
  registration change; expected final entry count is 29 (31 − 3 package fragments − 2 memory
  files + 1 packages/misc + 2 memory files, net −2).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_flag` was set for this dispatch, so ROADMAP.md is neither read as a planning input nor
modified by this plan. Task 88 is subtask blueprint #7 of the task-81 `modules/home/`
reorganization (parent_task 81), but its roadmap accounting is owned by the parent-task workflow,
not this granularity pass.

## Goals & Non-Goals

**Goals**:
- Split `email/agent-tools.nix` into `email/agent-tools/{lib.nix, census.nix, classify.nix, unsubscribe-extract.nix, archive-confirmed.nix, delete-confirmed.nix, default.nix}`.
- Merge `packages/{fonts,lean-math,ai-tools}.nix` into a single new `packages/misc.nix`.
- Co-locate `scripts/memory-monitor.nix` + `services/memory-services.nix` into `memory/{monitor.nix, services.nix}`.
- Rename `core/shell.nix` → `core/dotfiles.nix` (misnomer fix) via `git mv` + header reword.
- Update `modules/home/default.nix` (the single hand-edit site) for every path change.
- Preserve build inertness: empty `nix store diff-closures` against the pre-change baseline.

**Non-Goals**:
- No behavior changes, no new option schemas, no new dependencies (pure text/structure refactor).
- Do NOT rename or touch the existing top-level `modules/home/misc.nix` despite the deliberate
  `packages/misc.nix` basename collision (both paths sanctioned by `design/target-layout.md`);
  only add a disambiguating header comment.
- Do NOT touch stale documentation references (`README.md:71`, `docs/email-workflow.md:15`,
  `docs/how-to-add-service.md:121`) — those are explicitly task 91's scope.
- No further splitting of `agent-tools`' `mkMutationPreamble` or `core/dotfiles.nix`'s `home.file`
  block (both flagged as future direction, not this pass).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Missed helper reference during agent-tools split (e.g. `lower` used in `classify.nix`) | H | M | `nix build` fails loudly on any missing `import`/`inherit`; per-binary `--help` smoke test; `diff-closures` is authoritative byte-identity check |
| Forgetting an aggregator line edit (Nix silently drops the module, no error) | H | M | Aggregator is single hand-edit site; per-phase `nix eval ...activationPackage.name` after each edit; final entry-count self-check (expect 29) |
| `git mv` / new-file staging omitted — `flake.nix` `root = self` reads from git index, so untracked files are invisible to pure eval | H | M | Use `git mv` for the rename; `git add <path>` every new split/merge/memory file BEFORE running any `nix build`/`eval`; never `git add -A` |
| Closure changes despite "pure refactor" (accidental interpolation drift) | H | L | Capture baseline closure path on a clean tree (Phase 1) before any edit; final `nix store diff-closures` must be EMPTY, else revert and diff the generated shell scripts |
| `packages/misc.nix` edited by a future contributor confusing it with top-level `misc.nix` | M | L | Disambiguating header comment in the new file cross-referencing `../misc.nix` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |

Phases 2-5 are logically independent (each touches a disjoint set of module files) but are
serialized because they all edit the single shared aggregator `modules/home/default.nix`;
sequencing them keeps that one hand-edit site conflict-free and lets each structural change be
verified in isolation before the next.

### Phase 1: Capture pre-change baseline closure [COMPLETED]

**Goal**: Establish a clean, verified baseline so the final `nix store diff-closures` has a
correct reference point.

**Tasks**:
- [x] Confirm working tree is clean (`git status --porcelain` empty); if not, stop and reconcile.
      *(deviation: altered — `modules/home/`, `flake.nix`, `flake.lock`, `lib/mkHost.nix` were
      confirmed clean via scoped `git status --porcelain`, but the wider tree carried unrelated
      in-flight task artifacts (specs/086, specs/087, specs/089, specs/093, specs/TODO.md,
      specs/state.json). Proceeding was judged safe since none touch modules/home/ or the flake
      root files this task's diff-closures check depends on.)*
- [x] Build the current tree: `nix build .#homeConfigurations.benjamin.activationPackage --out-link /tmp/task88-baseline` (or capture the store path via `nix path-info`).
- [x] Record the baseline store path (e.g. `readlink -f /tmp/task88-baseline`) for the Phase 6 comparison.
      Baseline: `/nix/store/7zlz05l6ghw72r4sqmsq2hx4ljs2dhh5-home-manager-generation`
      *(deviation: altered — Phase 2 file edits were briefly made before this baseline capture
      was executed; corrected by `git stash`-ing the Phase 2 changes, building the baseline on
      the truly clean tree, then `git stash pop` to restore Phase 2 work. Baseline path above is
      verified correct — captured on a tree with zero staged/unstaged changes under
      modules/home/.)*

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- None (read-only baseline capture; produces a `/tmp` out-link only).

**Verification**:
- `nix build` succeeds and the baseline store path is recorded.

---

### Phase 2: Split email/agent-tools.nix into agent-tools/ directory [COMPLETED]

**Goal**: Replace the 761-line monolith with a `lib.nix` + five per-binary modules + `default.nix`,
registered as a directory import in the aggregator.

**Tasks**:
- [x] Create `modules/home/email/agent-tools/lib.nix` as a plain (non-module) Nix attrset
      `{ manifestDirDefault, mkPreamble, mkMutationPreamble, lower }` carrying the full original
      header comment (whole-subsystem contract provenance). No module args.
      *(deviation: altered — lib.nix is 316 lines, above the report's ~290-line estimate,
      because it carries the full original 27-line header plus mkPreamble (68 lines) plus
      mkMutationPreamble (199 lines, itself unsplittable per the plan's own Non-Goals) plus a
      short task-88 provenance note. All four helpers remain in one file per the plan's explicit
      instruction not to split mkMutationPreamble further; the "~290" figure in Testing &
      Validation is treated as approximate given the "~" qualifier.)*
- [x] Create `census.nix` — `{ pkgs, ... }: let inherit (import ./lib.nix) mkPreamble; in { home.packages = [ (pkgs.writeShellScriptBin "email-census" ...) ]; }` (~55 lines). Actual: 57 lines.
- [x] Create `classify.nix` (uses `mkPreamble`, `lower`; ~170 lines — largest post-split). Actual: 172 lines.
- [x] Create `unsubscribe-extract.nix` (uses `mkPreamble`; ~70 lines). Actual: 72 lines.
- [x] Create `archive-confirmed.nix` (uses `mkMutationPreamble`; ~60 lines). Actual: 62 lines.
- [x] Create `delete-confirmed.nix` (uses `mkMutationPreamble`; ~130 lines). Actual: 132 lines.
- [x] Create `default.nix` — `{ ... }: { imports = [ ./census.nix ./classify.nix ./unsubscribe-extract.nix ./archive-confirmed.nix ./delete-confirmed.nix ]; }`.
- [x] `git rm modules/home/email/agent-tools.nix` and `git add` all seven new files (never `git add -A`).
- [x] Edit `modules/home/default.nix`: replace `./email/agent-tools.nix` with `./email/agent-tools` (same position in the Email group).

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `modules/home/email/agent-tools.nix` - removed (content redistributed).
- `modules/home/email/agent-tools/{lib,census,classify,unsubscribe-extract,archive-confirmed,delete-confirmed,default}.nix` - new.
- `modules/home/default.nix` - one line: `./email/agent-tools.nix` -> `./email/agent-tools`.

**Verification**:
- [x] `nix eval .#homeConfigurations.benjamin.activationPackage.name` succeeds (evaluates cleanly).
- [x] Built and confirmed all five binaries (`email-census`, `email-classify`,
      `email-unsubscribe-extract`, `email-archive-confirmed`, `email-delete-confirmed`) support
      `--help` and print their expected banner text.
- [x] Each new file well below the original 761 lines (57/172/72/62/132/316/12); `nix store
      diff-closures` against the Phase 1 baseline was run early (ahead of schedule, informally)
      and is EMPTY, confirming byte-identical closure after the split.

---

### Phase 3: Merge tiny package fragments into packages/misc.nix [COMPLETED]

**Goal**: Collapse `fonts.nix` + `lean-math.nix` + `ai-tools.nix` into one `packages/misc.nix`.

**Tasks**:
- [x] Create `modules/home/packages/misc.nix` with signature `{ pkgs, lectic, ... }:` and a
      `home.packages` list combining all three fragments, using comment sub-groups (Fonts / Lean
      4 and formal-math tools / AI and coding assistant tools) to preserve per-source provenance.
- [x] Add a disambiguating header comment cross-referencing the unrelated top-level `../misc.nix`
      (activation/session settings) to prevent future edit confusion.
      *(deviation: altered — added a reciprocal disambiguating comment to the top-level
      `modules/home/misc.nix` header as well, cross-referencing `packages/misc.nix`. This is the
      one touch to that file explicitly sanctioned by the plan's own Non-Goals section ("only
      add a disambiguating header comment"), not a scope violation.)*
- [x] `git rm modules/home/packages/{fonts,lean-math,ai-tools}.nix`; `git add modules/home/packages/misc.nix`.
- [x] Edit `modules/home/default.nix`: remove the three `./packages/{ai-tools,lean-math,fonts}.nix`
      lines, add one `./packages/misc.nix` line (Package group shrinks 7 -> 5).

**Timing**: 0.25 hours

**Depends on**: 2

**Files to modify**:
- `modules/home/packages/{fonts,lean-math,ai-tools}.nix` - removed.
- `modules/home/packages/misc.nix` - new.
- `modules/home/default.nix` - 3 lines removed, 1 added in the Package group.

**Verification**:
- [x] `nix eval .#homeConfigurations.benjamin.activationPackage.name` succeeds.
- [x] `lectic` resolves without a "missing argument" error (confirms the special-arg signature).

---

### Phase 4: Co-locate memory system into memory/ directory [COMPLETED]

**Goal**: Move the two halves of the memory system into a single `modules/home/memory/` directory.

**Tasks**:
- [x] `git mv modules/home/scripts/memory-monitor.nix modules/home/memory/monitor.nix`.
- [x] `git mv modules/home/services/memory-services.nix modules/home/memory/services.nix`.
- [x] Reword each file's provenance header if it references the old `scripts/`/`services/` path (content otherwise unchanged — service unit names are NOT renamed).
      *(deviation: skipped — neither file's header comment literally referenced the old
      `scripts/`/`services/` path string (both just said "Memory monitoring scripts" /
      "Memory monitoring user services"), so there was nothing stale to reword; condition in
      the task bullet was not met. Left content byte-identical aside from the `git mv`.)*
- [x] Edit `modules/home/default.nix`: remove `./scripts/memory-monitor.nix` from the Script
      group and `./services/memory-services.nix` from the Service group; add a new
      comment-delimited group with `./memory/monitor.nix` and `./memory/services.nix`.

**Timing**: 0.25 hours

**Depends on**: 3

**Files to modify**:
- `modules/home/scripts/memory-monitor.nix` -> `modules/home/memory/monitor.nix` (git mv).
- `modules/home/services/memory-services.nix` -> `modules/home/memory/services.nix` (git mv).
- `modules/home/default.nix` - 2 lines removed, 2 added under a new Memory group.

**Verification**:
- [x] `nix eval .#homeConfigurations.benjamin.activationPackage.name` succeeds.
- [x] Script group retains its 3 other unrelated entries (sioyek-theme, gmail-oauth2, whisper);
      Service group retains its 4 other unrelated entries (screenshot, ydotool, gmail-oauth2,
      cache-cleanup) — the plan text said "3" for both groups but the Service group actually had
      4 non-memory entries pre-change; verified by direct inspection, not a defect.

---

### Phase 5: Rename core/shell.nix to core/dotfiles.nix [COMPLETED]

**Goal**: Fix the `shell.nix` misnomer (it deploys `config/`, not shell config).

**Tasks**:
- [x] `git mv modules/home/core/shell.nix modules/home/core/dotfiles.nix`.
- [x] Reword the header comment, e.g. `# Dotfiles deployment: session variables, home.file sources from config/, and related activation scripts.` (no logic change).
- [x] Edit `modules/home/default.nix`: `./core/shell.nix` -> `./core/dotfiles.nix` (same position in the Core group).

**Timing**: 0.25 hours

**Depends on**: 4

**Files to modify**:
- `modules/home/core/shell.nix` -> `modules/home/core/dotfiles.nix` (git mv).
- `modules/home/default.nix` - one line in the Core group.

**Verification**:
- [x] `nix eval .#homeConfigurations.benjamin.activationPackage.name` succeeds.
- [x] Aggregator entry count confirmed 29 via `grep -c '^\s*\./' modules/home/default.nix`.

---

### Phase 6: Final build and closure-inertness verification [COMPLETED]

**Goal**: Prove the whole refactor is behavior-inert.

**Tasks**:
- [x] Confirm all new files are `git add`-ed and all removals staged (`git status --short` — no untracked `.nix` under `modules/home/`). Confirmed clean; all five phases already committed.
- [x] Self-check the aggregator: `modules/home/default.nix` `imports` list should now have 29 entries (was 31; net −2). Confirmed via `grep -c '^\s*\./' modules/home/default.nix` -> 29.
- [x] Build: `nix build .#homeConfigurations.benjamin.activationPackage --out-link /tmp/task88-after`. Store path: `/nix/store/fx21pk2pqqiqk46ai9ig2wvmjrdlk2hd-home-manager-generation`.
- [x] `nix store diff-closures <baseline-store-path> $(readlink -f /tmp/task88-after)` — output MUST be EMPTY. Confirmed EMPTY (baseline `/nix/store/7zlz05l6ghw72r4sqmsq2hx4ljs2dhh5-home-manager-generation` vs. after `/nix/store/fx21pk2pqqiqk46ai9ig2wvmjrdlk2hd-home-manager-generation`).
- [x] If diff is non-empty: stop, diff the generated shell scripts to locate interpolation drift, fix forward (do not discard uncommitted work). N/A — diff was empty.
- [x] (Additional, not required by plan) Ran `nix flake check`: all checks passed (pre-existing,
      unrelated ZFS `boot.zfs.forceImportRoot` warnings on `hamsa`/`iso`/`usb-installer` hosts —
      not touched by this task).

**Timing**: 0.5 hours

**Depends on**: 5

**Files to modify**:
- None (verification only).

**Verification**:
- [x] `nix build` succeeds; `nix store diff-closures` against the Phase 1 baseline is empty.
- [x] Aggregator entry count is 29.

## Testing & Validation

- [x] `nix build .#homeConfigurations.benjamin.activationPackage` succeeds after all phases.
- [x] `nix store diff-closures <baseline> <after>` is EMPTY (pure structural refactor confirmed).
- [x] `nix eval .#homeConfigurations.benjamin.activationPackage.name` succeeds after each of Phases 2-5 (isolates any regression to its phase).
- [x] `modules/home/default.nix` `imports` list has exactly 29 entries.
- [x] No new untracked `.nix` files under `modules/home/` (all `git add`-ed / `git mv`-ed).
- [x] Each new agent-tools file is <= ~290 lines; original 761-line monolith removed.
      *(deviation: altered — `lib.nix` is 316 lines, ~9% over the report's ~290-line estimate,
      because it intentionally keeps all four shared helpers together per the plan's own
      Non-Goals (no further splitting `mkMutationPreamble`). All five per-binary files are well
      under the bound: 57/172/72/62/132 lines.)*
- [x] Top-level `modules/home/misc.nix` unchanged; `README.md`/`docs/*` untouched (task 91 scope).
      *(deviation: altered — `modules/home/misc.nix` received a one-line disambiguating header
      comment cross-referencing the new `packages/misc.nix`, which the plan's own Non-Goals
      section explicitly sanctions as the "only" allowed touch to that file given the deliberate
      basename collision; no logic changed. `README.md`/`docs/*` were left untouched as required.)*

## Artifacts & Outputs

- `specs/088_module_granularity_pass/plans/01_module-granularity-refactor.md` (this plan).
- `modules/home/email/agent-tools/` (7 new files) replacing `agent-tools.nix`.
- `modules/home/packages/misc.nix` (new) replacing three fragment files.
- `modules/home/memory/{monitor.nix,services.nix}` (relocated).
- `modules/home/core/dotfiles.nix` (renamed from `shell.nix`).
- `modules/home/default.nix` (updated aggregator, 29 entries).
- `specs/088_module_granularity_pass/summaries/01_module-granularity-refactor-summary.md` (at implement time).

## Rollback/Contingency

All changes are local `git mv` / add / edit operations on a clean baseline. To revert before
commit: `git restore --staged` the staged paths and `git checkout` the working tree back to the
baseline commit (tree is snapshot-clean per Phase 1, so no snapshot helper is needed). Because
each phase is verified in isolation via `nix eval`, a regression is localized to the phase whose
eval first fails — revert only that phase's file operations and aggregator line(s) and re-attempt.
The authoritative correctness gate is the empty `nix store diff-closures`; a non-empty diff means
the refactor changed behavior and must be fixed forward (diff the generated scripts) rather than
committed.

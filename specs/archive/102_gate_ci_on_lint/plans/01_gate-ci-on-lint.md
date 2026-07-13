# Implementation Plan: Gate CI on Lint

- **Task**: 102 - Gate CI on lint
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: Task 101 (lint-clean baseline) — satisfied
- **Research Inputs**: reports/01_gate-ci-on-lint.md
- **Artifacts**: plans/01_gate-ci-on-lint.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

The two lint steps in `.github/workflows/ci.yml` (statix, deadnix) are currently shielded
from failing the build by a trailing ` || true` on each `run:` line. Task 101 confirmed the
tree is lint-clean, so this task promotes both steps to blocking CI gates by removing the two
` || true` suffixes and dropping the now-stale `(non-blocking)` suffix from the two step
`name:` fields. No `continue-on-error:` key exists, and no changes to `statix.toml` or the
deadnix `--exclude` flag are needed — those exclusions were finalized in task 101 phase 7 and
must be preserved verbatim. Definition of done: the two lint commands run unshielded in CI,
the YAML remains valid, and both `statix` and `deadnix` still exit 0 locally via
`nix develop --command`, confirming the newly-gated steps pass on the current commit.

### Research Integration

The research report (`reports/01_gate-ci-on-lint.md`) verified locally that
`nix develop --command statix check` and
`nix develop --command deadnix --exclude 'hosts/*/hardware-configuration.nix' .` both exit 0
with zero findings on the current tree. It confirmed the shielding mechanism is shell-level
` || true` (not a `continue-on-error:` step key), pinned the exact lines to edit (lines 20-21
and 22-26 of `ci.yml`), and established that `statix.toml` and the deadnix `--exclude` flag
require no changes.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (no roadmap flag set).

## Goals & Non-Goals

**Goals**:
- Remove ` || true` from the statix `run:` line so a non-zero statix exit fails the job.
- Remove ` || true` from the deadnix `run:` line so a non-zero deadnix exit fails the job.
- Rename the two step `name:` fields from `statix (non-blocking)` / `deadnix (non-blocking)`
  to `statix` / `deadnix` to remove the now-misleading suffix.
- Confirm the tree remains lint-clean so the gated steps pass on the current commit.

**Non-Goals**:
- Modifying `statix.toml` (its `ignore` glob is already correct — do not touch).
- Modifying the deadnix `--exclude 'hosts/*/hardware-configuration.nix'` flag (preserve verbatim).
- Modifying the inline comment above the deadnix step (documents why the exclusion exists — keep).
- Fixing any lint findings (there are none; the tree is already clean).
- Adding or removing any `continue-on-error:` key (none exists).
- Optimizing CI runtime (multiple `nix develop` invocations) — out of scope.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A future edit reintroduces a lint finding and the build starts failing | L | M | This is the intended behavior of the task (gate future regressions), not a defect to mitigate. |
| CI runner's statix/deadnix version differs from local, producing different findings | M | L | The flake lock pins the exact `pkgs.statix`/`pkgs.deadnix` versions used both locally and in CI via the same `nix develop` invocation. |
| YAML edit introduces a syntax error | M | L | Phase 2 validates YAML parseability and greps to confirm no residual ` || true` remains and the `--exclude` flag is intact. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Remove lint shielding from ci.yml [COMPLETED]

**Goal**: Promote the statix and deadnix steps from warn-only to blocking by removing the
` || true` shields and dropping the `(non-blocking)` name suffix.

**Tasks**:
- [x] Edit `.github/workflows/ci.yml` line 20: change `- name: statix (non-blocking)` to `- name: statix`.
- [x] Edit `.github/workflows/ci.yml` line 21: change `run: nix develop --command statix check || true` to `run: nix develop --command statix check` (strip trailing ` || true` only).
- [x] Edit `.github/workflows/ci.yml` line 22: change `- name: deadnix (non-blocking)` to `- name: deadnix`.
- [x] Edit `.github/workflows/ci.yml` line 26: change `run: nix develop --command deadnix --exclude 'hosts/*/hardware-configuration.nix' . || true` to the same line without the trailing ` || true` (preserve the `--exclude` flag and the `.` target exactly).
- [x] Leave the inline comment (lines 23-25) above the deadnix step unchanged.
- [x] Do not touch `statix.toml`, `flake.nix`, or the `nix flake check` step.

**Timing**: ~10 minutes

**Depends on**: none

**Files to modify**:
- `.github/workflows/ci.yml` — remove two ` || true` suffixes; rename two step `name:` fields.

**Verification**:
- `grep -n '|| true' .github/workflows/ci.yml` returns no matches.
- `grep -n 'non-blocking' .github/workflows/ci.yml` returns no matches.
- `grep -F "deadnix --exclude 'hosts/*/hardware-configuration.nix' ." .github/workflows/ci.yml` still matches (flag and target preserved).

---

### Phase 2: Verify lint-clean tree and valid workflow [COMPLETED]

**Goal**: Confirm the newly-gated steps would pass on the current commit and the edited YAML
is syntactically valid, so gating does not break the build on the current tree.

**Tasks**:
- [x] Run `nix develop --command statix check` and confirm exit code 0 with no findings.
- [x] Run `nix develop --command deadnix --exclude 'hosts/*/hardware-configuration.nix' .` and confirm exit code 0 with no findings.
- [x] Validate `.github/workflows/ci.yml` parses as YAML (e.g. `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))"`, or an equivalent available YAML parser; if none is available, fall back to visual inspection of indentation).
- [x] Optionally run `nix flake check` to confirm the first CI step still succeeds end-to-end. *(deviation: skipped — not required for gate verification; statix/deadnix exit-0 checks and YAML validation already satisfy Phase 2's definition of done, and a full flake check was optional per the plan)*
- [x] Re-confirm the Phase 1 greps: no residual ` || true`, no `non-blocking`, `--exclude` flag intact.

**Timing**: ~10 minutes (plus nix devShell entry time)

**Depends on**: 1

**Files to modify**:
- None (verification only).

**Verification**:
- Both lint commands exit 0 (the exact commands CI will now run unshielded).
- YAML parser accepts `.github/workflows/ci.yml` (or visual inspection confirms valid structure).
- `nix flake check` succeeds if run.

---

## Testing & Validation

- [x] `grep -n '|| true' .github/workflows/ci.yml` → no matches.
- [x] `grep -n 'non-blocking' .github/workflows/ci.yml` → no matches.
- [x] `nix develop --command statix check` → exit 0, no findings.
- [x] `nix develop --command deadnix --exclude 'hosts/*/hardware-configuration.nix' .` → exit 0, no findings.
- [x] `.github/workflows/ci.yml` is valid YAML.
- [x] `statix.toml` and the deadnix `--exclude` flag are unchanged (diff scoped to the two `run:` lines and two `name:` lines).

## Artifacts & Outputs

- `.github/workflows/ci.yml` (edited: two blocking lint steps).
- `specs/102_gate_ci_on_lint/plans/01_gate-ci-on-lint.md` (this plan).
- `specs/102_gate_ci_on_lint/summaries/01_gate-ci-on-lint-summary.md` (produced at /implement).

## Rollback/Contingency

If gating causes an unexpected failure (e.g. a version-skew lint finding on CI), re-add
` || true` to the affected `run:` line(s) to restore warn-only behavior, then open a follow-up
task to reconcile the finding. Because the change is confined to `.github/workflows/ci.yml`,
`git checkout .github/workflows/ci.yml` (against a clean index) fully reverts it.

# Implementation Plan: Task #98

- **Task**: 98 - nix_formatter_lint_tooling
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: Task 97 (completed); sequencing recommendation: run after Task 96 lands (see Overview)
- **Research Inputs**: specs/098_nix_formatter_lint_tooling/reports/01_formatter-lint-tooling.md
- **Artifacts**: plans/01_formatter-lint-tooling.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Add Nix formatter and lint tooling to the single-system flake, then apply an initial
format pass. Three additive changes: (1) add `formatter.${system}` and
`devShells.${system}.default` outputs to `flake.nix`; (2) add non-blocking `statix` +
`deadnix` steps to the existing CI job, keeping `nix flake check` as the sole hard gate;
(3) run a whole-tree `nix fmt` pass as a dedicated final phase (47 of 80 `.nix` files need
reformatting). Definition of done: `nix flake check` stays green after the flake edit, the
devShell evaluates and exposes the three tools, the CI YAML is valid, and the whole tree
conforms to `nixfmt`.

### Research Integration

Integrates report `01_formatter-lint-tooling.md`. Key findings baked in:
- The flake is single-system (`system = "x86_64-linux";` hardcoded, no `flake-utils`), so
  `formatter`/`devShells` attach as plain `${system}` keys with no multi-system plumbing.
- Use `pkgs.nixfmt` directly (NOT `pkgs.nixfmt-rfc-style`): in this repo's pinned nixpkgs
  (`nixos-26.05`), `nixfmt-rfc-style` is a deprecated alias of the identical `nixfmt`
  derivation (version 1.3.1, "Official formatter for Nix code") and emits a stderr
  deprecation warning on every evaluation. `pkgs.nixfmt` is the official RFC 166 formatter
  and satisfies the task's intent without the warning.
- CI stays warn-only (USER DECISION): `statix`/`deadnix` steps use
  `nix develop --command ... || true` so their exit code is always 0; `nix flake check`
  remains the only step that can fail the job.
- No `statix.toml` and no deadnix config — keep it minimal per report. Existing live lint
  debt (33 statix warnings, several deadnix findings) is intentionally left unfixed;
  warn-only CI absorbs it.
- `nixfmt` defaults (width 100, indent 2) already match `.claude/rules/nix.md`, so no
  override flags are needed anywhere.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided in delegation context; roadmap consultation skipped. This task
advances the Group D cleanup backlog item from
`specs/094_review_nixos_config_documentation/reports/02_remaining-cleanup-backlog.md`.

### Sequencing note (Task 96)

Task 96 adds header comments to `packages/*.nix`. Per the delegation context this task runs
AFTER task 96 is committed. The Phase 3 format pass therefore reformats the whole tree
INCLUDING task 96's new headers — this is expected and desired. No coordination action is
required in this plan beyond formatting the full tree in Phase 3.

## Goals & Non-Goals

**Goals**:
- Add `formatter.${system} = pkgs.nixfmt;` to `flake.nix` (additive).
- Add `devShells.${system}.default` exposing `nixfmt`, `statix`, `deadnix` (additive).
- Add two non-blocking (`|| true`) lint steps to `.github/workflows/ci.yml`, keeping
  `nix flake check` as the only hard gate.
- Apply a whole-tree `nix fmt` pass so all 80 `.nix` files conform to `nixfmt`.

**Non-Goals**:
- Do NOT fix the existing 33 statix warnings or any deadnix findings (warn-only CI covers
  them; a separate future task).
- Do NOT add `statix.toml` or any deadnix config/exclude file.
- Do NOT convert the flake to `flake-utils.eachDefaultSystem` or otherwise refactor existing
  outputs.
- Do NOT reference `pkgs.nixfmt-rfc-style` anywhere.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Format pass produces a very large diff (47 files) | M | H (expected) | Isolate as its own dedicated Phase 3 commit, separate from the flake/CI edits, so history stays legible and the formatting-only diff is independently reviewable/revertible. |
| `nix develop --command` in CI fails because devShell does not evaluate | M | L | Phase 1 verification runs `nix flake check` plus a local `nix develop -c statix check` / `nix develop -c deadnix .` before Phase 2 relies on the devShell. |
| Accidentally reference deprecated `nixfmt-rfc-style` | L | L | Plan and phase tasks pin `pkgs.nixfmt` explicitly; comments name both spellings for searchability. |
| CI step mistakenly gates on lint findings | M | L | Both lint steps end in `|| true`; `nix flake check` left untouched as the sole failing step. |
| Format pass reformats task 96 headers unexpectedly | L | L (expected) | Single-line `#` comments are untouched by nixfmt; reformatting task 96's headers is expected and desired per delegation context. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Add formatter and devShell to flake.nix [COMPLETED]

**Goal**: Additively expose a `nix fmt` formatter and a `nix develop` shell with
`nixfmt`/`statix`/`deadnix`, without touching existing outputs.

**Tasks**:
- [x] Insert two new top-level keys into the `outputs` returned attrset, after
  `homeConfigurations` and before the final closing `};`:
  - `formatter.${system} = pkgs.nixfmt;`
  - `devShells.${system}.default = pkgs.mkShellNoCC { packages = [ pkgs.nixfmt pkgs.statix pkgs.deadnix ]; };`
- [x] Add a short comment above `formatter` noting `pkgs.nixfmt` is the RFC 166 official
  formatter (formerly `nixfmt-rfc-style`, now a deprecated alias) so a reader searching for
  either name finds the attribute.
- [x] Confirm `pkgs` (the stable overlay-applied set, ~line 76) is in scope and used as the
  package source; do not introduce a new package set.

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `flake.nix` - add `formatter.${system}` and `devShells.${system}.default` (additive only).

**Verification**:
- `nix flake check` succeeds (no evaluation errors, no `nixfmt-rfc-style` deprecation
  warning in output).
- `nix develop --command statix --version` and `nix develop --command deadnix --version`
  both resolve (devShell evaluates and exposes the tools).
- `nix fmt --help` resolves via `nix eval .#formatter.${system}` / `nix flake show`
  listing the formatter output.

---

### Phase 2: Add non-blocking statix + deadnix CI steps [COMPLETED]

**Goal**: Report statix/deadnix findings in CI without gating, keeping `nix flake check` as
the only hard gate.

**Tasks**:
- [x] Append two steps to the existing `flake-check` job in `.github/workflows/ci.yml`,
  after the `nix flake check` step:
  - `- name: statix (non-blocking)` / `run: nix develop --command statix check || true`
  - `- name: deadnix (non-blocking)` / `run: nix develop --command deadnix . || true`
- [x] Do NOT add a new job, matrix, separate workflow file, `continue-on-error`, or any
  config file — reuse the existing checkout/install-nix steps.
- [x] Leave the `nix flake check` step exactly as-is (sole failing step).

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.github/workflows/ci.yml` - add two `|| true` lint steps to the single existing job.

**Verification**:
- YAML is valid (e.g. `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))"` or equivalent parse).
- The two lint `run:` lines end in `|| true`; `nix flake check` line is unchanged.
- Locally, `nix develop --command statix check || true` and
  `nix develop --command deadnix . || true` both exit 0 regardless of findings (mirrors CI).

---

### Phase 3: Apply whole-tree nix fmt format pass [COMPLETED]

**Goal**: Bring all 80 `.nix` files into conformance with `nixfmt` in a single, isolated,
mechanical commit (this is the large, expected, bounded diff — kept LAST and separate from
the Phase 1/2 tooling edits).

**Tasks**:
- [x] Run `nix fmt` at the repo root to reformat the whole tree (formats all `.nix` files,
  including `flake.nix` itself and task 96's now-committed `packages/*.nix` headers).
  *(altered: bare `nix fmt .` failed — it recursively traverses the gitignored `./result`
  build-output symlink into the Nix store and hit an unrelated deeply-nested/broken
  symlink chain in a store path, aborting before formatting anything. Worked around by
  running `nix fmt $(git ls-files '*.nix')` — the exact 80 tracked `.nix` files — instead
  of passing `.`. Also hit `setOwnerAndGroup: permission denied` on
  `hosts/{garuda,nandi,usb-installer}/hardware-configuration.nix`, which carried a stale
  gid 1000 not resolvable to any group on this machine (nixfmt's atomic write tries to
  preserve the original group); fixed by `chgrp users` on those 3 files before retrying.
  Both workarounds are environment-recovery, not scope changes — see task 100 tracking
  the `./result` gitignore/nixfmt-tree follow-up.)*
- [x] Review the diff scope (expected ~47 files changed, 33 already-conforming files
  untouched, 0 parse errors) — confirm it is formatting-only. Confirmed: exactly 47 files
  changed (1214 insertions / 926 deletions), 0 parse errors.
- [x] Do NOT fix any statix/deadnix warnings surfaced during this phase — formatting only.
  Confirmed: no lint fixes applied, only nixfmt output accepted.
- [ ] Commit this format pass as its own dedicated commit, separate from Phase 1/2.
  *(deviation: skipped — orchestrator_mode is true for this run; the agent stages all
  Phase 1-3 changes via `git add` only and leaves the commit(s) to the orchestrator's
  postflight, per the delegation context.)*

**Timing**: 30 minutes (mostly review of a large mechanical diff)

**Depends on**: 1, 2

**Files to modify**:
- All non-conforming `.nix` files across the tree (approx. 47 of 80), reformatted by
  `nixfmt` via `nix fmt`. This is a formatting-only change; no semantic edits.

**Verification**:
- Run `nix fmt`, then `nixfmt --check .` reports zero files needing reformatting (or
  equivalently `git diff --stat` shows only the format-pass files and no further changes on
  a second `nix fmt` run — idempotent).
- `nix flake check` still succeeds after the format pass.
- Note: the diff is large by design; a large `git diff --stat` here is expected, not a
  defect.

## Testing & Validation

- [x] `nix flake check` passes after Phase 1 and again after Phase 3.
- [x] `nix develop --command statix check` and `nix develop --command deadnix .` run from
  the new devShell (findings are informational, not gating). statix found 33 warnings
  (exit 1), deadnix found findings (exit 0); both are expected and left unfixed per
  Non-Goals — CI wraps both in `|| true`.
- [x] `.github/workflows/ci.yml` parses as valid YAML; both lint steps are `|| true`;
  `nix flake check` remains the sole hard gate.
- [x] After `nix fmt`, `nixfmt --check .` (run as `nix fmt -- --check $(git ls-files
  '*.nix')`, see Phase 3 deviation note) reports no remaining files to reformat; a second
  `nix fmt` is a no-op (idempotent).
- [x] No `pkgs.nixfmt-rfc-style` code reference exists in `flake.nix` (only the intentional
  searchability comment naming the deprecated alias, per Phase 1 task); no deprecation
  warning in `nix flake check` output.

## Artifacts & Outputs

- `flake.nix` - `formatter.${system}` + `devShells.${system}.default` (Phase 1).
- `.github/workflows/ci.yml` - two non-blocking lint steps (Phase 2).
- Whole-tree `nix fmt` reformatting diff (Phase 3).
- `specs/098_nix_formatter_lint_tooling/summaries/01_formatter-lint-tooling-summary.md`
  (produced by /implement).

## Rollback/Contingency

- Phases 1 and 2 are additive and independently revertible via `git revert` of their
  respective commits (no existing outputs or steps are modified).
- Phase 3 is a formatting-only commit; if the large diff is undesirable it can be reverted
  in isolation with `git revert` without affecting the Phase 1/2 tooling additions.
- If the devShell fails to evaluate in CI (Phase 2), revert Phase 2 only; Phase 1's
  `formatter` output remains usable via `nix fmt` locally.

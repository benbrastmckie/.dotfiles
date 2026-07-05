# Implementation Plan: Task #84 - Add `nix flake check` CI Gate

- **Task**: 84 - Add a `nix flake check` GitHub Actions CI gate to the NixOS/Home Manager dotfiles repo
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/084_nix_flake_check_ci_gate/.orchestrator-handoff.json (research-phase handoff; no standalone report file)
- **Artifacts**: plans/01_ci-flake-check-gate.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Add a single GitHub Actions workflow (`.github/workflows/ci.yml`) that runs `nix flake check`
on every push and pull request, providing an automated evaluation gate for the dotfiles flake.
The flake exports only `nixosConfigurations` + `homeConfigurations` (no `packages`/`devShells`/
`checks`), so `nix flake check` is evaluation-only (~33s warm, currently passing locally) — no
build step and no binary cache are needed. The repo is a public GitHub repo, so Actions minutes
are free and unlimited. Definition of done: the workflow file exists, is valid YAML, local
`nix flake check` still passes, and the first CI run on the pushed branch reports green.

### Research Integration

Research conclusions carried directly from the handoff (`.orchestrator-handoff.json`):
- No `.github/` directory exists yet; remote is `git@github.com:benbrastmckie/.dotfiles.git`
  (confirmed public → free unlimited Actions minutes).
- Use `cachix/install-nix-action@v31`, NOT `DeterminateSystems/nix-installer-action` (which now
  defaults to Determinate Nix, diverging from the upstream Nix 2.34.7 this machine runs).
- Skip any binary-cache action (`magic-nix-cache-action`): eval-only flake has nothing to cache,
  and that action has an unstable maintenance history.
- No mandatory local pre-commit hook (conflicts with the repo's frequent-green-commit cadence);
  at most an OPTIONAL opt-in pre-push hook, documented in the README.
- Triggers: `push` and `pull_request` with no branch filter.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` exists but no `roadmap_flag` was passed to this planning run, so no roadmap
review/update phases are included. This task advances the CI/backstop item from the task-81
target layout (subtask 3: CI gate). The `/todo` completion step may annotate ROADMAP.md via the
task's `roadmap_items`; that is out of scope for this plan.

## Goals & Non-Goals

**Goals**:
- Create `.github/workflows/ci.yml` running `nix flake check` on push and pull_request.
- Use `cachix/install-nix-action@v31` + `actions/checkout@v7`, with a concurrency group that
  cancels superseded in-flight runs.
- Verify locally that `nix flake check` still passes and the workflow is syntactically valid YAML
  BEFORE committing, staging the new file with a specific-path `git add`.
- Document an OPTIONAL, opt-in pre-push hook in the README (not installed by default).
- Confirm the first CI run on the pushed branch is green.

**Non-Goals**:
- No mandatory/blocking local pre-commit or pre-push hook installed into the repo.
- No binary-cache action, no `nixos-rebuild`/`home-manager build` in CI (eval-only gate).
- No matrix builds, no scheduled runs, no branch-protection rule changes (GitHub UI, out of scope).
- No change to flake outputs or existing Nix configuration.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| CI installs Determinate Nix and diverges from local upstream Nix | M | L | Pin `cachix/install-nix-action@v31`; explicitly avoid `DeterminateSystems/nix-installer-action` |
| `nix flake check` needs private inputs / auth in CI | M | L | Pass `github_access_token: ${{ secrets.GITHUB_TOKEN }}` to the installer to raise the GitHub API rate limit for flake-input fetches |
| YAML indentation error silently disables the workflow | M | L | Validate YAML locally (Phase 2) before commit; confirm run appears in Actions after push |
| Over-staging unrelated working-tree edits on commit | L | M | Stage only `.github/workflows/ci.yml` (and README in its own phase) via specific-path `git add`; never `git add -A` |
| First CI run fails due to an eval issue not seen locally | M | L | Local `nix flake check` is confirmed green; Phase 4 inspects the run and fixes forward if red |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Author the CI workflow file [COMPLETED]

**Goal**: Create the `.github/` directory tree and write the `nix flake check` workflow.

**Tasks**:
- [x] Create directory `.github/workflows/` (does not yet exist).
- [x] Write `.github/workflows/ci.yml` with:
  - `name: nix-flake-check`
  - Triggers `on: push` and `on: pull_request` (no branch filter).
  - A `concurrency` block: `group: ${{ github.workflow }}-${{ github.ref }}`, `cancel-in-progress: true`.
  - Job `flake-check` on `runs-on: ubuntu-latest` with steps:
    - `actions/checkout@v7`
    - `cachix/install-nix-action@v31` with `github_access_token: ${{ secrets.GITHUB_TOKEN }}`
    - `run: nix flake check`

**Timing**: 20 min

**Depends on**: none

**Files to modify**:
- `.github/workflows/ci.yml` (create) - the CI workflow, exactly matching the researched template.

**Verification**:
- File exists at `.github/workflows/ci.yml` and is non-empty.
- Content matches the researched action versions (`checkout@v7`, `install-nix-action@v31`).

### Phase 2: Local verification and staging [COMPLETED]

**Goal**: Confirm the flake still evaluates green and the workflow is valid YAML, then stage the
new file with a specific-path `git add` (the critical cross-cutting protocol).

**Tasks**:
- [x] Run `nix flake check` locally and confirm it passes (expected ~33s warm). *(actual: 33.159s, all checks passed)*
- [x] Validate `.github/workflows/ci.yml` is syntactically valid YAML (e.g.
  `nix run nixpkgs#yq -- . .github/workflows/ci.yml`, or `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))"`).
- [x] Stage ONLY the workflow file: `git add .github/workflows/ci.yml` (specific path; never
  `git add -A` / `git commit -am`).
- [x] Confirm staged scope with `git status --short` and `git diff --staged`.

**Timing**: 15 min

**Depends on**: 1

**Files to modify**:
- None (verification + staging only).

**Verification**:
- `nix flake check` exits 0.
- YAML parser loads the file without error.
- `git status --short` shows only `.github/workflows/ci.yml` staged.

### Phase 3: Document the optional opt-in pre-push hook [COMPLETED]

**Goal**: Add a short README subsection describing an OPTIONAL, opt-in local pre-push hook that
runs `nix flake check`, explicitly noting it is not installed by default and does not conflict
with the repo's frequent-commit cadence.

**Tasks**:
- [x] Add a subsection under the README `## Maintenance` section (README.md currently has
  `### Full Update`, `### Manual Rebuilds` under it) titled e.g. `### Optional: local flake-check hook`.
- [x] Describe the CI gate briefly and provide the opt-in `.git/hooks/pre-push` snippet running
  `nix flake check`, with a clear statement that it is optional and that CI is the authoritative gate.
- [x] Stage ONLY `README.md`: `git add README.md`.

**Timing**: 20 min

**Depends on**: 1

**Files to modify**:
- `README.md` (edit) - add the optional pre-push hook documentation subsection under `## Maintenance`.

**Verification**:
- README renders the new subsection; wording states the hook is optional/opt-in and CI is the backstop.
- `git status --short` shows only `README.md` staged for this phase's change.

### Phase 4: Commit, push, and confirm first CI run [NOT STARTED]

**Goal**: Commit the staged changes on a branch, push, and confirm the first Actions run is green.

**Tasks**:
- [ ] If on `master`, create a branch first (e.g. `task-84-ci-flake-check`) per repo git policy. *(deviation: deferred — orchestrator-mode invocation instructs this implementation agent NOT to create the final git commit; the orchestrator commits)*
- [ ] Commit with message `task 84: add nix flake check CI gate` (+ session id in body). *(deviation: deferred to orchestrator commit step)*
- [ ] Push the branch to `origin`. *(deviation: deferred to orchestrator/user — no push performed by this agent)*
- [ ] Confirm the workflow run appears in Actions and reports success — via
  `gh run list --workflow=ci.yml` / `gh run watch`, or the GitHub UI. *(deviation: deferred — cannot confirm until after orchestrator commits and pushes)*
- [ ] If the run is red, inspect the log and fix forward (adjust the workflow), re-verifying locally. *(deviation: deferred — contingent on push happening first)*

**Timing**: 20 min

**Depends on**: 2, 3

**Files to modify**:
- None (commit/push/observe only; fix-forward edits to `.github/workflows/ci.yml` only if the run fails).

**Verification**:
- Commit exists staging only `.github/workflows/ci.yml` + `README.md`.
- The first CI run on the pushed branch completes with a green `flake-check` job.

## Testing & Validation

- [ ] `nix flake check` passes locally before commit (Phase 2).
- [ ] `.github/workflows/ci.yml` parses as valid YAML (Phase 2).
- [ ] Staging scope is exactly the intended files at each commit (Phases 2, 3, 4).
- [ ] First GitHub Actions run on the pushed branch shows the `flake-check` job green (Phase 4).

## Artifacts & Outputs

- `.github/workflows/ci.yml` - the CI workflow (primary deliverable).
- `README.md` - updated with an optional opt-in pre-push hook subsection.
- A green GitHub Actions run on the pushed branch.

## Rollback/Contingency

- The change is additive and isolated: reverting is `git rm .github/workflows/ci.yml` and
  reverting the README subsection, then committing. No existing Nix configuration is touched, so
  removal cannot break local builds or `nixos-rebuild`/`home-manager` flows.
- If the first CI run is red for an environment-specific reason not reproducible locally, fix
  forward on the branch (Phase 4); do not merge to `master` until the run is green.

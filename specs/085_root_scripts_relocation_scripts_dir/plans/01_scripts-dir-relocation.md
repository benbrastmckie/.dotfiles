# Implementation Plan: Task #85 - Relocate root shell scripts into scripts/

- **Task**: 85 - Relocate root shell scripts into a new `scripts/` directory
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: None (task 81 design done, task 82 done, task 83 done)
- **Research Inputs**: specs/085_root_scripts_relocation_scripts_dir/reports/01_scripts-relocation-research.md
- **Artifacts**: plans/01_scripts-dir-relocation.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: nix

## Overview

Move `install.sh`, `update.sh`, and `build-usb-installer.sh` from the repo root into a new
`scripts/` directory via `git mv` (contents unchanged — `update.sh` is already the task-83-fixed
version, move only), then update every **live** documentation reference to these three scripts so
that a repo-wide grep shows only `scripts/`-prefixed paths. Research confirmed the scripts have no
cross-script dependencies and no self-path (`$0`/`$BASH_SOURCE`/`dirname`) logic — all path
resolution is CWD-relative — so the move is safe as long as the scripts continue to be invoked
from the repo root (`./scripts/update.sh`, never `cd scripts && ./update.sh`).

**Definition of done**: `grep -rn` across docs shows only `scripts/`-prefixed paths for these
three scripts (no bare-name invocation refs remain except the intentionally-ignored `flake.nix`
comments); `./scripts/update.sh` and `./scripts/install.sh` execute; `nix flake check` is green;
all moves and doc edits are git-staged before verification.

### Research Integration

Integrates `reports/01_scripts-relocation-research.md`:
- `scripts/` directory confirmed absent — clear to create via `git mv`.
- No cross-script sourcing/calling and no self-path logic (all three CWD-relative). Move is safe.
- `update.sh` already carries task-83's clean `#!/bin/bash` shebang — **move only, do not edit**.
- Complete reference inventory: 3 explicitly-named docs PLUS 8 additional live files (the scope
  gap this plan resolves), PLUS a do-not-touch set (flake.nix comments, `.claude/` false
  positives, historical `specs/` records).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (roadmap flag not set). This task advances task 81 Tier-0 subtask
blueprint row 4 (repo reorganization: `scripts/` directory).

## Goals & Non-Goals

**Goals**:
- Relocate the three scripts into `scripts/` with `git mv` (preserving executable bit + history).
- Update ALL live doc references (the 3 named files + 8 additional live docs) to `scripts/`-prefix.
- Resolve the scope gap so the task's "no doc goes stale" intent holds repo-wide.
- Keep every change git-staged before verification (flake `root = self` visibility requirement).

**Non-Goals**:
- Editing script contents (shebang/logic) — `update.sh` is already fixed; this is a pure move.
- Touching `flake.nix`'s two bare-name comment mentions (inert, not Nix-evaluated).
- Touching `.claude/` false-positive `install.sh` hits (unrelated third-party installers).
- Rewriting historical `specs/` task records (point-in-time, remain accurate as written).
- The final commit — the orchestrator owns commit; this plan stages only.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Unstaged move: flake `root = self` makes Nix see only git-tracked content — an unstaged `mv` looks like stale-success or "file not found" | H | M | Use `git mv` (auto-stages both sides). For doc edits, `git add <specific paths>` before verification. NEVER `git add -A`. |
| Concurrent task 92 commits/sweeps in this repo | M | M | Keep the staged window small; stage work-scoped paths only; orchestrator owns the final commit. Never `git add -A`/`git commit -am`. |
| Doc scope gap — 8 live files outside the named 3 go stale after the move | H | H (confirmed by grep) | Phase 3 explicitly updates all 8; Phase 4 re-greps repo-wide to catch any miss. |
| Running a moved script from wrong CWD breaks `.#$HOSTNAME` flake ref / build-usb guard | L | L | Pre-existing CWD-relative behavior, not new. Verify by running from repo root only. |
| A reference the research missed remains bare-name | M | L | Phase 4 re-greps at implementation time (definition-of-done gate), not just trusting the inventory. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Baseline grep and move scripts into scripts/ [NOT STARTED]

- **Goal:** Capture a pre-move reference baseline, then relocate all three scripts with `git mv`.
- **Tasks:**
  - [ ] Run baseline inventory: `grep -rn -e 'install\.sh' -e 'update\.sh' -e 'build-usb-installer\.sh' . --exclude-dir=.git` and confirm it matches the research inventory (flag any NEW hits the research missed for handling in Phases 2-3).
  - [ ] Confirm `scripts/` is still absent: `ls scripts 2>/dev/null` (expect not found).
  - [ ] `git mv install.sh scripts/install.sh`
  - [ ] `git mv update.sh scripts/update.sh`
  - [ ] `git mv build-usb-installer.sh scripts/build-usb-installer.sh`
  - [ ] Confirm staging + executable bit preserved: `git status --short` shows renames; `git ls-files -s scripts/` shows mode `100755` for all three.
  - [ ] Do NOT edit any script contents (update.sh already carries task-83's fix).
- **Timing:** ~15 min
- **Depends on:** none
- **Files to modify:**
  - `install.sh` -> `scripts/install.sh` (move only)
  - `update.sh` -> `scripts/update.sh` (move only)
  - `build-usb-installer.sh` -> `scripts/build-usb-installer.sh` (move only)
- **Verification:** `git status --short` shows three `R` (rename) entries; `ls scripts/` lists all three; `git ls-files -s scripts/` shows executable mode.

### Phase 2: Update the three explicitly-named docs [NOT STARTED]

- **Goal:** Update all script references in the docs the task explicitly names.
- **Tasks:**
  - [ ] `README.md` (root): change `./update.sh` invocations (lines ~119, 188, 197) to `./scripts/update.sh`; normalize bare-name prose mentions to `scripts/update.sh` for consistency. (No `install.sh`/`build-usb-installer.sh` refs here.)
  - [ ] `docs/testing.md`: update all 4 `update.sh` refs (lines ~14, 90, 123, 126: `./update.sh --no-check`, `./update.sh`, prose "The update.sh script...", comment `# In update.sh`) to `scripts/`-prefixed form.
  - [ ] `docs/usb-installer.md`: update all 4 `update.sh` refs and 2 `build-usb-installer.sh` refs (lines ~453, 493, 632, 672, 755, 756) to `scripts/`-prefixed form. Leave line ~65-style doc pointers to `docs/usb-installer.md` itself untouched (that doc is not moving).
- **Timing:** ~15 min
- **Depends on:** 1
- **Files to modify:**
  - `README.md` - `./update.sh` -> `./scripts/update.sh`
  - `docs/testing.md` - 4x `update.sh` -> `scripts/`-prefixed
  - `docs/usb-installer.md` - 4x `update.sh` + 2x `build-usb-installer.sh` -> `scripts/`-prefixed
- **Verification:** `grep -n 'update\.sh\|build-usb-installer\.sh' README.md docs/testing.md docs/usb-installer.md` shows only `scripts/`-prefixed paths.

### Phase 3: Update the 8 additional live docs (resolve scope gap) [NOT STARTED]

- **Goal:** Update every live doc reference outside the named 3 so no doc goes stale repo-wide.
- **Tasks:**
  - [ ] `docs/installation.md` (lines ~30, 45, 62, 63): update 3x `./update.sh` invocations AND the `install.sh` "Scripts" table entry to `scripts/`-prefixed form. **This is the only live doc referencing `install.sh`.**
  - [ ] `docs/dual-home-manager.md` (lines ~12, 25, 29, 49, 58, 64, 85): normalize 7x bare-name `update.sh` prose mentions to `scripts/update.sh`.
  - [ ] `docs/development.md` (line ~71): `~/.dotfiles/update.sh` -> `~/.dotfiles/scripts/update.sh`.
  - [ ] `docs/unstable-packages.md` (lines ~89, 112): update comment `# In update.sh` and invocation `./update.sh` to `scripts/`-prefixed form.
  - [ ] `docs/README.md` (line ~49): `./update.sh` -> `./scripts/update.sh`.
  - [ ] `packages/README.md` (line ~35): prose `./update.sh` -> `./scripts/update.sh`.
  - [ ] `docs/ryzen-ai-300-support-summary.md` (line ~71): `./build-usb-installer.sh` (after `cd ~/.dotfiles`) -> `./scripts/build-usb-installer.sh`.
  - [ ] `hosts/README.md` (line ~46): `./update.sh` -> `./scripts/update.sh`.
  - [ ] `hosts/nandi/README.md` (line ~24): `./update.sh` -> `./scripts/update.sh`.
  - [ ] Include any NEW live hits surfaced by the Phase 1 baseline grep that are not in this list.
  - [ ] Do NOT touch: `flake.nix` comment mentions, `.claude/` false-positive `install.sh` hits, or any `specs/` historical records.
- **Timing:** ~20 min
- **Depends on:** 1
- **Files to modify:**
  - `docs/installation.md`, `docs/dual-home-manager.md`, `docs/development.md`,
    `docs/unstable-packages.md`, `docs/README.md`, `packages/README.md`,
    `docs/ryzen-ai-300-support-summary.md`, `hosts/README.md`, `hosts/nandi/README.md`
- **Verification:** `grep -n` on each file shows only `scripts/`-prefixed paths for the three scripts.

### Phase 4: Stage doc edits, re-grep, and verify [NOT STARTED]

- **Goal:** Stage all doc edits (scripts already staged by `git mv`), then satisfy the full
  definition-of-done: repo-wide grep clean, scripts run, flake check green.
- **Tasks:**
  - [ ] Stage doc edits with explicit paths (NEVER `git add -A`): `git add README.md docs/testing.md docs/usb-installer.md docs/installation.md docs/dual-home-manager.md docs/development.md docs/unstable-packages.md docs/README.md packages/README.md docs/ryzen-ai-300-support-summary.md hosts/README.md hosts/nandi/README.md` (plus this plan file and any Phase-1-discovered extra files).
  - [ ] Confirm the staged set: `git status --short` and `git diff --staged --stat` — verify no stray/concurrent (task 92) files are staged.
  - [ ] Repo-wide definition-of-done grep: `grep -rn -e 'install\.sh' -e 'update\.sh' -e 'build-usb-installer\.sh' . --exclude-dir=.git`. Confirm every remaining bare-name hit is one of the intentionally-ignored set only (flake.nix comments, `.claude/` third-party installers, `specs/` history). Every live doc reference must show `scripts/`.
  - [ ] Execute from repo root (NOT from inside `scripts/`): `./scripts/update.sh` (or `bash scripts/update.sh`) and `./scripts/install.sh` — confirm they run (or at minimum resolve/execute the flake ref correctly; abort before any actual system switch if running interactively).
  - [ ] `nix flake check` — confirm green (scripts are not Nix-evaluated; this guards against accidental breakage from the move).
  - [ ] Report the final staged file list to the orchestrator. Do NOT commit — the orchestrator owns the final commit (concurrent task 92 in this repo).
- **Timing:** ~15 min
- **Depends on:** 2, 3
- **Files to modify:** none (staging + verification only)
- **Verification:** repo-wide grep shows only `scripts/`-prefixed live refs; both scripts execute from repo root; `nix flake check` green; staged set is work-scoped only.

## Testing & Validation

- [ ] `git ls-files scripts/` lists exactly the three moved scripts with mode `100755`.
- [ ] `grep -rn -e 'install\.sh' -e 'update\.sh' -e 'build-usb-installer\.sh' . --exclude-dir=.git` shows no bare-name **live doc** references (only flake.nix comments, `.claude/` false positives, and `specs/` history remain).
- [ ] `./scripts/update.sh` and `./scripts/install.sh` execute from the repo root.
- [ ] `nix flake check` is green.
- [ ] Staged set contains only task-85 work-scoped files (no task-92 stray files).

## Artifacts & Outputs

- `scripts/install.sh`, `scripts/update.sh`, `scripts/build-usb-installer.sh` (moved)
- Updated docs: `README.md`, `docs/testing.md`, `docs/usb-installer.md`, `docs/installation.md`,
  `docs/dual-home-manager.md`, `docs/development.md`, `docs/unstable-packages.md`,
  `docs/README.md`, `packages/README.md`, `docs/ryzen-ai-300-support-summary.md`,
  `hosts/README.md`, `hosts/nandi/README.md`
- `plans/01_scripts-dir-relocation.md` (this file)
- `summaries/01_scripts-dir-relocation-summary.md` (on implementation)

## Rollback/Contingency

- The move is a pure `git mv` + text edits with no logic changes. To revert before commit:
  `git restore --staged <paths>` to unstage, then reverse-`git mv` the three scripts back to root
  and `git checkout -- <doc paths>` (only if the working tree is otherwise clean — respect the
  "No Destructive Git on Uncommitted Work" rule; snapshot first if the tree is dirty).
- If `nix flake check` unexpectedly fails, the scripts are not Nix inputs — investigate whether an
  unstaged move (flake `root = self` visibility) is the cause before touching script contents;
  re-stage with `git mv`/`git add <paths>` and re-check.

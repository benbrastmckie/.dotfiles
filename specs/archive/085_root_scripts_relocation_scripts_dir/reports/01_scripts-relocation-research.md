# Research Report: Task #85

**Task**: 85 - Relocate root shell scripts into a new `scripts/` directory
**Started**: 2026-07-04
**Completed**: 2026-07-04
**Effort**: Small (mechanical `git mv` + doc-reference text edits, no logic changes)
**Dependencies**: Task 81 (design, done), Task 82 (deleted test-sasl.sh, done), Task 83 (fixed update.sh shebang in place, done — this task moves the already-fixed file)
**Sources/Inputs**: Full-repo grep (all tracked files, `.git` excluded), direct reads of `install.sh`, `update.sh`, `build-usb-installer.sh`, and every doc file that mentions them; task 81 seed reports and target-layout.md
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `scripts/` does not exist yet at repo root — clear to create.
- None of the three scripts reference each other (no sourcing, no one script calling another) and none use `$(dirname "$0")`/self-path tricks — all three resolve paths relative to the **current working directory**, not their own location. As long as they continue to be invoked from the repo root (`./scripts/update.sh`, `./scripts/install.sh`, `./scripts/build-usb-installer.sh`), moving them into `scripts/` breaks nothing internally.
- `update.sh` is already fixed in place (clean `#!/bin/bash` shebang, task 83) — confirmed by direct read; just move it, don't re-fix it.
- The task's explicit scope is 3 doc files (root `README.md`, `docs/testing.md`, `docs/usb-installer.md`). A full-repo grep found **8 additional live (non-historical) files** with invocation-style references to these scripts that are NOT in that list and will go stale unless a follow-up subtask handles them — most notably `docs/installation.md`, which is the only file containing a live reference to `install.sh` at all.
- `flake.nix` has two prose comments mentioning `update.sh` by bare name (no path) — these are not invocation paths and are not consumed by Nix evaluation; they don't need touching for build correctness, but could optionally be left as-is since "update.sh runs both" remains true regardless of the script's directory.

## Context & Scope

Task 85 moves `install.sh`, `update.sh`, `build-usb-installer.sh` from repo root into a new `scripts/` directory, and updates references to them in root `README.md`, `docs/testing.md`, and `docs/usb-installer.md` — the three files the task description explicitly names. `test-sasl.sh` was already deleted (task 82) and is out of scope. `update.sh`'s shebang/stray-backslash bugs were already fixed in place (task 83); this task moves the corrected file, it does not re-fix it.

Verification bar (per task and design doc §2 row 5 / §3 row 4): build-only inertness — `grep` across docs shows only `scripts/`-prefixed paths for these three scripts, `./scripts/update.sh` and `./scripts/install.sh` run, `nix flake check` stays green.

## Findings

### 1. `scripts/` directory does not exist

```
$ ls /home/benjamin/.dotfiles/scripts
ls: cannot access '/home/benjamin/.dotfiles/scripts': No such file or directory
```
Confirmed clear to create.

### 2. Script file status (source of truth read directly, not from stale docs)

| Script | Mode | Tracked | Notes |
|---|---|---|---|
| `install.sh` | `-rwxr-xr-x` | yes | 25 lines. No shebang issues. |
| `update.sh` | `-rwxr-xr-x` | yes | 56 lines. **Confirmed** clean `#!/bin/bash` shebang and clean `echo "===> Dotfiles update complete!"` (no stray `\!`) — task 83's in-place fix is present in the current working tree. This task moves the already-fixed version; no further shebang work needed. |
| `build-usb-installer.sh` | `-rwxr-xr-x` | yes | 65 lines, `#!/usr/bin/env bash` + `set -euo pipefail`. |

### 3. Cross-script references and path assumptions (item 2 of the research ask)

Read all three scripts in full. Findings:

- **No script sources or calls another script.** `update.sh` does not call `install.sh` or vice versa; `build-usb-installer.sh` does not call either of the other two. There is no `source`/`.`/`bash <other-script>` invocation anywhere.
- **No self-path resolution.** None of the three scripts use `$(dirname "$0")`, `$BASH_SOURCE`, `realpath "$0"`, or similar. This means they have no baked-in assumption about *where on disk* they live — they only assume things about the **caller's current working directory**:
  - `install.sh` and `update.sh` both invoke `nixos-rebuild switch --flake .#$HOSTNAME` and `home-manager switch --flake .#benjamin` — the `.#...` flake ref resolves `.` against CWD, not script location.
  - `update.sh` also runs `git diff-index --quiet HEAD --`, `git add -A`, `git commit` for its auto-checkpoint feature — these git commands also operate relative to CWD (or more precisely, git repo root, found by walking up from CWD — safe either way since the repo root doesn't move).
  - `build-usb-installer.sh` explicitly guards on CWD: `if [[ ! -f "flake.nix" ]]; then echo "Error: run from dotfiles root directory"; exit 1; fi` and `if [[ ! -d "hosts/usb-installer" ]]; then ...`. Both checks are CWD-relative. It also invokes `nix build .#nixosConfigurations.usb-installer...` (CWD-relative flake ref) and writes to `result/iso/...` (CWD-relative build output symlink).
- **Conclusion**: moving all three into `scripts/` is safe for their internal logic *provided they continue to be invoked from the repo root* (e.g. `./scripts/update.sh`, `./scripts/install.sh`, `./scripts/build-usb-installer.sh`, or `bash scripts/update.sh` from repo root) — which matches the task's own verification commands (`./scripts/update.sh`, `./scripts/install.sh`). Do **not** `cd` into `scripts/` before running them. No code changes are needed inside the scripts themselves for the move to work — this is a pure file relocation plus doc-text updates.
- One informational, not functional, detail: `build-usb-installer.sh` line 65 prints `"📖 For detailed instructions, see: docs/usb-installer.md"` — this is a static doc pointer in an echo string, not a path used by the script; `docs/usb-installer.md` itself isn't moving, so this string stays correct as-is.

### 4. Complete reference inventory (item 1 of the research ask)

Full-repo grep for `install\.sh`, `update\.sh`, `build-usb-installer\.sh` (excluding `.git`). Results grouped by whether the file is in the task's explicit update scope, a live doc outside that scope, or historical/generated content that should NOT be touched.

#### In explicit task scope — MUST update these references

| File | Lines | Script(s) referenced | Action |
|---|---|---|---|
| `README.md` (root) | 119, 188, 197 | `update.sh` (×3, all as `` `./update.sh` `` or bare name in prose) | Change `./update.sh` invocations to `./scripts/update.sh`; prose mentions ("`update.sh` runs...") can stay bare-name or be updated to `scripts/update.sh` for consistency. **No `install.sh` or `build-usb-installer.sh` references exist in README.md** — nothing to do for those two scripts here. |
| `docs/testing.md` | 14, 90, 123, 126 | `update.sh` (×4: `./update.sh --no-check`, `./update.sh`, prose "The update.sh script...", comment `# In update.sh`) | Update all four to `scripts/`-prefixed form. No `install.sh`/`build-usb-installer.sh` refs in this file. |
| `docs/usb-installer.md` | 453, 493, 632, 672, 755, 756 | `update.sh` (×4) and `build-usb-installer.sh` (×2: line 672 `./build-usb-installer.sh`, line 756 `./build-usb-installer.sh  # Build new ISO`) | Update all six to `scripts/`-prefixed form. No `install.sh` refs in this file. |

Note: **`install.sh` has zero references in any of the three explicitly-scoped files.** The task 81 review report's claim that `install.sh` is "unreferenced by docs" is true *for these three files* but not true repo-wide (see next table) — `docs/installation.md` does reference it.

#### Live docs OUTSIDE the task's explicit scope — will go stale if not also handled

These are real, currently-accurate invocation-style references that the task description does not list. If task 85 only edits the 3 named files, these will silently become incorrect (pointing at a path that no longer exists at repo root) immediately after the move:

| File | Line(s) | Script(s) | Reference type |
|---|---|---|---|
| `docs/installation.md` | 30, 45, 62, 63 | `update.sh` (×3), `install.sh` (×1, "`- **install.sh**: Automated installation script`") | Invocation (`./update.sh`) + a "Scripts" reference table entry for both scripts. **This is the only live doc anywhere referencing `install.sh` by name/path.** |
| `docs/dual-home-manager.md` | 12, 25, 29, 49, 58, 64, 85 | `update.sh` (×7) | All prose/bare-name mentions (no `./` prefix), e.g. "`update.sh` runs both", "`update.sh` — Runs both..." — not invocation paths, lower urgency but still describes the script by its old bare name in a doc that's otherwise precise about paths. |
| `docs/development.md` | 71 | `update.sh` | Invocation: `~/.dotfiles/update.sh` (absolute-from-home path) |
| `docs/unstable-packages.md` | 89, 112 | `update.sh` | Comment `# In update.sh` + invocation `./update.sh` |
| `docs/README.md` | 49 | `update.sh` | Invocation: `` `./update.sh` `` |
| `packages/README.md` | 35 | `update.sh` | Prose: "...or `./update.sh`" |
| `docs/ryzen-ai-300-support-summary.md` | 71 | `build-usb-installer.sh` | Invocation: `./build-usb-installer.sh` (after `cd ~/.dotfiles`) |
| `hosts/README.md` | 46 | `update.sh` | Invocation: `./update.sh` |
| `hosts/nandi/README.md` | 24 | `update.sh` | Invocation: `./update.sh` |

**Recommendation**: flag this gap explicitly to the orchestrator/planner. Either (a) expand this subtask's doc list to cover all of the above (safest, avoids stale docs, still a same-subtask mechanical text edit), or (b) file it as an immediate task-85-adjacent follow-up so the "no doc goes stale" intent in the task description is actually honored repo-wide, not just for the 3 named files. The task's own verification command as literally stated (`grep` across "docs" showing only `scripts/`-prefixed paths) is ambiguous about whether it means all of `docs/` or just the 3 named files — a repo-wide `grep -rn 'install\.sh\|update\.sh\|build-usb-installer\.sh' docs/ README.md hosts/` would still show hits in `docs/installation.md`, `docs/dual-home-manager.md`, `docs/development.md`, `docs/unstable-packages.md`, `docs/README.md`, `docs/ryzen-ai-300-support-summary.md`, `hosts/README.md`, `hosts/nandi/README.md` if only the 3 named files are edited.

#### Not doc references — do not touch

| File | Lines | Note |
|---|---|---|
| `flake.nix` | 104, 192 | Comments mentioning `update.sh` by bare name only (no path), e.g. "`update.sh` runs both ... in sequence". Not consumed by Nix evaluation (confirmed: these are `#`-prefixed Nix comments). Not an invocation path, so not technically "stale" after the move — optional cosmetic touch-up only, not required for `nix flake check` or correctness. |
| `packages/README.md` line 35 | prose, see table above | (Already listed above — kept for completeness, it's the borderline "mention, not path" case.) |
| `.claude/scripts/check-extension-docs.sh:331`, `.claude/docs/guides/user-installation.md:40` | — | False positives: refer to unrelated third-party `install.sh` scripts (`astral.sh/uv/install.sh`, `elan-init.sh`, Claude Code's own installer curl), not this repo's `install.sh`. Confirmed by reading surrounding context. No action. |
| `specs/**` (all `.orchestrator-handoff.json`, `.return-meta.json`, `reports/`, `plans/`, `summaries/`, `TODO.md`, `state.json`) | many | Historical task records (tasks 60, 61, 66, 74, 81, 83) and the current task's own state entries. These describe past/current work and reference the scripts as they existed at time of writing (including task 81's design docs that *specify* this very move). They are point-in-time records, not living documentation — do not edit them to reflect the post-move path; they remain historically accurate as written. `opencode-discord-bot/` — confirmed no references at all. |

### 5. Hardcoded self-path assumptions (item 4 of the research ask)

None found. As detailed in §3, no script hardcodes its own filesystem location or the repo's absolute location, except:
- `build-usb-installer.sh`'s CWD guard (`[[ ! -f "flake.nix" ]]`) is a *soundness check*, not a hardcoded path — it will continue to correctly reject wrong-CWD invocations after the move.
- Docs `docs/development.md:71` and `docs/ryzen-ai-300-support-summary.md:71` hardcode `~/.dotfiles/update.sh` and `cd ~/.dotfiles` + `./build-usb-installer.sh` respectively — these are doc-level absolute-from-home invocation examples (out of the task's explicit 3-file scope, see §4) that will need `scripts/` inserted if/when those docs are also updated.

## Decisions

- Treat `update.sh` as already-fixed (task 83) — verified directly via `Read`, not assumed from prior reports. Task 85 must not re-touch its shebang/logic, only its path and doc references.
- Use `git mv install.sh scripts/install.sh`, `git mv update.sh scripts/update.sh`, `git mv build-usb-installer.sh scripts/build-usb-installer.sh` (preserves executable bit and git history) rather than manual `mv` + `git add`/`git rm`.
- Doc edits for `README.md`, `docs/testing.md`, `docs/usb-installer.md`: replace `./update.sh` → `./scripts/update.sh`, `./build-usb-installer.sh` → `./scripts/build-usb-installer.sh`; for bare-name prose mentions without `./`, either leave as-is or normalize to `scripts/update.sh` for consistency (recommend normalizing, since the doc's own code-block invocations will show the `scripts/`-prefixed form and mixed styles in the same doc would read as inconsistent).

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Unstaged `git mv` — `flake.nix`'s `root = self` means Nix only sees git-tracked content; an `mv` without staging looks like a stale success or "file not found" | Medium | Use `git mv` directly (auto-stages both sides), or `git add scripts/<file>` + `git rm <old-path>` if a manual `mv` was used. Never `git add -A`. |
| Doc scope gap — 8 live files outside the task's 3-file list will show stale `install.sh`/`update.sh`/`build-usb-installer.sh` references after the move | High (confirmed via grep) | Surface this finding to planning: either widen this subtask's doc list or schedule an immediate follow-up subtask before task 81's Tier-0 batch is considered fully "no doc goes stale." See §4 table 2. |
| `./scripts/update.sh` invoked with CWD ≠ repo root breaks the `.#$HOSTNAME` flake ref and `build-usb-installer.sh`'s `flake.nix` guard | Low | Scripts already behave this way today (CWD-relative, not new behavior introduced by the move) — document "run from repo root" if not already stated; `docs/testing.md`/`docs/usb-installer.md`'s existing examples already show `cd ~/.dotfiles` before invocation in the USB-installer doc, consistent with this. |
| `nix flake check` regression | Very low | The three scripts are not Nix-evaluated inputs (no `.nix` file executes or reads them); flake.nix's two comment mentions are inert text. Moving the files cannot affect flake evaluation. |

## Appendix

### Search queries used
- `grep -rn -e "install\.sh" -e "update\.sh" -e "build-usb-installer\.sh" . --exclude-dir=.git` (full repo)
- Targeted re-greps scoped to `README.md`, `docs/testing.md`, `docs/usb-installer.md`, `.claude/`, `.nix` files, `hosts/`, `docs/installation.md`, `docs/dual-home-manager.md`, `docs/unstable-packages.md`, `docs/development.md`, `docs/ryzen-ai-300-support-summary.md`, `docs/README.md`, `packages/README.md`, `opencode-discord-bot/`
- Direct `Read` of `install.sh`, `update.sh`, `build-usb-installer.sh` (full contents) to verify no cross-referencing, no self-path logic, and confirm task-83's shebang fix is present
- `ls -la install.sh update.sh build-usb-installer.sh` + `git ls-files` to confirm executable bit and tracked status
- `ls scripts` to confirm the target directory does not yet exist

### References
- `specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md` ("Root files" table, lines 142-144, 180-184)
- `specs/081_reorganize_nixos_dotfiles_repository_design/reports/02_team-research.md` (decision table row for `scripts/`, subtask blueprint row 4)
- `specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md` §1.3 (target layout scripts/ section, lines 61-63), §2 (decision table row 5, line 140), §3 (subtask blueprint row 4, line 168)
- `specs/083_git_hygiene_specs_tmp_nixos_repo/reports/01_git-hygiene-specs-tmp.md` (confirms update.sh fixed in place at root, move deferred to this task)

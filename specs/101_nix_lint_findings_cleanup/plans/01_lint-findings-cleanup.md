# Implementation Plan: Task #101

- **Task**: 101 - Nix lint findings cleanup (clear statix + deadnix findings so the tree is lint-clean)
- **Status**: [NOT STARTED]
- **Effort**: 6 hours
- **Dependencies**: task 98 (nix formatter + statix/deadnix lint tooling), completed
- **Research Inputs**: specs/101_nix_lint_findings_cleanup/reports/01_lint-findings-cleanup.md
- **Artifacts**: plans/01_lint-findings-cleanup.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Drive the repository to a lint-clean state for both `statix` (69 warnings) and `deadnix` (23
findings), leaving only a small, explicitly documented, deliberately-excluded remainder (the four
auto-generated `hosts/*/hardware-configuration.nix` files). Work follows the research report's
verified fix + verification sequence: skip-comment the intentional deadnix keep-set first, then
`deadnix --edit` the safe removals, then `statix fix` the auto-fixable rules, then hand-collapse
the non-excluded `repeated_keys` (W20) findings in difficulty tiers, then add the two path-based
exclusion mechanisms, and finally normalize with `nix fmt` and re-run all linters. The global
invariant is that `nix flake check` (currently green) stays green after every file edit, and the
terminal state is `statix check` and `deadnix` both reporting zero findings modulo the two
documented exclusions.

### Research Integration

Key findings from `reports/01_lint-findings-cleanup.md` integrated into this plan:
- statix: 69 warnings across 4 rule classes. 15 (W10 empty-pattern ×11, W04 manual-inherit ×3,
  W08 useless-parens ×1) are safely auto-fixable via `statix fix` (dry-run diffs inspected). 54
  are W20 `repeated_keys` with `suggestion: null` (no auto-fix) and must be hand-collapsed.
- Of the 54 W20 findings, 12 (3 each in 4 auto-generated `hardware-configuration.nix` files) are
  excluded via a repo-root `statix.toml` `ignore` glob (verified locally: drops those to zero
  without touching other findings, no CI change needed). The remaining 42 are hand-collapsed in
  three difficulty tiers, with `modules/system/desktop.nix` (7 `services.*` + 4 `programs.*`
  non-contiguous occurrences) called out as the single hardest, judgment-heavy file.
- deadnix: 23 findings. 11 safe-to-remove, 8 intentional-signature-convention that get
  `# deadnix: skip` comments (verified pragma placement: line immediately above the flagged
  binding), 4 auto-generated excluded via a `deadnix --exclude` glob in `ci.yml` (deadnix has no
  config-file mechanism).
- W20 collapses are semantically inert: Nix already desugars `a.b = x; a.c = y;` to
  `a = { b = x; c = y; }`, so collapsing is pure re-nesting. The main risk is a stray
  brace/indentation slip during hand-editing, caught by `nix flake check` after each file.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (no roadmap_path / roadmap_flag provided). This task is the
task-98 follow-on that clears the warn-only lint findings task 98 deferred.

## Goals & Non-Goals

**Goals**:
- Reduce `statix check` to zero findings tree-wide (hardware-config excluded via `statix.toml`).
- Reduce `deadnix` to zero findings (hardware-config excluded via CLI `--exclude` glob).
- Preserve evaluated configuration semantics exactly (W20 collapses and deadnix removals must not
  change what the config evaluates to).
- Keep `nix flake check` green throughout, verified after every file edit.
- Add path-based exclusions for the 4 auto-generated `hardware-configuration.nix` files so
  regeneration does not reintroduce churn.

**Non-Goals**:
- Do NOT hand-edit any `hosts/*/hardware-configuration.nix` file (auto-generated; excluded instead).
- Do NOT remove the 8 intentional-convention deadnix bindings (skip-comment them instead).
- Do NOT address the pre-existing top-level `with pkgs;` style question in `packages.nix` (out of
  scope; only the redundant W08 parens are in scope).
- Do NOT tighten the two CI lint steps from non-blocking `|| true` to hard-gating (noted in
  research as a separate future follow-up).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Hand-collapsing a W20 finding introduces a stray brace/semicolon/indent error | H | M | Run `nix flake check` after each file (or small batch); it is currently green (baseline confirmed) |
| `deadnix --edit` run before skip comments are in place deletes an intentional-convention binding | H | M | Sequence skip-comments-first (Phase 1), `--edit`-second (Phase 2); diff-review `--edit` output before commit |
| Collapsing `desktop.nix` / `power.nix` degrades the feature-walkthrough readability or drags unrelated single-use keys into a merged set | M | M | Tier 2 = wrap existing line range and strip prefix (comments keep position); `desktop.nix` gets its own deliberate manual-review phase, never a mechanical script |
| `nix fmt` re-indentation after fixes re-triggers a new statix/deadnix finding | M | L | Run the linters AFTER the final `nix fmt` pass (Phase 8), not before, so any regression is caught pre-completion |
| Regenerating a host's `hardware-configuration.nix` reintroduces excluded findings with shifted line numbers | L | L | Both exclusions match by path glob (`hosts/*/hardware-configuration.nix`), not line number, so they survive regeneration; rationale recorded in commit message |
| `statix fix` re-indentation differs from nixfmt's opinion | L | M | Follow `statix fix` with a `nix fmt` normalization pass (spot in Phase 3, full-tree in Phase 8) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 7 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |
| 7 | 8 | 2, 3, 4, 5, 6, 7 |

Phases within the same wave can execute in parallel. Phase 7 (exclusion config) touches only new
config files (`statix.toml`, `ci.yml`) and no `.nix` source, so it is independent of the edit
chain and may run in parallel with Phase 1; doing it early also makes intermediate `statix check`
runs already exclude the hardware-config files. The core edit phases (1->2->3->4->5->6) are
serialized because they touch overlapping files (`flake.nix`, `home.nix`, `services.nix`,
`xdg.nix`, `boot.nix`, `desktop.nix` each appear in more than one phase) and each must leave
`nix flake check` green before the next begins.

### Phase 1: Add deadnix skip comments to the 8 intentional-convention bindings [COMPLETED]

**Goal**: Protect the 8 keep-set bindings with `# deadnix: skip` comments so the later
`deadnix --edit` pass cannot strip them.

**Tasks**:
- [x] Add `# deadnix: skip` on the line immediately above `{ pkgs, lib, ... }:` in
  `modules/system/boot.nix`, `modules/system/nix.nix`, `modules/system/desktop.nix` (the `lib`
  arg mandated by this repo's `nix.md` standard signature).
- [x] Add `# deadnix: skip` above `overlays/claude-squad.nix:3` (`prev`) and
  `overlays/python-packages.nix:3` (`final`) — overlay `final: prev:` naming mandated by the
  overlay-pattern convention.
- [x] Add `# deadnix: skip` above the two `overridePythonAttrs (old: {...})` callbacks in
  `overlays/python-packages.nix:9,12` (`old`, `old`) — nixpkgs override-callback idiom.
- [x] Add `# deadnix: skip` above `modules/home/services/gmail-oauth2.nix:19` (`config`) — the
  deliberately-dormant module whose live `config` arg keeps the documented one-block revert intact.
- [x] Run `deadnix .` and confirm these 8 findings are now suppressed while the 11 safe-removal
  findings (Phase 2) still report. Verified: `deadnix . -o json` now reports 15 findings (11
  safe-removal + 4 hardware-config), the 8 keep-set bindings no longer appear. `nix flake check`
  stays green.

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `modules/system/boot.nix`, `modules/system/nix.nix`, `modules/system/desktop.nix` - add skip comment above header
- `overlays/claude-squad.nix`, `overlays/python-packages.nix` - add skip comments (3 total in python-packages.nix)
- `modules/home/services/gmail-oauth2.nix` - add skip comment above line 19

**Verification**:
- `nix flake check` stays green (comments are inert).
- `deadnix .` no longer lists the 8 keep-set bindings; the 11 safe-removal findings still appear.

---

### Phase 2: Remove the 11 safe deadnix bindings via `deadnix --edit` [COMPLETED]

**Goal**: Delete the genuinely-unused bindings deadnix flags, without touching the now-skip-marked
keep-set or the excluded hardware-config files.

**Tasks**:
- [x] Run `deadnix --edit --exclude 'hosts/*/hardware-configuration.nix' -- .` (exclude the 4
  auto-generated files so their `pkgs` args are not stripped even before Phase 7's CI flag lands).
  *(deviation: altered — the `--exclude 'glob' -- .` flag ordering did not actually suppress
  editing of the 4 hardware-configuration.nix files in this deadnix version; `--edit` stripped
  their `pkgs` arg too. Detected via post-edit diff review, manually restored all 4 files to
  their pre-edit content via `git show HEAD:<path> > <path>` before continuing. Confirmed the
  correct invocation order for exclusion purposes is `deadnix --exclude 'glob' . ...`
  (positional path immediately after exclude values, flags before positional) — used that order
  for the read-only verification checks in this phase and will use it again for Phase 7/8.)*
- [x] Diff-review the edit: expect removal of `flake.nix:45,49,52` (`lean4`, `utils`, `inputs`
  destructured outputs args), `home.nix:2-5` (`config`, `pkgs`, `pkgs-unstable`, `lectic` -> `_:`
  or reduced signature), and the `lib` args in `packages/aristotle.nix`, `packages/claude-code.nix`,
  `packages/polkit-gnome-agent-wrapper.nix`, `packages/slidev.nix`. Verified: diff matches exactly.
- [x] Confirm the removed `flake.nix` args do NOT remove the `lean4`/`utils` flake *inputs* (those
  stay in `inputs = {...}` and in `flake.lock`); only the dead destructured bindings go. Verified
  via grep: both `lean4 = { url = ...}` and `utils.url = ...` remain in the `inputs` block.

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `flake.nix` - remove 3 dead outputs-header args
- `home.nix` - reduce/empty the function signature
- `packages/aristotle.nix`, `packages/claude-code.nix`, `packages/polkit-gnome-agent-wrapper.nix`, `packages/slidev.nix` - remove unused `lib` arg

**Verification**:
- `nix flake check` stays green. Verified: `all checks passed!`.
- `deadnix --exclude 'hosts/*/hardware-configuration.nix' -- .` reports zero findings (the 8
  keep-set are skip-marked, the 11 safe ones are removed, the 4 auto-generated are excluded).
  Verified (using `deadnix --exclude 'hosts/*/hardware-configuration.nix' . -o json`, the working
  flag order): TOTAL 0.

---

### Phase 3: Apply the 15 auto-fixable statix findings via `statix fix` [COMPLETED]

**Goal**: Clear the three auto-fixable rule classes (W10 empty-pattern ×11, W04 manual-inherit ×3,
W08 useless-parens ×1) mechanically.

**Tasks**:
- [x] Run `statix fix` on the tree.
- [x] Diff-review against the dry-run expectations in the research report: W10 `{ ... }:` -> `_:`
  in the 11 module headers; W04 `lib = nixpkgs.lib;` -> `inherit (nixpkgs) lib;` at `flake.nix:55`
  and the two `overlays/unstable-packages.nix` entries (`niri`, `gemini-cli`); W08 outer-paren
  removal at `modules/system/packages.nix:5`. Verified: all 14 diffs match exactly, comments
  preserved.
- [x] Run a spot `nix fmt` on the files `statix fix` touched (statix's re-indentation may differ
  from nixfmt's opinion, especially around `packages.nix`'s `with pkgs; [ ... ]`). Verified: only
  whitespace/paren-removal changes (sorted-content diff confirms zero package-list changes).
- [x] Confirm no W20 finding was accidentally introduced by the paren/indent change. Verified:
  `statix check` now reports only 18 W20 findings, zero W10/W04/W08.

**Timing**: 0.5 hours

**Depends on**: 2

**Files to modify**:
- 11 module headers (`modules/system/shell.nix`, `networking.nix`, `services.nix`,
  `modules/home/core/git.nix`, `xdg.nix`, `modules/home/desktop/{waybar,mako,kanshi,swaylock}.nix`,
  `modules/home/email/{aerc,protonmail}.nix`) - `{ ... }:` -> `_:`
- `flake.nix:55`, `overlays/unstable-packages.nix:6,12` - assignment -> inherit
- `modules/system/packages.nix:5` - drop useless parens

**Verification**:
- `nix flake check` stays green. Verified: `all checks passed!`.
- `statix check` no longer reports any W10/W04/W08 findings (only W20 remain, minus any already
  excluded). Verified: 18 W20 findings remain, zero W10/W04/W08.

---

### Phase 4: Hand-collapse W20 Tier 1 (tight, low-risk files) [NOT STARTED]

**Goal**: Collapse the 8 Tier-1 `repeated_keys` findings where occurrences are adjacent/near and
the diff is small and mechanical.

**Tasks**:
- [ ] `flake.nix` - collapse `home-manager` (lines ~155-158) into one
  `home-manager = { useGlobalPkgs = true; useUserPackages = true; users.${username} = import ./home.nix; extraSpecialArgs = hmExtraSpecialArgs; };`.
- [ ] `lib/mkHost.nix` - collapse the mirroring `home-manager` block (lines ~42-44 + extraSpecialArgs).
- [ ] `hosts/iso/default.nix` - collapse `isoImage` (edition/compressImage/squashfsCompression).
- [ ] `hosts/usb-installer/default.nix` - collapse `isoImage`; confirm the nearby
  `networking.hostName` is a different key and is NOT absorbed.
- [ ] `home.nix` - collapse `home` (username/homeDirectory/stateVersion); preserve the historical
  stateVersion comment block between homeDirectory and stateVersion.
- [ ] `modules/system/audio.nix` - collapse `services` (blueman/pulseaudio/pipewire).
- [ ] `modules/system/services.nix` - collapse `services` (printing/avahi/xserver/libinput);
  move each per-entry 1-2 line comment inline into the collapsed set without loss.
- [ ] `modules/home/email/aerc.nix` - collapse the trailing `home.file` block (accounts.conf /
  querymap-gmail / querymap-logos); leave the earlier `programs.aerc = {...}` block untouched.
- [ ] Run `nix flake check` after each file (or a small batch).

**Timing**: 1.5 hours

**Depends on**: 3

**Files to modify**:
- `flake.nix`, `lib/mkHost.nix`, `hosts/iso/default.nix`, `hosts/usb-installer/default.nix`,
  `home.nix`, `modules/system/audio.nix`, `modules/system/services.nix`,
  `modules/home/email/aerc.nix` - collapse the flagged repeated key in each

**Verification**:
- `nix flake check` green after each file.
- `statix check` reports zero W20 findings for these 8 files.
- Spot-check: `nix eval` of one affected attr (e.g. host toplevel or `home.stateVersion`) is
  unchanged, or rely on the desugaring-equivalence argument plus green flake check.

---

### Phase 5: Hand-collapse W20 Tier 2 (whole-file wrap files) [NOT STARTED]

**Goal**: Collapse the 4 Tier-2 findings by wrapping the existing line range in one outer
`<key> = { ... };` and stripping the repeated prefix, preserving every interleaved comment's
relative position.

**Tasks**:
- [ ] `modules/system/boot.nix` - wrap the whole body in `boot = { ... };`, dropping the `boot.`
  prefix on all 6 assignments; keep the Ryzen comment blocks in place; re-flow with `nix fmt`
  after. (Note: this file already carries its Phase 1 `# deadnix: skip`; keep it above the header.)
- [ ] `modules/home/core/dotfiles.nix` - collapse `home` (sessionVariables / file / file.".zuliprc".source)
  one level only: keep `file = ...` and `file.".zuliprc".source = ...;` as two separate statements
  inside the merged `home = {...}` (not a full recursive collapse).
- [ ] `modules/home/core/xdg.nix` - wrap the whole file body in `xdg = { ... };` (enable /
  dataFile."applications/sioyek.desktop".text / mimeApps).
- [ ] `modules/system/power.nix` - collapse the 3 `services.*` occurrences
  (power-profiles-daemon.enable / udev.extraRules / fwupd.enable), skipping over the single-use
  `powerManagement` and `systemd.services.init-power-profile` keys (do NOT absorb them).
- [ ] Run `nix flake check` after each file.

**Timing**: 1 hour

**Depends on**: 4

**Files to modify**:
- `modules/system/boot.nix`, `modules/home/core/dotfiles.nix`, `modules/home/core/xdg.nix`,
  `modules/system/power.nix` - whole-body / range wrap of the flagged key

**Verification**:
- `nix flake check` green after each file.
- `statix check` reports zero W20 findings for these 4 files.
- Confirm no comment was lost or reordered relative to its code (visual diff review).

---

### Phase 6: Hand-collapse W20 Tier 3 - `modules/system/desktop.nix` (judgment-heavy) [NOT STARTED]

**Goal**: Collapse the file's `services` (7 non-contiguous occurrences) and `programs` (4
occurrences) into one merged attrset each, without dragging the unrelated single-use keys
(`environment.etc.*`, `hardware.graphics`, `security.polkit.enable`, `xdg.portal`) into them and
without silently destroying the deliberate top-to-bottom feature-walkthrough narrative.

**Tasks**:
- [ ] Read the full file and map every `services.*` and `programs.*` occurrence and the comment
  block attached to each.
- [ ] Merge all `services.*` assignments under one `services = { ... };` and all `programs.*`
  under one `programs = { ... };`, relocating the non-contiguous chunks while keeping each
  feature's explanatory comment adjacent to its code.
- [ ] Leave the interleaved non-repeated keys (`environment.etc`, `hardware.graphics`,
  `security.polkit`, `xdg.portal`) as their own statements; do not fold them into either merged set.
- [ ] Keep the Phase 1 `# deadnix: skip` above the `{ pkgs, lib, ... }:` header.
- [ ] Run `nix fmt` on the file and `nix flake check`.

**Timing**: 1 hour

**Depends on**: 5

**Files to modify**:
- `modules/system/desktop.nix` - merge `services` and `programs` repeated keys (its own commit)

**Verification**:
- `nix flake check` green.
- `statix check` reports zero W20 findings for `desktop.nix`.
- Visual review confirms the feature-walkthrough ordering and every comment are preserved.

---

### Phase 7: Add path-based exclusions for the 4 auto-generated hardware-configuration.nix files [NOT STARTED]

**Goal**: Exclude the auto-generated `hosts/*/hardware-configuration.nix` files from both linters
by path (not by editing them), so nixos-generate-config regeneration never reintroduces churn.

**Tasks**:
- [ ] Create repo-root `statix.toml` with:
  ```toml
  disabled = []
  ignore = [".direnv", "hosts/*/hardware-configuration.nix"]
  ```
  (verified in research to drop the 12 hardware-config W20 findings to zero with no other effect;
  `statix check` defaults `--config` to the repo root, so no CI change is needed for statix).
- [ ] Update `.github/workflows/ci.yml`'s deadnix step to
  `nix develop --command deadnix --exclude 'hosts/*/hardware-configuration.nix' -- . || true`
  (deadnix has no config-file mechanism; the glob must be quoted so the shell does not pre-expand
  it).
- [ ] Add a short note (commit message and/or devShell `shellHook` / README) explaining WHY these
  4 files are exempt (auto-generated "Do not modify this file!" header) and that the exclusion is
  path-based so it survives regeneration.

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `statix.toml` (new, repo root) - ignore glob for `.direnv` and hardware-config
- `.github/workflows/ci.yml` - add `--exclude 'hosts/*/hardware-configuration.nix'` to the deadnix step
- (optional) devShell `shellHook` / README note documenting the exemption rationale

**Verification**:
- `nix flake check` stays green (config files do not affect evaluation).
- `statix check` with the new `statix.toml` present reports zero findings in any
  `hardware-configuration.nix` path.
- `deadnix --exclude 'hosts/*/hardware-configuration.nix' -- .` reports zero findings in those files.

---

### Phase 8: Final normalization and full-tree verification [NOT STARTED]

**Goal**: Normalize formatting and confirm the terminal lint-clean state across the whole tree.

**Tasks**:
- [ ] Run `nix fmt $(git ls-files '*.nix')` (matching task 98's documented invocation to avoid the
  `./result`-symlink issue) to normalize all edits.
- [ ] Run `nix flake check` and confirm it is green.
- [ ] Run `statix check` and confirm zero findings tree-wide (hardware-config excluded via
  `statix.toml`).
- [ ] Run `deadnix --exclude 'hosts/*/hardware-configuration.nix' -- .` and confirm zero findings.
- [ ] Confirm `nix fmt`'s re-indentation did not re-introduce any statix/deadnix finding (this is
  why the linters run AFTER fmt, not before).

**Timing**: 0.5 hours

**Depends on**: 2, 3, 4, 5, 6, 7

**Files to modify**:
- Any `.nix` files whose formatting `nix fmt` normalizes (no semantic change)

**Verification**:
- `nix flake check` green.
- `statix check` = zero findings (modulo the documented `statix.toml` exclusion).
- `deadnix --exclude 'hosts/*/hardware-configuration.nix' -- .` = zero findings (modulo the
  documented CLI exclusion).

## Testing & Validation

- [ ] `nix flake check` is green after every file edit and at task completion (baseline confirmed
  green before work started).
- [ ] `statix check` reports zero findings tree-wide at completion (hardware-config excluded via
  `statix.toml`).
- [ ] `deadnix --exclude 'hosts/*/hardware-configuration.nix' -- .` reports zero findings at completion.
- [ ] The 8 intentional-convention deadnix bindings still exist and carry `# deadnix: skip` comments.
- [ ] No `hosts/*/hardware-configuration.nix` file was hand-edited.
- [ ] Evaluated configuration is unchanged: W20 collapses rely on Nix's `a.b=x; a.c=y;` ->
  `a={b=x;c=y;}` desugaring equivalence, corroborated by green `nix flake check` after each edit.

## Artifacts & Outputs

- plans/01_lint-findings-cleanup.md (this file)
- `statix.toml` (new, repo root)
- Edited: `.github/workflows/ci.yml`, `flake.nix`, `home.nix`, `lib/mkHost.nix`, and ~20 module /
  overlay / package / host `.nix` files (per-phase file lists above)
- summaries/01_lint-findings-cleanup-summary.md (at implementation completion)

## Rollback/Contingency

- Each phase leaves `nix flake check` green and is committed independently (Phase 6 `desktop.nix`
  gets its own commit), so any regression can be reverted at phase granularity with `git revert`
  of that phase's commit without unwinding earlier phases.
- If a W20 hand-collapse cannot be made green (persistent brace/indent error), revert that single
  file's edit (`git checkout -- <file>` only after a snapshot, or `git restore` the specific file
  from the last green commit) and leave that one W20 finding as a documented residual rather than
  block the rest of the cleanup.
- The two exclusion mechanisms (Phase 7) are additive config; reverting them simply restores the
  12 statix + 4 deadnix hardware-config findings and changes nothing about evaluation.

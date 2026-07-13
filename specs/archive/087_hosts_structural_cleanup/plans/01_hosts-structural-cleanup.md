# Implementation Plan: Task #87

- **Task**: 87 - hosts/ structural cleanup
- **Status**: [COMPLETED]
- **Effort**: 0.75 hours (Phase 1 ~5 min + Phase 2 ~15 min required; Phase 3 ~20 min optional/skippable)
- **Dependencies**: Task 86 (module convention + aggregators) — landed at `834943a`
- **Research Inputs**: specs/087_hosts_structural_cleanup/reports/01_hosts_readme_iso_extraction.md
- **Artifacts**: plans/01_hosts-structural-cleanup.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Task 87 has one required part and one explicitly optional stretch part. Required (Phase 2):
rewrite `hosts/README.md`'s obsolete inline-`nixosSystem` example (lines 28-37) to document the
current `lib/mkHost.nix` factory pattern — task 86 confirmed-deferred this to task 87 and research
re-verified the stale block is still present, so it is live doc work, not verify-only. Optional
(Phase 3, may be skipped): extract the ~30-line inline ISO module (`flake.nix`, the anonymous
`({ pkgs, lib, lectic, ... }: {...})` function inside the `iso` config) to
`hosts/iso/default.nix` for symmetry with `hosts/usb-installer/default.nix`, replacing the
closure-captured `system` with `pkgs.system`. Definition of done: `nix flake check` still reports
"all checks passed!" with only the two pre-existing zfs warnings, and (if Phase 3 taken) the
`iso` config's `drvPath` is byte-for-byte identical before and after extraction.

### Research Integration

Integrates report `01_hosts_readme_iso_extraction.md`:
- Item 1 is a live rewrite (task 86 explicitly deferred it; stale block confirmed present).
- `mkHost` factory signature and all four call sites (`nandi`, `hamsa`, `garuda`, `usb-installer`)
  are documented; `usb-installer` is the richest illustrative example (exercises both
  `extraModules` and `extraSpecialArgs`).
- ISO cannot route through `mkHost` (`mkHost.nix:31` unconditionally requires
  `hosts/<name>/hardware-configuration.nix`, which an installer image lacks; `lib/mkHost.nix`
  internals are frozen per `target-layout.md`). Extraction is a pure file-move of the ISO-specific
  module body only.
- Closure gotcha: the inline module's `nixpkgs.hostPlatform = system;` captures the outer
  `let system = "x86_64-linux"` binding via lexical closure. A verbatim cut-paste into a standalone
  file breaks with `undefined variable 'system'`. Fix: use `pkgs.system` (a standard module arg),
  avoiding any `specialArgs` change.
- Verification uses `nix eval` `drvPath` comparison because `iso`/`usb-installer` are excluded from
  the build-diff harness (task 68 lineage) and are not reliably buildable.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` exists but no `roadmap_flag` was set for this dispatch, so no roadmap
review/update phases are added. This task is subtask blueprint row 6 of parent task 81
(NixOS/Home Manager repo reorganization); it advances the hosts/ structural-cleanup line of that
roadmap item. ROADMAP.md is not modified by this plan.

## Goals & Non-Goals

**Goals**:
- Rewrite `hosts/README.md:28-37` to document the current `mkHost` factory pattern and its call
  sites (required).
- Correct two smaller drifts in `hosts/README.md` in the same edit: the "Structure" section
  (per-host directories now also carry `default.nix`/`README.md`) and, only if Phase 3 is taken,
  the "Available hosts" / "Hosts" lists to add `iso`.
- (Optional) Extract the inline ISO module to `hosts/iso/default.nix`, shrinking the `flake.nix`
  `iso` `modules` list entry to a single path reference, with `pkgs.system` substituted for the
  closed-over `system`.
- Preserve build-only inertness: `nix flake check` output unchanged (all checks pass, same two
  pre-existing zfs warnings); `iso`/`usb-installer` build state exactly as (un)buildable as before.

**Non-Goals**:
- Do NOT route `iso` through `mkHost` or touch `lib/mkHost.nix` (frozen internals).
- Do NOT touch task 68's broken zfs-kernel state or attempt to "fix" the pre-existing
  `boot.zfs.forceImportRoot` warnings.
- Do NOT add `hosts/hamsa/README.md` or address per-host README parity (out of scope for row 6).
- Do NOT include `iso`/`usb-installer` in any build-diff harness run.
- Do NOT stage with `git add -A`; stage only the specific paths each phase touches.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Verbatim ISO cut-paste breaks eval with `undefined variable 'system'` | H | H (if unaware) | Substitute `nixpkgs.hostPlatform = pkgs.system;` in the extracted file; confirm via `nix flake check --no-build` that `nixosConfigurations.iso` still evaluates |
| `git add -A` stages unrelated dirty orchestration files (TODO.md, state.json, other task artifacts) into the wrong commit and into `nix flake check`'s evaluated tree (`root = self`) | M | M | Stage only explicit paths per phase (`git add hosts/README.md`; `git add hosts/iso/default.nix flake.nix`); run `git status --short` before each commit |
| Scope creep into `lib/mkHost.nix` (attempting mkHost-unification for iso) | H | L | Explicitly out of scope; extraction is a pure file-move; keep `lib.nixosSystem` call in flake.nix |
| ISO extraction subtly changes evaluated config (regression) | M | L | Prove equivalence with identical `drvPath` before vs after (Phase 3); if `.drv` differs, revert |
| Treating pre-existing zfs warnings as new regressions | L | M | Baseline recorded in Phase 1; only deviations from that baseline count |
| README lists `iso` but Phase 3 is skipped (inconsistent doc) | L | M | Keep the `iso`-list additions inside Phase 3 only; Phase 2 leaves README self-consistent for the skip case |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |

Phases within the same wave can execute in parallel. Phase 3 is OPTIONAL and may be skipped
entirely; if skipped, the task is complete after Phase 2.

### Phase 1: Baseline capture [COMPLETED]

**Goal**: Record the pre-change verification baseline so any later deviation is attributable, and
capture the `iso` `drvPath` needed for Phase 3's before/after equivalence proof.

**Tasks**:
- [x] Run `nix flake check --no-build` and record the output (expect "all checks passed!" with the
      two pre-existing `boot.zfs.forceImportRoot` warnings on `iso`/`usb-installer`). *(completed —
      output matched exactly: "all checks passed!" with the two zfs warnings on iso and
      usb-installer)*
- [x] Capture `nix eval --raw .#nixosConfigurations.iso.config.system.build.toplevel.drvPath` and
      save the value (scratch note / terminal scrollback) as the "before" reference for Phase 3.
      *(deviation: altered — plain `nix eval --raw` fails with "Refusing to evaluate package
      'zfs-kernel-...' ... broken" because forcing `.drvPath` strictly evaluates the derivation,
      unlike `nix flake check` which does not force it; this is task 68's pre-existing broken
      zfs-kernel state, out of scope to fix. Worked around read-only via
      `NIXPKGS_ALLOW_BROKEN=1 nix eval --impure --raw ...` — an ephemeral env var for this eval
      invocation only, no tracked file touched. Captured value:
      `/nix/store/3vnp20n5d5w97da6kxgkz00d56li2cpn-nixos-system-nixos-iso-26.05.20260622.3426825.drv`)*
- [x] Confirm working tree state with `git status --short` so the later targeted staging is
      deliberate (unrelated dirty files may be present; they must not be staged). *(completed —
      confirmed several unrelated dirty specs/ files present from tasks 69/86/88/89/93; none will
      be staged by this task)*

**Timing**: ~5 minutes

**Depends on**: none

**Files to modify**: none (read/verify only)

**Verification**:
- `nix flake check --no-build` prints "all checks passed!" with exactly the two known zfs warnings.
- The `iso` `drvPath` value is captured and available for Phase 3.

---

### Phase 2: Rewrite hosts/README.md for the mkHost factory (REQUIRED) [COMPLETED]

**Goal**: Replace the obsolete inline-`nixosSystem` example and correct the "Structure" drift so
the directory-level doc reflects the current `mkHost` factory and per-host conventions.

**Tasks**:
- [x] Rewrite the `## Usage` code block (`hosts/README.md:28-37`) to document the `mkHost` factory:
      show the simple one-liner form (`hamsa = mkHost { hostname = "hamsa"; };`,
      `garuda = mkHost { hostname = "garuda"; };`) and the richer `usb-installer` form that
      exercises both `extraModules` and `extraSpecialArgs`
      (`usb-installer = mkHost { hostname = "usb-installer"; extraModules = [ "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix" ./hosts/usb-installer/default.nix ]; extraSpecialArgs = { inherit niri; }; };`).
      Note that `mkHost` (`lib/mkHost.nix`) wires in `configuration.nix`,
      `hosts/<name>/hardware-configuration.nix`, `sops-nix`, the nixpkgs overlay config, and the
      home-manager module automatically. *(completed; also added a one-line note that `iso` is
      not built via `mkHost` because it lacks `hardware-configuration.nix` — orthogonal to the
      Hosts-list deferral below, purely explaining the factory's own precondition)*
- [x] Update the `## Structure` section (lines 19-23): host directories contain
      `hardware-configuration.nix` and MAY also carry a per-host `default.nix` (opt-in module, per
      `.claude/rules/nix.md`'s Optional/Host-Toggled convention — e.g. `nandi/`, `usb-installer/`)
      and/or a `README.md` (e.g. `garuda/`, `nandi/`). *(completed)*
- [x] Leave the "Available hosts" line (line 49) and "Hosts" section (lines 5-17) unchanged in this
      phase — adding `iso` is deferred to Phase 3 so the README stays self-consistent if Phase 3 is
      skipped. *(completed — verified unchanged in final diff)*
- [x] Stage and verify: `git add hosts/README.md` (NEVER `git add -A`), then
      `nix flake check --no-build`. *(completed — `git diff --staged` showed only
      `hosts/README.md`; `nix flake check --no-build` output byte-identical to Phase 1 baseline:
      "all checks passed!" with the same two zfs warnings)*

**Timing**: ~15 minutes

**Depends on**: 1

**Files to modify**:
- `hosts/README.md` — rewrite the Usage example (lines 28-37) to the `mkHost` factory pattern;
  refresh the Structure section.

**Verification**:
- `git diff --staged` shows only `hosts/README.md` changed.
- `nix flake check --no-build` still prints "all checks passed!" with the same two zfs warnings
  (doc-only change is inert to evaluation).
- README no longer references `nixpkgs.lib.nixosSystem` directly in the Usage block; it documents
  `mkHost`.
- Commit: `task 87 phase 2: rewrite hosts/README.md for mkHost factory`.

---

### Phase 3: Extract inline ISO module to hosts/iso/default.nix (OPTIONAL — may be skipped) [COMPLETED]

**Goal**: Move the ISO-specific inline module body from `flake.nix` into `hosts/iso/default.nix`
for symmetry with `hosts/usb-installer/default.nix`, with zero change to the evaluated config
(proven by identical `drvPath`). The implementer MAY skip this phase; if skipped, the task is
complete after Phase 2 and this report stands as the rationale for skipping.

**Tasks**:
- [x] Create `hosts/iso/default.nix` containing the extracted module body: a `{ pkgs, lib, ... }:`
      function (drop the unused `lectic` arg) with the `isoImage.*` settings,
      `nixpkgs.hostPlatform = pkgs.system;` (NOT `system` — this is the closure fix), the
      `networking` block, and the `environment.systemPackages` list. Include a header comment
      explaining that `iso` is wired explicitly in `flake.nix` (not via `mkHost`) because an
      installer image has no `hardware-configuration.nix`. Mirror the shape/header style of
      `hosts/usb-installer/default.nix`. *(deviation: altered — the plan's own suggested fix,
      `nixpkgs.hostPlatform = pkgs.system;`, causes `error: infinite recursion encountered` at
      `lib/types.nix:892`, because the `pkgs` module arg is itself constructed from
      `config.nixpkgs.hostPlatform` — assigning `nixpkgs.hostPlatform = pkgs.system;` is a
      circular fixpoint, not a fix. Verified via `--show-trace`. Used `system` passed through
      `specialArgs` instead (see next task): the module signature is
      `{ pkgs, lib, system, ... }:` and the line is `nixpkgs.hostPlatform = system;`, with
      `system` now sourced from `specialArgs` rather than lexical closure. This still solves the
      original "undefined variable `system`" problem the plan flagged, without introducing
      recursion.)*
- [x] In `flake.nix`, replace the inline anonymous module `({ pkgs, lib, lectic, ... }: {...})`
      inside the `iso` config's `modules` list with a single `./hosts/iso/default.nix` path entry
      at the same list position. Leave everything else in the `iso` block unchanged (the
      `lib.nixosSystem` call, `configuration.nix`, the cd-dvd installer module, the
      `{ networking.hostName = "nixos-iso"; }` entry, `sops-nix`, `{ nixpkgs = nixpkgsConfig; }`,
      the home-manager block, and `specialArgs`). *(deviation: altered — added `inherit system;`
      to the `iso` block's `specialArgs` so the extracted module can consume it as a module arg,
      per the fix above; this is a one-line additive change to `specialArgs`, not a removal or
      restructuring of any other `iso` block content)*
- [x] Update `hosts/README.md`: add `iso` to the "Available hosts" line (line 49) and add a fifth
      entry to the "Hosts" section (lines 5-17), noting `iso` is wired directly via
      `lib.nixosSystem` in `flake.nix` rather than through `mkHost`. *(completed)*
- [x] Stage explicit paths only: `git add hosts/iso/default.nix flake.nix hosts/README.md`
      (NEVER `git add -A`). *(completed — `git diff --staged --stat` confirmed only these three
      paths)*
- [x] Prove equivalence: run
      `nix eval --raw .#nixosConfigurations.iso.config.system.build.toplevel.drvPath` and compare to
      the Phase 1 "before" value — they MUST be identical (byte-for-byte config equivalence; no ISO
      build required). *(completed with the same read-only `NIXPKGS_ALLOW_BROKEN=1 nix eval
      --impure --raw ...` workaround from Phase 1 — plain `nix eval --raw` still fails on the
      pre-existing broken zfs-kernel package, unrelated to this change. "After" value:
      `/nix/store/3vnp20n5d5w97da6kxgkz00d56li2cpn-nixos-system-nixos-iso-26.05.20260622.3426825.drv`
      — IDENTICAL to the Phase 1 "before" value. Equivalence proven.)*
- [x] Run `nix flake check --no-build` — expect unchanged "all checks passed!" with the same two
      zfs warnings. *(completed — output identical to Phase 1/2 baseline: "all checks passed!"
      with the same two zfs warnings on iso/usb-installer, no new errors or warnings)*

**Timing**: ~20 minutes

**Depends on**: 1, 2

**Files to modify**:
- `hosts/iso/default.nix` — NEW; extracted ISO-specific module body with `pkgs.system` fix.
- `flake.nix` — replace the inline ISO module function with `./hosts/iso/default.nix`.
- `hosts/README.md` — add `iso` to the hosts lists (only in this phase).

**Verification**:
- `nix eval --raw .#nixosConfigurations.iso.config.system.build.toplevel.drvPath` is IDENTICAL
  before (Phase 1) and after — the equivalence gate. If it differs, revert this phase.
- `nix flake check --no-build` prints "all checks passed!" with exactly the two pre-existing zfs
  warnings (no new `undefined variable 'system'` error, no new warnings).
- `git diff --staged` shows only `hosts/iso/default.nix`, `flake.nix`, `hosts/README.md`.
- Commit: `task 87 phase 3: extract inline ISO module to hosts/iso/default.nix`.

---

## Testing & Validation

- [ ] Phase 1 baseline recorded: `nix flake check --no-build` output + `iso` `drvPath` captured.
- [ ] `nix flake check --no-build` after Phase 2: "all checks passed!", same two zfs warnings.
- [ ] (If Phase 3 taken) `iso` `drvPath` identical before vs after — proves byte-for-byte config
      equivalence without building the ISO.
- [ ] (If Phase 3 taken) `nix flake check --no-build` after Phase 3: unchanged output, no new
      `undefined variable 'system'` error.
- [ ] All staging done with explicit paths; `git status --short` / `git diff --staged` reviewed
      before each commit; no `git add -A`.
- [ ] `iso`/`usb-installer` excluded from any build-diff harness run; no attempt to build them.
- [ ] `lib/mkHost.nix` and task 68's zfs state untouched.

## Artifacts & Outputs

- `specs/087_hosts_structural_cleanup/plans/01_hosts-structural-cleanup.md` (this plan)
- `hosts/README.md` (rewritten Usage/Structure; Phase 3 adds `iso` to host lists)
- `hosts/iso/default.nix` (NEW — only if Phase 3 taken)
- `flake.nix` (ISO `modules` entry simplified — only if Phase 3 taken)
- `specs/087_hosts_structural_cleanup/summaries/01_hosts-structural-cleanup-summary.md` (at implement time)

## Rollback/Contingency

- Phase 2 (doc-only): revert with `git checkout hosts/README.md` (before commit) or a revert
  commit after. No build impact.
- Phase 3 (optional): if the `drvPath` equivalence check fails or `nix flake check` shows a new
  error, revert `flake.nix`, remove `hosts/iso/default.nix`, and undo the README `iso`-list
  additions — restoring the exact pre-Phase-3 inline state. Because Phase 3 is optional and
  independent, reverting it leaves Phase 2's required work intact.
- General: never use destructive git on the dirty tree without a snapshot; prefer targeted
  `git checkout <path>` on the specific files this task owns, or a forward revert commit.

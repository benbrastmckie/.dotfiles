# Implementation Plan: Review and Refactor NixOS Configuration

- **Task**: 66 - Review and Refactor NixOS Configuration
- **Status**: [IN PROGRESS]
- **Effort**: 20 hours
- **Dependencies**: GATED — implementation must land AFTER tasks 62 (TTS swap, edits configuration.nix:635) and 65 (python pins, edits home.nix:352 + flake.nix python overlay) complete, and after tasks 60/61/63 settle their `nix.*` settings. Task 64 (cache cleanup, imperative) is independent. Planning is unblocked; the quick-win phase (Phase 1) is independently safe and may proceed before the full gate clears.
- **Research Inputs**: reports/01_team-research.md (synthesis of 4-teammate wave; teammate-a migration map and teammate-c safeguards consulted)
- **Artifacts**: plans/01_refactor-nixos-config.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
- **Type**: nix
- **Lean Intent**: false

## Overview

The configuration is 2,572 lines concentrated in three files — `flake.nix` (477L), `configuration.nix` (945L), `home.nix` (1627L) — with every domain of concern mixed together and an unused `modules/`/`home-modules/` scaffold. This plan performs a **semantically inert** restructure (identical system behavior, improved organization/documentation/modularity) into a hand-rolled `modules/system/` + `modules/home/` + `hosts/<name>/` layout with `overlays/*.nix` and `lib/mkHost.nix`. No framework (Snowfall/nixos-unified) is introduced. **Definition of done**: every phase produces an empty or expected-only `nix store diff-closures` against the pre-refactor closure for `.#nandi`, `nix flake check` passes throughout, and both the NixOS-integrated and standalone home-manager profiles remain equivalent.

### Research Integration

Integrated `reports/01_team-research.md` (the synthesized team report). Key inputs used directly: teammate A's line-by-line current→target migration table (phase boundaries for Phases 4 and 5), teammate C's safeguard tooling and the `nix store diff-closures` workflow (the recurring per-phase gate), the unanimous sequencing constraint vs tasks 60-65 (Dependencies field), and the critical-defect list (Phase 1 quick wins). The chosen top-level naming is `modules/system/` + `modules/home/` + `hosts/<name>/` per the synthesis resolution of the A-vs-D naming conflict.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this plan (roadmap_flag is false). The roadmap file may exist but is not part of this plan's phases.

## Goals & Non-Goals

**Goals**:
- Split `configuration.nix` into ~13 focused `modules/system/*.nix` modules behind a thin import list.
- Split `home.nix` into ~20 focused `modules/home/*.nix` modules (incl. inline scripts → `pkgs.writeShellApplication`) behind a thin import list.
- Extract the 3 inlined overlays into `overlays/*.nix`; add `lib/mkHost.nix` to dedupe the 4× host definitions; extract the ~200L inline USB-installer module; add `hosts/garuda/default.nix`.
- Fix critical latent defects: hardcoded `SASL_PATH` store hash (home.nix:1613), dead `unstable-packages.nix`, duplicate packages (stylua/cvc5/lectic/wl-clipboard + duplicate neovim), missing `follows = "nixpkgs"` on lean4/lectic/utils, dead `nix-ai-tools` arg.
- Username hygiene: replace hardcoded `"benjamin"` / `/home/benjamin` with `config.home.username` / `config.home.homeDirectory`.
- Documentation: add `docs/how-to-add-package.md`, `docs/how-to-add-service.md`, a module map in `README.md`; update stale `docs/` (configuration.md, unstable-packages.md).
- Verify behavioral equivalence at every structural phase; verify both home-manager profiles stay equivalent.

**Non-Goals**:
- No new or removed packages (behavior-preserving only).
- No channel migration (task 61) and no GC settings changes (task 63).
- No removal of the standalone `homeConfigurations.benjamin` path — flag the dual-home-manager consolidation as a QUESTION for the user; document the options only, do not silently change.
- No `packages/` directory reorganization (already well-structured).
- No `.claude/` agent-system changes.
- No secrets-backend change (sops-nix layout preserved; document the unmanaged `gmail-oauth2.env` only).
- No CI / pre-commit / lint-gate adoption (`git-hooks.nix`, statix, deadnix as enforced hooks) — separate task; tools may be invoked ad hoc during phases but not wired as a gate.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Merge conflict with in-flight tasks 62/65 touching the same lines | H | H | Gate implementation start until 62/65 complete and 60/61/63 settle (Dependencies field); Phase 0 re-verifies line refs before any edit |
| Module split silently changes system closure | H | M | Per-phase `nix store diff-closures` gate; "empty/expected-only diff = phase safe" acceptance criterion; revert phase commit if diff is unexpected |
| Home-manager import-order option conflicts | M | M | Use `lib.mkDefault`/`lib.mkForce` where needed; `home-manager build` before any switch |
| Standalone vs NixOS-integrated HM divergence after split (divergent extraSpecialArgs) | H | M | Phase 5 explicitly builds both profiles and diffs them; mkHost centralizes extraSpecialArgs so both paths share one definition |
| Booting into a broken generation during staged migration | H | L | Dedicated branch; commit per green milestone; `build` (not `switch`) used for verification; keep prior generation bootable |
| Inline-script → writeShellApplication changes runtime deps | M | M | Enumerate `runtimeInputs` explicitly per script; shellcheck via writeShellApplication catches latent bugs; diff-closures catches store-path changes |
| Docs go stale the moment files split | M | H | Documentation phase (Phase 8) is in-scope, not a follow-up; update configuration.md and unstable-packages.md |
| Removing dead `nix-ai-tools` arg breaks a hidden consumer | M | L | grep all four nixosConfigurations + homeConfigurations before removal; remove arg only, keep flake input if still referenced elsewhere |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 0 | -- |
| 2 | 1 | 0 |
| 3 | 2 | 1 |
| 4 | 3 | 2 |
| 5 | 4 | 3 |
| 6 | 5 | 4 |
| 7 | 6 | 5 |
| 8 | 7 | 6 |
| 9 | 8 | 7 |
| 10 | 9 | 8 |

Phases are largely sequential because each structural phase rebases the working tree and must pass a closure-diff before the next begins. Phase 1 (quick wins) is the only phase safe to run ahead of the full sequencing gate.

### Phase 0: Branch, Baseline, and Equivalence Harness [COMPLETED]

**Goal**: Establish the dedicated branch, capture the pre-refactor closure baseline, and define the reusable behavioral-equivalence procedure that every later phase reuses.

**Tasks**:
- [x] Confirm tasks 62 and 65 are complete and 60/61/63 have settled their `nix.*` settings (check specs/state.json); abort if still [IMPLEMENTING] (Phase 1 may still proceed independently). *(deviation: tasks 62 and 65 are still [implementing]; Phase 1 proceeds independently per plan; structural phases 2+ gated)*
- [x] Create dedicated branch `task-66-refactor-nixos` from current master.
- [x] Record baseline: `nix eval .#nixosConfigurations.nandi.config.system.build.toplevel` → `/nix/store/wrx0z1klfvax2b4c3hj8amlvv95kw2zr-nixos-system-nandi-26.11.20260616.567a49d.drv`; home-manager baseline → `/nix/store/334nly6g09am503dsa95j8ma1gcigid3-home-manager-generation.drv`.
- [x] Verify `nix flake check` passes on the unmodified tree (establish green baseline). *(deviation: `nix flake check` has a pre-existing failure on `usb-installer` — `hashedInitialPassword` is not a valid NixOS option; nandi/hamsa/homeConfigurations.benjamin all evaluate successfully; this pre-existing defect is fixed in Phase 1)*
- [x] Write a short equivalence-check snippet (build `.#nandi`, run `nix store diff-closures $PRE $POST`) to reuse per phase; acceptance criterion "empty/expected-only diff = phase safe".
- [x] Re-verify the teammate-A line references against current files (line numbers may have shifted after 62/65). *(completed: SASL_PATH is at line 1613, nix-ai-tools only in signature line 1, duplicate packages confirmed at configuration.nix:555-601)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- (none — branch + baseline only; no source edits)

**Verification**:
- Branch exists; `PRE` closure path captured; `nix flake check` green on baseline.

---

### Phase 1: Quick-Win Safe Fixes [COMPLETED]

**Goal**: Apply the independently-safe critical fixes that require no structural moves. Safest phase; can run ahead of the full sequencing gate.

**Tasks**:
- [x] Fix `SASL_PATH` at `home.nix:1613` — replaced hardcoded store hash with `"${pkgs.cyrus-sasl-xoauth2}/lib/sasl2:${pkgs.cyrus_sasl}/lib/sasl2"` (matching the correct dynamic form already at home.nix:882/systemd.user.sessionVariables).
- [x] Delete dead `unstable-packages.nix` (root); grep-confirmed no importer — deleted.
- [x] Remove duplicate packages from `environment.systemPackages`: `stylua`, `cvc5`, `lectic`, `wl-clipboard` (kept in `home.packages`) — replaced with comments noting home-manager ownership.
- [x] Remove `neovim` from `environment.systemPackages` (managed by `programs.neovim.enable`) — commented out with note.
- [x] Add `follows = "nixpkgs"` to flake inputs `lean4` and `lectic`. *(deviation: `utils` (flake-utils) does not have a nixpkgs input — only has `systems` input — so no follows added for utils; lean4 and lectic both confirmed to have nixpkgs inputs via lock file)*
- [x] Remove dead `nix-ai-tools` argument from `home.nix` arg list — verified only appears in line 1 signature and is never used in the file body; removed from `{ ... }:` signature; kept flake input and inheritance since it's passed via extraSpecialArgs to all hosts.
- [x] **Bonus**: Fixed pre-existing `hashedInitialPassword` → `initialHashedPassword` in usb-installer inline module (caused `nix flake check` to fail on baseline).

**Timing**: 1.5 hours

**Depends on**: 0

**Files to modify**:
- `home.nix` - fix SASL_PATH; remove dead nix-ai-tools arg
- `configuration.nix` - remove 4 duplicate packages + duplicate neovim
- `flake.nix` - add follows to lean4/lectic/utils
- `unstable-packages.nix` - delete

**Verification**:
- `nix flake check` passes; `diff-closures` shows only the expected store-path normalization for SASL_PATH (and nothing else); duplicate removals produce empty system-closure diff. Commit.

---

### Phase 2: Extract Overlays into overlays/*.nix [NOT STARTED]

**Goal**: Move the 3 inlined overlays (~120L) out of the flake `let` block into dedicated files; flake imports them.

**Tasks**:
- [ ] Create `overlays/claude-squad.nix` from flake.nix:50-81.
- [ ] Create `overlays/unstable-packages.nix` from flake.nix:83-103 (supersedes the deleted root file).
- [ ] Create `overlays/python-packages.nix` from flake.nix:105-123 (coordinate with task 65's python overlay edits — verify final post-65 content).
- [ ] Rewire `flake.nix` to import the overlay files; remove the inlined definitions.

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `overlays/claude-squad.nix`, `overlays/unstable-packages.nix`, `overlays/python-packages.nix` - new
- `flake.nix` - replace inline overlays with imports

**Verification**:
- `nix flake check` passes; `diff-closures` for `.#nandi` empty. Commit.

---

### Phase 3: flake.nix Cleanup — mkHost + USB Installer + garuda [NOT STARTED]

**Goal**: Add `lib/mkHost.nix` to dedupe the 4× host definitions, extract the ~200L inline USB-installer module, and add the missing `hosts/garuda/default.nix`. Centralize `extraSpecialArgs` in mkHost so both HM paths share one definition.

**Tasks**:
- [ ] Create `lib/mkHost.nix` (function producing `nixpkgs.lib.nixosSystem`; centralizes modules, overlays, sops, home-manager wiring, and `extraSpecialArgs`).
- [ ] Rewrite the 4 `nixosConfigurations` (nandi, hamsa, iso, usb-installer) in flake.nix to call `mkHost`.
- [ ] Extract the inline USB-installer anonymous module (flake.nix:242-279) into `hosts/usb-installer/default.nix`.
- [ ] Add `hosts/garuda/default.nix` (imports common + its existing hardware-configuration.nix).
- [ ] Ensure `homeConfigurations.benjamin` and the NixOS-integrated path draw `extraSpecialArgs` from the same source (prep for Phase 5 equivalence).

**Timing**: 2 hours

**Depends on**: 2

**Files to modify**:
- `lib/mkHost.nix`, `hosts/usb-installer/default.nix`, `hosts/garuda/default.nix` - new
- `flake.nix` - call mkHost; remove inline USB module + duplicated host blocks

**Verification**:
- `nix flake check` passes; `diff-closures` for `.#nandi` empty; `nix build .#nixosConfigurations.usb-installer.config.system.build.isoImage` still evaluates. Commit.

---

### Phase 4a: Split configuration.nix — Core System Modules (part 1) [NOT STARTED]

**Goal**: Extract the first half of `configuration.nix` into `modules/system/*.nix` using teammate A's migration table. Leave the rest in place; `configuration.nix` still imports remaining inline content.

**Tasks**:
- [ ] Create `modules/system/boot.nix` (configuration.nix:22-78), `networking.nix` (85-99), `locale.nix` (102-138), `desktop.nix` (156-264).
- [ ] Create `modules/system/services.nix` (273-290), `audio.nix` (292-316 + 813-848), `power.nix` (318-401 + 433-438).
- [ ] Add `imports = [ ./modules/system/... ]` to configuration.nix; delete the migrated inline blocks.

**Timing**: 2 hours

**Depends on**: 3

**Files to modify**:
- `modules/system/{boot,networking,locale,desktop,services,audio,power}.nix` - new
- `configuration.nix` - add imports; remove migrated blocks

**Verification**:
- `nix flake check` passes; `diff-closures` for `.#nandi` empty. Commit.

---

### Phase 4b: Split configuration.nix — Core System Modules (part 2) + thin import list [NOT STARTED]

**Goal**: Extract the remaining `configuration.nix` content into modules (incl. `optional/`), collapsing `configuration.nix` to a ~50-line import list.

**Tasks**:
- [ ] Create `modules/system/users.nix` (441-484, users only), `nix.nix` (734-780), `display.nix` (713-732 fonts + GDM bits), `packages.nix` (486-697), shell module for programs.fish (700-711).
- [ ] Create `modules/system/optional/discord-bot.nix` (sops secrets + discord-bot + opencode-serve systemd services, configuration.nix:799-940) and `optional/usb-installer.nix` if not already covered by Phase 3.
- [ ] Collapse `configuration.nix` to a thin import list referencing `modules/system/` (core always-on) and host-opted `optional/`.

**Timing**: 2 hours

**Depends on**: 4a

**Files to modify**:
- `modules/system/{users,nix,display,packages,shell}.nix`, `modules/system/optional/discord-bot.nix` - new
- `configuration.nix` - reduce to thin import list

**Verification**:
- `nix flake check` passes; `diff-closures` for `.#nandi` empty; discord-bot/opencode-serve services still present in closure. Commit.

---

### Phase 5a: Split home.nix — Core + Desktop + Email Modules [NOT STARTED]

**Goal**: Extract the non-script halves of `home.nix` into `modules/home/*.nix` per teammate A's table.

**Tasks**:
- [ ] Create `modules/home/core/{git,neovim,shell,xdg}.nix` (home.nix:14-44, shell/sessionVars at 1580-1626).
- [ ] Create `modules/home/desktop/{gnome,cursor,waybar,mako,kanshi,swaylock}.nix` (dconf 50-173, waybar 1203-1335, swaylock/kanshi 1580-1626).
- [ ] Create `modules/home/email/{notmuch,aerc,mbsync,protonmail}.nix` (mbsyncrc 949-1119, protonmail/notmuch 1338-1392, aerc 1394-1578).
- [ ] Add corresponding `imports` to home.nix; delete migrated blocks.

**Timing**: 2 hours

**Depends on**: 4b

**Files to modify**:
- `modules/home/core/*.nix`, `modules/home/desktop/*.nix`, `modules/home/email/*.nix` - new
- `home.nix` - add imports; remove migrated blocks

**Verification**:
- `nix flake check` passes; `home-manager build --flake .#benjamin` succeeds; `diff-closures` for `.#nandi` empty. Commit.

---

### Phase 5b: Split home.nix — Scripts (writeShellApplication) + Services + Packages + thin import list [NOT STARTED]

**Goal**: Convert the 6 inline `writeShellScriptBin` scripts to `pkgs.writeShellApplication` modules, extract systemd user services and the package lists, and collapse `home.nix` to a ~50-line import list. Equivalence between the two home-manager profiles is verified at the end.

**Tasks**:
- [ ] Create `modules/home/scripts/{sioyek-theme,gmail-oauth2,whisper,memory-monitor}.nix` converting each script to `pkgs.writeShellApplication` with explicit `runtimeInputs` (home.nix:203-225, 270-320, 416-506, 521-694).
- [ ] Create `modules/home/services/{ydotool,screenshot,memory-services}.nix` (home.nix:736-803, 804-884).
- [ ] Create `modules/home/packages/*.nix` splitting `home.packages` (185-693) by concern (ai-tools, dev-tools, lean-math, media, python, fonts).
- [ ] Collapse `home.nix` to a thin import list with `home.username`/`stateVersion`; migrate `modules/opencode.nix` + `home-modules/mcp-hub.nix` into the new layout (or document as intentionally disabled).
- [ ] **Equivalence check**: build BOTH `.#nandi` (NixOS-integrated HM) and `.#benjamin` (standalone) and confirm the home profile derivations match expectations; document any divergence found.

**Timing**: 2.5 hours

**Depends on**: 5a

**Files to modify**:
- `modules/home/scripts/*.nix`, `modules/home/services/*.nix`, `modules/home/packages/*.nix` - new
- `home.nix` - reduce to thin import list
- `modules/opencode.nix`, `home-modules/mcp-hub.nix` - relocate or document

**Verification**:
- `nix flake check` passes; `diff-closures` for `.#nandi` empty; `home-manager build --flake .#benjamin` closure equivalent to the NixOS-integrated per-user profile (record both and diff). Commit.

---

### Phase 6: Username Hygiene [NOT STARTED]

**Goal**: Replace hardcoded `"benjamin"` / `/home/benjamin` literals with `config.home.username` / `config.home.homeDirectory` in home modules (and parameterize where system modules reference the username).

**Tasks**:
- [ ] Grep all `benjamin` / `/home/benjamin` literals across the new `modules/home/` and `modules/system/` files.
- [ ] Replace home-scope literals with `config.home.username` / `config.home.homeDirectory`; use `%h` in systemd unit paths where already idiomatic.
- [ ] Leave `update.sh` hardcoding documented (out of scope to rewire output names) unless trivially safe.

**Timing**: 1.5 hours

**Depends on**: 5b

**Files to modify**:
- `modules/home/**/*.nix` - replace username literals
- `modules/system/users.nix` - parameterize where safe

**Verification**:
- `nix flake check` passes; `diff-closures` for `.#nandi` empty (literals resolve to identical paths); `home-manager build` matches. Commit.

---

### Phase 7: Document Dual Home-Manager Decision (Question for User) [COMPLETED]

**Goal**: Do NOT change the dual HM path. Record the trade-offs and surface the consolidation decision to the user as an explicit open question.

**Tasks**:
- [x] Write `docs/dual-home-manager.md` documenting the two paths (NixOS-integrated vs standalone `homeConfigurations.benjamin`), how `update.sh` runs both, the two GC roots / doubled eval cost, and the previously-divergent `extraSpecialArgs` (now centralized via mkHost). *(deviation: mkHost is planned for Phase 3, not yet implemented; doc notes extraSpecialArgs alignment done in Phase 1)*
- [x] List options: (a) keep both, (b) drop standalone, (c) drop integrated — with consequences each.
- [x] Mark as a QUESTION for the user in the doc and the task summary; make no functional change.

**Timing**: 1 hour

**Depends on**: 6

**Files to modify**:
- `docs/dual-home-manager.md` - new (documentation only)

**Verification**:
- Doc present and accurate; no `.nix` change; `nix flake check` still passes. Commit.

---

### Phase 8: Documentation + README Module Map [COMPLETED]

**Goal**: Add the how-to docs and a module map, and refresh docs made stale by the split.

**Tasks**:
- [x] Write `docs/how-to-add-package.md` (where a package goes: system vs home vs programs.X.enable vs custom derivation — the ownership policy). Created with full decision tree and ownership policy table.
- [x] Write `docs/how-to-add-service.md` (system service vs home systemd user service; sops secret wiring). Created with decision tree, system and user service patterns, sops integration.
- [x] Add a module map to `README.md` (the `modules/system/`, `modules/home/`, `hosts/`, `overlays/`, `lib/` layout). Added comprehensive ASCII tree showing current and planned structure.
- [x] Update stale docs: `docs/configuration.md` — updated to reflect new file structure including planned overlays/lib/modules; `docs/unstable-packages.md` — noted deletion of root unstable-packages.nix and updated package list. *(deviation: references to `modules/system/` and `modules/home/` in docs are marked as "planned" since Phases 4-5 are gated on tasks 62/65)*

**Timing**: 1.5 hours

**Depends on**: 7

**Files to modify**:
- `docs/how-to-add-package.md`, `docs/how-to-add-service.md` - new
- `README.md` - add module map
- `docs/configuration.md`, `docs/unstable-packages.md` - update

**Verification**:
- Docs reference real paths; module map matches the tree; no `.nix` change. Commit.

---

### Phase 9: Final Behavioral-Equivalence Audit + Merge Prep [NOT STARTED]

**Goal**: Whole-tree confirmation that the refactor is a no-op from the system's perspective across all hosts, then prepare the branch for merge.

**Tasks**:
- [ ] Build all `nixosConfigurations` (nandi, hamsa, garuda, usb-installer) and `homeConfigurations.benjamin`; run `nix store diff-closures` / `nvd` against pre-refactor baselines for each.
- [ ] Confirm every diff is empty or explained by an intended fix (only SASL_PATH normalization from Phase 1 is expected to differ).
- [ ] Run `nix flake check` final pass; optionally run `statix check .` and `deadnix .` ad hoc and note (do not gate).
- [ ] Verify `update.sh` still references valid output names (`#benjamin`, `#$HOSTNAME`).
- [ ] Summarize the open user question (dual HM) and the unmanaged-secret note (`gmail-oauth2.env`) in the task summary.

**Timing**: 1 hour

**Depends on**: 8

**Files to modify**:
- (none — verification + summary)

**Verification**:
- All hosts build; all closure diffs empty/expected; `nix flake check` green; `update.sh` outputs valid. Final commit.

## Testing & Validation

- [ ] `nix flake check` passes after every phase (and on the Phase 0 baseline).
- [ ] `nixos-rebuild build --flake .#nandi --no-link --print-out-paths` succeeds each phase; `nix store diff-closures $PRE $POST` is empty/expected-only ("empty/expected-only diff = phase safe").
- [ ] `home-manager build --flake .#benjamin` succeeds after the home.nix split (Phases 5a/5b).
- [ ] NixOS-integrated per-user profile and standalone `.#benjamin` profile closures are equivalent (Phase 5b).
- [ ] All four `nixosConfigurations` build in the final audit (Phase 9); `usb-installer` isoImage still evaluates (Phase 3).
- [ ] `update.sh` output references remain valid (Phase 9).

## Artifacts & Outputs

- `overlays/claude-squad.nix`, `overlays/unstable-packages.nix`, `overlays/python-packages.nix`
- `lib/mkHost.nix`
- `hosts/garuda/default.nix`, `hosts/usb-installer/default.nix`
- `modules/system/*.nix` (~13 modules incl. `optional/discord-bot.nix`, `optional/usb-installer.nix`)
- `modules/home/{core,desktop,email,packages,scripts,services}/*.nix` (~20 modules)
- Thin `configuration.nix` and `home.nix` import lists
- `docs/dual-home-manager.md`, `docs/how-to-add-package.md`, `docs/how-to-add-service.md`; updated `README.md`, `docs/configuration.md`, `docs/unstable-packages.md`
- Deleted: `unstable-packages.nix` (root)

## Rollback/Contingency

All work is on the dedicated `task-66-refactor-nixos` branch with one commit per green milestone. If any phase produces an unexpected `diff-closures`, revert that phase's commit and re-attempt — earlier phases remain valid because each was independently verified. The master branch and the prior NixOS generation remain bootable throughout (verification uses `build`, never `switch`), so a broken refactor never reaches the running system. If the full refactor is abandoned, Phase 1 (quick wins) can be cherry-picked to master independently as it is behavior-preserving and self-contained.

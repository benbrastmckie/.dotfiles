# Implementation Plan: NixOS Config Documentation and Config Improvements

- **Task**: 94 - Systematically review the NixOS config to improve the documentation (and the config) where relevant
- **Status**: [NOT STARTED]
- **Effort**: 5.5 hours (executable phases 1-7); Phase 8 deferred, not executed autonomously
- **Dependencies**: None (builds on completed tasks 65, 66, 81-91)
- **Research Inputs**: specs/094_review_nixos_config_documentation/reports/01_nixos-config-doc-review.md
- **Artifacts**: plans/01_nixos-doc-config-improvements.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/context/formats/plan-format.md
  - .claude/rules/nix.md
- **Type**: nix

## Overview

The research report audited the `/home/benjamin/.dotfiles` NixOS + Home Manager flake and found the
repo structurally healthy (task 66/81-91 reorg fully landed) but its narrative docs lagging behind
reality: several contributor-facing docs describe the pre-reorg architecture as still current or
still-planned, and would actively misdirect a contributor into editing `configuration.nix`/`home.nix`
directly instead of the correct `modules/system/*` / `modules/home/**` files. There is also one
confirmed factual bug (root README labels `nandi` as AMD when it is Intel; `hamsa` is the AMD host).
This plan sequences the fixes strictly by priority: high-priority doc-accuracy corrections first, then
mechanical medium-priority cleanup, then conservative low-priority config-comment cleanups, and finally
a clearly-marked deferred phase for items the research flagged as requiring user confirmation. The
definition of done: every high/medium/low finding is either fixed-and-verified or explicitly deferred,
with doc changes verified by re-reading against the live config and any `.nix` edits verified by
`nix flake check`.

### Research Integration

All 14 findings from `reports/01_nixos-config-doc-review.md` are mapped into phases:
- Findings 1-2 (stale architecture-status docs) -> Phase 2
- Findings 3-4 (stale contributor how-to guides) -> Phase 3
- Findings 5-6 (stale package-inventory docs) -> Phase 4
- Finding 7 (README CPU-vendor factual bug) -> Phase 1 (first, quick, highest-confidence fix)
- Finding 8 (emoji-convention drift) -> Phase 5 (eligible docs only)
- Findings 11-13 (small dead-comment cleanups) -> Phase 6
- Finding 14 (missing overlays/README.md) -> Phase 7
- Findings 9-10 (Ryzen doc consolidation, niri "testing phase" framing) + niri.md emoji strip -> Phase 8 (DEFERRED)

### Prior Plan Reference

No prior plan. This is the first plan for task 94.

### Roadmap Alignment

No ROADMAP.md consulted (no roadmap_path provided for this dispatch). No roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Correct the one confirmed factual error (nandi/hamsa CPU vendor) in root README.md.
- Bring the stale contributor/architecture docs into agreement with the post-reorg module layout so
  they no longer misdirect contributors.
- Correct the package-inventory docs (remove nonexistent `marker-pdf.nix`, add real missing packages,
  replace `python312` with `python3`, fix the deleted-file reference).
- Sweep emoji from eligible documentation files to satisfy the repo's own "No emojis in documentation"
  rule.
- Make only conservative, individually-justified config-comment cleanups, each verified by `nix flake check`.
- Close the `overlays/README.md` convention gap.

**Non-Goals**:
- No functional config changes (no new packages, services, options, or behavior). Only stale comment
  pruning / clarification in `.nix` files.
- No `stateVersion` bumps and no `flake.lock` edits (explicitly frozen per `modules/README.md` Verified
  Health Notes).
- No touching `modules/home/services/gmail-oauth2.nix` (deliberately-disabled, gold-standard reference).
- No speculative restructuring or content deletion that may reflect deliberate user choices
  (Ryzen doc consolidation, niri usage-phase framing) — these are deferred to Phase 8, not executed
  under autonomous orchestration.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A "doc fix" introduces a new inaccuracy by rewriting from memory | M | M | Every doc edit is verified by re-reading the target section against the actual `.nix` source it describes (mirror `modules/README.md`, the known-good current doc) |
| Deleting the `core-network` line (finding 12) loses real intent | M | L | Do NOT delete an ambiguous option line; document-or-leave only. Treat gmail-oauth2.nix's rationale style as the model |
| Config comment edit breaks flake evaluation | H | L | Comment-only edits; still run `nix flake check` after Phase 6 (may be slow) before considering it green |
| Emoji sweep collides with doc rewrites on shared files | M | M | Phase 5 depends on Phases 2 and 3 so shared files (unstable-packages.md, how-to-add-*.md) are rewritten first, then swept |
| Autonomously acting on a user-judgment item | M | M | Findings 9, 10 and the niri.md emoji strip are isolated in deferred Phase 8, explicitly marked skip-under-orchestration |
| Pruning a still-needed "missing package" comment item (finding 11) | L | M | Prune only the four items confirmed configured (mako, waybar, kanshi, swaylock); verify each remaining item before removal, keep uncertain X11-era items |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3, 4, 6, 7 | -- |
| 2 | 5 | 2, 3 |

Phases within the same wave can execute in parallel (they touch disjoint files). Phase 8 is DEFERRED
and excluded from execution under autonomous orchestration; it is not part of any executable wave.
Under sequential orchestration, execute phases in ascending numeric order (1 -> 7), which respects all
dependencies.

---

### Phase 1: Correct hardware/host factual error in root README.md [NOT STARTED]

**Goal**: Fix the confirmed factual bug where the root README module map labels `nandi` as AMD when it
is Intel, and `hamsa` (the actual AMD host) carries no CPU annotation.

**Tasks**:
- [ ] Read `README.md` around the "Module Map" ASCII tree (line ~32) and confirm the current text.
- [ ] Read `hosts/nandi/hardware-configuration.nix` and `hosts/hamsa/hardware-configuration.nix` to
      confirm ground truth (`kvm-intel`/`hardware.cpu.intel` for nandi; `kvm-amd`/`hardware.cpu.amd`
      for hamsa).
- [ ] Correct the nandi line to drop the false "AMD Ryzen AI 300" label (annotate as Intel, or drop the
      CPU annotation entirely and point to `hosts/README.md` for hardware details, matching how the
      `garuda` line already has no CPU annotation). If keeping annotations, add the AMD label to the
      `hamsa` line so the map is internally consistent with `hosts/README.md`.

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `README.md` - correct/rebalance the nandi (and optionally hamsa) CPU-vendor annotations in the Module Map.

**Verification**:
- Re-read the corrected README lines against both hosts' `hardware-configuration.nix`; confirm no host
  is labeled with the wrong CPU vendor and that the README now agrees with `hosts/README.md` and
  `hosts/nandi/README.md` (both already say Intel).

---

### Phase 2: Update stale architecture-status docs [NOT STARTED]

**Goal**: Bring `docs/configuration.md` and `docs/unstable-packages.md` into agreement with the
completed reorg so they stop describing implemented artifacts as "planned"/"pending Phase 2".

**Tasks**:
- [ ] `docs/configuration.md`: remove the `# (planned)` markers on `overlays/` and `lib/` in the File
      Structure ASCII tree (both are fully implemented); delete the stale "Phases 2-6 ... gated on
      tasks 62 and 65" status blockquote (lines ~23-25); fix line ~54's "Package Overlays (inlined in
      flake.nix, pending Phase 2 extraction)" heading (all three overlays are extracted files); rewrite
      the `configuration.nix`/`home.nix` prose sections (lines ~27-43 and ~75-83) to describe them as
      thin import shims pointing at `modules/system/*.nix` and `modules/home/**/*.nix`, mirroring the
      current `modules/README.md`.
- [ ] `docs/unstable-packages.md`: delete the stale intro note (lines ~5-7) claiming the overlay is
      "inlined in flake.nix ... pending Phase 2 extraction" (contradicted by line 12 in the same file);
      update line ~51's "(after Phase 2: ...)" caveat to reflect that `overlays/unstable-packages.nix`
      already exists.

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `docs/configuration.md` - de-stale the File Structure tree, overlay heading, config/home prose; delete task-66 status blockquote.
- `docs/unstable-packages.md` - delete stale "pending Phase 2" intro note; fix line ~51 caveat.

**Verification**:
- Re-read both docs end-to-end; confirm no remaining "planned"/"pending Phase 2"/"gated on task"
  language, and that every path they reference (`overlays/*.nix`, `lib/mkHost.nix`, `modules/system/`,
  `modules/home/`) exists on disk. Cross-check the rewritten `configuration.nix`/`home.nix` description
  against the actual 19/20-line shim files.

---

### Phase 3: Update stale contributor how-to guides [NOT STARTED]

**Goal**: Rewrite `docs/how-to-add-package.md` and `docs/how-to-add-service.md` so their decision trees
and examples point at the current module locations, not the superseded `configuration.nix`/`home.nix`
workflow.

**Tasks**:
- [ ] `docs/how-to-add-package.md`: rewrite the decision tree (lines ~9, ~13) so `modules/system/packages.nix`
      and `modules/home/packages/*.nix` are the primary (not parenthetical "after Phase 4b/5b") targets;
      fix line ~80 (`overlays/unstable-packages.nix` is a real file, not a "planned Phase 2 artifact");
      fix line ~97 (`overlays/python-packages.nix` is a real standalone file, not "inlined in flake.nix").
- [ ] `docs/how-to-add-service.md`: update all examples and the "Current Services in This Config" table
      (lines ~104-121) to attribute system services to `modules/system/*.nix` (e.g. `services.nix`,
      `optional/discord-bot.nix`) and user services to `modules/home/services/*.nix`; add a short
      subsection naming the optional/host-toggled module pattern (`options.<path>.enable` + `mkIf`,
      per `modules/README.md` and `.claude/rules/nix.md`), pointing at
      `modules/system/optional/discord-bot.nix` as the worked example (which the guide's own
      "Discord-Bot Style Service" section already demonstrates without naming).

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `docs/how-to-add-package.md` - repoint decision tree/examples to modules/; fix overlay-file staleness.
- `docs/how-to-add-service.md` - repoint examples + service table to modules/; document optional/host-toggled pattern.

**Verification**:
- Re-read both guides; confirm every "add it here" location names a path that is actually where that
  kind of declaration now lives (spot-check against `modules/system/packages.nix`,
  `modules/home/packages/`, `modules/system/services.nix`, `modules/system/optional/discord-bot.nix`,
  `modules/home/services/`). Confirm no "planned/after Phase" qualifiers remain on real files.

---

### Phase 4: Correct package-inventory docs [NOT STARTED]

**Goal**: Fix `packages/README.md` and `docs/packages.md` so they describe the actual set of packages
and the actual file locations and Python attribute.

**Tasks**:
- [ ] `packages/README.md`: delete the `marker-pdf.nix` section (lines ~48-59) and its "UVX/UV Wrapper
      Pattern" reference (line ~132) — confirm zero `marker` hits first (`find . -iname "*marker*"`);
      add standalone sections for `opencode.nix`, `kooha.nix`, `slidev.nix` (all real files referenced
      from `overlays/unstable-packages.nix`), following the existing per-file section format; replace all
      5 stale `python312`/`python312Packages` references (lines ~98, 106, 110, 161, 165) with `python3`.
- [ ] `docs/packages.md`: fix line ~14 to reference `overlays/unstable-packages.nix` instead of the
      deleted root-level `unstable-packages.nix`; replace the `python312.withPackages` reference
      (line ~39) with `python3.withPackages`.

**Tasks (verification of ground truth before editing)**:
- [ ] Confirm `packages/opencode.nix`, `packages/kooha.nix`, `packages/slidev.nix` exist and read their
      headers so the new sections describe them accurately.
- [ ] Confirm zero `python312` references remain in any `.nix` file (sanity: `grep -rn python312 --include=*.nix .`).

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `packages/README.md` - remove marker-pdf.nix; add opencode/kooha/slidev sections; python312 -> python3.
- `docs/packages.md` - fix deleted-file reference; python312 -> python3.

**Verification**:
- `grep -n "marker" packages/README.md` returns nothing; new sections exist for opencode/kooha/slidev;
  `grep -rn "python312" docs/packages.md packages/README.md` returns nothing; the `unstable-packages.nix`
  reference in `docs/packages.md` now includes the `overlays/` path prefix and that file exists.

---

### Phase 5: Sweep emoji from eligible documentation files [NOT STARTED]

**Goal**: Remove emoji glyphs from documentation files to satisfy `docs/README.md`'s "No emojis in
documentation files" rule, without touching the deferred files.

**Tasks**:
- [ ] Enumerate emoji occurrences in eligible docs (all of `docs/*.md` EXCEPT `docs/niri.md`,
      `docs/ryzen-ai-300-compatibility.md`, `docs/ryzen-ai-300-support-summary.md`, which are handled/
      deferred in Phase 8). Use the report's scan command:
      `grep -oP '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]' docs/*.md | sort | uniq -c`.
- [ ] Remove emoji glyphs (and any now-orphaned leading spaces) from the eligible files:
      `docs/usb-installer.md`, `docs/himalaya.md`, `docs/how-to-add-package.md`, `docs/discord-bot.md`,
      `docs/how-to-add-service.md`, `docs/wifi.md`, `docs/gnome-settings.md`, `docs/dictation.md`,
      `docs/development.md`, `docs/installation.md`, `docs/unstable-packages.md`. Preserve the
      intentional `<-` / navigation arrows called out in the report (not emoji).
- [ ] Do NOT alter heading meaning or section structure — remove the glyph only.

**Timing**: 45 minutes

**Depends on**: 2, 3

**Files to modify**:
- Eligible `docs/*.md` files listed above (emoji-glyph removal only).

**Verification**:
- Re-run the emoji scan restricted to the eligible files; confirm zero emoji glyphs remain (nav arrows,
  which are outside the scanned ranges, may remain). Spot-read a couple of stripped headings to confirm
  they still read correctly.

---

### Phase 6: Conservative config-comment cleanups [NOT STARTED]

**Goal**: Make only safe, individually-justified comment cleanups in three `.nix` files; verify the
flake still evaluates.

**Tasks**:
- [ ] `modules/system/packages.nix` (lines ~24-35): in the commented-out "For use with Niri without
      Gnome utilities" block, prune only the four items now genuinely configured as home-manager modules
      (`mako`, `waybar`, `kanshi`, `swaylock` — confirm each via the existence of
      `modules/home/desktop/{mako,kanshi,swaylock,waybar}.nix`). Keep the remaining items
      (`grim`, `slurp`, `swayidle`, `network-manager-applet`, `blueman`, `wl-clipboard-x11`, `clipman`)
      since they may be deliberate X11-era exclusions; verify each is genuinely still absent before
      leaving it, and do not add any package.
- [ ] `modules/system/desktop.nix` (line ~70): the stray commented `# core-network.enable = true;` line
      is inconsistent with the well-documented sibling lines below it. Do NOT delete it blindly (its
      validity as a current NixOS option was not confirmed in research). Either (a) add a brief rationale
      comment + spec/task reference matching the sibling `localsearch`/`tinysparql` lines if the intent
      is recoverable, or (b) leave it unchanged and note it in the summary. Default to (b) if intent is
      unclear — do not remove.
- [ ] `home.nix` (lines ~17-19): the two commented-out historical `home.stateVersion` values
      (`24.05`, `23.11`) beneath the active `24.11` line are unexplained clutter. Add a one-line
      clarifying comment (e.g. "history, do not restore — active stateVersion is frozen") rather than
      deleting, to preserve the intentional-history signal. Do NOT touch the active `24.11` value.

**Timing**: 45 minutes (including flake check)

**Depends on**: none

**Files to modify**:
- `modules/system/packages.nix` - prune only the 4 confirmed-configured items from the stale comment block.
- `modules/system/desktop.nix` - document-or-leave the stray `core-network` comment (no deletion).
- `home.nix` - annotate the dead historical stateVersion comment lines (no value change).

**Verification**:
- Run `nix flake check` (note: may be slow) and confirm it passes — comment-only edits must not change
  evaluation. Re-read each edited block to confirm no functional line was altered and no active option
  or `stateVersion` value changed.

---

### Phase 7: Create overlays/README.md [NOT STARTED]

**Goal**: Close the convention gap where `overlays/` (unlike `hosts/`, `modules/`, `packages/`, `config/`)
has no README, giving `flake.nix`'s overlay list an authoritative place to point.

**Tasks**:
- [ ] Read the three overlay files (`overlays/claude-squad.nix`, `overlays/unstable-packages.nix`,
      `overlays/python-packages.nix`) and their header comments.
- [ ] Write `overlays/README.md` mirroring `packages/README.md`'s per-file section format: a short intro
      plus one section per overlay describing its purpose and what it provides. Do not invent behavior;
      describe only what the files actually do.

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `overlays/README.md` - new file (create `overlays/`-level README; the only new file in this plan).

**Verification**:
- Re-read the new README against the three overlay files; confirm each described overlay matches its
  actual content and that the format matches the sibling `packages/README.md`. Confirm the root
  `README.md` "Directory Organization" section's link target (if it references `overlays/`) now resolves.

---

### Phase 8: DEFERRED — user-confirmation items (do NOT execute autonomously) [NOT STARTED]

**Goal**: Record the items the research flagged as requiring user judgment so they are tracked but NOT
acted on under autonomous orchestration. Per the safe interpretation, this phase is documentation-only
of the deferral; no files are changed.

**Tasks** (all deferred — require explicit user confirmation before any action):
- [ ] Ryzen doc consolidation (finding 9): `docs/ryzen-ai-300-compatibility.md` (210 lines) and
      `docs/ryzen-ai-300-support-summary.md` (120 lines) are near-duplicates. Consolidation/deletion may
      remove content the user intentionally keeps as a separate executive summary — confirm with user first.
- [ ] niri "testing phase" framing (finding 10): `docs/niri.md`'s "Recommended Usage Strategy" section
      frames GNOME+PaperWM as the daily driver and niri as "Phase 1: Testing", which appears stale
      against `flake.nix`/overlay "ENABLED (dual-session)" language — but actual daily-driver usage is
      only knowable from the user. Confirm before rewriting.
- [ ] `docs/niri.md` emoji strip (~58 glyphs, 1035-line file): excluded from Phase 5 per the research
      recommendation to give it its own follow-up task; bundling it here risks a large, error-prone edit.
      Recommend a dedicated follow-up task.

**Timing**: 0 (not executed under this orchestration run)

**Depends on**: none

**Files to modify**:
- None. This phase makes no changes; it exists to explicitly document the deferral boundary.

**Verification**:
- Confirm none of `docs/ryzen-ai-300-compatibility.md`, `docs/ryzen-ai-300-support-summary.md`,
  `docs/niri.md` were modified by this task. The implementation summary must state these items were
  deferred and recommend spawning follow-up task(s) for them.

---

## Testing & Validation

- [ ] Phase 1: README CPU annotations agree with both hosts' `hardware-configuration.nix` and with `hosts/README.md`.
- [ ] Phases 2-4: re-read each edited doc; zero remaining "planned"/"pending Phase 2"/"gated on task"
      language; every referenced path exists on disk; no `python312` or `marker-pdf` references remain.
- [ ] Phase 5: emoji scan over eligible docs returns zero glyphs.
- [ ] Phase 6: `nix flake check` passes (may be slow); no functional line or active `stateVersion` changed.
- [ ] Phase 7: `overlays/README.md` accurately describes all three overlays.
- [ ] Phase 8: the three deferred files are unmodified; deferral is recorded in the summary.

## Artifacts & Outputs

- plans/01_nixos-doc-config-improvements.md (this file)
- Modified docs: `README.md`, `docs/configuration.md`, `docs/unstable-packages.md`,
  `docs/how-to-add-package.md`, `docs/how-to-add-service.md`, `docs/packages.md`, `packages/README.md`,
  plus eligible `docs/*.md` emoji sweeps.
- Modified config (comments only): `modules/system/packages.nix`, `modules/system/desktop.nix`, `home.nix`.
- New file: `overlays/README.md`.
- summaries/01_nixos-doc-config-improvements-summary.md (on completion).

## Rollback/Contingency

- All doc edits are independently revertable per-file via `git checkout -- <path>` on a clean tree
  (or snapshot-then-revert if the tree is dirty, per git-workflow.md). Because phases touch disjoint
  files, reverting one phase does not disturb others.
- If `nix flake check` fails after Phase 6, the comment-only edits are the sole suspect: re-inspect the
  three edited `.nix` files, fix forward (restore any accidentally-removed functional line); do not
  discard unrelated uncommitted work to reach green.
- Phase 7's `overlays/README.md` is a new file — rollback is simply deleting it.
- Phase 8 makes no changes, so it has nothing to roll back.

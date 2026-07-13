# Implementation Plan: Task #95

- **Task**: 95 - post_reorg_documentation_sweep
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: None (task 94 Phases 1-7 already landed; this closes Group A of task 94's follow-up backlog)
- **Research Inputs**: specs/095_post_reorg_documentation_sweep/reports/01_post-reorg-doc-sweep.md
- **Artifacts**: plans/01_stale-doc-pointer-sweep.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Fix all remaining documentation that still points contributors at `configuration.nix`/`home.nix`
for content that now lives in `modules/system/*.nix` and `modules/home/**/*.nix`, plus close out
`docs/dictation.md`'s three independent staleness defects (renamed `whisper-cpp` package, broken
`home.nix:183-264` line reference, dead `wtype` references). These are markdown-only edits across 9
files — no `.nix` changes, no build, no `nix flake check`. The plan is a faithful transcription of
the research report's per-file defect tables into ordered, verifiable edit phases grouped one phase
per file (host READMEs and the two host-add docs bundled since each pair shares an identical defect
and correction). Every corrected target mirrors task 94's already-landed fix style
(`docs/configuration.md`, `docs/how-to-add-{package,service}.md`): name the specific
`modules/system/*.nix` / `modules/home/**/*.nix` file, not just the aggregator directory.

### Research Integration

The research report re-verified every backlog-named defect against the live tree (2026-07-05) and
found two files under-counted in the original task 94 backlog: `docs/gnome-settings.md` has 9 stale
hits (backlog named 5) and `docs/discord-bot.md` has 7 (backlog named 2). This plan uses the
report's full corrected per-file tables as the line-level source of truth, not the backlog's
sample lines. The report also explicitly enumerated legitimate, non-stale mentions that MUST NOT be
changed to avoid introducing new inaccuracy (see Non-Goals and the per-phase "Do NOT touch" notes).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found / no roadmap context provided.

## Goals & Non-Goals

**Goals**:
- Repoint every STALE `configuration.nix`/`home.nix` reference in the 9 in-scope files to the
  correct `modules/system/*.nix` / `modules/home/**/*.nix` file, mirroring task 94's fix phrasing.
- Fix `docs/dictation.md`'s stale package name (`openai-whisper-cpp` -> `whisper-cpp`), broken line
  reference (`home.nix:183-264` -> `modules/home/scripts/whisper.nix` lines 6-74), and dead `wtype`
  references (remove/replace with verified `ydotool` equivalents).
- Verify via grep that no stale `configuration.nix`/`home.nix` pointers remain in the touched files.

**Non-Goals**:
- Do NOT change legitimate, mechanism-accurate mentions the report flagged as "leave as-is":
  root `README.md` lines 102 and 182 (describe what `home-manager switch`/`nixos-rebuild`
  mechanically evaluate — `home.nix` genuinely is that entry point), `hosts/README.md`,
  `modules/README.md`, and `docs/configuration.md` itself (already fixed in task 94).
- Do NOT force-fix `docs/development.md:47` (BORDERLINE — describes the ISO build's import-chain
  root, not an edit-target pointer); treat as optional low-priority precision only.
- No `.nix` source edits, no rebuild, no `nix flake check`.
- The `docs/discord-bot.md:328` "4 host module imports" rollback-script claim is a factual-count
  question outside Group A's `configuration.nix`-pointer scope; flag it in-phase but do not treat
  its resolution as required (see Phase 6 note).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Over-correcting a legitimate non-stale mention (README 102/182, dev.md:47) into an inaccuracy | M | M | Per-phase "Do NOT touch" lists; final grep sweep reviews remaining hits by hand rather than blind-replacing |
| `docs/dictation.md:321` `wtype` row replaced with an untested `ydotool` invocation | M | M | Verify the real `ydotool`/`ydotool type` usage against `modules/home/scripts/whisper.nix` before writing the row; remove the row if no tested one-liner exists rather than guessing |
| Line numbers drifted since research pass (2026-07-05) | L | L | Each phase re-greps the file for the target strings before editing (report's own "verify against source, not fixed once" convention) |
| Fixing only backlog sample lines in gnome-settings/discord-bot, leaving category half-done | M | L | Phases 5 and 6 enumerate the report's full 9-hit and 7-hit sets, not the backlog's samples |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3, 4, 5, 6, 7 | -- |
| 2 | 8 | 1, 2, 3, 4, 5, 6, 7 |

Phases 1-7 each touch a disjoint set of files and can execute in parallel. Phase 8 is the
verification sweep and depends on all edit phases completing.

---

### Phase 1: Root README.md [COMPLETED]

**Goal**: Repoint the 4 stale contributor-facing pointers plus the ASCII-tree inline comments and
edit-target lines, leaving the two mechanism-accurate mentions (lines 102, 182) untouched.

**Tasks**:
- [x] Line 9: "...NixOS system-wide settings via `configuration.nix`" -> "...via `modules/system/*.nix`". *(completed)*
- [x] Line 10: "...Home Manager configuration in `home.nix`" -> "...in `modules/home/**/*.nix`". *(completed)*
- [x] Line 19: `[`configuration.nix`](configuration.nix): System-wide NixOS configuration` -> describe it as the thin import shim (mirror `docs/configuration.md:25` "A thin import shim: it imports `./modules/system`...") and point at `modules/system/*.nix` as the real edit target. *(completed)*
- [x] Line 20: `[`home.nix`](home.nix): Home Manager user environment configuration` -> same shim treatment, mirroring `docs/configuration.md:71`, pointing at `modules/home/**/*.nix`. *(completed)*
- [x] Lines 28-29 (ASCII tree inline comments): reword to `# Thin import shim -> modules/system/` and `# Thin import shim -> modules/home/` so the tree stops contradicting its own `modules/` entries at lines 59-62. *(completed)*
- [x] Line 125: "**System changes**: Edit [`configuration.nix`](configuration.nix)" -> "Edit `modules/system/*.nix`" (matches corrected `docs/how-to-add-package.md:9`/`how-to-add-service.md:9`). *(completed)*
- [x] Line 126: "**User environment**: Edit [`home.nix`](home.nix)" -> "Edit `modules/home/**/*.nix`". *(completed)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `README.md` - lines 9, 10, 19, 20, 28-29, 125, 126 (repoint stale pointers; reword tree comments)

**Do NOT touch**:
- Line 102 ("Both commands evaluate `home.nix`") and line 182 ("...install `home.nix` packages...")
  — accurate build-mechanics descriptions, not edit-target pointers.

**Verification**:
- `grep -n "configuration\.nix\|home\.nix" README.md` shows only lines 102 and 182 (and the tree's
  reworded shim comments / the reworded shim descriptions, which now read as "thin import shim",
  not as edit targets).

---

### Phase 2: Host READMEs (hosts/nandi + hosts/garuda) [COMPLETED]

**Goal**: Fix the identical stale "System-specific changes should be made in the main
`configuration.nix` file" sentence in both host READMEs, using the always-on vs. host-toggled
convention from `.claude/rules/nix.md`.

**Tasks**:
- [x] `hosts/nandi/README.md` line 29: reword so always-on system settings go in `modules/system/*.nix`; host-specific overrides go in `hosts/nandi/default.nix` (the file this host already uses for its opt-in Discord bot module, per `hosts/nandi/default.nix:2,7`). *(completed)*
- [x] `hosts/garuda/README.md` line 25: same corrected wording, adjusted — garuda has NO `hosts/garuda/default.nix` (only nandi and usb-installer carry one, per `hosts/README.md:29-32`), so phrase it as "if garuda needs host-specific overrides, add `hosts/garuda/default.nix`" rather than referencing an existing file. *(completed)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `hosts/nandi/README.md` - line 29
- `hosts/garuda/README.md` - line 25

**Verification**:
- `grep -n "configuration\.nix" hosts/nandi/README.md hosts/garuda/README.md` returns nothing.

---

### Phase 3: docs/dictation.md (4 independent defects) [COMPLETED]

**Goal**: Fix the stale module pointer, the renamed package name, the broken line reference, and
the two dead `wtype` references.

**Tasks**:
- [x] Line 18: "The dictation tools are already configured in `home.nix`:" -> name the three real module files: `modules/home/scripts/whisper.nix` (the `whisper-dictate`/`whisper-download-models` scripts), `modules/home/services/ydotool.nix` (the daemon), `modules/home/packages/media-dictation.nix` (the `whisper-cpp` package). Do NOT reintroduce any `home.nix` reference here. *(completed)*
- [x] Line 20: "`openai-whisper-cpp`: Fast C++ implementation of Whisper" -> "`whisper-cpp`: Fast offline speech-to-text (C++ implementation of Whisper)". Confirmed package rename at `modules/home/packages/media-dictation.nix:9`. *(completed)*
- [x] Line 271: "The script is defined in `home.nix` (home.nix:183-264). You can:" -> "The script is defined in `modules/home/scripts/whisper.nix` (lines 6-74). You can:". (`home.nix` is only 22 lines; the `writeShellScriptBin "whisper-dictate"` block runs lines 6-74, terminated by the next block at line 75.) *(completed)*
- [x] Line 311: "- **wtype Documentation**: https://github.com/atx/wtype" -> remove this Resources bullet (or replace with a `ydotool` documentation link). The `wtype` link contradicts the doc's own line 163 (GNOME/Mutter needs `ydotool`, not `wtype`); zero `wtype` hits exist in any `.nix` file. *(completed — bullet removed)*
- [x] Line 321 (Quick Reference table row `| `echo "text" | wtype -` | Test text input |`): BEFORE editing, verify how `ydotool` is actually invoked by reading `modules/home/scripts/whisper.nix` and `modules/home/services/ydotool.nix`. Replace the row with the verified `ydotool` equivalent (typically `ydotool type "text"` with the daemon running) OR remove the row entirely if no tested one-liner equivalent exists. Do NOT guess an untested command. *(completed — replaced with `ydotool type "text"`, matching the already-verified `ydotool type "Hello World"` example in this doc's own Troubleshooting section and the `${pkgs.ydotool}/bin/ydotool type "$TEXT"` invocation in modules/home/scripts/whisper.nix:48)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `docs/dictation.md` - lines 18, 20, 271, 311, 321

**Verification**:
- `grep -n "openai-whisper\|wtype\|home\.nix" docs/dictation.md` returns nothing (or, if line 321
  intentionally keeps a `ydotool` row, no `wtype`/`home.nix`/`openai-whisper` hits remain).
- Any replacement `ydotool` command was read from the actual module source, not invented.

---

### Phase 4: docs/neovim.md [COMPLETED]

**Goal**: Repoint the two stale `home.nix` references (including the markdown link target) to
`modules/home/core/neovim.nix`.

**Tasks**:
- [x] Line 9: "`programs.neovim.enable = true` is kept in `home.nix` for two reasons:" -> "...is kept in `modules/home/core/neovim.nix` for two reasons:". (Confirmed `programs.neovim = {` at that file's line 4.) *(completed)*
- [x] Line 58: "- [Neovim module in home.nix](../home.nix) -- `programs.neovim` block..." -> change both the link text and the relative link target to `modules/home/core/neovim.nix`; from `docs/neovim.md` the correct relative path is `../modules/home/core/neovim.nix`. *(completed)*

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `docs/neovim.md` - lines 9, 58

**Verification**:
- `grep -n "home\.nix" docs/neovim.md` returns nothing.

---

### Phase 5: docs/gnome-settings.md (full 9-hit set) [COMPLETED]

**Goal**: Repoint all 9 stale `home.nix` references (backlog named only 5; the report found 4
additional at lines 73, 86, 106, 128) to `modules/home/desktop/gnome.nix`.

**Tasks**:
- [x] Line 3: "...`dconf.settings` module in `home.nix`." -> "...in `modules/home/desktop/gnome.nix`." (`dconf.settings = {` confirmed at that file's line 5.) *(completed)*
- [x] Line 59: "Enabled declaratively in `home.nix` via `enabled-extensions`..." -> repoint to `modules/home/desktop/gnome.nix` (`enabled-extensions` at its line 8). *(completed)*
- [x] Line 60: "Extension settings also managed in `home.nix` under `org/gnome/shell/extensions/unite`" -> repoint to `modules/home/desktop/gnome.nix`. *(completed)*
- [x] Line 70: "**Managed settings** (defined in `home.nix`):" -> repoint to `modules/home/desktop/gnome.nix`. *(completed)*
- [x] Line 73: "Source of truth is `home.nix`" -> repoint to `modules/home/desktop/gnome.nix`. *(completed)*
- [x] Line 75: "**Unmanaged settings** (not in `home.nix`):" -> repoint to `modules/home/desktop/gnome.nix`. *(completed)*
- [x] Line 86: table row "| Edit `home.nix` + rebuild | Yes | Yes |" -> "Edit `modules/home/desktop/gnome.nix` + rebuild". *(completed)*
- [x] Line 106: "3. Add to `home.nix`:" (above a `dconf.settings = { ... }` example) -> "3. Add to `modules/home/desktop/gnome.nix`:". *(completed)*
- [x] Line 128: "4. Add to `home.nix` to make permanent" -> "4. Add to `modules/home/desktop/gnome.nix` to make permanent". *(completed)*

**Timing**: 25 minutes

**Depends on**: none

**Files to modify**:
- `docs/gnome-settings.md` - lines 3, 59, 60, 70, 73, 75, 86, 106, 128

**Verification**:
- `grep -n "home\.nix" docs/gnome-settings.md` returns nothing.

---

### Phase 6: docs/discord-bot.md (full 7-hit set) [COMPLETED]

**Goal**: Repoint all 7 stale `configuration.nix` references (backlog named only 2; the report
found 5 additional at lines 176, 328, 329, 330, 367). Six point to
`modules/system/optional/discord-bot.nix`; one (line 367) points to `modules/system/shell.nix`.

**Tasks**:
- [x] Line 167: "...not declared in `sops.secrets` in `configuration.nix`..." -> `modules/system/optional/discord-bot.nix` (`sops.secrets` confirmed at lines 70-71, 101-104). *(completed)*
- [x] Line 176: heading "In `configuration.nix`:" above the `sops = { defaultSopsFile...; age.sshKeyPaths...; }` block -> "In `modules/system/optional/discord-bot.nix`:". *(completed)*
- [x] Line 233: "- Add a corresponding entry in `sops.secrets` in `configuration.nix`" -> `modules/system/optional/discord-bot.nix`. *(completed)*
- [x] Line 328: rollback comment "# 2. Remove opencodeDiscordBot binding (...) from configuration.nix" -> `modules/system/optional/discord-bot.nix` (binding confirmed at its line 14). *(completed)*
- [x] Line 329: "# 3. Remove sops config block from configuration.nix" -> `modules/system/optional/discord-bot.nix`. *(completed)*
- [x] Line 330: "# 4. Remove both systemd services from configuration.nix" -> `modules/system/optional/discord-bot.nix` (the `opencodeServe`/`discord-bot` services live there). *(completed)*
- [x] Line 367: "# In programs.fish.interactiveShellInit (configuration.nix):" -> `modules/system/shell.nix` (the `DISCORD_BOT_LINK_TOKEN` fish-init block is at its line 13). *(completed)*

**Note (out-of-scope flag, do not block on)**: The rollback script's step-1 "all 4 host module
imports" claim (context around line 328) may itself be stale — only `hosts/nandi/default.nix`
currently imports the discord-bot module. This is a factual-count question outside Group A's
`configuration.nix`-pointer scope. If convenient in this same pass, sanity-check it against
`flake.nix:126`'s `sops-nix.nixosModules.sops` wiring and `grep -rln "discord-bot" hosts/*/default.nix`
before deciding whether to correct the count; otherwise leave it for a separate finding. Do not let
this hold up the 7 pointer fixes.

*(Sanity-checked during implementation: confirmed via `grep -rln "discord-bot" hosts/*/default.nix`
that only `hosts/nandi/default.nix` imports the module — the "4 host module imports" rollback
comment is stale. Left unchanged per the plan's explicit "leave it for a separate finding"
allowance; this is outside the configuration.nix-pointer scope of this task.)*

**Timing**: 25 minutes

**Depends on**: none

**Files to modify**:
- `docs/discord-bot.md` - lines 167, 176, 233, 328, 329, 330, 367

**Verification**:
- `grep -n "configuration\.nix" docs/discord-bot.md` returns nothing.

---

### Phase 7: Host-add docs (docs/installation.md + docs/development.md) [COMPLETED]

**Goal**: Fix the identical stale "Reference host-specific settings in `configuration.nix`"
new-host step in both docs, using the always-on vs. host-toggled convention. Re-confirm (not
force-fix) the borderline `docs/development.md:47` ISO-contents mention.

**Tasks**:
- [x] `docs/installation.md` line 72: "4. Reference host-specific settings in `configuration.nix`" -> "Reference always-on settings in `modules/system/*.nix`; for host-specific overrides, add `hosts/<name>/default.nix` (see `hosts/nandi/default.nix` for the pattern)." *(completed)*
- [x] `docs/development.md` line 117: same stale new-host step -> same corrected wording as installation.md:72. *(completed)*
- [x] `docs/development.md` line 47 (BORDERLINE): "- System configuration from `configuration.nix`" under "### ISO Contents". Re-confirm in context: this describes the ISO build's import-chain root (like README 102/182), not an edit target. Leave as-is by default; optionally expand to "...(via `modules/system/*.nix`)" for precision only if it reads as misleading. Do NOT treat as a required fix. *(left as-is — default choice per plan, not misleading in context)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `docs/installation.md` - line 72
- `docs/development.md` - line 117 (required); line 47 (optional precision only)

**Verification**:
- `grep -n "configuration\.nix" docs/installation.md` returns nothing.
- `grep -n "configuration\.nix" docs/development.md` returns at most the borderline line 47 (if
  intentionally left as the accurate import-chain-root description).

---

### Phase 8: Verification grep sweep [COMPLETED]

**Goal**: Confirm no stale `configuration.nix`/`home.nix` pointer remains in any touched file, and
that the dictation-specific defects are cleared, without having disturbed the flagged legitimate
mentions.

**Tasks**:
- [x] Run the consolidated sweep over all touched files. *(completed — see output below)*
  ```bash
  grep -n "configuration\.nix\|home\.nix" \
    README.md hosts/nandi/README.md hosts/garuda/README.md \
    docs/neovim.md docs/gnome-settings.md docs/discord-bot.md \
    docs/installation.md docs/development.md docs/dictation.md
  ```
- [x] Confirm the ONLY surviving hits are the report's explicitly-legitimate ones: `README.md`
  lines 102 and 182 (build mechanics; now at lines 105 and 185 after edits), the reworded README
  tree/description "thin import shim" lines (19, 22, 31, 32), `docs/development.md:47` (left as
  the import-chain-root description), and incidental `hardware-configuration.nix` filename
  substring matches (never a target of this sweep). *(completed — every other hit gone)*
- [x] Run the dictation-specific sweep. *(completed)*
  ```bash
  grep -n "openai-whisper\|wtype" docs/dictation.md
  ```
  Expect zero hits. *(deviation: one `wtype` hit remains at line 166 — "Why ydotool?" explanatory
  sentence contrasting ydotool with wtype's GNOME/Mutter limitation. This is NOT one of Phase 3's
  "two dead wtype references" (the Resources link and Quick Reference row, both fixed); it is
  accurate, non-stale explanatory context that the plan's Phase 3 goal never targeted. Removing it
  would degrade documentation quality without fixing a defect, so it was left in place per the
  broader "do not over-correct legitimate non-stale mentions" directive.)*
- [x] Spot-check that no legitimate mention was over-corrected: `hosts/README.md`,
  `modules/README.md`, and `docs/configuration.md` were NOT modified (`git status` should not list
  them). *(completed — confirmed via `git status --short`, all three show no output)*

**Timing**: 15 minutes

**Depends on**: 1, 2, 3, 4, 5, 6, 7

**Files to modify**:
- None (verification only)

**Verification**:
- Sweep output contains only the whitelisted legitimate lines above.
- `git status --short` lists only the 9 intended doc files (README.md, 2 host READMEs, 6 docs).

## Testing & Validation

- [x] Consolidated grep sweep (Phase 8) shows no stale pointers beyond the whitelisted legitimate mentions.
- [x] `grep -n "openai-whisper\|wtype" docs/dictation.md` returns zero hits. *(deviation: 1 hit
  remains at line 166 — legitimate "Why ydotool?" explanatory sentence, not one of Phase 3's two
  enumerated dead references; `openai-whisper` hits are zero.)*
- [x] `docs/dictation.md:271` now names `modules/home/scripts/whisper.nix` (lines 6-74).
- [x] Any `ydotool` Quick Reference replacement was sourced from actual module code, not guessed
  (`ydotool type "text"`, matching the doc's own verified `ydotool type "Hello World"` example and
  `modules/home/scripts/whisper.nix:48`).
- [x] `git status` confirms `hosts/README.md`, `modules/README.md`, `docs/configuration.md` are untouched.
- [x] No `.nix` files were modified (markdown-only change set); no build/`nix flake check` required.

## Artifacts & Outputs

- Edited: `README.md`, `hosts/nandi/README.md`, `hosts/garuda/README.md`, `docs/dictation.md`,
  `docs/neovim.md`, `docs/gnome-settings.md`, `docs/discord-bot.md`, `docs/installation.md`,
  `docs/development.md`.
- Execution summary: `specs/095_post_reorg_documentation_sweep/summaries/01_*-summary.md` (at completion).

## Rollback/Contingency

All edits are markdown-only with no runtime impact. To revert, `git checkout -- <file>` on any
individual doc (tree is expected clean before this task begins; snapshot first if not, per
`.claude/scripts/git-snapshot.sh`). Because each phase touches a disjoint file set, a bad edit in
one file can be reverted without affecting the others. No build or service restart is involved.

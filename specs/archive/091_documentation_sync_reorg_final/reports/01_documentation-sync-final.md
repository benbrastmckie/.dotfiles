# Research Report: Task #91

**Task**: 91 - Final documentation sync across the NixOS/Home Manager dotfiles repo (capstone,
parent_task 81, blueprint row 10)
**Started**: 2026-07-05T00:00:00Z
**Completed**: 2026-07-05T00:00:00Z
**Effort**: Small-medium (doc-only, no nix source changes)
**Dependencies**: 82, 83, 84, 85, 86, 87, 88, 89, 90 — all `completed` per `specs/state.json`
**Sources/Inputs**:
- Codebase: `README.md`, `docs/`, `modules/`, `hosts/`, `packages/`, `flake.lock`, `configuration.nix`, `home.nix`, `.claude/rules/nix.md`
- `specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md`
- `specs/081_.../reports/02_team-research.md`
- `specs/081_.../design/target-layout.md` (§2, §3, §4, §5, §6)
- `specs/state.json` (task 66, 78, 81-91 status/dependency checks)
**Artifacts**: This report — `specs/091_documentation_sync_reorg_final/reports/01_documentation-sync-final.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All 9 gating subtasks (82-90) are `completed`. The repo tree has moved substantially since
  the original `01_repo-organization-review.md` seed: `modules/` now has `system/` and `home/`
  subtrees each with a `default.nix` aggregator, `home-modules/` is gone, `modules/opencode.nix`
  is gone, `packages/neovim.nix` is gone, `packages/piper-bin.nix`/`piper-voices.nix` exist,
  `hosts/README.md` was already rewritten to the `mkHost` pattern (task 87) and is accurate,
  `docs/dual-home-manager.md` already contains the task-69 closure text (added by task 69's own
  implementation) — task 91 only needs a short confirming note, not new content.
- Root `README.md`'s Module Map (lines 23-105) is stale in more ways than the two items named in
  the task description: the ASCII tree still shows the pre-task-86/87/88 flat `modules/system/*`
  layout with no aggregators, still lists a standalone `modules/opencode.nix` (deleted), still
  lists a `home-modules/` bullet in "Directory Organization" (directory no longer exists), and
  has no bullet at all pointing to a `modules/README.md`. All of this must be resynced, not just
  the "(planned: task 66 ...)" annotations and the `neovim.nix`/`piper-*.nix` package-list swap.
- `docs/README.md` is missing exactly the 6 files named in the task description — confirmed
  present on disk, confirmed absent from the index (verified by direct diff below).
- `modules/README.md` does not exist yet; `modules/system/default.nix` and `modules/home/default.nix`
  are real, present aggregators with descriptive header comments already explaining the
  always-on/optional split — the new README should draw directly from that existing prose plus
  the `optional/` convention captured in `hosts/nandi/default.nix` and `.claude/rules/nix.md`
  §"Optional / Host-Toggled Modules" (line 39).
- `flake.lock` health and `stateVersion` are both confirmed non-issues at their current values —
  ready to record as one-line "checked, no action needed" notes.
- **Drift-check bonus findings** (out of task 91's named scope, but requested by the "README-vs-
  find drift check"): `packages/README.md` documents a `marker-pdf.nix` package that does not
  exist anywhere in the repo (verified via `find . -iname "*marker*"` — zero hits outside
  `.claude/`/`.opencode/` boilerplate), and is missing entries for `kooha.nix`, `opencode.nix`,
  `slidev.nix`; `docs/configuration.md:20` still says `modules/` is a "Stub scaffold
  (opencode.nix; home-modules/ stubs)"; `docs/unstable-packages.md:12` still says
  `overlays/unstable-packages.nix` is "(planned: ... after task 66 Phase 2)" though it has existed
  and been wired into `flake.nix:59` since task 66 completed. These are recommended as either an
  opportunistic same-task fix (cheap, doc-only, same verification level) or a follow-up
  `/fix-it`/spawned task — see Decisions below.

## Context & Scope

Task 91 is the Final-tier capstone of task 81's 10-subtask reorg blueprint (blueprint row 10,
`design/target-layout.md` §3), gated on all of subtasks 82-90. Its job is to make the repo's
documentation match the tree those 9 subtasks produced — it makes no `.nix` source changes.
Verification level is "full regression" (`nix flake check` + nandi/hamsa/garuda builds + HM
activation, per the task-66/81 harness) plus a manual README-vs-`find` drift check, run once at
implement time as the final check across the whole task-81 lineage.

## Findings

### 1. Root README.md Module Map — exact lines and required changes

Read in full: `README.md` lines 1-120.

**Stale "(planned: task 66 ...)" annotations to drop** (task 66 status is `completed` — confirmed
via `jq '.active_projects[] | select(.project_number==66)' specs/state.json`):
- Line 49: `├── overlays/                      # (planned: task 66 Phase 2)`
- Line 54: `├── lib/                           # (planned: task 66 Phase 3)`
- Line 59: `│   └── system/                    # (planned: task 66 Phases 4a/4b)`
- Lines 84-85 (the explanatory note block):
  ```
  > **Note**: Directories marked "(planned: task 66)" contain planned targets that will be
  > created once tasks 62 and 65 complete (the implementation gate for Phases 2-6).
  ```
  This whole note should be removed (or replaced) — there are no more "(planned: task 66)"
  markers left once the three above are dropped.

**Package list (lines 37-47)**: current list does NOT include `neovim.nix` already — confirmed
via `grep -n "neovim.nix" README.md` returning nothing in that block; `packages/*.nix` on disk
(13 files) confirms `neovim.nix` is gone (removed by subtask 82, per task 91's own description —
verified independently, not just asserted). **However** the list is missing `piper-bin.nix` and
`piper-voices.nix` (both exist on disk, confirmed via `ls packages/*.nix`) and also
`opencode-discord-bot.nix` (added by subtask 89, also absent from this list). All three should be
added.

**Beyond the two named items — the `modules/` subtree in the ASCII diagram (lines 57-73) is
entirely obsolete**, not just its "(planned: task 66)" tag:
```
├── modules/
│   ├── opencode.nix               # OpenCode Home Manager module (standalone)
│   └── system/                    # (planned: task 66 Phases 4a/4b)
│       ├── boot.nix
│       ...
│       └── optional/
│           └── discord-bot.nix
```
Current reality (verified via `find modules -maxdepth 3`):
- `modules/opencode.nix` does not exist (`opencode` is now split across `packages/opencode.nix`,
  `modules/system/packages.nix`, `modules/home/core/dotfiles.nix`,
  `modules/home/memory/monitor.nix`, and `modules/system/optional/discord-bot.nix`'s
  `opencode-serve` service — there is no single standalone Home Manager module file for it
  anymore).
- `modules/system/` has 12 files plus `default.nix` (the subtask-86 aggregator) plus
  `optional/discord-bot.nix`.
- `modules/home/` is a new subtree entirely absent from the current README diagram: `core/`
  (`dotfiles.nix`, `git.nix`, `neovim.nix`, `xdg.nix`), `desktop/` (5 files), `email/` (4 files +
  `agent-tools/` with 6 files), `memory/` (2 files), `misc.nix`, `packages/` (5 files),
  `scripts/` (3 files), `services/` (4 files), plus `default.nix` (the subtask-86 aggregator).
- `home-modules/` (README lines 75-76, and the "Directory Organization" bullet at line 91) no
  longer exists on disk at all (`test -d home-modules` → does not exist).

**Recommendation**: replace the entire `modules/` block in the ASCII tree with a short pointer
form (2-3 lines: `modules/system/`, `modules/home/`, cross-reference to the new
`modules/README.md` for the full breakdown) rather than re-enumerating ~35 files inline — mirrors
how `config/`, `docs/`, `hosts/`, `packages/` are already handled via the "Directory
Organization" bullet list (lines 87-93) rather than full inline enumeration. Remove the
`home-modules/` bullet (line 91) from that list (dead link, directory gone) and add a `modules/`
bullet pointing at the new `modules/README.md`.

### 2. docs/README.md index — disk vs. index diff

`ls docs/` (24 files) vs. `docs/README.md`'s "Documentation Files" section (full file read):

| File on disk | In docs/README.md index? |
|---|---|
| applications.md | Yes |
| configuration.md | Yes |
| development.md | Yes |
| dictation.md | Yes |
| discord-bot.md | Yes |
| **dual-home-manager.md** | **No** |
| **email-workflow.md** | **No** |
| **gnome-settings.md** | **No** |
| himalaya.md | Yes |
| **how-to-add-package.md** | **No** |
| **how-to-add-service.md** | **No** |
| installation.md | Yes |
| neovim.md | Yes |
| niri.md | Yes |
| packages.md | Yes |
| ryzen-ai-300-compatibility.md | Yes |
| ryzen-ai-300-support-summary.md | Yes |
| terminal.md | Yes |
| testing.md | Yes |
| unstable-packages.md | Yes |
| usb-installer.md | Yes |
| **video-editing.md** | **No** |
| wifi.md | Yes |

All 6 files named in the task description are confirmed present on disk and confirmed absent
from the index — exactly matching the task's claim, no surprises. Suggested categories based on
content-adjacent existing sections: `dual-home-manager.md` and `how-to-add-package.md`/
`how-to-add-service.md` fit naturally under a "Configuration & Architecture" grouping near
`configuration.md`; `email-workflow.md` fits near `himalaya.md`; `gnome-settings.md` fits near
`applications.md`/`niri.md`; `video-editing.md` fits near `dictation.md` (both are
media/desktop-workflow docs). Exact heading names are an implementation-time judgment call, not
fixed by any seed document.

### 3. New modules/README.md — actual structure to document

Verified via `find modules -type f` (43 files total) and reading both aggregators in full:

- **`modules/system/default.nix`** (read in full): header comment already states the
  always-on/optional split policy explicitly — "Optional/host-toggled modules (e.g.
  `optional/discord-bot.nix`) are deliberately NOT imported here — they are opt-in per host via
  `hosts/<name>/default.nix` + `extraModules` in `flake.nix`." Imports 12 files
  (`boot.nix networking.nix locale.nix desktop.nix services.nix audio.nix power.nix users.nix
  nix.nix display.nix packages.nix shell.nix`), explicitly excluding `optional/`.
- **`modules/home/default.nix`** (read in full): imports grouped by category with inline section
  comments already in the file — Core (`core/git.nix core/neovim.nix core/dotfiles.nix
  core/xdg.nix`), Desktop (5 files), Email (`mbsync.nix protonmail.nix notmuch.nix aerc.nix` +
  directory-import `email/agent-tools`), Packages (5 files), Scripts (3 files), Services
  (4 files), Memory (`memory/monitor.nix memory/services.nix`), and top-level `misc.nix`.
- **`modules/system/optional/`**: contains exactly one file today, `discord-bot.nix`. It defines
  `options.services.discordBot.enable` (an `mkEnableOption`) and gates all of its `config` under
  `lib.mkIf cfg.enable` — the concrete example of the "optional module" convention. It is wired
  in per-host via `hosts/nandi/default.nix` (`imports = [ ../../modules/system/optional/discord-bot.nix
  ]; services.discordBot.enable = true;`) and `flake.nix`'s `extraModules` for the `nandi`
  `mkHost` call — hamsa/garuda/iso do not import it. `modules/home/` has **no** `optional/`
  subdirectory today (verified: `find modules -type d -name optional` returns only
  `modules/system/optional`) — the README should note the convention exists on the system side
  only so far, not imply parity that doesn't exist yet.
- `.claude/rules/nix.md` line 39 has a "Optional / Host-Toggled Modules" section (not read in
  full here, but confirmed present) that the new `modules/README.md` should cross-reference
  rather than duplicate, per this repo's existing "inline vs. docs/" convention
  (`docs/README.md`'s own "Documentation Conventions" section).

**Recommended modules/README.md sections** (structure only, not prose): overview of the
`system/`+`home/` split and why (mirrors NixOS vs. Home Manager's own config-vs-user-environment
split, matches root `README.md`'s "System Configuration"/"User Environment" framing already at
lines 9-10); the aggregator convention (`default.nix` per subtree, one import per module,
grouped/commented by category — cite the two files verbatim as the live example rather than
re-describing their contents from scratch); the always-on vs. optional distinction and
`optional/`'s current single-file, system-only scope; a cross-reference to
`.claude/rules/nix.md`'s "Optional / Host-Toggled Modules" for the full policy; a short
per-subdirectory index (`core/`, `desktop/`, `email/` + `email/agent-tools/`, `memory/`,
`packages/`, `scripts/`, `services/` for `home/`; the 12 flat files + `optional/` for `system/`).

### 4. flake.lock health + stateVersion values

- `flake.lock`: JSON schema `version: 7`, `root: "root"`, 26 nodes total, including 5
  nixpkgs-family pins (`nixpkgs`, `nixpkgs_2`, `nixpkgs-old`, `nixpkgs-older`,
  `nixpkgs-unstable`) plus transitive `systems`/`utils` duplicates (`systems_2`..`systems_4`,
  `utils_2`) pulled in by different flake inputs' own lockfiles. This is the exact shape the
  Critic in report 02 (Coverage Gap #6) already verified as healthy/intentional — multiple
  nixpkgs pins are expected for a flake with several independently-versioned inputs (e.g. `lean4`,
  `niri`, `nix-ai-tools` each pin their own nixpkgs transitively), not lock corruption or an
  unintended duplicate. **One-line note to record**: "flake.lock's multiple nixpkgs/systems/utils
  pins (26 nodes total) are expected transitive duplication from independently-versioned flake
  inputs, not corruption — checked, no action needed."
- `stateVersion`: `configuration.nix:18` → `system.stateVersion = "24.11";`; `home.nix:17` →
  `home.stateVersion = "24.11";` (with two commented-out historical values at lines 18-19,
  `"24.05"` and `"23.11"`, left as a visible changelog per the file's own comment "Please read
  the comment before changing"). Both live values match each other (`24.11` == `24.11`) — no
  system/home-manager stateVersion skew. **One-line note to record**: "`stateVersion` is `24.11`
  in both `configuration.nix` and `home.nix` (matched, frozen since original install per NixOS/HM
  convention — never bump to 'update') — checked, no action needed."

### 5. Task 69 dual-home-manager doc closure — already resolved

`docs/dual-home-manager.md` (read in full) already contains a dedicated bullet under
"Consequences of the Dual Setup": **"extraSpecialArgs unified (task 69)"**, which documents in
detail that task 69 fixed the `lectic` value-resolution asymmetry between the NixOS-integrated
and standalone home-manager paths (previously the NixOS-integrated path installed an inert,
unbuilt `lectic` flake-input reference; task 69 applied the standalone path's existing resolution
expression everywhere). The file's "Current Recommendation" section also already states "Keep
both paths (Option A)" as the resolution to the Option A/B/C question raised in
`target-layout.md` §5 Gap #8. **This means task 69's documentation-only closure is fully done
already** (most likely landed as part of task 69's own implementation, not subtask 86). Task 91
only needs a short confirming note — e.g. a one-line addition near the top of
`docs/dual-home-manager.md` or in the new `modules/README.md`'s home-manager-adjacent section
stating "Task 69's dual-home-manager `extraSpecialArgs` asymmetry and the Option A/B/C question
are both closed and documented above/here — verified current as of task 91, no further action" —
rather than writing new resolution content from scratch.

### 6. "Docs verified against source, not fixed once" convention

No file in the repo currently states this convention explicitly by that phrase (confirmed via
targeted greps of `docs/README.md`, `README.md`, and `.claude/rules/`) — it exists today only as
language in `target-layout.md` §5 Gap #9 and §3 blueprint row 10 ("Establish a 'docs verified
against source, not fixed once' convention that task 78 can cite (not merge with)"). Task 91
should be the first place this convention is written down verbatim, most naturally as a new
subsection in `docs/README.md`'s existing "Documentation Conventions" section (which already has
"Inline comments", "Cross-references to docs/", "Inline vs. docs/", "Adding new docs/ files", and
"Prohibited practices" subsections — this is a fifth, sibling subsection, not a new file).
Confirmed via `specs/state.json`: task 78 has `dependencies: [74, 75, 76, 77]` and
`parent_task: null` — it does **not** depend on 81 or 91, matching the design's explicit
"adopt-but-not-merge" instruction (no dependency-graph change is needed or expected; task 78 just
cites the convention prose once task 91 lands it).

### Additional Drift Findings (outside task 91's named scope)

Found via the requested README-vs-`find` drift check across the tree, beyond the 3 named
targets:

1. **`packages/README.md` documents a nonexistent `marker-pdf.nix`.** Two sections
   (`## UVX/UV Wrapper Pattern` bullet list and its own `### marker-pdf.nix` subsection, both
   read in full) describe a `marker-pdf.nix` package. `find . -iname "*marker*"` (excluding
   `.git/`) returns zero matches anywhere in the tree except unrelated `.claude/`/`.opencode/`
   status-marker docs. `packages/README.md` is also missing standalone sections for `kooha.nix`,
   `opencode.nix`, and `slidev.nix` (all three exist in `packages/*.nix` but have no matching
   `### {name}.nix` heading — checked via a per-file grep loop against all 13 files currently in
   `packages/`).
2. **`docs/configuration.md:20`** still describes `modules/` as: `└── modules/ # Stub scaffold
   (opencode.nix; home-modules/ stubs)` — both referents (`opencode.nix`, `home-modules/`) are
   gone from disk.
3. **`docs/unstable-packages.md:12`** still says `overlays/unstable-packages.nix` is "(planned:
   ... after task 66 Phase 2)" — the file exists today (`overlays/unstable-packages.nix`,
   confirmed via `ls overlays/`) and is already wired into `flake.nix:59`
   (`unstablePackagesOverlay = import ./overlays/unstable-packages.nix pkgs-unstable;`).

None of these three are in task 91's explicit description scope (root README, docs/README.md
index, new modules/README.md, flake.lock/stateVersion notes, task-69 closure, the
docs-convention). They are cheap, doc-only, same-verification-level fixes, so the two viable
paths are: (a) fold them into task 91 opportunistically since the drift check was explicitly
requested and the fixes are trivial one-line edits within files already being touched or grepped
this pass, or (b) leave them for `/fix-it` or a small follow-up task if the planner wants to keep
task 91 strictly scoped to its named items. Recommendation: (a) for `docs/configuration.md:20`
and `docs/unstable-packages.md:12` (single-line, zero-risk, directly related to the same "planned:
task 66" staleness class task 91 is already fixing in root `README.md`); flag
`packages/README.md`'s `marker-pdf.nix`/missing-sections gap as (b) a follow-up, since it's a
larger, separate file with no other task-91 touchpoint and risks scope creep on a capstone task
whose harness re-runs the full build regression.

`hosts/README.md` was checked and found already fully accurate (rewritten by task 87 to the
current `mkHost` pattern, including the `iso`-is-not-built-via-`mkHost` caveat) — no action
needed there, confirming the seed review's "documents the pre-mkHost pattern" complaint is
already resolved.

## Decisions

- Root README Module Map: drop all three "(planned: task 66 ...)" annotations and their
  explanatory note (lines 49, 54, 59, 84-85); add `piper-bin.nix`, `piper-voices.nix`,
  `opencode-discord-bot.nix` to the package list; replace the obsolete inline `modules/` ASCII
  block (lines 57-76, including the dead `modules/opencode.nix` reference and the
  `home-modules/` entry) with a short pointer to the new `modules/README.md`; add a `modules/`
  bullet to "Directory Organization" and remove the dead `home-modules/` bullet.
- docs/README.md: add all 6 named files to the index, integrated into existing category
  headings rather than a new catch-all section (matches the file's existing categorization
  style).
- Create `modules/README.md` grounded in the two aggregator files' own header comments and the
  `discord-bot.nix` optional-module example, cross-referencing `.claude/rules/nix.md`'s
  "Optional / Host-Toggled Modules" section rather than duplicating it.
- Record the flake.lock and stateVersion one-liners verbatim as drafted in Findings §4 (or
  materially equivalent), placed wherever the planner decides fits best (candidates: a short
  "Health Notes" subsection in the new `modules/README.md`, or `docs/configuration.md`).
- Add a confirming note (not new resolution content) that task 69's dual-home-manager
  documentation closure is complete, since `docs/dual-home-manager.md` already contains it.
- Add the "docs verified against source, not fixed once" convention as a fifth subsection in
  `docs/README.md`'s existing "Documentation Conventions" section.
- Fold the two single-line `docs/configuration.md`/`docs/unstable-packages.md` stale "task 66"
  references into this task's edit set (same staleness class, zero extra risk). Leave
  `packages/README.md`'s `marker-pdf.nix`/missing-sections drift as an explicit out-of-scope
  finding for a follow-up task, not silently fixed and not silently ignored.
- No dependency-graph changes to task 78 — it already correctly excludes 81/91 from its
  `dependencies` in `specs/state.json`; nothing to change, only a convention to cite once written.

## Risks & Mitigations

- **Risk**: rewriting the Module Map's `modules/` block too tersely could remove useful
  information users currently get from the inline enumeration. **Mitigation**: the new
  `modules/README.md` is exactly the destination for that detail — the root README should point
  to it, matching the existing pattern for `config/`, `docs/`, `hosts/`, `packages/`.
- **Risk**: scope creep from the "Additional Drift Findings" section causing the capstone task to
  balloon beyond its named scope and delay closing out task 81. **Mitigation**: explicit (a)/(b)
  split above — two trivial single-line fixes folded in, one larger file left as a flagged
  follow-up rather than expanded into this task.
- **Risk**: full regression harness (`nix flake check` + 3 host builds + HM activation) is a
  meaningful time cost for a doc-only task. **Mitigation**: this is intentional per
  `target-layout.md` §3 row 10 ("Verification level: Full harness once more as final regression
  check") — it's the last chance to catch any residual regression from the entire 82-90 chain,
  not overkill specific to task 91's own (zero-risk, doc-only) edits.

## Context Extension Recommendations

- None required specific to this task's markdown scope. (Task type is `markdown`; no new
  `.claude/context/` topic gap was surfaced — the relevant Nix conventions already live in
  `.claude/rules/nix.md` and are being cross-referenced, not duplicated.)

## Appendix

### Search/verification commands used

```
jq -r '.active_projects[] | select(.project_number==91)' specs/state.json
grep -n "Module Map\|planned: task 66\|neovim.nix\|piper-bin\|piper-voices" README.md
ls packages/*.nix
find modules -maxdepth 3 ...
find modules/system -type f; find modules/home -type f
find hosts -maxdepth 2
test -d home-modules
cat modules/system/default.nix; cat modules/home/default.nix
cat hosts/README.md; cat hosts/nandi/default.nix; hosts/usb-installer/default.nix; hosts/iso/default.nix
ls docs/; cat docs/README.md
cat docs/dual-home-manager.md
jq '{root,nodeCount:(.nodes|length),version}' flake.lock; jq -r '.nodes|keys[]' flake.lock
grep -rn "stateVersion" --include="*.nix" .
grep -rn "planned: task 66\|task 66 Phase\|(planned:" README.md docs/*.md
grep -rln "home-modules" --include="*.md" .
grep -n "marker-pdf\|marker_pdf" --include="*.nix" -r .; find . -iname "*marker*"
cat packages/README.md (in full)
grep -n "Documentation drift" -A 40 specs/081_.../reports/01_repo-organization-review.md
grep -n "Conflicts Resolved" -A 60 / "Coverage Gap" -A 5 specs/081_.../reports/02_team-research.md
sed -n '150,345p' specs/081_.../design/target-layout.md
jq -r '.active_projects[] | select(.project_number==78) | {status,dependencies,parent_task}' specs/state.json
```

### References

- `specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md`
  ("Documentation drift" section, lines 151-160)
- `specs/081_reorganize_nixos_dotfiles_repository_design/reports/02_team-research.md`
  (Conflicts Resolved, Coverage Gaps #6/#8/#9, Recommended Subtask Decomposition)
- `specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md` §2, §3
  (blueprint row 10), §4, §5 (dispositions #6, #8, #9), §5.3 (Roadmap Linkage Note), §6

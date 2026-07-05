# Implementation Plan: Task #99

- **Task**: 99 - ryzen_docs_niri_framing
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None (carried over from task 94 deferred Phase 8)
- **Research Inputs**: specs/099_ryzen_docs_niri_framing/reports/01_ryzen-docs-niri-framing-research.md
- **Artifacts**: plans/01_ryzen-docs-niri-framing.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: nix (markdown-only content work; routes to skill-nix-implementation)
- **Lean Intent**: false

## Overview

Execute the two user-decided documentation cleanups deferred from task 94's Phase 8. First,
consolidate the two overlapping AMD Ryzen AI 300 docs (`docs/ryzen-ai-300-compatibility.md`, the
210-line canonical doc, and `docs/ryzen-ai-300-support-summary.md`, its 120-line session-recap
duplicate) into a single authoritative `docs/ryzen-ai-300.md`, delete both originals, and repoint
the exactly 3 live inbound links the research identified. Second, replace the stale
"Phase 1: Testing (You are here!)" migration framing in `docs/niri.md`'s "Recommended Usage
Strategy" section (lines 95-113) with permanent dual-session daily-driver framing. All work is
markdown-only. Definition of done: `docs/ryzen-ai-300.md` exists with the merged structure and all
preserved-unique content; both old Ryzen files are gone; no inbound link outside `specs/` points at
either deleted filename; niri.md's Recommended Usage Strategy section reads as settled steady-state
rather than in-progress migration, with edits confined to that one section.

### Research Integration

The research report (`reports/01_ryzen-docs-niri-framing-research.md`) supplies: (1) a section-by-
section content map classifying every heading in both Ryzen docs as unique/duplicated/drop, (2) the
exact proposed merged structure for `docs/ryzen-ai-300.md`, (3) a complete inbound-link inventory
separating the 3 live links to update from the historical `specs/` hits that must NOT be touched,
and (4) the exact current text and proposed replacement wording for niri.md lines 95-113. This plan
executes that research directly; phases below cite the report's sections.

### Prior Plan Reference

No prior plan for task 99. This task carries forward Group E / Phase 8 of task 94's plan
(`specs/094_review_nixos_config_documentation/plans/01_nixos-doc-config-improvements.md`), which was
deliberately left [NOT STARTED] because both items required user judgment. That judgment has now
been supplied (single new file + delete originals + repoint links for Ryzen; permanent dual-session
framing for niri), so this plan executes without re-litigating the approach.

### Roadmap Alignment

`specs/ROADMAP.md` exists but no `roadmap_flag` was set for this dispatch and no explicit
`roadmap_items` are attached to the task. This is documentation hygiene continuing the task 94
NixOS-config-documentation cleanup thread; no ROADMAP.md phases are added or modified by this plan.

## Goals & Non-Goals

**Goals**:
- Produce a single authoritative `docs/ryzen-ai-300.md` using the report's proposed merged structure.
- Preserve the two genuinely-unique facts from the summary doc: the
  `hardware.cpu.amd.updateMicrocode = true;` line and the `./scripts/build-usb-installer.sh` step.
- Delete `docs/ryzen-ai-300-compatibility.md` and `docs/ryzen-ai-300-support-summary.md`.
- Update the exactly 3 live inbound links (docs/README.md:37, docs/README.md:38, docs/usb-installer.md:774).
- Replace niri.md's stale 3-phase "testing -> migration -> primary" framing (lines 95-113) with
  permanent dual-session daily-driver framing.
- Verify via grep that no inbound link outside `specs/` still references either deleted filename.

**Non-Goals**:
- Rewriting historical `specs/` task-artifact references to the old filenames (they are point-in-time
  records; the report enumerates them as out of scope).
- Any niri.md edits outside the "Recommended Usage Strategy" section — including the file-wide emoji
  strip and line 78's separate "Ready to Test" section (both are task 100's scope).
- Blocking on user confirmation of the exact niri-vs-GNOME daily split (see Phase 3 — the implementer
  makes a reasonable factual statement instead).
- Dropping the stale "Repository Status" git-hash section or the "Created Comprehensive Guide"
  self-pointer section into the merged doc (both are intentionally omitted).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Merged doc silently drops `updateMicrocode` line or `build-usb-installer.sh` step (unique to the lesser doc) | M | M | Phase 1 checklist calls out both explicitly; Phase 4 greps the new doc for both strings |
| Link-update pass rewrites historical `specs/` artifacts, falsifying task history | M | L | Phase 2 edits only the 3 enumerated live lines; Phase 4 grep excludes `specs/` and `.git` |
| niri.md rewrite scope-creeps into emoji removal or line 78's "Ready to Test" section, colliding with task 100 | M | M | Phase 3 confines edits to lines 95-113 only; Phase 4 confirms only that section changed |
| An inbound link to the deleted files is missed | H | L | Phase 4 grep over the whole repo (excluding specs/ and .git) must return zero hits |
| Implementer blocks on the niri daily-split open item | L | M | Phase 3 explicitly directs a reasonable factual statement (both sessions available, niri as primary Wayland compositor alongside GNOME) rather than a user gate |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Create consolidated docs/ryzen-ai-300.md [COMPLETED]

**Goal**: Write the new single authoritative Ryzen doc using the report's proposed merged structure,
folding in all unique content from both source docs and dropping the enumerated stale sections.

**Tasks**:
- [x] Read `docs/ryzen-ai-300-compatibility.md` (canonical source) and
  `docs/ryzen-ai-300-support-summary.md` (for the two unique facts) in full.
- [x] Create `docs/ryzen-ai-300.md` titled `# AMD Ryzen AI 300 Series Support`, following the report
  section 2 structure: System Overview; Hardware Support Summary (Fully Supported Out of the Box:
  Core System / Graphics / Connectivity; Ryzen AI 9 HX 370 Specific Features: Fully Supported + May
  Need Configuration caveats); USB Installer Configuration (single kernel-module nix block + Key
  Improvements bullets); Recommended Post-Installation Configuration (Graphics; CPU and Power
  Management; AI/NPU Support Optional); Installation Process (build USB installer -> boot ->
  nixos-generate-config -> review hardware-configuration.nix -> nixos-install); Expected Performance;
  Troubleshooting (compatibility.md's 4 issue/solution pairs verbatim); Conclusion.
- [x] Fold in the `hardware.cpu.amd.updateMicrocode = true;` line under CPU and Power Management
  (unique to support-summary.md).
- [x] Fold in the `cd ~/.dotfiles && ./scripts/build-usb-installer.sh` build step as Installation
  Process step 1 (unique to support-summary.md; path confirmed current per task 85).
- [x] Preserve compatibility.md's unique "May Need Configuration" caveats, AI/NPU (`amdxdna`) block,
  and full Troubleshooting section.
- [x] Do NOT carry over: the "Repository Status" commit-hash section, the "Created Comprehensive
  Guide" self-pointer section, or the "Answer: Yes, It Will Work Perfectly" session-voice intro.

**Timing**: 40 minutes

**Depends on**: none

**Files to modify**:
- `docs/ryzen-ai-300.md` - create (new consolidated doc)

**Verification**:
- `docs/ryzen-ai-300.md` exists and is non-empty.
- `grep -c "updateMicrocode" docs/ryzen-ai-300.md` >= 1 and
  `grep -c "build-usb-installer.sh" docs/ryzen-ai-300.md` >= 1.
- `grep -c "Repository Status\|Created Comprehensive Guide" docs/ryzen-ai-300.md` == 0.
- All merged-structure top-level headings from report section 2 are present.

---

### Phase 2: Delete originals and repoint the 3 live inbound links [COMPLETED]

**Goal**: Remove both superseded Ryzen docs and update the exactly 3 live inbound links to point at
`docs/ryzen-ai-300.md`, touching no historical `specs/` artifacts.

**Tasks**:
- [x] Delete `docs/ryzen-ai-300-compatibility.md`.
- [x] Delete `docs/ryzen-ai-300-support-summary.md`.
- [x] In `docs/README.md`, collapse lines 37-38 (the two separate compatibility/summary entries) into
  a single entry, e.g.
  `- **[ryzen-ai-300.md](ryzen-ai-300.md)** - AMD Ryzen AI 300 series hardware support and installation guide`.
- [x] In `docs/usb-installer.md` line 774, change
  `- [Ryzen AI 300 Compatibility](ryzen-ai-300-compatibility.md) - Modern hardware support` to
  `- [Ryzen AI 300 Support](ryzen-ai-300.md) - Modern hardware support`.
- [x] Do NOT edit any `specs/` file (historical task artifacts enumerated in report section 3).

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `docs/ryzen-ai-300-compatibility.md` - delete
- `docs/ryzen-ai-300-support-summary.md` - delete
- `docs/README.md` - collapse lines 37-38 into one link to ryzen-ai-300.md
- `docs/usb-installer.md` - repoint line 774 to ryzen-ai-300.md

**Verification**:
- Neither old file exists on disk.
- `docs/README.md` and `docs/usb-installer.md` each link to `ryzen-ai-300.md`.
- No `specs/` file was modified in this phase.

---

### Phase 3: Reframe niri.md Recommended Usage Strategy section [COMPLETED]

**Goal**: Replace the stale "Phase 1: Testing (You are here!)" 3-phase migration narrative in
`docs/niri.md` lines 95-113 with permanent dual-session daily-driver framing, confined strictly to
that section.

**Tasks**:
- [x] Read `docs/niri.md` lines ~82-116 to confirm the exact current bounds of the
  `### Recommended Usage Strategy` section (sibling to `### How to Switch Between Sessions`, followed
  by a `---` then `## Overview`).
- [x] Replace the section body (the "Phase 1/2/3" blocks and the "(You are here!)" marker) with the
  report section 4 proposed wording: both sessions are permanent, daily-driver-ready options — this
  is not a migration in progress; choose per-context (niri as the default/primary Wayland compositor
  for daily/scrollable-tiling work; GNOME + PaperWM when screen sharing is required, since
  Zoom/Teams/Meet reliability is guaranteed on GNOME); both sessions coexist permanently at the GDM
  login screen, switchable anytime with no reconfiguration.
- [x] On the ONE open item (exact niri-vs-GNOME daily split): make a reasonable factual statement —
  both sessions available, niri as the primary Wayland compositor alongside GNOME — and do NOT block
  on user confirmation.
- [x] Retain the durable screen-sharing tradeoff (GNOME guarantees reliable screen sharing; niri's is
  not asserted) and reposition the "both sessions coexist permanently" substance as a lead statement
  of settled fact.
- [x] Keep the `### Recommended Usage Strategy` heading. Confine ALL edits to this section: do not
  touch line 78's "Best for" line, do not touch any other section, and do not add/remove/alter emoji
  anywhere (task 100 handles the file-wide emoji strip).

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `docs/niri.md` - rewrite only the `### Recommended Usage Strategy` section (~lines 95-113)

**Verification**:
- `grep -c "You are here\|Phase 1: Current\|Gradual Migration\|Primary Niri" docs/niri.md` == 0.
- The `### Recommended Usage Strategy` heading still exists.
- A `git diff docs/niri.md` shows changes confined to the lines within that section (no edits to
  line 78 or elsewhere; emoji count outside the section unchanged).

---

### Phase 4: Verification pass [COMPLETED]

**Goal**: Confirm no dangling inbound links to the deleted filenames remain outside `specs/`, and
that the markdown edits are internally consistent.

**Tasks**:
- [x] Run the dangling-link grep (must return zero hits):
  `grep -rn "ryzen-ai-300-compatibility\|ryzen-ai-300-support-summary" /home/benjamin/.dotfiles --include="*.md" --include="*.nix" --include="*.sh" --exclude-dir=.git --exclude-dir=specs`
- [x] Confirm `docs/ryzen-ai-300.md` is referenced by both `docs/README.md` and `docs/usb-installer.md`:
  `grep -rn "ryzen-ai-300.md" docs/README.md docs/usb-installer.md`.
- [x] Confirm both old files are absent:
  `test ! -e docs/ryzen-ai-300-compatibility.md && test ! -e docs/ryzen-ai-300-support-summary.md`.
- [x] Confirm niri.md staleness is gone:
  `grep -n "You are here\|Gradual Migration" docs/niri.md` returns nothing.
- [x] Spot-check `docs/ryzen-ai-300.md` renders sensibly (headings nested, code blocks closed).

**Timing**: 15 minutes

**Depends on**: 2, 3

**Files to modify**:
- None (read-only verification).

**Verification**:
- Dangling-link grep returns zero hits outside `specs/`.
- Both new inbound links resolve to `ryzen-ai-300.md`.
- niri.md contains no "testing phase" / "migration" framing.

## Testing & Validation

- [x] `docs/ryzen-ai-300.md` exists, non-empty, contains `updateMicrocode` and
  `build-usb-installer.sh`, and omits "Repository Status" / "Created Comprehensive Guide".
- [x] `docs/ryzen-ai-300-compatibility.md` and `docs/ryzen-ai-300-support-summary.md` no longer exist.
- [x] `docs/README.md` (single collapsed entry) and `docs/usb-installer.md:774` both link to
  `ryzen-ai-300.md`.
- [x] Dangling-link grep (excluding `specs/` and `.git`) returns zero hits for either old filename.
- [x] `docs/niri.md` "Recommended Usage Strategy" section has no "You are here" / "Phase 1/2/3"
  migration framing; edits confined to that section; no emoji added/removed.
- [x] No file under `specs/` was modified by the implementation.

## Artifacts & Outputs

- `docs/ryzen-ai-300.md` (new consolidated doc)
- `docs/README.md` (edited: lines 37-38 collapsed to one link)
- `docs/usb-installer.md` (edited: line 774 repointed)
- `docs/niri.md` (edited: Recommended Usage Strategy section reframed)
- Deleted: `docs/ryzen-ai-300-compatibility.md`, `docs/ryzen-ai-300-support-summary.md`
- `specs/099_ryzen_docs_niri_framing/summaries/01_ryzen-docs-niri-framing-summary.md` (on implement)

## Rollback/Contingency

All changes are markdown docs under `docs/` and are fully git-reversible. If the merged doc is found
to have dropped content or an inbound link is broken, `git checkout -- docs/` restores the pre-task
state (the two deleted files are recoverable from git history). Because no config (`.nix`) files are
touched, there is no build/rebuild risk and no `nix flake check` gate is required. Each phase is an
independent, verifiable commit, so a single bad phase can be reverted without unwinding the others.

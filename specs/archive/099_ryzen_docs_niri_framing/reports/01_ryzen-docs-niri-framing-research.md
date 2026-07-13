# Research Report: Task #99

**Task**: 99 - ryzen_docs_niri_framing
**Started**: 2026-07-05T09:48:44Z
**Completed**: 2026-07-05T00:00:00Z
**Effort**: 1-2 hours (implementation, given this research)
**Dependencies**: None (carried over from task 94 deferred Phase 8)
**Sources/Inputs**: `docs/ryzen-ai-300-compatibility.md`, `docs/ryzen-ai-300-support-summary.md`,
`docs/niri.md`, `flake.nix`, `overlays/unstable-packages.nix`, repo-wide grep,
`specs/094_review_nixos_config_documentation/reports/02_remaining-cleanup-backlog.md` (Group E),
`specs/094_review_nixos_config_documentation/plans/01_nixos-doc-config-improvements.md` (Phase 8)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **User decision already made** (per task dispatch, not re-litigated here): consolidate into a
  new `docs/ryzen-ai-300.md`, delete both originals, and repoint all inbound links.
- `docs/ryzen-ai-300-compatibility.md` (210 lines) is the canonical, more-detailed doc.
  `docs/ryzen-ai-300-support-summary.md` (120 lines) is a session-recap of the same work; its only
  two pieces of content not already in `compatibility.md` are (a) the
  `hardware.cpu.amd.updateMicrocode = true;` Nix line and (b) the
  `./scripts/build-usb-installer.sh` invocation step. Everything else is either exact duplicate
  content or historical noise (a "Repository Status" section naming a git commit hash) that has no
  place in an authoritative reference doc.
- Exactly **3 live inbound links** need updating (2 in `docs/README.md`, 1 in
  `docs/usb-installer.md`). All other repo hits are historical `specs/` task artifacts (past
  reports/plans/summaries) that document what was true when those tasks ran and should **not** be
  rewritten.
- `docs/niri.md`'s "Recommended Usage Strategy" section (lines 95-113) is confirmed stale: it
  frames the dual-session GNOME+PaperWM / GNOME+Niri setup as a 3-phase "testing -> migration ->
  primary" journey with "(You are here!)" pinned to Phase 1 ("Testing"). This directly contradicts
  `flake.nix:14` / `overlays/unstable-packages.nix:5`'s own comment: "ENABLED (dual-session with
  GNOME)" — settled, not experimental — and the task's stated fact that hamsa is now a daily
  driver. Proposed wording is below; exact "which session for which task" specifics should still be
  confirmed by the user during implementation, since that's a fact about actual daily usage habits
  that can't be derived from the config tree alone.

## Context & Scope

Task 99 carries forward Group E of task 94's deferred backlog (Phase 8, never executed under
autonomous orchestration because both items require user judgment). The user has now supplied the
missing judgment call for the Ryzen docs (single new file, delete originals, repoint links) and
partial judgment for niri.md (hamsa is a daily driver, so "testing phase" is stale). This report is
research-only: no files were edited. It produces (1) a content map and proposed structure for the
merged Ryzen doc, (2) a full inbound-link inventory, and (3) an exact quote + proposed rewording
for niri.md's "Recommended Usage Strategy" section, scoped precisely to that section per the task's
explicit boundary (task 100 will separately strip emoji from the rest of `docs/niri.md`).

## Findings

### 1. Ryzen doc content map

#### `docs/ryzen-ai-300-compatibility.md` (210 lines) — canonical/detailed doc

| Section (heading) | Content | Status |
|---|---|---|
| `## System Overview` | Processor/arch/platform one-liners | Unique (more explicit than summary's prose) |
| `## USB Installer Compatibility` → `### ✅ What Will Work Out of the Box` (Core System, Graphics, Connectivity subsections) | Detailed bullet breakdown by subsystem | Unique — summary.md only has a condensed version |
| `### ✅ Updated USB Installer Configuration` (nix code block: `boot.initrd.availableKernelModules`, `boot.kernelModules`) | Full kernel-module list with per-line comments | **Duplicated** — byte-for-byte same code block appears in summary.md's "Enhanced USB Installer Configuration" |
| `#### Key Improvements for Ryzen AI:` bullets | `nvme`, `kvm-amd`, `thunderbolt`, AMD microcode | **Duplicated** (near-identical bullets in summary.md, summary.md's version literally identical wording) |
| `## Ryzen AI 9 HX 370 Specific Features` → `### ✅ Fully Supported` | Hybrid arch, NPU, P-state, memory ctrl, PCIe | **Duplicated** (same 5 bullets, same order, in summary.md's "Ryzen AI Specific Features") |
| `### ⚠️ May Need Configuration` | iGPU config caveat, NPU kernel-version caveat, power-profile caveat | Unique — absent from summary.md entirely |
| `### 📋 Recommended Post-Installation Configuration` (3 numbered code blocks: Graphics, CPU/Power, AI/NPU) | Full config snippets incl. `services.xserver.videoDrivers`, `hardware.graphics`, `amd_pstate=active`, `amdxdna` module | Partially unique — summary.md's "Post-Installation Optimization" has only a 3-line subset (`videoDrivers`, `amd_pstate=active`, `hardware.cpu.amd.updateMicrocode = true;`) and **is missing the AI/NPU block entirely**, but **adds** `hardware.cpu.amd.updateMicrocode = true;` which compatibility.md never states explicitly |
| `## Installation Process for Ryzen AI 300 Series` (Steps 1-4: boot USB, `nixos-generate-config`, review `hardware-configuration.nix`, `nixos-install`) | Full install walkthrough | Unique/more-detailed — summary.md's "Installation Process" only covers building+booting the USB installer, not the `nixos-generate-config`/`nixos-install` steps |
| `## Expected Performance` (Excellent Performance Expected, Ryzen AI Advantages) | CPU/graphics/storage/memory/virt bullets + AI/gaming/productivity/power bullets | **Duplicated** — summary.md's "Expected Performance" is a condensed subset of the same bullets |
| `## Troubleshooting for Ryzen AI Systems` (4 issue/solution pairs) | Graphics not detected, poor performance, NPU not working, power-management issues | **Unique — entirely absent from summary.md** |
| `## Conclusion` (Key Points, Recommendation) | 4 key points + 4-step recommendation | **Duplicated in spirit** — summary.md's "Conclusion" covers the same ground with different wording |

#### `docs/ryzen-ai-300-support-summary.md` (120 lines) — session-recap doc

| Section (heading) | Content | Status |
|---|---|---|
| `## ✅ Answer: Yes, It Will Work Perfectly` | Intro framing ("I've now optimized it...") | Unique but purely narrative/session-voice, not reference content — drop |
| `## 🔧 What I've Updated` (Enhanced USB Installer Configuration + Key Improvements) | Same nix block + bullets as compatibility.md | Duplicate (see above) |
| `## 📋 Ryzen AI 9 HX 370 Compatibility` (Fully Supported Out of Box, Ryzen AI Specific Features) | Condensed duplicate of compatibility.md's two "Fully Supported" bullet lists | Duplicate |
| `## 📖 Created Comprehensive Guide` | Meta-pointer: "New documentation: `docs/ryzen-ai-300-compatibility.md`" + bullet list of what that guide includes | **Obsolete once merged** — this section only exists to point at the other doc, which will no longer exist under that name |
| `## 🚀 Installation Process` (Build USB Installer script, Boot and Install, Post-Installation Optimization) | `cd ~/.dotfiles && ./scripts/build-usb-installer.sh`, then 3-line post-install nix snippet incl. `hardware.cpu.amd.updateMicrocode = true;` | **Partially unique** — the `./scripts/build-usb-installer.sh` invocation and the `updateMicrocode` line are not stated anywhere in compatibility.md and are worth folding in |
| `## 🎮 Expected Performance` | Condensed duplicate | Duplicate |
| `## 🔍 Repository Status` (commit hash `9958cd2`, "files updated" list) | Session/commit log entry | **Drop entirely** — this is a point-in-time git-log snapshot from whenever this doc was authored, not evergreen reference content, and is already stale-by-nature in any future doc |
| `## ✅ Conclusion` | Restates "fully supported... proceed with confidence" | Duplicate in spirit with compatibility.md's Conclusion |

**Bottom line**: `compatibility.md` is materially the more complete and better-organized source.
`support-summary.md` contributes exactly two non-duplicate, still-useful facts: the
`hardware.cpu.amd.updateMicrocode = true;` config line, and the
`./scripts/build-usb-installer.sh` build step (already correctly `scripts/`-prefixed per task 85's
earlier fix — confirmed current, not stale). Everything else in `support-summary.md` is either an
exact/near-exact duplicate or a narrative/session-log artifact with no place in a reference doc.

### 2. Proposed merged structure for `docs/ryzen-ai-300.md`

```
# AMD Ryzen AI 300 Series Support

## System Overview
  (processor / architecture / platform — from compatibility.md)

## Hardware Support Summary
  ### Fully Supported Out of the Box
    (Core System, Graphics, Connectivity — merge compatibility.md's detailed
    subsections; this supersedes support-summary.md's condensed version)
  ### Ryzen AI 9 HX 370 Specific Features
    - Fully Supported (hybrid arch, NPU, P-state, memory, PCIe)
    - May Need Configuration (iGPU, NPU kernel version, power profiles)
      [caveats section — unique to compatibility.md, keep as-is]

## USB Installer Configuration
  (the boot.initrd.availableKernelModules / boot.kernelModules nix block — appears
  once; both source docs had it byte-identical)
  ### Key Improvements for Ryzen AI
    (nvme / kvm-amd / thunderbolt / AMD microcode bullets)

## Recommended Post-Installation Configuration
  ### Graphics Configuration
  ### CPU and Power Management
    (fold in `hardware.cpu.amd.updateMicrocode = true;` from support-summary.md
    alongside amd_pstate=active / cpuFreqGovernor from compatibility.md)
  ### AI/NPU Support (Optional)
    (compatibility.md's amdxdna block — support-summary.md omitted this entirely)

## Installation Process
  1. Build the USB installer (`./scripts/build-usb-installer.sh` — from support-summary.md,
     confirmed current path)
  2. Boot from USB installer
  3. Generate hardware configuration (`nixos-generate-config`)
  4. Review generated `hardware-configuration.nix`
  5. Install (`nixos-install --flake .#<hostname>`)
  (steps 2-5 from compatibility.md, which is more thorough than support-summary.md here)

## Expected Performance
  (merge — both docs cover the same ground; use compatibility.md's fuller bullet set)

## Troubleshooting
  (compatibility.md's 4 issue/solution pairs — unique, keep verbatim)

## Conclusion
  (single conclusion combining both docs' key-points/recommendation lists —
  drop the "Repository Status" commit-hash section and the
  "Created Comprehensive Guide" self-reference section entirely, since both are
  now-obsolete artifacts of the two-doc split this task is closing)
```

**Explicit drop list** (content intentionally NOT carried into the merged doc):
- `support-summary.md`'s `## 🔍 Repository Status` section (commit hash `9958cd2`, "files updated"
  list) — a stale point-in-time session log, not reference material.
- `support-summary.md`'s `## 📖 Created Comprehensive Guide` section — a meta-pointer to the other
  doc, obsolete once both are merged into one file.
- `support-summary.md`'s `## ✅ Answer: Yes, It Will Work Perfectly` narrative intro — session-voice
  framing, not needed once there's a single authoritative doc with its own title.

### 3. Inbound-link inventory (repo-wide grep for both old filenames)

**Live docs/config requiring an update** (link text + path must change to point at
`ryzen-ai-300.md`):

| File:Line | Current text |
|---|---|
| `docs/README.md:37` | `- **[ryzen-ai-300-compatibility.md](ryzen-ai-300-compatibility.md)** - AMD Ryzen AI 300 series hardware support` |
| `docs/README.md:38` | `- **[ryzen-ai-300-support-summary.md](ryzen-ai-300-support-summary.md)** - Ryzen AI 300 support summary` |
| `docs/usb-installer.md:774` | `- [Ryzen AI 300 Compatibility](ryzen-ai-300-compatibility.md) - Modern hardware support` |

These two `docs/README.md` lines (37-38) collapse into a single line pointing at the new file,
e.g. `- **[ryzen-ai-300.md](ryzen-ai-300.md)** - AMD Ryzen AI 300 series hardware support and
installation guide`. `docs/usb-installer.md:774`'s single line becomes
`- [Ryzen AI 300 Support](ryzen-ai-300.md) - Modern hardware support`.

**Checked, no update needed** (mentions "Ryzen" but does not link to either doc file):
- `README.md:33` (root) — `│   ├── hamsa/hardware-configuration.nix   # Secondary machine (AMD Ryzen AI 300)` — descriptive comment in the module-map tree, not a doc link.
- `hosts/usb-installer/hardware-configuration.nix:11,26` — inline Nix comments ("Generic boot
  configuration for USB installer with AMD Ryzen support", "AMD virtualization support (for Ryzen
  AI processors)") — not doc references.

**Historical `specs/` artifacts — intentionally out of scope, do NOT edit**:
These are point-in-time task reports/plans/summaries documenting what was true when those tasks
ran; rewriting them after the fact would falsify the historical record. Found via the same grep,
listed for completeness only:
- `specs/TODO.md:76` (task 99's own description — will naturally go stale/get archived when this
  task completes; not a content-consolidation target)
- `specs/state.json` (task 99's own description field, same as above)
- `specs/094_review_nixos_config_documentation/reports/01_nixos-config-doc-review.md` (lines 181,
  194, 195, 201, 210)
- `specs/094_review_nixos_config_documentation/reports/02_remaining-cleanup-backlog.md:264-269`
  (this task's own primary source document)
- `specs/094_review_nixos_config_documentation/plans/01_nixos-doc-config-improvements.md`
  (lines 248, 356-357, 375)
- `specs/094_review_nixos_config_documentation/summaries/01_nixos-doc-config-improvements-summary.md`
  (lines 86, 107)
- `specs/094_review_nixos_config_documentation/.orchestrator-handoff.json` (continuation_context
  field)
- `specs/091_documentation_sync_reorg_final/reports/01_documentation-sync-final.md` (lines 144-145)
- `specs/archive/051_documentation_refactor_integrate_adhoc_notes/reports/01_documentation-analysis.md`
  (lines 144-145)
- `specs/085_root_scripts_relocation_scripts_dir/reports/01_scripts-relocation-research.md`
  (lines 82, 86, 101, 122)
- `specs/085_root_scripts_relocation_scripts_dir/plans/01_scripts-dir-relocation.md`
  (lines 126, 136, 157, 181)
- `specs/085_root_scripts_relocation_scripts_dir/summaries/01_scripts-dir-relocation-summary.md:30`

**Verification command used**:
```bash
grep -rln "ryzen-ai-300-compatibility\|ryzen-ai-300-support-summary" /home/benjamin/.dotfiles --exclude-dir=.git
```

### 4. `docs/niri.md` "Recommended Usage Strategy" — current framing vs. proposed

**Section location**: `docs/niri.md` lines 95-113 (a `###`-level section, sibling to the preceding
`### How to Switch Between Sessions` section at line 82, and followed by a `---` separator then
`## Overview` at line 116).

**Exact current text** (lines 95-113):

```
### Recommended Usage Strategy

**Phase 1: Current - Testing** (You are here!)
- **Primary**: Use GNOME + PaperWM for daily work
- **Testing**: Log into niri session to test and learn
- **Safety**: Always have GNOME as reliable fallback

**Phase 2: Gradual Migration** (When comfortable with niri)
- **Casual work**: Use niri session
- **Important meetings**: Use GNOME (guaranteed screen sharing)
- **Adjustment**: Tweak niri config as needed

**Phase 3: Primary Niri** (When fully comfortable)
- **Default**: Use niri as primary session
- **Fallback**: Keep GNOME for emergencies or preference
- **Flexibility**: Both sessions remain available

**Safety Net**: Both sessions coexist permanently. You can always switch back to GNOME at any time.
```

**Why it's stale**: The section frames the whole dual-session setup as an in-progress
evaluation/migration ("You are here!" pinned to "Phase 1: Testing", "When comfortable with niri",
"When fully comfortable"). This contradicts:
- `flake.nix:14` — `# Niri input - ENABLED (dual-session with GNOME)` (not "experimental" or
  "testing" language)
- `flake.nix:144` — `inherit niri; # Enabled for dual-session with GNOME`
- `overlays/unstable-packages.nix:5` — `# Window Manager - ENABLED (dual-session with GNOME)`
- The task's own stated fact that hamsa is now a daily driver.

None of these describe a migration-in-progress; they describe a settled, permanent dual-session
arrangement. The 3-phase "testing -> migration -> primary" narrative structure itself is the stale
element, not just a word or two.

**Exactly what should change** (proposed wording, confined to this section only, honoring the
explicit instruction to leave the rest of `docs/niri.md` — including its emoji, which task 100
handles separately — untouched):

- Remove the "Phase 1/2/3" migration narrative entirely; it presumes an ongoing evaluation that
  has already concluded.
- Remove "(You are here!)" — there is no "current phase" to be "here" in; the dual-session setup
  is the steady state.
- Replace with a direct statement of current, settled practice: both sessions are permanent,
  supported options, selected per-context (e.g., niri for daily/scrollable-tiling work; GNOME for
  screen-sharing-critical meetings), not a progression toward "eventually switching to niri
  primary."
- Retain the one piece of genuinely durable guidance from the old text — the screen-sharing
  caveat (GNOME/PaperWM guarantees reliable screen sharing in Zoom/Teams/Meet per line 27's
  "Benefits" list; niri's screen-sharing reliability is not asserted anywhere in the doc) — since
  that's a real technical tradeoff, not a "testing phase" artifact.
- Keep the "**Safety Net**: Both sessions coexist permanently..." line's substance (still
  accurate and useful), but reposition it as the lead statement of settled fact rather than a
  trailing reassurance to someone mid-migration.

**Suggested replacement draft** (for the implementation task to adapt/confirm, not applied here):

```
### Recommended Usage Strategy

Both sessions are permanent, daily-driver-ready options — this is not a migration in progress.
Choose per-context:

- **Niri**: Default choice for daily/casual work — scrollable tiling, lower overhead.
- **GNOME + PaperWM**: Use when screen sharing is required (Zoom/Teams/Meet reliability is
  guaranteed on GNOME; niri's screen-share behavior is not).
- **Both sessions coexist permanently** at the GDM login screen — switch anytime with no
  reconfiguration needed.
```

**Open item for the implementer, not resolved by this research pass**: the exact "which session is
actually used for which kind of work day-to-day" mapping above (niri-for-casual /
GNOME-for-screen-share) is inferred from the doc's own existing "Benefits"/"Best for" lines (26-30,
78) and from the task's statement that hamsa is a daily driver — but the precise current split
(e.g., is niri now the actual default for most days, or still occasional?) is a fact only the user
can confirm, the same category of judgment call task 94 originally flagged this item for. The
"testing-phase, 3-phase migration" framing is unambiguously stale and should change regardless;
the exact replacement wording's specifics should get a quick user confirmation during
implementation.

**Explicitly out of scope for this section's rewrite** (per task instruction — task 100 handles
these separately): line 78's `**Best for**: Testing niri workflow, when you want better
performance, casual work` (part of the earlier "Session 2: GNOME + Niri (Hybrid) - Ready to Test"
section, not "Recommended Usage Strategy") and all emoji throughout `docs/niri.md` (~58 glyphs
across the 1035-line file, per task 94's report 02 finding 16). Noted here only so the
implementation task doesn't accidentally widen scope past the one section this task's dispatch
names.

## Decisions

- Treated the user's stated consolidation approach (single new `docs/ryzen-ai-300.md`, delete
  both originals, repoint all live links) as settled; this report does not re-litigate that
  choice, only maps content and proposes structure to execute it.
- Classified `specs/` hits as historical and out of scope for link updates, consistent with how
  every other doc-consolidation task in this repo's history (e.g., task 85's scripts relocation)
  has treated past task artifacts — they are point-in-time records, not live navigation.
- Did not attempt to resolve the "exact niri usage split" open item myself; flagged it explicitly
  as needing a quick user confirmation during implementation, per the same reasoning task 94
  originally used to defer this whole item (only the user knows actual daily-driver habits).

## Risks & Mitigations

- **Risk**: Merged doc silently drops the `hardware.cpu.amd.updateMicrocode = true;` line or the
  `./scripts/build-usb-installer.sh` step since they only exist in the "lesser" doc.
  **Mitigation**: Both are called out explicitly in section 2's proposed structure above as
  content to fold in from `support-summary.md`.
- **Risk**: An inbound-link update pass touches `specs/` historical artifacts, silently rewriting
  task history.
  **Mitigation**: Section 3 above explicitly enumerates and separates "live, must update" from
  "historical, do not touch" — implementer should stage only the 3 live-file line edits plus the
  deletion of the 2 old doc files and creation of the new one.
- **Risk**: niri.md rewrite scope-creeps into emoji removal or into line 78's separate "Ready to
  Test" section, colliding with task 100's planned emoji-strip pass.
  **Mitigation**: Section 4 above explicitly calls out line 78 and the file-wide emoji count as
  out of scope for this task.

## Appendix

### Search/verification commands used

```bash
grep -rn "ryzen-ai-300-compatibility" /home/benjamin/.dotfiles --include="*.md" --include="*.nix" --include="*.sh"
grep -rn "ryzen-ai-300-support-summary" /home/benjamin/.dotfiles --include="*.md" --include="*.nix" --include="*.sh"
grep -rln "ryzen-ai-300-compatibility\|ryzen-ai-300-support-summary" /home/benjamin/.dotfiles --exclude-dir=.git
grep -n "ryzen" -i /home/benjamin/.dotfiles/README.md
grep -rn "ryzen" -i /home/benjamin/.dotfiles/hosts/
grep -n -i "testing\|phase 1\|phase 2\|phase 3\|daily driver\|daily-driver\|You are here" /home/benjamin/.dotfiles/docs/niri.md
grep -n -i "niri\|dual-session\|ENABLED" /home/benjamin/.dotfiles/flake.nix /home/benjamin/.dotfiles/overlays/unstable-packages.nix
```

### Files read in full
- `docs/ryzen-ai-300-compatibility.md` (210 lines)
- `docs/ryzen-ai-300-support-summary.md` (120 lines)
- `docs/niri.md` (lines 1-160, covering the header/status section through "Recommended Usage
  Strategy" and into "Overview")
- `flake.nix` (lines 100-170, `nixosConfigurations` block)
- `specs/094_review_nixos_config_documentation/reports/02_remaining-cleanup-backlog.md`
  (Group E, lines 258-329)
- `specs/094_review_nixos_config_documentation/plans/01_nixos-doc-config-improvements.md`
  (Phase 8 references and surrounding plan structure, lines 1-130+)

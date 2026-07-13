# Research Report: Task #100

**Task**: 100 - strip_niri_doc_emoji
**Started**: 2026-07-05T00:00:00Z
**Completed**: 2026-07-05T00:00:00Z
**Effort**: 15 minutes (mechanical enumeration only)
**Dependencies**: None (carried over from task 94 deferred Phase 8; task 99's niri.md
  "Recommended Usage Strategy" reframing already landed and committed on disk)
**Sources/Inputs**: `docs/niri.md` (current, 1028 lines), `.claude/context/standards/
  documentation-standards.md` (authoritative emoji convention), `specs/094_review_
  nixos_config_documentation/reports/02_remaining-cleanup-backlog.md` (Group F / item 16),
  `specs/094_review_nixos_config_documentation/plans/01_nixos-doc-config-improvements.md`
  (Phase 5, the sibling emoji-sweep that explicitly excluded this file)
**Artifacts**: This report
**Standards**: report-format.md

## Executive Summary

- `docs/niri.md` (current on-disk version, 1028 lines, post-task-99) contains **83 decorative
  emoji-glyph instances** across **8 distinct glyphs** (✅ ⭐ ❌ ⚠️ 📝 ⚙️ 🖱️ 🔄) on **56 lines**,
  all of which must be STRIPPED per the repo's documentation-standards.md emoji policy.
- The file also contains **26 plain-Unicode navigation arrows** (→ ×23, ↔ ×2, ↓ ×1) plus two
  ASCII-art diagrams built from Unicode box-drawing characters (single-line `┌│└─├` and
  double-line `╔║╚═`) and one bullet `•` used inside a diagram — all of these are STRUCTURAL and
  must be PRESERVED unchanged.
- The authoritative convention is NOT "no glyphs above U+2000" — it is a specific prohibited/
  permitted split documented in `.claude/context/standards/documentation-standards.md` (lines
  148-182): prohibited = emoji (status indicators, decorative icons, faces, objects); permitted =
  plain Unicode arrows, math symbols, and box-drawing characters used for technical/diagram
  purposes. This is the same rule task 94's Phase 5 sweep applied to the other `docs/*.md` files
  (which explicitly excluded `docs/niri.md` and left it for this task).
- **Two occurrences require special handling beyond simple glyph deletion** (lines 86 and 942,
  identical text): the gear glyph sits alone inside a parenthetical — `(⚙️)` — with no other
  content, so deleting only the glyph leaves an empty, dangling `()`. The plan should specify
  deleting the entire `" (⚙️)"` construct, not just the glyph.
- All other occurrences follow one of two uniform, mechanically-safe trim rules (see "Trim Rules"
  below) that avoid doubled spaces or orphaned single spaces.

## Context & Scope

Research-only. No files modified. Scope was to (1) pin down the exact preserve-vs-strip rule
from the repo's own emoji convention (not task 91 specifically — task 91's completed artifacts
contain no emoji-policy content; the actual convention lives in `.claude/context/standards/
documentation-standards.md`, which task 94 Phase 5 already applied to sibling docs and cited as
"the repo's own `docs/README.md` 'No emojis in documentation' convention"), and (2) enumerate
every emoji occurrence in the CURRENT `docs/niri.md` (re-verified against disk after task 99's
completed reframing of the "Recommended Usage Strategy" section, which did not touch line
numbers materially — the file is 1028 lines, not the ~1035 quoted in the task 94 backlog report,
because task 99's edits netted a few lines shorter).

### Correction to task 94's backlog note

The task 94 backlog report (`02_remaining-cleanup-backlog.md` line 75, and its own Phase 8 note)
estimated "~58 glyphs / 1035 lines." A precise scan of the file as it exists today counts **83
decorative-emoji instances** (not ~58) across 1028 lines. The discrepancy is not a sign of new
drift — it most likely reflects an approximate/rounded estimate in the original scan (possibly
undercounting multi-glyph runs like `⭐⭐⭐⭐⭐`, which read as a single visual "chunk" but are 5
codepoints). This report's counts are derived from exact `grep -oP` codepoint-range extraction
and a Python cross-check (see Appendix) and should be treated as authoritative for planning.

## Findings

### The authoritative convention (from documentation-standards.md)

`.claude/context/standards/documentation-standards.md`, section "Prohibited Content > Emojis"
(lines 148-182):

- **Prohibited**: "Any emoji characters including: Status indicators (checkmarks, cross marks,
  warning signs); Decorative icons (sparkles, stars, arrows); Face/emotion emojis; Object
  emojis." (Note: "arrows" here means colorful/decorative *emoji-style* arrows like `🔄` or
  `➡️`, not plain Unicode arrow glyphs — see next bullet, and see also task 94's own
  Phase 5 completion note: "intentional `<-` / navigation arrows ... not emoji.")
- **Permitted**: "Unicode characters for technical purposes: Mathematical symbols (`→`, `∧`,
  `∨`, `¬`, `□`, `◇`, `∀`, `∃`); Arrows for diagrams (`↑`, `↓`, `←`, `→`, `↔`); Box-drawing
  characters (`├`, `└`, `│`, `─`); Special characters (`×`, `÷`, `±`, `≤`, `≥`, `≠`)."

This is the exact rule task 94 Phase 5 already used for every other `docs/*.md` file, and it is
unambiguous for this file: plain arrow glyphs (→ ↔ ↓) and box-drawing characters stay; the
emoji-range status/decorative glyphs (✅ ⭐ ❌ ⚠️ 📝 ⚙️ 🖱️ 🔄) go.

### STRIP inventory (83 instances, 8 glyphs, 56 lines)

| Glyph | Codepoint(s) | Meaning in doc | Count | Lines (first→last) |
|-------|-------------|----------------|-------|---------------------|
| ✅ | U+2705 | "advantage/works" bullet marker | 39 | 5, 24-28, 64-68, 70, 330-333, 654, 782(x3), 784, 785(x2), 786(x2), 787(x2), 790(x2), 997-1000, 1007-1011, 1022 |
| ⭐ | U+2B50 | table "rating" stars (1-5 in a row) | 25 | 789(x8 across 3 cells), 791(x7 across 3 cells), 792(x10 across 3 cells) |
| ❌ | U+274C | "trade-off/no" bullet marker | 7 | 661, 784(x2), 1018, 1019, 1020, 1021 |
| ⚠️ | U+26A0 (+U+FE0F on 4 of 6) | "caution/needs work" marker | 6 | 785, 786, 787, 790, 1001, 1012 |
| 📝 | U+1F4DD | "manual config" table icon | 2 | 788 (x2, two cells) |
| ⚙️ | U+2699 + U+FE0F | "gear icon" parenthetical | 2 | 86, 942 |
| 🖱️ | U+1F5B1 + U+FE0F | "GUI/mouse" table icon | 1 | 788 |
| 🔄 | U+1F504 | decorative heading icon | 1 | 82 |

**Total: 83 glyph instances to strip.**

Representative lines (full text, showing the pattern that repeats):

```
5:   ### Dual-Session Setup: GNOME + PaperWM AND GNOME + Niri ✅
24:  - ✅ Zero configuration maintenance
70:  **Configuration Status**: ✅ Fully configured and ready to use!
82:  ### How to Switch Between Sessions 🔄
86:     2. Click gear icon (⚙️) at bottom-right
654: **✅ Advantages:**
661: **❌ Trade-offs:**
782: | **Scrollable Tiling** | ✅ Via extension | ✅ Native compositor | ✅ Native compositor |
785: | **Screen Sharing** | ✅ Perfect (GNOME) | ✅ Perfect (GNOME portal) | ⚠️ Needs debugging |
788: | **Configuration** | 🖱️ GUI only | 📝 Minimal (3-5 files) | 📝 Extensive (10+ files) |
789: | **Maintenance** | ⭐ Auto-updates | ⭐⭐ Low | ⭐⭐⭐⭐⭐ High |
792: | **Elegance** | ⭐⭐⭐ Good | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐ Complex |
1018:- ❌ High configuration complexity (10-15 services)
```

### PRESERVE inventory (structural — do not touch)

| Glyph(s) | Role | Count | Lines |
|----------|------|-------|-------|
| → | plain navigation/flow arrow (headings, list items, table cells, ASCII diagram) | 23 | 10, 11, 88, 89, 384(x2), 398(x2), 599, 749, 752, 756, 763-766, 944, 945 |
| ↔ | bidirectional keyboard-remap notation | 2 | 228, 229 |
| ↓ | ASCII-art diagram flow arrow | 1 | 53 |
| `┌ │ └ ─` (single-line box-drawing) | ASCII architecture diagram box | — | 47-52, 54-60 |
| `╔ ║ ╚ ═` (double-line box-drawing) | "Quick Reference Card" keybinding box | — | 623-638 |
| `•` (U+2022 bullet) | bullet list *inside* the single-line diagram box (lines 49-51, 56-58) | 6 | 49, 50, 51, 56, 57, 58 |
| `—` (em dash, U+2014) | ordinary prose punctuation, not an emoji at all | 1 | 101 |

None of these require any edit. In particular, do not let a naive "strip anything above ASCII"
approach touch the two ASCII-art diagrams (lines 46-61 and 622-639) — both are entirely
box-drawing characters plus the one preserved `↓` arrow and the `•` bullets, with zero emoji-
range glyphs inside them.

## Awkward-Spacing / Load-Bearing Cases

Simple character-deletion of the glyph alone will leave incorrect spacing in most positions.
Two uniform mechanical trim rules cover 82 of the 83 instances; one line pattern (2 occurrences)
needs bespoke handling.

### Rule A — glyph followed by a space (the common case: list items, table cells, headings-
with-trailing-text, bold-wrapped lines)

Delete the glyph (and its trailing `U+FE0F` variation selector, if present) **together with the
one space that immediately follows it**.

- `- ✅ Zero configuration maintenance` → `- Zero configuration maintenance`
- `**✅ Advantages:**` → `**Advantages:**`
- `| ✅ Via extension |` → `| Via extension |`
- `⭐⭐⭐⭐⭐ High` (multi-glyph run, no internal spaces) → delete the whole run + trailing
  space → `High`

### Rule B — glyph at end of line/heading, preceded by a space, nothing following

Delete the one space that immediately **precedes** the glyph, together with the glyph.

- `### Dual-Session Setup: GNOME + PaperWM AND GNOME + Niri ✅` →
  `### Dual-Session Setup: GNOME + PaperWM AND GNOME + Niri`
- `### How to Switch Between Sessions 🔄` → `### How to Switch Between Sessions`

Applying Rule A here instead (deleting glyph + trailing space) is impossible since there is no
trailing space/char at all — Rule B is the only correct form for line-final glyphs.

### Special case — parenthetical icon-only aside (2 occurrences, identical text, lines 86 & 942)

```
2. Click gear icon (⚙️) at bottom-right
```

The gear glyph has **no adjacent space on either side inside the parentheses** — it is the
entire parenthetical content. Deleting only the glyph (± its VS16) leaves a dangling empty
`()`:  `Click gear icon () at bottom-right`. This is the one case the implementer must NOT treat
as simple deletion. Instead, delete the whole `" (⚙️)"` span (the leading space, both
parentheses, and the glyph) so the sentence reads cleanly:

```
2. Click gear icon at bottom-right
```

This exact line appears twice verbatim (line 86, in the "How to Switch Between Sessions"
section, and line 942, in the "Switching Between Sessions at GDM" section) — both need the same
fix.

## Decisions

- Use `.claude/context/standards/documentation-standards.md` (not any task-91 artifact — task 91
  did not itself define the emoji policy; it is a pre-existing repo standard task 94/Phase 5
  already applied elsewhere) as the authoritative source for what counts as "emoji to strip" vs
  "structural to preserve."
- Treat the two `(⚙️)` parenthetical lines (86, 942) as a named special case in the implementation
  plan rather than folding them into the generic "delete glyph + adjacent space" rule, since a
  naive apply would leave empty parentheses.
- Report the corrected exact count (83, not ~58) so the plan is not built against a stale
  estimate from the task 94 backlog note.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| A regex-based strip accidentally touches the two ASCII-art diagrams (box-drawing chars) | Scope the strip to the explicit 8-glyph STRIP list (✅ ⭐ ❌ ⚠️ 📝 ⚙️ 🖱️ 🔄 + optional trailing U+FE0F), never a blanket "non-ASCII" filter |
| Naive glyph-only deletion leaves doubled spaces (e.g. `-  Zero configuration`) | Apply Rule A/Rule B (delete adjacent space with the glyph, not the glyph alone) uniformly |
| The `(⚙️)` special case gets glyph-deleted instead of whole-parenthetical-deleted, leaving `()` | Call out lines 86 and 942 explicitly in the plan as a named exception |
| Table rows with multi-glyph star runs (`⭐⭐⭐⭐⭐`) get partially stripped, leaving stray stars | Match the full contiguous glyph run per cell, not one glyph at a time |
| Verification step tries to run `nix flake check` or similar config verification | Not needed — task description explicitly states "no config verification needed"; this is a pure `docs/niri.md` text edit. A final `grep -noP` re-scan of the 8 STRIP glyphs (should return zero) plus a visual diff of the ~56 touched lines is sufficient verification |

## Appendix

### Search/verification commands used

```bash
# Primary emoji-range + arrow-range sweep with line numbers
grep -noP "[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}\x{2190}-\x{21FF}\x{2B00}-\x{2BFF}]" docs/niri.md

# Per-glyph line lists (repeated for each of the 8 STRIP glyphs)
grep -noP "\Q✅\E" docs/niri.md | cut -d: -f1

# Variation-selector-16 (U+FE0F) check on the 4 multi-codepoint glyphs (⚠️ ⚙️ 🖱️)
grep -noP "[\x{2600}-\x{27BF}\x{1F300}-\x{1FAFF}]\x{FE0F}?" docs/niri.md

# Full-file character census (Python) to catch anything outside the known emoji/arrow ranges
# and confirm the two box-drawing diagrams and the bullet/em-dash are the only other non-ASCII
# characters present
python3 -c "... census script, see this task's research transcript ..."
```

### Line-number cross-check

Total lines with at least one STRIP-glyph occurrence: 56 (of 1028). Total STRIP-glyph
occurrences: 83. Total PRESERVE arrow occurrences: 26 (23 `→` + 2 `↔` + 1 `↓`). No other emoji-
range or ambiguous characters exist in the file outside the 8 STRIP glyphs and the arrow/box-
drawing/bullet/em-dash PRESERVE set enumerated above.

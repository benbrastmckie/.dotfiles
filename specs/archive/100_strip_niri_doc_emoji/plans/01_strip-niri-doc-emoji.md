# Implementation Plan: Strip Decorative Emoji from docs/niri.md

- **Task**: 100 - strip_niri_doc_emoji
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: None (task 99's niri.md reframing already landed and committed on disk)
- **Research Inputs**: specs/100_strip_niri_doc_emoji/reports/01_emoji-strip-inventory.md
- **Artifacts**: plans/01_strip-niri-doc-emoji.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Strip all 83 decorative emoji-glyph instances (8 distinct glyphs across 56 lines) from
`docs/niri.md` to conform to the repo's emoji convention, while preserving the 26 plain-Unicode
navigation arrows and the two ASCII-art box-drawing diagrams. This is a purely mechanical,
single-file Markdown edit against the current on-disk `docs/niri.md` (1028 lines, post-task-99,
committed). No Nix build or config verification is required or performed. Definition of done: a
grep of the file for the 8 stripped glyphs returns zero hits, the preserved arrows still grep
positive, both ASCII diagrams are byte-for-byte intact, and no dangling `()` remains.

### Research Integration

The plan is built directly on `reports/01_emoji-strip-inventory.md`, which supplies:
- The authoritative convention source: `.claude/context/standards/documentation-standards.md`
  (lines 148-182), the same rule task 94's Phase 5 sweep applied to every other `docs/*.md` file
  (which explicitly excluded `docs/niri.md`, deferring it to this task).
- The exact STRIP inventory: 83 instances across 8 glyphs — checkmark U+2705 (39), star U+2B50
  (25), cross U+274C (7), warning U+26A0 (6), memo U+1F4DD (2), gear U+2699 (2), mouse U+1F5B1
  (1), recycle U+1F504 (1) — with per-line locations.
- The exact PRESERVE inventory: 26 arrows (right-arrow ×23, left-right-arrow ×2, down-arrow ×1)
  plus two ASCII diagrams (single-line box-drawing lines ~47-60; double-line box-drawing lines
  ~623-638) and the in-diagram bullets and em-dash.
- The two uniform trim rules (Rule A / Rule B) plus the named parenthetical special case at
  lines 86 and 942.

### Prior Plan Reference

No prior plan. This is the first plan for task 100. The sibling task 95 and task 97 doc-sweep
plans (same session, same repo) validate the effective pattern used here: one mechanical edit
phase with an explicit Do-NOT-touch list, followed by a grep-based verification phase, markdown-
only with no nix build.

### Roadmap Alignment

No `specs/ROADMAP.md` was provided in the delegation context and `roadmap_flag` is not set. No
roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Remove all 83 decorative emoji-glyph instances (the 8-glyph STRIP set) from `docs/niri.md`.
- Apply the two mechanical trim rules so no doubled or orphaned spaces are left behind.
- Handle the `(gear-icon)` parenthetical special case at lines 86 and 942 by deleting the whole
  ` (glyph)` span so no dangling `()` remains.
- Leave the 26 structural arrows and both ASCII-art diagrams completely untouched.

**Non-Goals**:
- No rewording, restructuring, or content changes beyond glyph/adjacent-space deletion.
- No Nix build, `nix flake check`, or any config verification (explicitly out of scope).
- No edits to any file other than `docs/niri.md`.
- No blanket "strip all non-ASCII" transformation — the strip is scoped to the explicit 8-glyph
  list only.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A regex/blanket strip touches the two ASCII-art diagrams (box-drawing chars) | H | M | Scope every edit to the explicit 8-glyph STRIP list plus optional trailing U+FE0F; never use a "non-ASCII" filter. Verify diagrams intact in Phase 2. |
| Naive glyph-only deletion leaves doubled spaces (e.g. `-  Zero config`) | M | H | Apply Rule A (delete glyph + trailing space) / Rule B (delete preceding space + glyph) uniformly. |
| The `(gear)` special case gets glyph-only deletion, leaving `()` | M | M | Treat lines 86 and 942 as a named exception: delete the whole ` (glyph)` span. Phase 2 greps for `()`. |
| Multi-glyph star runs (`star`×5) partially stripped, leaving stray stars | M | M | Match the full contiguous glyph run per cell, not one glyph at a time. Phase 2 greps for the star codepoint. |
| A preserved arrow accidentally removed | M | L | Phase 2 confirms the right-arrow still greps positive (23 expected); arrows are not in the STRIP set. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Strip the 83 decorative emoji glyphs [COMPLETED]

**Goal**: Remove every instance of the 8 STRIP glyphs from `docs/niri.md`, applying the correct
trim rule for each position so spacing stays clean, while leaving all preserved characters
untouched.

**Reference (from research report)** — the 8 STRIP glyphs and their line locations:
- Checkmark (U+2705) ×39 — lines 5, 24-28, 64-68, 70, 330-333, 654, 782(×3), 784, 785(×2),
  786(×2), 787(×2), 790(×2), 997-1000, 1007-1011, 1022
- Star (U+2B50) ×25 — lines 789 (×8), 791 (×7), 792 (×10), each a contiguous run inside table cells
- Cross (U+274C) ×7 — lines 661, 784(×2), 1018, 1019, 1020, 1021
- Warning (U+26A0, +U+FE0F on 4 of 6) ×6 — lines 785, 786, 787, 790, 1001, 1012
- Memo (U+1F4DD) ×2 — line 788 (×2, two cells)
- Gear (U+2699 + U+FE0F) ×2 — lines 86, 942 (SPECIAL CASE, see below)
- Mouse (U+1F5B1 + U+FE0F) ×1 — line 788
- Recycle (U+1F504) ×1 — line 82

**Trim rules to apply** (verbatim from report):
- **Rule A — glyph followed by a space** (common case: list items, table cells, bold-wrapped
  lines, heading-with-trailing-text): delete the glyph (and its trailing U+FE0F variation
  selector if present) together with the one space immediately following it.
  - `- <check> Zero configuration maintenance` becomes `- Zero configuration maintenance`
  - `**<check> Advantages:**` becomes `**Advantages:**`
  - `| <check> Via extension |` becomes `| Via extension |`
  - A multi-glyph star run with no internal spaces (`<star><star><star><star><star> High`):
    delete the whole run + its trailing space, giving `High`.
- **Rule B — glyph at end of line/heading, preceded by a space, nothing after**: delete the one
  space immediately preceding the glyph, together with the glyph.
  - `### Dual-Session Setup: GNOME + PaperWM AND GNOME + Niri <check>` becomes
    `### Dual-Session Setup: GNOME + PaperWM AND GNOME + Niri`
  - `### How to Switch Between Sessions <recycle>` becomes `### How to Switch Between Sessions`
- **SPECIAL CASE — parenthetical icon-only aside** (lines 86 and 942, identical text
  `2. Click gear icon (<gear>) at bottom-right`): the gear glyph is the entire parenthetical
  content with no adjacent space inside the parens. Do NOT do a glyph-only deletion (that leaves
  a dangling `()`). Instead delete the whole ` (<gear>)` span (leading space, both parens, and
  the glyph + its U+FE0F) so the line reads `2. Click gear icon at bottom-right`. Both lines get
  the identical fix.

**Tasks**:
- [x] Confirm working against the current committed `docs/niri.md` (1028 lines); do not re-fetch
      or reorder — line numbers in the report are authoritative for this on-disk version.
      *(completed)*
- [x] Strip all 39 checkmark (U+2705) instances, choosing Rule A or Rule B per position (line 5
      and line 70's trailing marker are Rule B / line-context; the list-item and table-cell
      occurrences are Rule A). *(completed — verified only line 5 was actually Rule B;
      line 70's checkmark is mid-line, correctly handled by Rule A)*
- [x] Strip all 25 star (U+2B50) instances by matching each full contiguous run per table cell
      (lines 789, 791, 792), applying Rule A (run + trailing space) so no stray stars remain.
      *(completed)*
- [x] Strip all 7 cross (U+274C) instances (lines 661, 784, 1018-1021) per Rule A / line context.
      *(completed)*
- [x] Strip all 6 warning (U+26A0, with U+FE0F where present) instances (lines 785, 786, 787,
      790, 1001, 1012), deleting the trailing variation selector along with the glyph.
      *(completed)*
- [x] Strip both memo (U+1F4DD) instances and the single mouse (U+1F5B1 + U+FE0F) instance on
      line 788 (all table cells, Rule A). *(completed)*
- [x] Strip the single recycle (U+1F504) on line 82 heading (Rule B). *(completed)*
- [x] Apply the SPECIAL CASE to lines 86 and 942: delete the whole ` (<gear>)` span on each.
      *(completed)*
- [x] Do NOT touch: the 26 arrows (right/left-right/down), the single-line box-drawing diagram
      (lines ~47-60), the double-line "Quick Reference Card" diagram (lines ~623-638), the
      in-diagram bullets, or the em-dash on line 101. *(completed — verified via git diff:
      no box-drawing/arrow characters appear in the diff)*

**Timing**: ~40 minutes

**Depends on**: none

**Files to modify**:
- `docs/niri.md` — delete the 83 STRIP glyphs (plus adjacent space per Rule A/B, or the whole
  ` (glyph)` span for the two gear lines). No other content changes.

**Verification** (phase-local sanity check, full verification in Phase 2):
- Spot-check that each edited line reads cleanly with no doubled or leading/trailing stray space
  and no orphaned stars or dangling parentheses.

---

### Phase 2: Verify strip completeness and structural preservation [COMPLETED]

**Goal**: Prove mechanically that all decorative glyphs are gone, the structural characters
survive, and spacing is clean — no Nix build involved.

**Tasks**:
- [x] Grep `docs/niri.md` for each of the 8 STRIP glyphs (checkmark, star, cross, warning, memo,
      gear, mouse, recycle) — every one MUST return zero hits. Suggested single sweep:
      `grep -noP "[\x{2705}\x{2B50}\x{274C}\x{26A0}\x{1F4DD}\x{2699}\x{1F5B1}\x{1F504}\x{FE0F}]" docs/niri.md`
      must produce no output. *(completed — zero hits confirmed)*
- [x] Grep for the preserved right-arrow (U+2192): `grep -c "\xe2\x86\x92" docs/niri.md` (or
      `grep -oP "\x{2192}"` count) must still show the arrows (23 expected); also confirm the
      left-right-arrow (U+2194, ×2) and down-arrow (U+2193, ×1) survive. *(completed — 23/2/1
      confirmed unchanged from pre-edit baseline)*
- [x] Confirm the two ASCII-art diagrams are intact: visually inspect (or `sed -n`) the
      single-line box-drawing block (lines ~47-60) and the double-line "Quick Reference Card"
      block (lines ~623-638) — box-drawing characters and the in-diagram down-arrow/bullets
      unchanged. *(completed — both diagrams byte-for-byte identical to pre-edit read; confirmed
      absent from the git diff)*
- [x] Grep for a dangling empty parenthesis pair: `grep -n "()" docs/niri.md` must return no
      hits introduced by this change (specifically confirm lines 86 and 942 read
      `Click gear icon at bottom-right`). *(completed — zero hits; both lines read correctly)*
- [x] Confirm no doubled spaces were introduced on edited lines: spot-check with
      `grep -nP "  " docs/niri.md` against the ~56 touched lines (ignore any intentional
      alignment inside code blocks / diagrams). *(completed — remaining double-space hits are
      all pre-existing code-block/diagram indentation, none on the 56 edited lines)*
- [x] Confirm only `docs/niri.md` changed: `git status --short` should list exactly that one file.
      *(completed — confirmed for this task's scope; other concurrently-modified files in the
      working tree belong to task 96, running in parallel, and are out of this task's scope)*

**Timing**: ~15 minutes

**Depends on**: 1

**Files to modify**: None (verification only).

**Verification**:
- All six task checks above pass: zero STRIP-glyph hits, arrows present, both diagrams intact,
  no dangling `()`, no stray doubled spaces, single-file diff.

## Testing & Validation

- [x] `grep` for the 8 STRIP glyphs (U+2705, U+2B50, U+274C, U+26A0, U+1F4DD, U+2699, U+1F5B1,
      U+1F504, and trailing U+FE0F) returns zero hits in `docs/niri.md`.
- [x] `grep` for the right-arrow still shows the preserved arrows (23), plus U+2194 (×2) and
      U+2193 (×1).
- [x] Both ASCII-art diagrams (lines ~47-60 and ~623-638) are byte-for-byte unchanged.
- [x] No dangling `()` anywhere; lines 86 and 942 read `2. Click gear icon at bottom-right`.
- [x] No doubled/orphaned spaces on the ~56 edited lines.
- [x] `git status --short` shows only `docs/niri.md` modified (within this task's scope). No Nix
      build run.

## Artifacts & Outputs

- `docs/niri.md` (modified: 83 glyphs stripped across 56 lines)
- `specs/100_strip_niri_doc_emoji/plans/01_strip-niri-doc-emoji.md` (this plan)
- `specs/100_strip_niri_doc_emoji/summaries/01_strip-niri-doc-emoji-summary.md` (produced at
  implementation)

## Rollback/Contingency

Single-file, markdown-only change with no build side effects. If the strip is wrong (e.g. an
arrow removed or a diagram touched), revert with `git checkout -- docs/niri.md` (clean-tree
form; the file is committed) and re-apply against the report's inventory. Because the change is
mechanical and isolated to one file, a full revert carries no downstream risk.

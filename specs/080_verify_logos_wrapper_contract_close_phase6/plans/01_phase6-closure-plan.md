# Implementation Plan: Task #80

- **Task**: 80 - Live-verify the task-79 email wrapper multi-account contract and produce a self-contained, /spawn-ready closure report the nvim email/ extension consumes to finish its remaining Phase-6 work
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: 79 (`email_wrappers_multi_account`, COMPLETED and switched in)
- **Research Inputs**: specs/080_verify_logos_wrapper_contract_close_phase6/reports/01_contract-verification-research.md
- **Artifacts**: plans/01_phase6-closure-plan.md (this file); summaries/01_phase6-closure-report.md (the deliverable)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

Research (report 01) already performed the entire live verification: all 9 contract rows PASS
with zero divergence, the exact shipped `--account <gmail|logos>` enum was confirmed verbatim in
all five wrapper `--help` outputs, live `email-census --account logos` counts were captured
(INBOX 62 / Sent 12 / Archive 54 / Trash 1764 / Drafts 10), and the read-only/dry-run
`/email --logos` exercise (census -> classify -> archive/delete dry-run) was proven end-to-end
with correct `folder:Logos` / `folder:Logos/.Archive` scoping. This plan therefore does NOT
re-run verification. Its sole job is to **author a polished, self-contained closure report**
that doubles as both the task summary AND the artifact the user hands to `/spawn` in the nvim
repo to finish the remaining nvim-side Phase-6 edits with no back-references needed. Definition
of done: the closure report exists, is non-empty, is fully self-contained (a fresh nvim agent
needs nothing but this one file), and its "WHAT THE NVIM AGENT MUST DO" checklist plus
folder-token table are present and internally consistent.

### Research Integration

All substantive content is sourced from report 01
(`reports/01_contract-verification-research.md`): Finding 1 (rows 1-9 verdict table), Finding 2
(live Logos/Gmail census output), Finding 3 (proven read-only/dry-run exercise sequence),
Finding 4 (assembled closure-note content: confirmed enum, per-account folder-token table,
mbsync channel mapping, no-new-binaries fact, precondition-gate status). The reciprocal handoff
`specs/079_email_wrappers_multi_account/reports/03_nvim-extension-followup-handoff.md` supplies
the §2 rows 1-9 framing, the §4 Phase-6 checklist, and the §6 cross-repo pointers that the
closure report restates so the nvim agent needs no back-reference.

### Prior Plan Reference

No prior plan. This is the first plan for task 80.

### Roadmap Alignment

No ROADMAP.md consulted (none provided in delegation context). This task closes the cross-repo
Phase-6 loop between .dotfiles task 79 and nvim task 815.

## Goals & Non-Goals

**Goals**:
- Author a single self-contained closure report at
  `summaries/01_phase6-closure-report.md` that is directly `/spawn`-ready for the nvim repo.
- Include all six required content blocks (status banner; rows 1-9 verdict table with the exact
  `--account` enum spelling; per-account folder-token + mbsync-channel + no-new-binaries table
  formatted for wrapper-contracts.md §2/§11; the live `/email --logos` exercise results; an
  explicit "WHAT THE NVIM AGENT MUST DO" checklist; cross-repo source-file pointers).
- Make the report double as the task summary so no separate summary artifact is needed.

**Non-Goals**:
- Re-running any live verification (research already proved all of it). No `email-census`,
  `email-classify`, or dry-run mutation re-run is required; a trivially cheap spot-check is
  permitted but not necessary.
- Any `--execute` mail mutation, `home-manager switch`, or `mbsync` invocation.
- Any nix build (`nix flake check`, `home-manager build`) — this task touches no nix.
- Any edit to the nvim repo (`~/.config/nvim/...`), to `wrapper-contracts.md`,
  `archive-mode-risk.md`, or the task-815 plan marker — the report only ENABLES those edits.
- Any edit to `modules/home/email/agent-tools.nix` or `mbsync.nix`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Report contains unresolved "see other report" gaps, forcing the nvim agent to chase back-references | M | M | Phase 2 explicitly greps for and eliminates dangling cross-references; all rows-1-9 evidence, the folder-token table, and the exercise results are inlined verbatim from report 01 |
| Folder-token table or `--account` enum transcribed inaccurately from research | H | L | Copy the table and enum verbatim from report 01 Finding 1 / Finding 4; Phase 2 diff-checks the transcription against the research report |
| Checklist omits one of the three concrete nvim actions (wrapper-contracts.md refresh; archive-mode-risk.md generalization; task-815 Phase 6 marker flip) | M | L | Phase 2 verifies all three actions with their exact target paths are present in the checklist |
| Accidental scope creep into nvim-repo edits or live mutation | H | L | Non-Goals enumerated above; no wrapper or nix command is part of either phase |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Author the self-contained closure report [COMPLETED]

- **Goal:** Write `summaries/01_phase6-closure-report.md` — the single deliverable that serves
  as both the task summary AND the `/spawn`-ready handoff a fresh nvim agent consumes with no
  back-references. Source every fact from report 01; do not re-run live commands.
- **Tasks:**
  - [x] Create `summaries/01_phase6-closure-report.md` with a title and a short framing header
        naming its dual purpose (task-80 summary + nvim `/spawn` handoff) and the direction
        (.dotfiles -> `~/.config/nvim` nvim task 815 Phase 6). *(completed)*
  - [x] **Section 1 — Status banner**: task 79 landed and is switched in; all 9 contract rows
        PASS (zero divergence); the nvim `/email --logos` precondition gate now PASSES. (Source:
        report 01 Executive Summary + Finding 4 "Precondition gate status".) *(completed)*
  - [x] **Section 2 — Rows 1-9 verdict table**: copy the Finding 1 verdict table verbatim
        (`#`, Assumption, Verdict PASS, Evidence) and state the EXACT shipped enum spelling
        `--account <gmail|logos>` (and its `=`-form `--account=<value>`), default `gmail`,
        unknown-account rejected with actionable error. (Source: report 01 Finding 1 +
        "Exact flag spelling shipped".) *(completed)*
  - [x] **Section 3 — Contract data block formatted for wrapper-contracts.md §2/§11**: the
        per-account folder-token table (gmail: `folder:Gmail` / `folder:Gmail/.All_Mail` /
        real folders `.All_Mail,.Sent,.Trash,.Spam,.Drafts`; logos: `folder:Logos` /
        `folder:Logos/.Archive` / real folders `.Sent,.Archive,.Drafts,.Trash`, no
        `.All_Mail`/`.Spam`); the mbsync channel mapping (`gmail -> mbsync gmail` Group `gmail`
        mbsync.nix:114-119; `logos -> mbsync logos` Group `logos` mbsync.nix:190-197; never
        `mbsync -a`); the no-new-binaries fact (same 5 binaries; `mail-guard.sh` empty diff
        across the full task-79 range). (Source: report 01 Finding 4 table + bullets.) *(completed)*
  - [x] **Section 4 — Live `/email --logos` exercise results**: the census counts (Logos INBOX
        62 / Sent 12 / Archive 54 / Trash 1764 / Drafts 10, and bare-gmail baseline for
        contrast); the classify read/tag-only result (query matched 62, processed first 2,
        candidates NOT approved); the archive/delete dry-run scoping proof (`PLAN: move ...
        (envelope 885 in INBOX) -> Archive` and `PLAN: move-to-Trash ... (envelope 885 in
        INBOX)`, proving `folder:Logos` resolution and `Archive` (not `All_Mail`) targeting).
        (Source: report 01 Findings 2 and 3.) *(completed)*
  - [x] **Section 5 — "WHAT THE NVIM AGENT MUST DO" checklist**: explicit, self-contained
        action items — (a) refresh
        `~/.config/nvim/.claude/extensions/email/context/project/email/domain/wrapper-contracts.md`
        §2/§11 with the confirmed enum + folder-token table from Section 3; (b) *(optional
        editorial)* generalize the illustrative `folder:Gmail/.All_Mail` tokens in
        `.../domain/archive-mode-risk.md` to be account-neutral; (c) flip the task-815 plan
        Phase 6 marker `[BLOCKED]` -> `[COMPLETED]` in
        `~/.config/nvim/specs/815_revise_email_extension_multi_account/plans/01_email-multi-account-support.md`.
        (Source: report 01 Finding 4 + report 03 §4 checklist.) *(completed)*
  - [x] **Section 6 — Cross-repo source pointers**: .dotfiles side
        (`modules/home/email/agent-tools.nix` with the resolver/census/classify/mutation line
        refs, `modules/home/email/mbsync.nix:114-119,190-197`, `.claude/hooks/mail-guard.sh`);
        nvim side (extension dir, wrapper-contracts.md, archive-mode-risk.md, task-815 dir).
        (Source: report 01 References + report 03 §6.) *(completed)*
  - [x] Ensure the report reads standalone: no phrase requires the reader to open report 01 or
        report 03 to act (restate, do not merely cite). *(completed)*
- **Timing:** ~40 minutes
- **Depends on:** none
- **Files to modify:**
  - `specs/080_verify_logos_wrapper_contract_close_phase6/summaries/01_phase6-closure-report.md`
    (create) - the closure report / deliverable
- **Verification:**
  - The file exists and is non-empty.
  - All six sections (1 status banner, 2 rows-1-9 table, 3 wrapper-contracts.md-ready table,
    4 exercise results, 5 nvim checklist, 6 pointers) are present.
  - The `--account <gmail|logos>` enum spelling and the folder-token table match report 01
    verbatim.

### Phase 2: Verify self-containment and internal consistency [COMPLETED]

- **Goal:** Confirm the closure report is non-empty, self-contained (no unresolved
  "see other report" gaps for the nvim agent), and that its checklist and folder-token table are
  present and internally consistent with the rows-1-9 verdict.
- **Tasks:**
  - [x] Confirm the file exists and is non-empty (`test -s`). *(completed: 251 lines)*
  - [x] Grep for dangling back-references (e.g. "see report", "see report 01", "report 03",
        "see §", "as noted above in the research") that would force the nvim agent to open
        another file to act; resolve any by inlining the needed content. (Pointers to source
        files in Section 6 are allowed — those are optional deep-dive references, not
        action-blocking gaps.) *(completed: grep found zero matches)*
  - [x] Confirm the "WHAT THE NVIM AGENT MUST DO" checklist is present and names all three
        concrete actions with their exact target paths (wrapper-contracts.md §2/§11;
        archive-mode-risk.md generalization; task-815 plan Phase 6 marker flip).
        *(completed: all three present with exact paths, Section 5)*
  - [x] Confirm the per-account folder-token table is present and internally consistent with
        the rows-1-9 verdict (Logos archive is `folder:Logos/.Archive` not `.All_Mail`; Gmail
        archive is `folder:Gmail/.All_Mail`; Logos has no `.All_Mail`/`.Spam`). *(completed:
        Section 3 table matches Section 2 verdict rows 4-5 verbatim)*
  - [x] Confirm the status banner's three claims (79 switched in; 9/9 PASS; precondition gate
        PASSES) are stated and consistent with the verdict table. *(completed: Section 1)*
  - [x] (Optional, trivially cheap) spot-check `email-census --help` shows
        `--account <gmail|logos>` to reconfirm the enum in the report — only if it costs
        nothing; otherwise rely on report 01's already-live-confirmed evidence. *(completed:
        live spot-check this session reconfirmed `--account <gmail|logos> Account to operate
        on (default: gmail)` verbatim)*
- **Timing:** ~15 minutes
- **Depends on:** 1
- **Files to modify:**
  - None (verification only; edit Phase-1 output in place if a gap is found).
- **Verification:**
  - `test -s summaries/01_phase6-closure-report.md` passes.
  - Grep confirms no action-blocking back-references remain.
  - All three nvim checklist actions and the folder-token table are present and consistent.

## Testing & Validation

- [ ] `summaries/01_phase6-closure-report.md` exists and is non-empty.
- [ ] All six required content blocks are present (status banner; rows-1-9 verdict table with
      exact enum; wrapper-contracts.md-ready folder-token + mbsync + no-new-binaries table;
      live exercise results; nvim checklist with all three actions; cross-repo pointers).
- [ ] The report is self-contained: a fresh nvim agent can act on it with no back-references
      (verified by grep for dangling cross-references).
- [ ] Folder-token table and rows-1-9 verdict are internally consistent (Logos archive
      `folder:Logos/.Archive`, no `.All_Mail`/`.Spam`; Gmail unchanged).
- [ ] No nvim-repo file was edited; no `--execute` mutation, `home-manager switch`, `mbsync`,
      or nix build was run.

## Artifacts & Outputs

- `specs/080_verify_logos_wrapper_contract_close_phase6/plans/01_phase6-closure-plan.md` (this plan)
- `specs/080_verify_logos_wrapper_contract_close_phase6/summaries/01_phase6-closure-report.md`
  (the deliverable — doubles as task summary AND the nvim `/spawn` handoff)

## Rollback/Contingency

Single new file with no side effects. If the report is wrong or incomplete, re-edit or delete
`summaries/01_phase6-closure-report.md` and re-author from report 01 — no system state, mail
state, or nix state is touched by this task, so there is nothing else to revert.

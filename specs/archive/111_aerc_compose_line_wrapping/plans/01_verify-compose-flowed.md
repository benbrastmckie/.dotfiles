# Implementation Plan: Task #111

- **Task**: 111 - Stop aerc-composed/replied email from hard-wrapping at ~72-80 columns
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None (independent of tasks 110/112/113, which touch other blocks of the same file)
- **Research Inputs**: specs/111_aerc_compose_line_wrapping/reports/01_aerc-compose-flowed-verification.md
- **Artifacts**: plans/01_verify-compose-flowed.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: true

## Overview

The two-line fix for this task is already drafted (uncommitted) in `modules/home/email/aerc.nix`'s `[compose]` block, and research VERIFIED it as correct, complete, and sufficient — no code changes are required. This is therefore a verify-and-confirm plan, not an author-from-scratch plan: confirm the drafted edits are present and match the verified values, confirm the configuration builds, then commit only the compose-block changes. Runtime verification (sending a long-paragraph test message and inspecting headers) is a manual user step performed outside this plan.

### Research Integration

The research report confirms both drafted lines are correct for aerc 0.21.0 / nvim 0.12.x:
- `editor = "nvim -c 'setlocal textwidth=0 formatoptions-=t'"` — quoting is parsed by a real POSIX shell (`/bin/sh -c`), and the `-c` override deterministically runs *after* nvim's `mail` ftplugin, re-zeroing `textwidth` and stripping the `t` autowrap flag. Live-reproduced (`tw=0`, no `t` in `fo`).
- `format-flowed = true` — exact, correctly-cased `[compose]` key per the locally installed `aerc-config(5)`; passes through home-manager's freeform `extraConfig` verbatim.
- No additional aerc/nvim settings are needed (`lf-editor`, viewer-side wrap filter, and `edit-headers` are all explicitly out of scope).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found (roadmap flag not set).

## Goals & Non-Goals

**Goals**:
- Confirm the drafted `[compose]` edits (`editor` override + `format-flowed = true`) are present and byte-for-byte match the research-verified values.
- Confirm the Home Manager configuration builds with the drafted edits (`home-manager build --flake .#benjamin`).
- Commit only the compose-block changes to `modules/home/email/aerc.nix`, leaving the unrelated task 110/112/113 changes in the same file unstaged.

**Non-Goals**:
- Authoring or modifying the fix (research confirmed it needs no changes).
- Committing the intermingled querymap / archive-hook edits in the same file (those belong to tasks 110/112/113).
- Runtime send-test verification (a manual user step, documented below but not performed by the agent).
- Any viewer-side format=flowed reflow filter (out of scope; possible future task).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Over-staging the shared file pulls in task 110/112/113 hunks | M | M | Use `git add -p` (patch mode) to stage only the two `[compose]` hunks; never `git add <file>` wholesale, never `git add -A` / `git commit -am`. Verify with `git diff --staged` before committing. |
| Drafted edits drift or were reverted since research | L | L | Phase 1 re-reads the `[compose]` block and diffs against the verified values before anything else. |
| Build fails for a reason unrelated to this task | L | L | Build the current working tree as-is; if failure is outside `modules/home/email/aerc.nix`, record it and treat as a pre-existing/blocking condition rather than a defect of this fix. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Verify drafted compose edits [COMPLETED]

**Goal**: Confirm the two drafted `[compose]` lines are present in the working tree and match the research-verified values.

**Tasks**:
- [x] Read the `[compose]` block of `modules/home/email/aerc.nix`.
- [x] Confirm `editor = "nvim -c 'setlocal textwidth=0 formatoptions-=t'";` is present exactly.
- [x] Confirm `format-flowed = true;` is present in the same `[compose]` block.
- [x] Confirm no other change to the fix is needed (research recommended none).

**Timing**: 0.1 hours

**Depends on**: none

**Files to modify**:
- None (read-only verification of `modules/home/email/aerc.nix`).

**Verification**:
- Both drafted lines are present and match the verified values character-for-character.

---

### Phase 2: Build verification [COMPLETED]

**Goal**: Confirm the Home Manager configuration evaluates and builds with the drafted edits.

**Tasks**:
- [x] Run `home-manager build --flake .#benjamin` from the repo root.
- [x] Confirm the build succeeds (exit 0).

**Timing**: 0.2 hours

**Depends on**: 1

**Files to modify**:
- None (build-only).

**Verification**:
- `home-manager build --flake .#benjamin` exits 0. If it fails, capture the error; a failure localized to `aerc.nix`/`extraConfig` blocks the task, whereas an unrelated failure is recorded as a pre-existing condition.

---

### Phase 3: Scoped commit of compose changes [NOT STARTED]

*(deviation: deferred to orchestrator — the orchestrator's consolidated final commit step handles
scoped staging/commit across tasks 110/111/112/113 in this shared file, since it has full batch
visibility across all four tasks' hunks. This agent explicitly did not run `git add` or
`git commit` per delegation instructions.)*

**Goal**: Commit only the `[compose]`-block changes to `modules/home/email/aerc.nix`, leaving the unrelated task 110/112/113 hunks (querymap INBOX rescope, archive-on-reply hook) unstaged.

**Tasks**:
- [ ] Stage only the two `[compose]` hunks via `git add -p modules/home/email/aerc.nix` (select the `editor` override + `format-flowed` hunk; skip the `hooks`/`querymap` hunks). *(deviation: deferred to orchestrator's consolidated commit)*
- [ ] Review with `git diff --staged` to confirm ONLY the compose `editor` and `format-flowed` changes are staged. *(deviation: deferred to orchestrator's consolidated commit)*
- [ ] Commit with message `task 111: enable format-flowed and disable compose hard-wrap` including the session ID in the body. *(deviation: deferred to orchestrator's consolidated commit)*
- [ ] Confirm the querymap and archive-hook changes remain unstaged (`git status --short`). *(deviation: deferred to orchestrator's consolidated commit)*

**Timing**: 0.2 hours

**Depends on**: 2

**Files to modify**:
- `modules/home/email/aerc.nix` — commit the `[compose]` `editor` and `format-flowed` lines only (no content edit; staging/commit only).

**Verification**:
- `git diff --staged` before commit shows only the compose `editor` + `format-flowed` lines.
- After commit, `git status --short` still lists `modules/home/email/aerc.nix` as modified (the task 110/112/113 hunks remain), confirming scoped staging.

## Testing & Validation

- [ ] Phase 1: both drafted `[compose]` lines present and verified.
- [ ] Phase 2: `home-manager build --flake .#benjamin` exits 0.
- [ ] Phase 3: staged diff contains only the compose changes; commit created; unrelated hunks remain unstaged.
- [ ] **Manual (user, post-merge/switch)**: compose or reply to a message with a long paragraph in aerc; confirm (a) nvim inserts no hard line break mid-paragraph while typing, and (b) the sent message's raw source carries `Content-Type: text/plain; format=flowed`. Optional headless proxy for (a): `/bin/sh -c "nvim -c 'setlocal textwidth=0 formatoptions-=t' <tmp>.eml --headless -c \"echo 'tw='.&tw.' fo='.&fo\" -c 'qa!'"` against an `aerc-compose-*.eml`-named tempfile, expecting `tw=0` and no `t` in `fo`.

## Artifacts & Outputs

- A scoped git commit containing only the `modules/home/email/aerc.nix` `[compose]` `editor` and `format-flowed` changes.
- Confirmation that `home-manager build --flake .#benjamin` succeeds with the drafted edits.

## Rollback/Contingency

- If the build fails due to the compose edits: unstage (`git restore --staged modules/home/email/aerc.nix`), report the evaluation error, and leave the working-tree edits intact for revision (do not discard uncommitted work).
- If a scoped commit accidentally includes task 110/112/113 hunks: reset the commit softly (`git reset --soft HEAD~1`), re-run `git add -p` with correct hunk selection, and re-commit. Do not force-push or run destructive git on the dirty tree without a snapshot.

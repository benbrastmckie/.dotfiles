# Implementation Plan: Task #141

- **Task**: 141 - Prevent Sapience hook reinjection (close the recurrence gap left by task 138)
- **Status**: [IMPLEMENTING]
- **Effort**: 1.25 hours
- **Dependencies**: 142 (landed — see Premise Re-Validation)
- **Research Inputs**: specs/141_prevent_sapience_hook_reinjection/reports/01_prevent-sapience-hook-reinjection.md
- **Artifacts**: plans/01_prevent-sapience-hook-reinjection.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

The only unmet code gap this task still owns is the FOURTH DEFECT: `_SAPIENCE_NOTE` is absent
from `home.activation.claudeSettings`'s enforced-key array, so the live
`~/.claude/settings.json`'s copy of that note is preserved across switches and today still
carries pre-task-138 text that misattributes the vendor's machine-wide hooks to
`modules/home/services/sapience.nix` and claims they are guarded. The fix is a one-token
insertion into that array, plus two documentation hunks that make the live file and the
activation entry self-explaining about *which* layer owns detection. Dispatch scope items (a)
and (c)/(d) are already satisfied by work verified below rather than re-implemented here: the
enforced-key reset already fully converges `.hooks` on every switch (empirically reproduced
during research), and the between-activations detector shipped with task 142 and in the
agent-system sapience extension's own verifier. Definition of done: after a real
`home-manager switch`, the live `_SAPIENCE_NOTE` matches `config/claude/settings.json`
verbatim, `nix flake check` is green, and the live file still carries exactly one Sapience hook
entry.

### Research Integration

The research report's four Decisions are adopted unchanged and shape this plan's narrow scope:

- **Finding 2 (adopted as a verified no-op)**: the `claudeSettings` jq pipeline's
  `reduce $enforced[] as $k (...)` step does a flat `.hooks = $src.hooks` whenever the source
  declares `hooks`, so the three measured vendor entries are stripped in full on every switch.
  This was reproduced against a synthetic live file carrying the exact 2026-11-14 three-hook
  state, not read off the comment. Scope (a)'s literal ask ("actively strip ... instead of
  relying only on the enforced-key reset") is therefore a defense-in-depth addition, and the
  thing it would add now exists elsewhere (below), so this plan adds no stripping code.
- **Finding 3 + Decision 2 (adopted)**: the between-activations detector is not built here. Its
  automatic, every-switch form is `sapienceHooksGuard` in `modules/home/services/sapience.nix`
  (declared `entryBefore [ "claudeSettings" ]` so it reads the pre-merge live file) calling
  `scripts/check-sapience-hooks.sh`; its on-demand form is `verify-sapience-mcp.sh`'s
  vendor-hook-recurrence check in the agent-system sapience extension's source store. Both are
  now committed (the first landed with task 142 during this same orchestration run), so a third
  detector here would be duplicate code in a file region another task owns.
- **Decision 3 (adopted)**: the remaining concrete change is the `_SAPIENCE_NOTE` enforced-key
  addition.
- **Recommendation 3 (resolved, see Decisions below)**: whether the note should gain a pointer
  to the shipped layers was left to planning; this plan resolves it as yes, one sentence.
- **Recommendation 4 (adopted)**: the live-file state is time-dependent, so Phase 2 re-reads it
  rather than reciting any earlier snapshot.

### Premise Re-Validation

Per report-format.md's Carried-Figure Discipline, every carried figure in the dispatch
description was re-checked against live state on 2026-11-18, including the extracted SCOPE line.
Results, stated even where they confirm the description unchanged:

1. **Enforced-key list — CONFIRMED UNCHANGED.** `modules/home/core/dotfiles.nix:107` still reads
   `--argjson enforced '["_NOTE","env","hooks","model","permissions","statusLine"]'`;
   `_SAPIENCE_NOTE` is absent. Scope (b) stands exactly as described. A repo-wide grep finds the
   list spelled out in no other non-`specs/**` file, so there is no second copy to keep in sync.
2. **FOURTH DEFECT — CONFIRMED PRESENT TODAY.** `jq -r '._SAPIENCE_NOTE' ~/.claude/settings.json`
   returns the stale text ("owned by modules/home/services/sapience.nix", "guarded with a
   `[ -f ~/.sapience/mcp.py ]` test"), which does not match
   `jq -r '._SAPIENCE_NOTE' config/claude/settings.json`. Both of the dispatch's two
   wrongness claims about that live text are accurate.
3. **The three-vendor-hook measurement — NO LONGER DESCRIBES LIVE STATE.** The live file's
   `SessionStart` carries the inhibitor, the lean-lsp registration hook, and the
   `sapience-mcp-register-project.sh` registration hook; `SessionEnd` carries only the inhibitor
   cleanup; there is no `Stop` entry. No command anywhere in the live file references
   `.sapience/mcp.py`. `jq '.hooks' ~/.sapience/config.json` is `false`. The dispatch's
   2026-11-14 evidence was real but has since been converged — do not treat the three entries as
   present when writing the implementation summary.
4. **Scope (c)/(d) — the detector is SHIPPED, not merely planned** (the research report, written
   before task 142's implementation phases closed, described it as planned). Confirmed on disk:
   `scripts/check-sapience-hooks.sh` exists and is executable;
   `modules/home/services/sapience.nix:922` declares
   `sapienceHooksGuard = config.lib.dag.entryBefore [ "claudeSettings" ]` invoking that script;
   `docs/sapience.md:676` carries the "The three layers that keep machine-wide hooks out of
   settings.json" section. Commits `f4db314`, `16da4b7`, `01aadc4`, `24dc083`, `0f398a8`.
5. **Vendor ceiling — unchanged and still the governing constraint.** `~/.sapience/mcp.py`
   remains vendor-owned and self-updating, so this task's target stays convergence plus
   detection, not another one-time cleanup.

### Prior Plan Reference

No prior plan for this task.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch, so no roadmap consultation was performed.

## Goals & Non-Goals

**Goals**:

- Add `"_SAPIENCE_NOTE"` to `home.activation.claudeSettings`'s enforced-key array so the live
  note text can no longer drift from `config/claude/settings.json` (dispatch scope (b), FOURTH
  DEFECT).
- Record the detector-siting decision durably in the two files this task edits, so a reader of
  either the activation entry or the live settings file learns which layer owns detection and
  which owns reversion (dispatch scope (c)/(d)'s "Record the siting decision either way").
- Verify, against live state rather than a recited snapshot, that a real switch converges
  `_SAPIENCE_NOTE` to source and leaves exactly one Sapience hook entry in the live file.

**Non-Goals**:

- Adding any vendor-hook stripping or detection code to
  `home.activation.claudeSettings`. The enforced-key reset already strips (verified), and
  detection is owned by `sapienceHooksGuard` / `scripts/check-sapience-hooks.sh`.
- Editing `modules/home/services/sapience.nix`, `scripts/check-sapience-hooks.sh`, or
  `docs/sapience.md`. The first two are task 142's landed territory and need no amendment; the
  third is in a concurrent sibling's declared `file_scope` (see Risks).
- Re-doing task 138's removal of the five machine-wide hook entries from
  `config/claude/settings.json`. That source file's `hooks` object is correct.
- Any edit under `.claude/**` (a disposable deploy mirror per
  `rules/source-store-deploy-boundary.md`) or to the agent-system sapience extension's
  `verify-sapience-mcp.sh`, which lives in a different repository's source store.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `nixfmt --check` reflows the long `--argjson` line after the insertion, failing `nix flake check` | L | M | Phase 1 inserts the token in place without disturbing the surrounding whitespace runs, then runs `nixfmt` on the file and `nix flake check` before closing; accept whatever `nixfmt` produces rather than hand-formatting |
| A concurrent sibling (task 144, research phase this cycle, `file_scope` includes `modules/home/services/sapience.nix`, `home.nix`, `modules/system/secrets.nix`, `docs/sapience.md`) lands an edit mid-flight, so Phase 2's `home-manager switch` fails for a reason outside this task's scope | M | L | Per the dispatch's concurrency note: re-read both target files immediately before editing, stage only this task's two files by explicit path, and treat a build failure in a file outside this task's `file_scope` as possibly a sibling's in-flight edit — stop and report rather than "fixing" it |
| Enforcing `_SAPIENCE_NOTE` removes an operator's ability to hand-annotate the live note (the next switch reverts it) | L | H | This is the intended effect and matches every other enforced key; the rationale is already stated in the activation entry's own comment block ("Adding a key to ENFORCED makes it repo-owned ... so add deliberately") and Phase 1 extends that block to say why this key qualifies |
| The live file regresses between Phase 1 and Phase 2 if the vendor's daily auto-update re-runs | L | M | Harmless to this task: Phase 2's switch reconverges both `hooks` and `_SAPIENCE_NOTE`, and `sapienceHooksGuard` will report the injection loudly before the merge — observing that happen would be a confirmation of the shipped design, and should be recorded in the summary rather than treated as a Phase 2 failure |
| The note's new pointer sentence drifts from `docs/sapience.md` if that document's section is later renamed | L | L | The pointer cites the section by its heading text (a durable anchor), not by line number, and names the two mechanisms directly so the sentence stands alone if the heading moves |

## Decisions

1. **Detector siting (dispatch scope (c)/(d)) — not here.** The automatic, every-switch detector
   belongs in `modules/home/services/sapience.nix`'s `sapienceHooksGuard` plus
   `scripts/check-sapience-hooks.sh`, which is where it now lives; the on-demand counterpart
   belongs in the agent-system sapience extension's `verify-sapience-mcp.sh`, in the repository
   that owns that extension's source store. `home.activation.claudeSettings` stays the backstop
   that *reverts* what those two *report*. Grounds: the guard must read the live file **before**
   the enforced-key merge to observe an injection at all, which is why it is declared
   `entryBefore [ "claudeSettings" ]` — an inverted ordering, or a detector built inside
   `claudeSettings` itself, would inspect a file the merge had already cleaned and would be
   structurally dead code that looks like a working check. This plan records the decision in
   `modules/home/core/dotfiles.nix`'s own comment block (Phase 1), which is a durable deliverable
   this task already edits, rather than only in a `specs/**` artifact.
2. **No stripping code added to `claudeSettings` (dispatch scope (a)).** Grounds: the research
   pass reproduced the exact merge pipeline against a synthetic live file carrying the measured
   three-vendor-hook state and observed `.hooks` come out as the source's object verbatim; the
   fallback path (`cp` on a missing, unparseable, or failed-merge live file) resets just as
   completely. A separate signature-targeted strip would duplicate the shipped guard's detection
   signature in a second place, with no additional convergence.
3. **`_SAPIENCE_NOTE` gains exactly one pointer sentence, not a fuller retelling.** Grounds: the
   note's job is to explain the one Sapience entry this source file owns; the three-layer story
   belongs in `docs/sapience.md`, which already tells it. But the note is now the enforced,
   authoritative text a reader meets when inspecting the live file — the very reader the FOURTH
   DEFECT misinformed — so one sentence naming the other two layers and pointing at that section
   is worth its length. This resolves the research report's Recommendation 3, which explicitly
   deferred the call to planning.
4. **Correction target confirmed to exist.** The artifact this task corrects is the
   `_SAPIENCE_NOTE` key in `config/claude/settings.json:128` and its mirror in the live
   `~/.claude/settings.json`; both were read on 2026-11-18 and both exist. No phase's goal turns
   on correcting an orchestration sidecar.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Enforce `_SAPIENCE_NOTE` and record the siting decision [COMPLETED]

**Goal**: `config/claude/settings.json`'s `_SAPIENCE_NOTE` becomes repo-owned, and both edited
files state which layer owns detection versus reversion.

**Tasks**:

- [x] Re-read `modules/home/core/dotfiles.nix` and `config/claude/settings.json` immediately
      before editing (concurrent-sibling discipline), confirming line 107's `--argjson enforced`
      array and line 128's `_SAPIENCE_NOTE` are still as this plan describes them.
- [x] Insert `"_SAPIENCE_NOTE"` into the enforced array at `modules/home/core/dotfiles.nix:107`,
      immediately after `"_NOTE"`, yielding
      `["_NOTE","_SAPIENCE_NOTE","env","hooks","model","permissions","statusLine"]`. Change
      nothing else on that line — the surrounding multi-space runs are `nixfmt` output and must
      survive the edit.
- [x] Extend the comment block above the `claudeSettings` entry (the block ending at the
      `Failure mode is fail-safe` paragraph, roughly lines 66-92) with a short paragraph stating
      (a) why `_SAPIENCE_NOTE` qualifies for ENFORCED — it documents which Sapience surfaces this
      file owns, and a stale live copy actively misinforms a reader of
      `~/.claude/settings.json` — and (b) that detecting a vendor hook injected *between* two
      switches is not this entry's job: `sapienceHooksGuard` in
      `modules/home/services/sapience.nix` (ordered `entryBefore` this entry so it reads the
      pre-merge file) via `scripts/check-sapience-hooks.sh` is the automatic detector,
      `verify-sapience-mcp.sh` in the agent-system sapience extension is the on-demand one, and
      this entry is the backstop that reverts what they report.
- [x] Append one sentence to `config/claude/settings.json`'s `_SAPIENCE_NOTE` value naming the
      `~/.sapience/config.json` `"hooks": false` opt-out and the `sapienceHooksGuard` activation
      entry as the two layers that keep the vendor's machine-wide hooks out of this file, and
      pointing at `docs/sapience.md`'s section "The three layers that keep machine-wide hooks out
      of settings.json" for the full account. Keep it to one sentence; do not restate the layers'
      internals. Use no task numbers and no draft-history phrasing (`rules/no-task-references-in-deliverables.md`,
      `rules/no-record-versioning-in-deliverables.md` — both files are outside `specs/**`).
- [x] Run `jq -e . config/claude/settings.json >/dev/null` to confirm the JSON still parses, then
      `nixfmt modules/home/core/dotfiles.nix` and `nix flake check`.
- [x] Commit both files by explicit path (`git add -- modules/home/core/dotfiles.nix
      config/claude/settings.json`), never a directory or glob add, after reviewing
      `git status --short` and `git diff --staged`.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for both
`modules/home/core/dotfiles.nix` and `config/claude/settings.json` (run during planning — no
agent-system shell suite maps a repository `.nix` or config `.json` file), so the honest covering
check is this repository's own authoritative gate, `nix flake check` (per `rules/nix.md`:
`statix`, `deadnix --fail`, `nixfmt --check`, `shellcheck`, and the `home-eval` evaluation
check), plus `jq -e . config/claude/settings.json` for the JSON edit.

**Scope Hypothesis**: this phase touches exactly two tracked files and three hunks (the enforced
array, the comment block above it, and the `_SAPIENCE_NOTE` string). Confirm with
`git diff --stat` showing those two paths and no others; if a fourth hunk or a third file turns
out to be required, stop and report it rather than widening the phase silently.

**Files to modify**:

- `modules/home/core/dotfiles.nix` - add `"_SAPIENCE_NOTE"` to the `--argjson enforced` array;
  extend the comment block with the ENFORCED rationale for that key and the detection-versus-
  reversion siting record
- `config/claude/settings.json` - append one pointer sentence to the `_SAPIENCE_NOTE` value

**Verification**:

- `jq -e . config/claude/settings.json >/dev/null` exits 0.
- `jq -r '._SAPIENCE_NOTE' config/claude/settings.json` shows the new sentence present and the
  existing text intact (no truncation of the surrounding content).
- `nix flake check` exits 0 (status checked, not just output skimmed), including
  `nixfmt --check` over the reflowed activation line.
- `grep -n '_SAPIENCE_NOTE' modules/home/core/dotfiles.nix` shows the key inside the enforced
  array.
- A dry replay of the merge pipeline against the current live file — the same jq expression the
  activation entry runs, with the edited source as `$src` and `~/.claude/settings.json` as
  `$live`, written to a scratch file and inspected rather than to the live path — shows
  `._SAPIENCE_NOTE` in the output equal to the source value.

---

### Phase 2: Activate and verify against live state [COMPLETED]

**Goal**: a real switch is observed to converge the live file, and the dispatch's acceptance
criteria are checked against what the machine actually reports.

**Tasks**:

- [x] Capture the pre-switch live state for the summary: `jq -r '._SAPIENCE_NOTE'
      ~/.claude/settings.json` and every `hooks.*[].hooks[].command` string, plus
      `jq '.hooks' ~/.sapience/config.json`.
- [x] Run a user-level `home-manager switch --flake .#benjamin` (the generation that owns
      `~/.nix-profile` and actually executes `home.activation`; `sudo` is unavailable inside this
      harness, and the NixOS-integrated generation stays out of sync until a human runs it — say
      so in the summary rather than claiming a system-level switch).
- [x] Confirm `_SAPIENCE_NOTE` in the live file now matches the source verbatim:
      `diff <(jq -r '._SAPIENCE_NOTE' config/claude/settings.json) <(jq -r '._SAPIENCE_NOTE'
      ~/.claude/settings.json)` produces no output.
- [x] Confirm the live file carries exactly one Sapience hook entry (the
      `sapience-mcp-register-project.sh` registration hook) and no command referencing
      `.sapience/mcp.py`, by enumerating every hook command rather than grepping the whole file.
- [x] Run `bash scripts/check-sapience-hooks.sh` standalone and record its exit status, and note
      whether `sapienceHooksGuard` printed anything during the switch (if it did, an injection
      occurred since the last switch — record it as a confirmation of the shipped design, with
      the reported commands quoted).
- [x] Re-confirm the three shipped layers are intact and consistent with the two new
      documentation hunks: `jq '.hooks' ~/.sapience/config.json` is `false`,
      `sapienceHooksGuard`'s `entryBefore [ "claudeSettings" ]` declaration is unchanged, and
      `docs/sapience.md`'s three-layer section still carries the heading the note now cites.
      Read-only — do not edit any of those files.
- [x] Run the repository's complete gate set and observe it green. *(deviation: altered — per
      the dispatch's Batch Gate Deferral directive, ran `nix flake check` directly (unmappable
      to `--only`/`--only-gate`: no shell-suite or gate-number maps to a repository `.nix`/
      config `.json` file) plus `bash .claude/scripts/verify-deploy.sh --skip-unchanged`
      (this repository is a deploy consumer, not the source store, so 23 of 24 agent-system
      gates `[SKIP]`; 12 checks ran, 0 failures). Both exited 0. The full unflagged sweep is
      deferred to the batch stage per that directive, not independently re-run here.)*
- [x] Record any issue or win as it arises via `issue-record.sh` (and attest explicitly in the
      handoff if there was genuinely nothing to record).

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: this phase changes no tracked file — it is operational verification only.
Confirm with `git status --short` showing no new or modified tracked file attributable to it; if
a defect surfaces that needs a source change, return to Phase 1 rather than editing here.

**Files to modify**:

- none planned (operational verification only)

**Verification**:

- The complete gate set for this repository, run and observed green rather than assumed:
  `nix flake check` (authoritative per `rules/nix.md` — `statix`, `deadnix --fail`,
  `nixfmt --check`, `shellcheck`, `home-eval`), plus
  `bash .claude/scripts/verify-deploy.sh /home/benjamin/.dotfiles` for the agent-system gates
  over this task's `specs/**` artifacts.
- `home-manager switch --flake .#benjamin` completes successfully.
- The `_SAPIENCE_NOTE` `diff` between source and live produces no output (acceptance criterion:
  "matches the source verbatim").
- Enumerated live hook commands show exactly one Sapience entry, the registration hook
  (acceptance criteria: "exactly one Sapience hook entry" and "no Sapience briefing, receipt, or
  effect line in a repository with no sapience extension loaded" — this task's contribution to
  the latter is indirect, via the layers task 142 landed, and must be stated as such rather than
  claimed as this task's own mechanism).
- `bash scripts/check-sapience-hooks.sh` exits 0 against the post-switch live file.
- `git status --short` shows no tracked-file change from this phase.

---

## Testing & Validation

- [ ] `jq -e . config/claude/settings.json` exits 0 after the note edit.
- [ ] `nix flake check` exits 0 at the close of Phase 1 (the only phase changing a tracked file)
      and again in Phase 2's full sweep.
- [ ] `bash .claude/scripts/verify-deploy.sh /home/benjamin/.dotfiles` is green in Phase 2.
- [ ] The source-versus-live `_SAPIENCE_NOTE` `diff` is empty after a real switch.
- [ ] The live file's enumerated hook commands contain exactly one Sapience entry and no
      `.sapience/mcp.py` reference.
- [ ] `bash scripts/check-sapience-hooks.sh` exits 0 post-switch.
- [ ] The summary reports live state as observed on the day of implementation, not the
      dispatch's 2026-11-14 snapshot (which Premise Re-Validation item 3 shows is stale).

## Artifacts & Outputs

- `modules/home/core/dotfiles.nix` — `_SAPIENCE_NOTE` added to the enforced-key array; comment
  block extended with the ENFORCED rationale and the detection-versus-reversion siting record.
- `config/claude/settings.json` — `_SAPIENCE_NOTE` gains one pointer sentence.
- `specs/141_prevent_sapience_hook_reinjection/summaries/01_prevent-sapience-hook-reinjection-summary.md`
  — implementation summary, including the observed live-state readings, the recorded siting
  decision, and explicit statements that dispatch scope (a) was a verified no-op and scope
  (c)/(d) was satisfied by already-shipped work.
- Two commits: one per phase (Phase 2 is verification-only and may close with no commit of its
  own if it changes no tracked file; the task-completion commit then carries the summary).

## Rollback/Contingency

Both edits are small, additive, and independently revertible, and neither changes behavior
outside `~/.claude/settings.json`:

- If `nix flake check` or the switch fails for a reason traceable to this task, revert the two
  hunks with `git revert` of the Phase 1 commit (preferred — leaves history intact and needs no
  working-tree discard) and re-run `nix flake check`.
- If an uncommitted working tree must be discarded instead, that is a genuine rollback: take a
  snapshot first per `context/contracts/recovery.md`'s rollback rung (including its
  out-of-scope override flag for a deliberate whole-tree case) before any
  `git reset`/`checkout`/`restore`, rather than emitting a bare precautionary snapshot call.
- If enforcing `_SAPIENCE_NOTE` proves unwanted, removing the single token from the enforced
  array restores the prior preserve-live behavior with no other consequence; the live note then
  keeps whatever text it last had until hand-corrected.
- A failure in a file outside this task's two paths (for example in
  `modules/home/services/sapience.nix` or `home.nix`) is more likely a concurrent sibling's
  in-flight edit than a regression from this task: check `git log` and `git status`, then stop
  and report rather than reverting another task's work.

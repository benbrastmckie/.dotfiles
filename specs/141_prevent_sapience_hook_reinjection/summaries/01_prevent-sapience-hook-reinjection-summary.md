# Implementation Summary: Prevent Sapience hook reinjection

- **Task**: 141 - Prevent Sapience hook reinjection (close the recurrence gap left by task 138)
- **Status**: [COMPLETED]
- **Started**: 2026-11-18T19:20:40Z
- **Completed**: 2026-11-18T19:58:00Z
- **Effort**: 1.25 hours (as planned)
- **Dependencies**: 142 (landed)
- **Artifacts**: plans/01_prevent-sapience-hook-reinjection.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

The only unmet code gap this task owned was the FOURTH DEFECT: `_SAPIENCE_NOTE` was absent from
`home.activation.claudeSettings`'s enforced-key array, so the live `~/.claude/settings.json`
copy of that note could drift from source and, before this change, carried stale text
misattributing the vendor's machine-wide hooks and claiming they were guarded. Dispatch scope
items (a) (stripping) and (c)/(d) (detector siting) were already satisfied by prior work —
task 142's `sapienceHooksGuard`/`scripts/check-sapience-hooks.sh` and the enforced-key reset
itself — so this task's only code change was a one-token insertion plus two documentation
hunks, followed by a real `home-manager switch` to verify convergence against live state.

## What Changed

- `modules/home/core/dotfiles.nix` — added `"_SAPIENCE_NOTE"` to the `claudeSettings`
  activation entry's `--argjson enforced` array (now `["_NOTE","_SAPIENCE_NOTE","env","hooks",
  "model","permissions","statusLine"]`), making the live note repo-owned. Extended the comment
  block above the entry with the ENFORCED rationale for that key and a durable
  detection-vs-reversion siting record naming `sapienceHooksGuard` (automatic, every-switch
  detector, `entryBefore [ "claudeSettings" ]`) and the agent-system sapience extension's
  `verify-sapience-mcp.sh` (on-demand detector), with this activation entry named explicitly as
  the backstop that reverts what those two report.
- `config/claude/settings.json` — appended one sentence to `_SAPIENCE_NOTE`'s value naming the
  `~/.sapience/config.json` `"hooks": false` opt-out and the `sapienceHooksGuard` activation
  entry as the two layers that keep the vendor's machine-wide hooks out of this file, pointing
  at `docs/sapience.md`'s "The three layers that keep machine-wide hooks out of settings.json"
  section for the full account.
- No other tracked file was modified. `modules/home/services/sapience.nix`,
  `scripts/check-sapience-hooks.sh`, and `docs/sapience.md` were read-only reference points,
  exactly as the plan's Non-Goals specified.

## Decisions

1. **Detector siting (dispatch scope (c)/(d)) resolved as already-shipped, not re-implemented
   here.** The automatic detector is `sapienceHooksGuard` in `modules/home/services/sapience.nix`
   plus `scripts/check-sapience-hooks.sh`; the on-demand counterpart is
   `verify-sapience-mcp.sh` in the agent-system sapience extension's own source store. Both
   predate this task's dispatch (landed with task 142 earlier in this run). The decision is now
   recorded durably in `modules/home/core/dotfiles.nix`'s own comment block, not only in this
   specs/** artifact.
2. **No stripping code added to `claudeSettings` (dispatch scope (a)).** The enforced-key
   reset's flat `.hooks = $src.hooks` assignment already fully converges the `hooks` object on
   every switch; a parallel signature-targeted strip would duplicate that convergence with no
   additional effect. Verified empirically in this run (see Impacts).
3. **`_SAPIENCE_NOTE` gains exactly one pointer sentence, not a fuller retelling of the
   three-layer design** — that full account already lives in `docs/sapience.md` and is cited by
   section heading rather than restated.

## Plan Deviations

- Phase 2's "Run the repository's complete gate set and observe it green" task was discharged
  under the dispatch's Batch Gate Deferral directive rather than literally: ran `nix flake
  check` directly (unmappable to `--only`/`--only-gate` — no shell-suite or gate-number maps to
  a repository `.nix`/config `.json` file) plus `bash .claude/scripts/verify-deploy.sh
  --skip-unchanged` (this repository is a deploy consumer, not the source store, so 23 of 24
  agent-system gates `[SKIP]`ped; 12 checks ran, 0 failures). Both exited 0. The full unflagged
  sweep for the batch is deferred to the batch stage, as the dispatch directed, not
  independently re-run here. No other deviation occurred; all other checklist items in both
  phases were executed exactly as planned.

## Impacts

- **Live-file convergence confirmed end-to-end for the first time.** Pre-switch, the live
  `_SAPIENCE_NOTE` still carried the pre-task-138 stale text (misattributing the vendor hooks to
  `modules/home/services/sapience.nix` and claiming they were guarded) even though the live
  `hooks` object already carried no vendor `mcp.py` entries — confirming the dispatch's own
  Premise Re-Validation item 3 that the 2026-11-14 three-vendor-hook measurement no longer
  describes live state. Post-switch: `diff` between source and live `_SAPIENCE_NOTE` is empty;
  the live file's enumerated hook commands contain exactly the inhibitor pair, the
  lean-lsp registration hook, and the Sapience registration hook — no `.sapience/mcp.py`
  command anywhere (the one `mcp.py` substring match in the live file is the note's own prose
  mentioning "an mcp.py hook" descriptively, not a hook command).
- `sapienceHooksGuard` ran (`entryBefore [ "claudeSettings" ]`, confirmed in the switch's
  activation log, ordered before `claudeSettings`) and printed nothing, meaning no vendor
  reinjection had occurred since the prior switch — observed as a live confirmation of the
  shipped design rather than a Phase 2 failure, per the plan's own risk table.
  `bash scripts/check-sapience-hooks.sh` run standalone post-switch exited 0 with message "carries
  no ~/.sapience injection hook."
  - **This task's contribution to "no Sapience briefing/receipt/effect-line in a repository
    with no sapience extension loaded" is indirect**, via the layers task 142 landed
    (`sapienceHooksGuard` plus the enforced-key reset this task extended); this task's own
    direct mechanism is the `_SAPIENCE_NOTE` enforcement and its documentation, not a new
    detection or stripping path.
- `jq '.hooks' ~/.sapience/config.json` is `false`, `sapienceHooksGuard`'s declaration is
  unchanged, and `docs/sapience.md`'s three-layer section still carries the heading the note
  now cites — all three shipped layers confirmed intact and mutually consistent, read-only.
- Only a user-level `home-manager switch --flake .#benjamin` was run (owns `~/.nix-profile` and
  actually executes `home.activation`). `sudo` is categorically denied inside this harness, so
  the NixOS-integrated generation (`sudo nixos-rebuild switch`) was not attempted and stays out
  of sync until a human runs it — this is a human checkpoint, not a task defect.

## Follow-ups

- Human checkpoint: run `sudo nixos-rebuild switch` (or equivalent) to bring the
  NixOS-integrated generation in sync with the user-level `home-manager switch` already applied
  in this run.
- None owned by this task beyond that — scope (a), (c), and (d) are closed by already-shipped
  work, and scope (b) (the `_SAPIENCE_NOTE` enforcement) is closed by this task.

## References

- `specs/141_prevent_sapience_hook_reinjection/plans/01_prevent-sapience-hook-reinjection.md`
- `specs/141_prevent_sapience_hook_reinjection/reports/01_prevent-sapience-hook-reinjection.md`
- `modules/home/core/dotfiles.nix`
- `config/claude/settings.json`
- `modules/home/services/sapience.nix` (read-only reference — `sapienceHooksGuard`)
- `scripts/check-sapience-hooks.sh` (read-only reference)
- `docs/sapience.md` (read-only reference — "The three layers that keep machine-wide hooks out
  of settings.json")

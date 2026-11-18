# Research Report: Prevent Sapience Hook Reinjection

**Task**: 141 - Close the recurrence gap left by task 138 (convergence-on-activation plus
detection-between-activations for the vendor's machine-wide Sapience hook reinjection)
**Started**: 2026-11-18
**Completed**: 2026-11-18
**Effort**: Small (one enforced-key list edit; the rest is coordination, not new code)
**Dependencies**: 142 (edge added during this research pass — see Decisions)
**Sources/Inputs**:
- `config/claude/settings.json`, `modules/home/core/dotfiles.nix` (`home.activation.claudeSettings`)
- `modules/home/services/sapience.nix` (full read, 1211 lines)
- Live machine state: `~/.claude/settings.json`, `~/.sapience/config.json`
- `/home/benjamin/.config/nvim/agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh`
  and `hooks/sapience-mcp-register-project.sh` (nvim repository, read-only — out of this
  repository's source-store territory)
- `specs/142_sapience_hooks_opt_out_default/reports/01_sapience_hooks_opt_out.md` and
  `plans/01_sapience-hooks-opt-out.md` (sibling task, status `planned`)
- `specs/state.json` (task 141 and 142 entries)
- Empirical jq test against the exact `claudeSettings` merge pipeline, reproducing the measured
  live 3-vendor-hook state
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The live machine has already **re-converged**: `~/.claude/settings.json` today (checked
  2026-11-18) carries exactly one Sapience hook — the legitimate
  `sapience-mcp-register-project.sh` `SessionStart` registration — not the three vendor entries
  the dispatch's 2026-11-14 evidence measured. The only drifted field left is `_SAPIENCE_NOTE`
  (confirmed live vs. source mismatch), which is the FOURTH DEFECT and the one genuine code gap
  this task closes.
- **Convergence-on-activation already works with zero code change.** Empirically reproduced the
  `claudeSettings` jq pipeline against a synthetic live file carrying the exact measured
  3-vendor-hook state: the existing `reduce $enforced[] as $k (...)` step fully replaces `.hooks`
  with the source's `.hooks` object (jq's `*` does not merge arrays, and the enforced-key
  override then does a flat `.hooks = $src.hooks` regardless). Dispatch scope item (a)'s premise
  — "relying only on the enforced-key reset ... does converge the file at switch time" — is
  correct and the reset is already sufficient for that half of the goal.
- **The between-activations detector this task's scope (c)/(d) asks about already exists or is
  already planned, in two places, neither of which is this task's own territory to rebuild:**
  1. **Already committed**, nvim repository, `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh`
     check (g) (task 636 phase 1, commit `6be5d9f45`): an on-demand, per-invocation scan of
     `$HOME/.claude/settings.json`'s `SessionStart`/`SessionEnd`/`Stop` hooks for any command
     referencing `.sapience/mcp.py` or `.sapience/sapience_cli.py`, reported as a loud `FAIL` with
     remediation text — not silent. This satisfies the manual/on-demand half of "reported rather
     than silent."
  2. **Already planned**, this repository, task 142 (`sapience_hooks_opt_out_default`, status
     `planned`) Phase 2: a new `scripts/check-sapience-hooks.sh` plus a `sapienceHooksGuard`
     `home.activation` entry in `modules/home/services/sapience.nix`, ordered
     `entryBefore [ "claudeSettings" ]` specifically so it inspects the live file **before** the
     enforced-key reset can hide an injection — i.e. an automatic, every-switch detector for
     exactly the condition this task's scope (a)/(c) describes. Task 142 also fixes the actual
     root cause (the `.hooks = (.hooks // true)` jq bug in `sapienceBootstrap` that silently
     resets the vendor opt-out from `false` back to `true`).
- **Added a `141 -> 142` dependency edge during this research pass** (via
  `update-task-status.sh preflight 141 research <session> --depends-on-add='[142]'`) to serialize
  the shared sapience territory: task 142 is about to add a new, better-sited activation detector
  in the exact file region this task's scope (a) describes, and both tasks narrate the same
  2026-11-14 measured evidence. Building a third, independent detector here would duplicate 142's
  Phase 2 and risks a doc/comment narrative (`_SAPIENCE_NOTE`, `sapience.nix` header,
  `docs/sapience.md`) that contradicts whatever 142 actually lands.
- **This task's actual remaining implementation scope, once 142's territory is excluded, is
  narrow**: add `"_SAPIENCE_NOTE"` to the enforced-key list in
  `modules/home/core/dotfiles.nix` (currently `["_NOTE","env","hooks","model","permissions","statusLine"]`),
  and record the siting/overlap findings above so planning does not re-derive them.

## Context & Scope

### What was researched

1. Whether the live machine still exhibits the three-vendor-hook drift the dispatch's
   2026-11-14 evidence measured, and whether `_SAPIENCE_NOTE` is actually stale on the live file.
2. Whether `home.activation.claudeSettings`'s existing enforced-key reset genuinely converges
   `.hooks` at switch time, or only appears to (verified mechanically, not read off the comment).
3. Where the "detection between activations" the dispatch's scope (c) asks about already lives or
   is already planned, across both this repository and the nvim repository that owns the
   companion verifier.
4. Whether any other in-flight task shares this task's territory, given the same 2026-11-14
   measured evidence appears verbatim in another task's description.

### Territory boundary

This task's edit targets (`modules/home/core/dotfiles.nix`) live in this repository's own
filesystem, so the task is correctly sited here per
`context/standards/source-store-deploy-boundary-narrative.md`'s task-siting rule. The nvim
repository's `verify-sapience-mcp.sh` is read-only reference material for the siting decision
below — no edit to it, or to `.claude/**` in this repository (a disposable deploy mirror), is in
scope.

## Findings

### 1. Live-file state today contradicts the dispatch's premise that drift is currently present

```
jq '.hooks' ~/.claude/settings.json   # SessionStart: inhibitor, lean-lsp hook, sapience
                                       # registration hook only. No --briefing-text/--receipt/
                                       # --effect-line entries. SessionEnd: inhibitor cleanup
                                       # only.
```

Live mtime of `~/.claude/settings.json` is 2026-11-18T18-ish (after the 2026-11-14 evidence),
and `~/.sapience/config.json`'s `"hooks"` field reads `false` right now. The machine has already
re-converged since the dispatch's evidence was captured — most plausibly via an intervening
`home-manager switch` exercising the existing enforced-key reset (see Finding 2), and/or the
hand-applied `"hooks": false` opt-out from the 2026-11-14 manual fix still holding (task 142 has
not yet landed its fix for the `.hooks = (.hooks // true)` reset bug, so this could still regress
on the next `sapience-bootstrap` re-run — that regression is task 142's territory, not this
task's).

**The one confirmed, present drift**: `_SAPIENCE_NOTE` on the live file still reads the stale
text from before task 138's rewrite — it claims the mcp.py hook entries are "guarded with
`[ -f ~/.sapience/mcp.py ]`" and "owned by `modules/home/services/sapience.nix`", neither of
which is true (confirmed: `grep` over `modules/home/services/sapience.nix` for
`--briefing-text`/`--receipt`/`--effect-line` returns nothing; that module defines no Claude Code
hooks at all — see its own header comment, which states the hooks live in the sapience
extension's `settings-fragment.json` instead). This is the FOURTH, SEPARATE DEFECT the dispatch
names, and it persists because `_SAPIENCE_NOTE` is not in `claudeSettings`'s enforced-key array.

### 2. The enforced-key reset already fully converges `.hooks` at switch time (verified, not assumed)

`modules/home/core/dotfiles.nix`'s `claudeSettings` activation entry runs:

```
jq -s --argjson enforced '["_NOTE","env","hooks","model","permissions","statusLine"]'
  '.[0] as $src | .[1] as $live
   | ($src * $live)
   | reduce $enforced[] as $k (.;
       if ($src | has($k)) then .[$k] = $src[$k] else . end)'
  "$settingsSrc" "$settingsDst"
```

Reproduced this exact pipeline against a synthetic `$live` file carrying the measured
3-vendor-hook state (SessionStart with an extra `--briefing-text` entry, SessionEnd with
`--receipt`, Stop with `--effect-line`) and a `$src` carrying only the one legitimate
registration hook. Result: `.hooks` in the output is the source's object **verbatim** — the
vendor entries are gone. This holds because (a) jq's `*` operator does not deep-merge arrays, so
`($src * $live)`'s array-valued `.hooks.SessionStart` etc. is whichever side's array survives the
object-merge rules, and (b) the `reduce` step then unconditionally overwrites the top-level
`"hooks"` key with `$src.hooks` in full, since `$src` has that key. The fallback path (`cp
"$settingsSrc" "$settingsDst"` when the live file is missing/unparseable or the jq run fails)
resets just as completely.

**Conclusion**: dispatch scope (a)'s literal ask ("make `home.activation.claudeSettings`
actively strip ... instead of relying only on the enforced-key reset") describes a defense-in-depth
addition, not a bug fix — the reset it is contrasted against already fully converges `.hooks` on
every switch. No code change is needed in `dotfiles.nix` to achieve "convergence on activation"
for the hooks key itself. An explicit, vendor-signature-targeted strip (independent of the
`ENFORCED` array) would be a legitimate self-documenting addition, but it would duplicate exactly
what task 142 Phase 2 is about to build in `sapience.nix` (see Finding 3) — recommend against
building it a second time here.

### 3. The between-activations detector already exists (nvim repo) and is already planned (task 142) — this task should not build a third one

**Nvim repository, already committed** — `verify-sapience-mcp.sh` check (g) (header comment
documents it explicitly as "machine-wide vendor hook recurrence detector," added by task 636
phase 1, commit `6be5d9f45`, 2026-11-18 per `git log`):

- Scans `$HOME/.claude/settings.json`'s `hooks.SessionStart`/`SessionEnd`/`Stop` command strings
  for `*.sapience/mcp.py*` or `*.sapience/sapience_cli.py*`.
- Reports a loud, non-silent `FAIL` naming every offending command plus remediation text
  (`~/.sapience/config.json`'s `"hooks": false` / `SAPIENCE_NO_HOOKS=1`) when found; a clean
  `PASS` otherwise.
- Also reports the opt-out's current value (`$SAPIENCE_CONFIG`'s `.hooks`) unconditionally, so a
  clean pass can be distinguished from "never wired" vs. "opted out."
- This is a **manually/on-demand invoked** script (its own test suite and documentation are the
  only call sites found; it is not wired into a hook, timer, or CI in either repository today).

**This repository, already planned (not yet implemented)** — task 142's Phase 2 plan:

- New `scripts/check-sapience-hooks.sh`, detecting the same vendor signature
  (`.sapience/mcp.py` + one of `--briefing-text`/`--receipt`/`--effect-line`), exits `1`
  standalone on a match.
- A new `sapienceHooksGuard` `home.activation` entry in `modules/home/services/sapience.nix`,
  explicitly ordered `config.lib.dag.entryBefore [ "claudeSettings" ]` — ahead of the
  enforced-key reset — specifically because an entry ordered *after* `claudeSettings` would
  "inspect a file whose `hooks` key has already been replaced ... and would be structurally dead
  code that looks like a working check" (task 142 plan, Decision 3). This is the automatic,
  every-switch counterpart to the nvim repo's manual check, and is a more direct match to this
  task's own scope (c)/(d) language ("Decide where the between-activations detector belongs") than
  anything this task would build independently.
- Task 142's own Non-Goals list states explicitly: "Changing `modules/home/core/dotfiles.nix`'s
  `claudeSettings` entry or its enforced-key list. This plan orders a new entry relative to it and
  must not alter it." — so 142 will not touch the `_SAPIENCE_NOTE` fix this task owns, and this
  task should not touch `sapience.nix`'s new guard or `scripts/check-sapience-hooks.sh`.

**Siting decision for this task's scope (c)**: the between-activations detector belongs in
`modules/home/services/sapience.nix` + `scripts/check-sapience-hooks.sh` (task 142's territory,
already planned) for the automatic/every-switch half, and in the nvim repository's
`verify-sapience-mcp.sh` (already built) for the manual/on-demand half. This task adds neither —
it would duplicate in-flight or already-shipped work in the same file region two different tasks
already own.

### 4. Task overlap is real and warranted a dependency edge

Task 142's description reproduces this task's own 2026-11-14 "MEASURED EVIDENCE" paragraph
near-verbatim, and its plan's Phase 2 directly answers this task's scope item (c)/(d). The two
tasks do not edit the identical file (141: `modules/home/core/dotfiles.nix`; 142:
`modules/home/services/sapience.nix` + new `scripts/check-sapience-hooks.sh`), so there is no
literal git-merge collision, but there is a real risk of inconsistent narrative: `_SAPIENCE_NOTE`
(this task), `sapience.nix`'s header comment (142), and `docs/sapience.md` (142 Phase 3) all
describe the same hook-reinjection story and need to agree once both land. Per
`context/patterns/batch-orchestration-guardrails.md`'s "Batching Is the Default" guidance for an
unordered overlap, a `141 -> 142` dependency edge was added during this research pass (see
Decisions) rather than left as a note for a future conflict.

## Decisions

1. **Added a `141 -> 142` dependency edge** via `bash .claude/scripts/update-task-status.sh
   preflight 141 research sess_1795027105_555221_141 --depends-on-add='[142]'` (a no-op status
   replay solely to attach the edge, per that script's documented `--depends-on-add` contract).
   Rationale: task 142's Phase 2 is the better-sited, already-planned answer to this task's own
   scope (a)/(c)/(d) questions, and letting 142 land first means this task's final
   `_SAPIENCE_NOTE` text and any header-comment cross-reference can describe the actual shipped
   three-layer design (opt-out default, automatic pre-switch guard, enforced-key backstop) instead
   of a provisional one that 142's implementation might contradict.
2. **This task will not add a new vendor-hook detector of its own** in either
   `modules/home/core/dotfiles.nix` or `modules/home/services/sapience.nix`. The detection-between-
   activations goal is satisfied by the nvim repo's existing check (g) (manual) and task 142's
   planned `sapienceHooksGuard` (automatic); duplicating either here would be redundant,
   file-region-contentious with task 142, and inconsistent with task 142's own explicit Non-Goal
   ("must not alter" `dotfiles.nix`'s enforced-key list/entry).
3. **This task's remaining concrete code change is the `_SAPIENCE_NOTE` enforced-key addition**:
   add `"_SAPIENCE_NOTE"` to `modules/home/core/dotfiles.nix`'s `--argjson enforced` array (line
   107), converging the live file's note text to source on every switch, closing the FOURTH
   DEFECT. The source `_SAPIENCE_NOTE` text in `config/claude/settings.json` is already accurate
   for the current (pre-142) design; whether it needs a further addition describing task 142's
   new layers is a planning-time question to resolve once 142's actual implementation (not just
   its plan) is known — this task's plan should sequence that update after 142 closes, consistent
   with Decision 1's dependency edge.
4. **Convergence-on-activation for `.hooks` requires no code change**, per the empirical
   verification in Finding 2. The plan should record this as a verified-no-op item rather than
   treat the dispatch's scope (a) literally as an unmet requirement.

## Recommendations

1. **Implement only the `_SAPIENCE_NOTE` enforced-key addition** in this task's plan/implementation
   phase: one-line change to `modules/home/core/dotfiles.nix`'s enforced array, verified by a
   `home-manager switch --dry-run` (or a direct jq replay) showing the live `_SAPIENCE_NOTE`
   reset to source text, and `nix flake check` passing.
2. **Do not build a new activation-time or standalone detector in this task.** Point the plan at
   task 142's Phase 2 (`sapienceHooksGuard` / `scripts/check-sapience-hooks.sh`) as the owning,
   in-flight work, and at the nvim repo's `verify-sapience-mcp.sh` check (g) as the existing
   manual counterpart.
3. **Sequence this task's `_SAPIENCE_NOTE` finalization after task 142 lands** (the dependency
   edge already encodes this ordering preference, though it is advisory for scheduling rather than
   a hard gate): once 142's `docs/sapience.md` and `sapience.nix` header updates exist, confirm
   whether `_SAPIENCE_NOTE` itself should gain a one-line pointer to the opt-out/guard layers, or
   whether that level of detail is better left to `docs/sapience.md` alone (the note's existing
   text is already fairly long; recommend keeping `_SAPIENCE_NOTE` focused on the one entry it
   currently explains — the registration hook — and letting `docs/sapience.md` carry the fuller
   three/four-layer story, but this is a planning-time call, not settled here).
4. **Re-run the live-file check at implementation time** (`jq '.hooks' ~/.claude/settings.json`
   and `jq '._SAPIENCE_NOTE' ~/.claude/settings.json`) before writing the implementation summary,
   since the live machine's drift state is time-dependent (confirmed to have already changed once
   between the dispatch's 2026-11-14 evidence and this 2026-11-18 research pass) and the summary
   should report what was actually observed, not the dispatch's now-stale snapshot.
5. **Acceptance-criteria note for planning**: the dispatch's acceptance text ("a Claude Code
   session in a repository with no sapience extension loaded produces no Sapience briefing,
   receipt, or effect line") is already satisfied today on this machine (live file carries none of
   those three hooks) and will stay satisfied once task 142's root-cause fix lands; this task's
   own contribution to that acceptance line is indirect (the `_SAPIENCE_NOTE` fix does not itself
   gate hook presence) and should be stated as such rather than claimed as this task's own
   mechanism.

## Risks & Mitigations

- **Risk**: task 142's Phase 2 could be re-scoped or dropped during its own planning/implementation
  review, leaving the "automatic between-switches detection" half unimplemented and this task's
  Decision 2 (no new detector here) then under-delivering on the dispatch's acceptance criterion.
  *Mitigation*: the dependency edge means this task's own postflight/implementation check should
  re-verify task 142's actual landed state (not just its plan) before closing; if 142 is abandoned
  or materially descoped, this task's plan should be revisited rather than silently leaving the
  gap.
- **Risk**: the live machine's current clean state (Finding 1) could itself regress before this
  task implements, if `sapience-bootstrap` or the vendor's daily auto-update re-runs and task
  142's jq fix has not yet landed (the `.hooks = (.hooks // true)` bug is still live in
  `sapience.nix` today). *Mitigation*: this is exactly task 142's territory to fix; this task
  should not attempt a parallel fix to the same jq expression.
- **Risk**: adding `_SAPIENCE_NOTE` to the enforced-key list changes its live-editability — an
  operator who hand-edits the live note (e.g. to add a temporary caveat) will have that edit
  reverted at the next switch, matching the existing behavior of every other enforced key.
  *Mitigation*: this is the intended effect (the FOURTH DEFECT is precisely that the note is
  currently NOT reset), and matches the existing enforced-key design rationale documented in
  `dotfiles.nix`'s own comment block ("Adding a key to ENFORCED makes it repo-owned").

## Appendix

### Commands/greps used

- `jq '.hooks' ~/.claude/settings.json`; `stat -c '%Y %n'` on live vs. source settings.json;
  `jq -r '._SAPIENCE_NOTE' ~/.claude/settings.json`.
- Full read of `modules/home/core/dotfiles.nix` (192 lines) and `modules/home/services/sapience.nix`
  (1211 lines).
- `grep -rn "_SAPIENCE_NOTE"` across the repository (confirms no other reader/writer depends on
  the note staying non-enforced).
- Synthetic jq replay of the exact `claudeSettings` merge pipeline against fixture `src.json`/
  `live.json` files in `/tmp`, reproducing the measured 3-vendor-hook live state.
- `jq '.hooks' ~/.sapience/config.json` (live opt-out value: `false`).
- `find`/`ls` across `/home/benjamin/.config/nvim/agent-system/extensions/sapience/` for
  `settings-fragment.json`, `scripts/verify-sapience-mcp.sh`, and
  `hooks/sapience-mcp-register-project.sh`; full read of all three.
- `git log --oneline -5 -- agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh`
  (nvim repository) — confirms check (g)'s origin (task 636 phase 1, commit `6be5d9f45`).
- Full read of `specs/142_sapience_hooks_opt_out_default/reports/01_sapience_hooks_opt_out.md`
  and `plans/01_sapience-hooks-opt-out.md`; `specs/state.json` entries for tasks 141/142/144.

### References

- `modules/home/core/dotfiles.nix:93-128` (`claudeSettings` activation entry, enforced-key array
  at line 107)
- `config/claude/settings.json:1-2,128` (`_NOTE`, `_SAPIENCE_NOTE`)
- `modules/home/services/sapience.nix:319-332` (the two `config.json` `"hooks"` write sites task
  142 owns), header comment lines 1-23 (confirms no Claude Code hooks are defined in this module)
- `/home/benjamin/.config/nvim/agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh:380-425`
  (check (g))
- `specs/142_sapience_hooks_opt_out_default/plans/01_sapience-hooks-opt-out.md` Phase 2 and
  Decisions 3-5 (the `sapienceHooksGuard` ordering and detection-signature design)

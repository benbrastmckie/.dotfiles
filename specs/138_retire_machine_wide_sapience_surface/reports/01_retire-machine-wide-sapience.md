# Research Report: Retire Machine-Wide Sapience Activation Surface

- **Task**: 138 - Retire every machine-wide Sapience ACTIVATION surface this repository owns
- **Started**: 2026-11-13T00:00:00Z
- **Completed**: 2026-11-13T00:40:00Z
- **Effort**: ~1 hour (on-disk verification against an unusually detailed dispatch)
- **Dependencies**: Companion project 612 (`gate_sapience_activation_behind_extension`, sited in
  `/home/benjamin/.config/nvim`) — confirmed landed, see Findings
- **Sources/Inputs**: dispatch file; `modules/home/services/sapience.nix`; `modules/home/core/dotfiles.nix`;
  `config/claude/settings.json`; `docs/sapience.md`; `/home/benjamin/.config/nvim`'s
  `agent-system/extensions/sapience/**` and its summary for project 612;
  `~/.claude.json`; `~/.sapience/config.json`; four repos' `.claude-extensions.json`
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The companion task is confirmed landed and verified: both installed files
  (`$HOME/.claude/hooks/sapience-mcp-register-project.sh`,
  `$HOME/.claude/scripts/setup-sapience-mcp.sh`) exist, mode 755, dated 2026-11-12, and
  `agent-system/extensions/sapience/settings-fragment.json` carries all 11 permission grants and
  all 5 hooks byte-identical to this repo's current `config/claude/settings.json`. This task may
  proceed.
- **Correction to the dispatch's file/line attribution**: the top-level `mcpServers.sapience`
  merge is NOT inside a `claudeMcpServers` entry in `sapience.nix`. `claudeMcpServers` is a
  distinct activation block defined in `modules/home/core/dotfiles.nix` (merges
  `mcpServers.playwright`/`mcpServers.nixos` only, and must not be touched by this task). The
  actual merge lives in `sapience.nix`'s own activation entry named **`sapienceMcpServer`**
  (line ~1019, gated by `lib.mkIf cfg.registerMcpServer`), which is merely ordered
  `entryAfter [ "writeBoundary" "claudeMcpServers" "sapiencePayload" "sapienceTokenRepair" ]` —
  i.e. it runs after the (unrelated) `claudeMcpServers` block, it is not inside it. The
  `registerMcpServer` option (line 783) and the `sapienceMcpServer` activation entry (lines
  ~1019-1055) are the two things to remove; `dotfiles.nix`'s `claudeMcpServers` block is
  out of scope and must be left exactly as-is.
- The seven read-tool grants and five hooks in `config/claude/settings.json` are confirmed
  byte-identical to the extension's `settings-fragment.json` copies — removal here is safe
  because the per-repo equivalents already exist.
- The exact registration `SessionStart` entry this task must add is confirmed against the
  companion's installer: command string
  `bash $HOME/.claude/hooks/sapience-mcp-register-project.sh 2>/dev/null || echo '{}'`, shape
  `{"hooks":[{"type":"command","command":"<string>"}]}`, no matcher/timeout/async. The
  **mechanism to make it durable** is already established precedent in this same file: the
  lean-lsp installer (`/home/benjamin/.config/nvim/agent-system/extensions/lean/scripts/install-lean-lsp-session-hook.sh`)
  writes its own `SessionStart` entry directly into `$HOME/.dotfiles/config/claude/settings.json`
  (the repo source), in addition to the live file — confirmed by reading that script. This task's
  job is the equivalent one-time edit to the repo source for the sapience registration entry,
  which then survives every future switch via the existing enforced-key mechanism.
- `~/.sapience/config.json` on disk matches the dispatch's verbatim transcription exactly,
  including the stale pre-move `sapience-app` key — the owner-instruction content in the
  dispatch is accurate and ready to hand off unchanged.
- `~/.claude.json` currently shows `.projects` registered only for `/home/benjamin/.config/nvim`
  and the OLD path `/home/benjamin/Projects/sapience-app` (pre-move); `abood` and the moved
  `Sapience/sapience-app` path are not yet registered. This is expected (registration is
  session-start-triggered and no session has run in those two since the companion landed /
  the repo moved) and is not a defect this task needs to fix — the registration `SessionStart`
  hook, once durable, will populate them on next session start in each repo.
- `docs/sapience.md` has more stale statements than the dispatch's own enumeration: beyond the
  "What is installed" table row and hook-count error, its **Rollback** section (around line 780)
  also still instructs `jq 'del(.mcpServers.sapience)' ~/.claude.json` and says "the hooks and
  tool grants go away by deleting their entries from `config/claude/settings.json`" — both
  statements become false once this task lands and should be corrected in the same rewrite pass,
  even though the dispatch's enumeration did not name this section explicitly.
- `core/context/patterns/mcp-server-ownership.md`'s sapience worked example lives at
  `/home/benjamin/.config/nvim/agent-system/extensions/core/context/patterns/mcp-server-ownership.md`
  (confirmed to exist, confirmed sapience-specific text at its "Permission" section) — out of
  scope for this task, coordination-only, per the dispatch.

## Context & Scope

This is a removal task (five Sapience activation surfaces retired from
`config/claude/settings.json` and `modules/home/services/sapience.nix`) plus exactly one addition
(a durable per-project MCP-registration `SessionStart` entry) and one documentation rewrite
(`docs/sapience.md`). The task is gated on a companion task in a different repository having
landed first; that gate is confirmed satisfied. This report verifies every load-bearing factual
claim in the dispatch against live on-disk state so the planning phase can proceed from
confirmed facts rather than re-deriving them, and surfaces the two corrections above (the
`claudeMcpServers`/`sapienceMcpServer` naming, and the Rollback-section staleness) that the
dispatch's own text did not fully capture.

## Findings

### Companion Landing (Ordering Constraint)

- `/home/benjamin/.config/nvim/specs/612_gate_sapience_activation_behind_extension/summaries/01_gate-sapience-activation-extension-summary.md`:
  **Status: [COMPLETED]**. Summary confirms: 11 grants and 5 hooks moved into
  `agent-system/extensions/sapience/settings-fragment.json`; new MCP-registration triad (writer,
  hook, installer, verifier); no `.dotfiles` file touched; one documented residual (4 of 11
  write-tool grants don't retract on unload, a pre-existing merge-tracking defect, explicitly
  out of this task's scope to fix).
- `$HOME/.claude/hooks/sapience-mcp-register-project.sh` and
  `$HOME/.claude/scripts/setup-sapience-mcp.sh`: both present, `-rwxr-xr-x`, dated Nov 12 22:58 —
  matches the companion's installer output.
- `agent-system/extensions/sapience/settings-fragment.json`'s `permissions.allow` carries all 11
  `mcp__sapience__*` entries; its `hooks` object carries all 5 keys
  (`PreToolUse`, `SessionEnd`, `SessionStart`, `Stop`, `UserPromptSubmit`), confirmed
  byte-identical (diffed by eye against `.dotfiles`' current `config/claude/settings.json`
  command strings, timeouts, and the `async: true` flags).
- **Conclusion**: ordering constraint satisfied; this task may proceed.

### The Top-Level MCP Merge: Correcting the Dispatch's Attribution

- `grep -n "claudeMcpServers" modules/` shows exactly two hits, both in `sapience.nix` at lines
  1017 and 1023 — both references inside an `entryAfter [ ... "claudeMcpServers" ... ]`
  dependency list, never a definition.
- The actual *definition* of `claudeMcpServers` is `modules/home/core/dotfiles.nix:167`, and its
  body merges only `mcpServers.playwright` and `mcpServers.nixos` — nothing sapience-related.
  This block must be left untouched by this task.
- `sapience.nix`'s own activation block that performs the top-level
  `.mcpServers.sapience = {...}` merge is named **`sapienceMcpServer`** (line ~1019), gated by
  `lib.mkIf cfg.registerMcpServer`, and is the entry this task must remove (together with the
  `registerMcpServer` option at line 783 and its description, which currently reads "Merge
  mcpServers.sapience into ~/.claude.json at user scope... Set false to leave ~/.claude.json
  untouched").
- The ordering comment the dispatch asked to "preserve... in whatever replaces it" (at line
  ~1017, "Ordered after claudeMcpServers, which merges into the same ~/.claude.json") refers to
  dotfiles.nix's `claudeMcpServers`, confirming that this task's removal is scoped to
  `sapienceMcpServer` alone and must not perturb the ordering or body of `claudeMcpServers`
  itself.
- `sapiencePayload` (line 907) and `sapienceTokenRepair` (line 938) are separate activation
  entries that seed/repair `~/.sapience/config.json` state — they are not Claude Code activation
  surfaces (no `~/.claude.json` or `~/.claude/settings.json` writes) and are out of this task's
  removal scope; `sapienceMcpServer` was the only consumer that needed them as ordering
  predecessors, so removing `sapienceMcpServer` leaves them as harmless, still-useful
  config.json maintenance entries.

### `config/claude/settings.json`: Current Shape Confirmed

- `permissions.allow` sapience entries (7, confirmed): `mcp__sapience__sapience`,
  `_search`, `_briefing`, `_context`, `_ask`, `_outstanding`, `_papers`.
- `hooks` object currently has 5 keys. `SessionStart` currently holds **three** entries: (1) the
  systemd-inhibit/sleep-inhibitor entry (unrelated, keep), (2) the lean-lsp registration entry
  (`matcher: "startup"`, command `bash $HOME/.claude/hooks/lean-lsp-register-project.sh
  2>/dev/null || echo '{}'` — unrelated, keep, and structurally the precedent for what this task
  adds), (3) the Sapience briefing entry (`[ -f "$HOME/.sapience/mcp.py" ] && python3
  "$HOME/.sapience/mcp.py" --briefing-text 2>/dev/null || true` — remove).
  `UserPromptSubmit`, `PreToolUse` (matcher `Edit|Write|MultiEdit`), `SessionEnd`, `Stop` each
  hold exactly one entry, each Sapience-only — all four arrays become empty and (per existing
  JSON shape conventions in this file) should be removed as keys entirely once empty, not left
  as `[]`, unless the planning phase finds a reason to keep an empty array (none apparent here).
- `_SAPIENCE_NOTE` (line 178) is a single string value, not an object; its current text already
  states the enforced-key rationale, the `statusLine` ruling, and the deliberately-unwired
  `sapience_cli.py hook session`/`hook stop` ruling, exactly as the dispatch's item 4 says must
  be carried forward. The rewrite is additive-in-spirit (carry these three rulings forward,
  state where the five hooks/seven grants now live, state why the registration SessionStart
  entry alone stays) rather than requiring new fact-finding.

### Registration `SessionStart` Entry: Mechanism for Durability Confirmed by Precedent

- The companion's installer (`install-sapience-mcp-session-hook.sh`) writes the `SessionStart`
  entry ONLY to `$HOME/.claude/settings.json` (the live file) — confirmed by reading the script
  header and the `LIVE_SETTINGS`/no-`DOTFILES_SETTINGS`-variable code, and the script's own
  comments state this is deliberate because that task was forbidden to touch `.dotfiles`.
- The **lean** extension's equivalent installer
  (`agent-system/extensions/lean/scripts/install-lean-lsp-session-hook.sh`) is the live
  structural precedent for what durability actually requires: it defines both `LIVE_SETTINGS`
  (`$HOME/.claude/settings.json`) and `DOTFILES_SETTINGS`
  (`$HOME/.dotfiles/config/claude/settings.json`) and calls the same
  `merge_session_start_entry` function against both. The dotfiles-side write is exactly the
  "durable user-level entry" the dispatch asks this task to supply — confirmed by direct
  inspection of the installed artifact: `config/claude/settings.json`'s own `hooks.SessionStart`
  already has the lean entry sitting there today, written by that exact mechanism in an earlier
  task.
- **Implication for planning**: this task's job is the matching one-time edit — add the sapience
  registration entry (command string confirmed above, no matcher per dispatch's instruction) to
  `config/claude/settings.json`'s `hooks.SessionStart` array, placed alongside the existing
  lean-lsp entry. No script needs to be written by this task; the companion's installer already
  handles the live-file side on every machine where it's run, and the repo-source copy added here
  is what survives `home-manager switch`.
- Re-running the companion's installer after this task lands will find its own command string
  already present in the (now home-manager-reasserted) live file and report a no-op — the
  installer's idempotency check (`already=$(jq ... any(. == $cmd))`) only tests for the command
  string's presence, not which writer put it there, so this is expected to pass without any
  change to the installer itself.

### Extension-Loaded Repo Set: Confirmed Exactly as Stated

```
/home/benjamin/.config/nvim          sapience status = active
/home/benjamin/.dotfiles             sapience status = active
/home/benjamin/Projects/abood        sapience status = active
/home/benjamin/Projects/Sapience/sapience-app   sapience status = active
/home/benjamin/Projects/cslib        sapience status = absent (negative-test candidate)
/home/benjamin/Projects/Logos/Theory sapience status = absent (negative-test candidate)
```

### `~/.claude.json` Current State

- Top-level `mcpServers` keys: `nixos`, `playwright`, `sapience` — `sapience` is the entry this
  task removes; the other two belong to `dotfiles.nix`'s unrelated `claudeMcpServers` block and
  must survive untouched.
- `.projects[*].mcpServers.sapience` currently registered for exactly two keys:
  `/home/benjamin/.config/nvim` and `/home/benjamin/Projects/sapience-app` (the **old**,
  pre-move path). Neither `/home/benjamin/.dotfiles`, `/home/benjamin/Projects/abood`, nor the
  new `/home/benjamin/Projects/Sapience/sapience-app` path is registered yet. This is consistent
  with registration being session-start-triggered (via the companion's hook, which only a
  session actually starting in that directory invokes) rather than retroactive, and is not a
  defect — the durable registration entry this task adds will populate the missing three (and
  repair the stale key, since the hook keys strictly on the current working directory's absolute
  path) on each repo's next session start. Nothing in this task needs to pre-seed these entries
  by hand.
- Precedent cross-check: `.projects[*].mcpServers["lean-lsp"]` is registered for four Lean repos
  (`Logos/Theory`, `BimodalLogic`, `cslib`, `cslib-pr648`) — confirms the per-project shape this
  task's registration entry will produce is a proven, already-working pattern in this same file.

### `~/.sapience/config.json` Current State — Confirmed Verbatim

- Mode 600, confirmed.
- Top-level `folders` (5 entries) and `capture.projects` (10 entries, 5 `enabled: true`) match
  the dispatch's transcription exactly, including the stale `name: "sapience-app"`-free content
  (abood/sapience-app genuinely absent from this file) and the pre-move path issue (no
  `sapience-app` entry currently points at the moved location; the dispatch's owner-instruction
  for this file is accurate as written and needs no revision).

### Documentation (`docs/sapience.md`) — Additional Staleness Beyond the Dispatch's Enumeration

Confirmed stale exactly as named in the dispatch:
- Line 45: `mcpServers.sapience in ~/.claude.json` / "Merged on activation, preserving every
  other key" row.
- Line 47: `Three hooks and seven tool grants` — count is wrong today already (5 hooks exist, not
  3); becomes doubly wrong after this task (0 Sapience-specific hooks remain in this file, plus
  1 unrelated registration hook).
- Lines 637-650 ("Why the hooks live in the repo" section) and the first-time-setup step 4
  narrative (lines ~116-123) — both describe the now-retired machine-wide arrangement.

**Additional staleness found, not named in the dispatch's enumeration** (surfaced here for
planning): the **Rollback** section (~line 764-786) still instructs
`jq 'del(.mcpServers.sapience)' ~/.claude.json > /tmp/cj && mv /tmp/cj ~/.claude.json` as the way
to remove the MCP entry, and states "The hooks and tool grants go away by deleting their entries
from `config/claude/settings.json`; because those keys are enforced, the next switch resets the
live file to match." Both sentences describe exactly the surface this task retires and will be
false the moment it lands (there will be no `config/claude/settings.json`-owned Sapience hooks or
grants left to delete, and the `mcpServers.sapience` top-level key will no longer be something
`programs.sapience.enable = false` leaves behind, since the activation block that wrote it is
gone). Recommend folding a Rollback-section correction into the same rewrite pass acceptance
criterion 5 already requires, even though the dispatch text named only the "What is installed"
table and the "Why the hooks live in the repo" section explicitly.

### Cross-Repo Follow-Up (Out of Scope, Confirmed to Exist)

- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` exists at
  `/home/benjamin/.config/nvim/agent-system/extensions/core/context/patterns/mcp-server-ownership.md`
  (and its deployed mirror at `.claude/context/patterns/mcp-server-ownership.md` in the same
  repo). Its "Permission" section's worked example (around its line 339) describes the
  now-companion-landed four-write/seven-read grant split as still coexisting with a
  machine-wide seven-grant user-scope allow-list — this will go stale the moment this task lands,
  confirming the dispatch's claim. This task must not edit it; an nvim-sited follow-up task should
  update it, coordinated to land alongside this task per the dispatch's instruction.

### SF-1 Card Sessions

- `git -C /home/benjamin/Projects/Sapience/sapience-app ls-files .claude` returns empty — confirms
  `.claude/` is untracked in the card repo, so a fresh worktree checked out from it carries no
  `.claude/` tree and therefore no hooks/grants by construction, exactly as the dispatch states.
- `~/.local/state/sf1-hub-ben/hub/runner/work/` does not currently exist (no card session is live
  right now), so no live worktree was available to directly inspect in this research pass; the
  structural guarantee above does not depend on one being live, since it follows from the
  repo-level `git ls-files` result plus how the extension's settings merge works (only through a
  `.claude-extensions.json`-driven merge into `.claude/settings.local.json`, which a fresh
  worktree never has). Recommend the implementation phase do a live check if a card session
  happens to be running at that time, but it is not required to establish the property.

### `nix flake check` Baseline

Not run in this research pass (verification of the gate is explicitly owned by the implementation
phase per the dispatch's "VERIFICATION THIS TASK OWNS" section, and running it is a multi-minute
operation not needed to answer any open research question). No reason to expect a pre-existing
failure: `git status` at dispatch time showed no uncommitted changes to any of the three edit
targets.

## Decisions

- Recommend the plan target `sapience.nix`'s `registerMcpServer` option (line 783) and
  `sapienceMcpServer` activation entry (lines ~1019-1055) for removal — NOT any entry named
  `claudeMcpServers`, which is a different, unrelated block in `dotfiles.nix` that must be left
  untouched. This is the single most important correction this research pass makes to the
  dispatch's own text.
- Recommend the plan add the registration `SessionStart` entry directly to `config/claude/settings.json`'s
  existing `hooks.SessionStart` array (alongside the lean-lsp entry already there), using the
  confirmed command string and the no-matcher/no-timeout/no-async shape — mirroring the general
  mechanism (not the literal content) of the lean-lsp entry already present in this exact file.
- Recommend the plan fold a Rollback-section correction into the `docs/sapience.md` rewrite,
  alongside the sections the dispatch named explicitly, since both are necessary for the document
  to stop making false claims.
- No action needed on `~/.sapience/config.json`'s owner instruction — the dispatch's content is
  independently confirmed correct and can be handed to the user verbatim at implementation time.

## Recommendations

1. Target `sapience.nix`'s `registerMcpServer` option and `sapienceMcpServer` activation entry
   for removal; leave `dotfiles.nix`'s `claudeMcpServers` block (playwright/nixos) untouched.
2. Remove the 7 Sapience `permissions.allow` entries and the 5 Sapience-only hook entries
   (`SessionStart`'s briefing entry, and the sole entries in `UserPromptSubmit`, `PreToolUse`,
   `SessionEnd`, `Stop`) from `config/claude/settings.json`; drop the now-empty hook array keys
   entirely rather than leaving `[]`.
3. Add the registration `SessionStart` entry (confirmed command string, no matcher/timeout/async)
   to `config/claude/settings.json`'s `hooks.SessionStart` array, alongside the existing lean-lsp
   entry — this is the one addition, and it is what makes the entry survive `home-manager switch`.
4. Rewrite `_SAPIENCE_NOTE` to carry forward the enforced-key rationale, the `statusLine` ruling,
   and the deliberately-unwired-`sapience_cli.py`-hooks ruling, while stating where the moved
   hooks/grants now live and why the registration entry alone stays.
5. Rewrite `docs/sapience.md`'s "What is installed" table row, hook count, "Why the hooks live in
   the repo" section, first-time-setup step 4 narrative, AND the Rollback section (the last one
   not named in the dispatch's own enumeration but independently confirmed stale in this report).
6. Hand the user the `~/.sapience/config.json` reconciliation instruction verbatim as given in the
   dispatch — independently confirmed accurate against the live file, no revision needed.
7. Do not edit `core/context/patterns/mcp-server-ownership.md`; flag/coordinate the nvim-sited
   follow-up task instead, per the dispatch.
8. Defer `nix flake check` / `home-manager switch` / live-file inspection to the implementation
   phase, which owns that verification explicitly.

## Risks & Mitigations

- **Risk**: an implementer, trusting the dispatch's literal "claudeMcpServers" naming, edits or
  searches for the wrong block and either misses `sapienceMcpServer` or accidentally touches
  `dotfiles.nix`'s playwright/nixos block. **Mitigation**: this report's correction, and the
  issue-log entry recorded during this research pass, name the exact entry and line range.
- **Risk**: `docs/sapience.md`'s Rollback section is overlooked because the dispatch's
  enumeration did not name it. **Mitigation**: named explicitly in this report's Findings and
  Decisions.
- **Risk**: the registration entry is added only to the live file (mirroring the companion's
  installer) rather than to the repo source, reproducing the exact non-durability bug this task
  exists to fix. **Mitigation**: this report traces the precedent (lean's installer writing to
  both `LIVE_SETTINGS` and `DOTFILES_SETTINGS`) and states plainly that the edit target is the
  repo source file, `config/claude/settings.json`.

## Appendix

### Search/Verification Commands Used

- `jq` queries against `.claude-extensions.json` (4 target repos + 2 negative-test repos),
  `~/.claude.json`, `~/.sapience/config.json`, `config/claude/settings.json`,
  `agent-system/extensions/sapience/settings-fragment.json`.
- `grep -n` against `modules/home/services/sapience.nix`, `modules/home/core/dotfiles.nix`,
  `docs/sapience.md` for section anchors, hook/option names, and stale-statement line numbers.
- Direct read of
  `/home/benjamin/.config/nvim/agent-system/extensions/sapience/scripts/install-sapience-mcp-session-hook.sh`
  and
  `/home/benjamin/.config/nvim/agent-system/extensions/lean/scripts/install-lean-lsp-session-hook.sh`
  for the exact command string and the durability-mechanism precedent.
- `git -C /home/benjamin/Projects/Sapience/sapience-app ls-files .claude` for the card-session
  structural guarantee.
- Read of
  `/home/benjamin/.config/nvim/specs/612_gate_sapience_activation_behind_extension/summaries/01_gate-sapience-activation-extension-summary.md`
  for companion-landing confirmation.

### References

- `/home/benjamin/.dotfiles/modules/home/services/sapience.nix`
- `/home/benjamin/.dotfiles/modules/home/core/dotfiles.nix`
- `/home/benjamin/.dotfiles/config/claude/settings.json`
- `/home/benjamin/.dotfiles/docs/sapience.md`
- `/home/benjamin/.config/nvim/agent-system/extensions/sapience/settings-fragment.json`
- `/home/benjamin/.config/nvim/agent-system/extensions/sapience/scripts/install-sapience-mcp-session-hook.sh`
- `/home/benjamin/.config/nvim/agent-system/extensions/lean/scripts/install-lean-lsp-session-hook.sh`
- `/home/benjamin/.config/nvim/agent-system/extensions/core/context/patterns/mcp-server-ownership.md`

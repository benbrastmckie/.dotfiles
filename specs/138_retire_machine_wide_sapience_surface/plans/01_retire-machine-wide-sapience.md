# Implementation Plan: Retire Machine-Wide Sapience Activation Surface

- **Task**: 138 - Retire every machine-wide Sapience ACTIVATION surface this repository owns
- **Status**: [IMPLEMENTING]
- **Effort**: 6.5 hours
- **Dependencies**: Companion project `gate_sapience_activation_behind_extension`, sited in
  `/home/benjamin/.config/nvim` (project 612) — confirmed landed; re-confirmed at Phase 1
- **Research Inputs**: `specs/138_retire_machine_wide_sapience_surface/reports/01_retire-machine-wide-sapience.md`
- **Artifacts**: plans/01_retire-machine-wide-sapience.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

This repository currently turns Sapience on for every Claude Code session on this machine, by
three independent means: a top-level `mcpServers.sapience` merge into `~/.claude.json` performed
at home-manager activation, seven `mcp__sapience__*` read-tool grants in
`config/claude/settings.json`'s `permissions.allow`, and five Sapience hook entries in that same
file's `hooks` object. All three are retired here, so that loading the sapience extension into a
repository becomes the only thing that turns Sapience on there. One machine-wide surface is
ADDED in exchange: a durable user-level `SessionStart` entry invoking the companion's per-project
MCP-registration hook, which is the gating mechanism rather than an activation surface and must
survive every `home-manager switch`. Done means: `nix flake check` passes, a switch leaves the
live `~/.claude/settings.json` carrying the registration entry and nothing else Sapience-specific,
`~/.claude.json` has no top-level `mcpServers.sapience` and no other key disturbed, the four
extension-loaded repositories still get all nine tools / eleven grants / five hooks, a
verified-unloaded repository gets none of them, and the documentation states the new contract
without a false hook count.

### Research Integration

The research report confirmed the companion landed (both installed files present, mode 755, and
all eleven grants plus all five hooks byte-identical in the extension's `settings-fragment.json`)
and made one load-bearing correction to the dispatch's own text, carried into this plan: the
top-level merge is NOT in a block named `claudeMcpServers`. `claudeMcpServers` is an unrelated
activation entry defined in `modules/home/core/dotfiles.nix:167` that merges
`mcpServers.playwright` and `mcpServers.nixos` only and MUST NOT be touched. The entry to remove
is `sapienceMcpServer` in `modules/home/services/sapience.nix`, gated by
`lib.mkIf cfg.registerMcpServer`. The report also surfaced staleness in `docs/sapience.md`'s
Rollback section that the dispatch's own enumeration did not name.

Three further findings were established at plan time by direct re-read of live files, and
correct or extend what the report recorded:

1. **`hooks.SessionEnd` holds TWO entries, not one.** The report stated that
   `UserPromptSubmit`, `PreToolUse`, `SessionEnd` and `Stop` "each hold exactly one entry, each
   Sapience-only" and that "all four arrays become empty". That is false for `SessionEnd`: its
   first entry is the systemd sleep-inhibitor cleanup (`kill` on
   `/tmp/claude-inhibitor-${SESSION_ID}.pid`, `async: true`), which is unrelated to Sapience and
   MUST be kept. Only `UserPromptSubmit`, `PreToolUse` and `Stop` become empty and have their
   keys dropped; `SessionEnd` survives with its one remaining entry.
2. **A second copy of the module exists and is deliberately out of scope.**
   `packages/sapience-flake/modules/sapience.nix` carries its own `registerMcpServer` (line 195)
   and `sapienceMcpServer` (line 354), with `packages/sapience-flake/checks/hm-module.nix`
   asserting that the option gates the `~/.claude.json` merge and README rows documenting it.
   That directory is a standalone, publishable flake with its own `flake.lock`, verified
   separately by `nix flake check -L ./packages/sapience-flake`; `modules/home/default.nix:48`
   imports `./services/sapience.nix`, never the flake copy, so the flake copy is not a
   machine-wide surface active on this machine. See Non-Goals.
3. **`_SAPIENCE_NOTE` is not an enforced key.** `modules/home/core/dotfiles.nix`'s
   `claudeSettings` activation entry enforces exactly
   `["_NOTE","env","hooks","model","permissions","statusLine"]`. `hooks` and `permissions` are
   enforced, so their removal propagates to the live file; `_SAPIENCE_NOTE` is merged with the
   live copy winning, so a rewritten note will NOT appear in `~/.claude/settings.json` while a
   live copy of the old note exists. This is cosmetic, affects no acceptance criterion, and is
   recorded here so a stale live note is not misread as a failed switch.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided for this dispatch and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- Remove the `registerMcpServer` option and the `sapienceMcpServer` activation entry from
  `modules/home/services/sapience.nix`, leaving `dotfiles.nix`'s `claudeMcpServers`,
  `sapiencePayload`, `sapienceTokenRepair` and `sapienceApiKey` untouched.
- Remove the seven `mcp__sapience__*` grants and the five Sapience hook entries from
  `config/claude/settings.json`, keeping every non-Sapience entry in that `hooks` object.
- Add the durable registration `SessionStart` entry to `config/claude/settings.json`, byte-for-byte
  matching the command string the companion's installer keys its idempotency check on.
- Rewrite `_SAPIENCE_NOTE` so it carries forward the enforced-key rationale, the `statusLine`
  ruling and the deliberately-unwired-`sapience_cli.py`-hooks ruling, and states why the
  registration entry is the one Sapience entry that stays here.
- Rewrite every statement in `docs/sapience.md` that the change makes false, with a correct hook
  count, and document the registration entry this repository now owns.
- Verify against live merged state after a switch, not merely against repo source.
- Hand the owner an exact, runnable `~/.sapience/config.json` reconciliation instruction covering
  both `capture.projects` and the top-level `folders` allowlist, naming the sanctioned route.

**Non-Goals**:

- Editing `packages/sapience-flake/**`. It is a standalone publishable flake not imported by this
  machine's home configuration, verified by its own separate `nix flake check`, and
  `registerMcpServer = true` remains a correct default for a consumer who does not use the
  per-repo extension mechanism at all. Touching it would break its own checks and README for no
  gain here.
- Editing `modules/home/core/dotfiles.nix`'s `claudeMcpServers` block (playwright/nixos).
- Editing `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` under
  `/home/benjamin/.config/nvim`. That is a source-store file in another repository; per
  `.claude/rules/source-store-deploy-boundary.md`'s Task Siting subsection the edit belongs to an
  nvim-sited task. Coordination only — see Phase 5.
- Closing the four-write-tool-grant unload residual (a pre-existing merge-engine defect the
  companion scoped out and named as a separately-scoped follow-up).
- Closing the SF-1 card-worktree retrieval gap (registration keyed on worktree rather than parent
  checkout). The registration logic lives in `agent-system/extensions/sapience/` under
  `/home/benjamin/.config/nvim`, so that follow-up is nvim-sited.
- Editing anything under `~/.sapience/**`. That is owner-only state, and its payload self-updates
  daily.
- Pre-seeding `.projects[<path>].mcpServers.sapience` entries in `~/.claude.json` by hand. Those
  are session-start-triggered and populate themselves on each repository's next session.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The registration `SessionStart` entry is omitted, or removed along with the other five | H | M | Phase 3 adds it in the same edit that removes the briefing entry; Phase 6 re-reads the LIVE file after the switch and byte-compares the command string. This is the one check that distinguishes a correct landing from one that silently turns Sapience off everywhere |
| An implementer searches for `claudeMcpServers`, edits `dotfiles.nix`, and breaks playwright/nixos registration | H | M | The correct target (`sapienceMcpServer`, `lib.mkIf cfg.registerMcpServer`) is named in Phase 2's tasks; `dotfiles.nix` is named in Non-Goals; Phase 6 asserts `mcpServers.nixos` and `mcpServers.playwright` survive in `~/.claude.json` |
| The systemd sleep-inhibitor cleanup entry in `hooks.SessionEnd` is deleted along with the Sapience receipt entry | M | M | Phase 3 states the target shape of every hook key explicitly and Phase 6 asserts the inhibitor entry is still present in the live file |
| An implementer edits `packages/sapience-flake/modules/sapience.nix` because grep finds `registerMcpServer` there | M | M | Named in Non-Goals with the reason; Phase 6's `git diff --stat` review asserts no file under `packages/` is touched |
| The `docs/sapience.md` rewrite introduces record-versioning language ("no longer", "previously", "formerly") while describing a removal | M | H | Phase 4 states the constraint as a task; Phase 6 runs the repo's task-reference and doc lints and reads the diff for the forbidden phrasing enumerated in `.claude/rules/no-record-versioning-in-deliverables.md` |
| A stale `_SAPIENCE_NOTE` in the live file after the switch is misread as a failed switch | L | M | Recorded above under Research Integration and restated in Phase 6's verification criteria as an expected, non-failing observation |
| `home-manager switch` cannot be run (e.g. a concurrent activation holds the lock) | M | L | Fall back to `home-manager build --flake .#benjamin` as the dispatch allows, mark the live-file checks [PARTIAL] with the exact outstanding checks named, and do not claim criteria 2, 3 or 8 |
| `nix flake check`'s `deadnix` flags a now-unused binding after the option removal | L | L | Phase 2 removes the option and its sole consumer together; Phase 6 runs the full `nix flake check`, which is authoritative |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 5 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 6 | 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Re-confirm the ordering constraint and capture the pre-change baseline [COMPLETED]

**Goal**: Establish, at implementation time rather than from the dispatch's note, that the
companion task landed and that every surface this task removes is currently present as described;
record the evidence durably, as acceptance criterion 6 requires.

**Tasks**:

- [ ] Read
  `/home/benjamin/.config/nvim/specs/612_gate_sapience_activation_behind_extension/summaries/01_gate-sapience-activation-extension-summary.md`
  and confirm its plan-level `- **Status**:` field reads `[COMPLETED]`.
- [ ] Confirm both installed files exist and are executable:
  `ls -l $HOME/.claude/hooks/sapience-mcp-register-project.sh $HOME/.claude/scripts/setup-sapience-mcp.sh`.
- [ ] Confirm all eleven grants are present at per-repo scope:
  `jq -r '.permissions.allow[] | select(startswith("mcp__sapience"))' /home/benjamin/.config/nvim/agent-system/extensions/sapience/settings-fragment.json | sort`
  and confirm the seven read-tool entries are byte-identical to the seven in this repository's
  `config/claude/settings.json`.
- [ ] Extract the registration command string from the companion's installer
  (`/home/benjamin/.config/nvim/agent-system/extensions/sapience/scripts/install-sapience-mcp-session-hook.sh`)
  and confirm it is byte-identical to the string this plan records in Phase 3. If it differs,
  STOP: the installer is the authority on its own idempotency key, and Phase 3 must use the
  installer's current string instead of this plan's transcription.
- [ ] Capture a baseline of the four extension-loaded repositories by reading each
  `.claude-extensions.json` and confirming `extensions.sapience.status == "active"` for
  `/home/benjamin/.config/nvim`, `/home/benjamin/.dotfiles`, `/home/benjamin/Projects/abood` and
  `/home/benjamin/Projects/Sapience/sapience-app`, and `absent` for `/home/benjamin/Projects/cslib`
  and `/home/benjamin/Projects/Logos/Theory`.
- [ ] Capture the pre-change `~/.claude.json` top-level key list and the full
  `.projects | keys` list, so Phase 6 can assert nothing else was disturbed.
- [ ] Write the confirmation record, including the commands run and their output, to
  `specs/138_retire_machine_wide_sapience_surface/records/01_companion-landing-confirmation.md`.
  Create the `records/` directory if absent.
- [ ] If the companion is NOT confirmed landed, stop and report: do not proceed to Phase 2.
  Removing the machine-wide surface first leaves Sapience off in every repository.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this phase's one
touched path, which lies entirely under `specs/**` (sub-case (a), where the task-reference lint's
own exempt tree makes `--only-gate 3,4` meaningless), so the covering check is the `prose` row's
diff read-through of the written record.

**Scope Hypothesis**: This phase asserts the companion is landed, that both installed files are
present at mode 755, and that eleven grants sit in the extension's fragment. Each is a hypothesis
to be confirmed by the commands above, not a fact carried from the dispatch; a mismatch on the
first three is a STOP condition and a mismatch on the command string redirects Phase 3's content.

**Files to modify**:

- `specs/138_retire_machine_wide_sapience_surface/records/01_companion-landing-confirmation.md` - new; the acceptance-criterion-6 evidence record

**Verification**:

- The record file exists, is non-empty, and names each check with its observed result.
- The companion summary's status field was read directly, not inferred.

---

### Phase 2: Remove the top-level MCP registration from the nix module [NOT STARTED]

**Goal**: Delete the only activation surface that merges `mcpServers.sapience` into the top level
of `~/.claude.json`, together with the option that gates it, and reconcile every comment in that
file that describes the retired arrangement.

**Tasks**:

- [ ] In `modules/home/services/sapience.nix`, delete the `registerMcpServer` option block
  (currently at line 783, through the closing `};` of that `lib.mkOption`), including its
  description text.
- [ ] Delete the `sapienceMcpServer` activation entry (currently the comment block beginning
  "Registers without a token until config.json has one" at line ~1014 through the closing `);` of
  that entry at line ~1056). This is the last entry in the `activation` attribute set; remove the
  entry whole, leaving `sapiencePayload`, `sapienceTokenRepair` and `sapienceApiKey` intact and
  their relative ordering unchanged.
- [ ] Do NOT touch `modules/home/core/dotfiles.nix`. Its `claudeMcpServers` entry merges
  `mcpServers.playwright` and `mcpServers.nixos` only; `sapienceMcpServer` merely named it in an
  `entryAfter` dependency list, and that reference disappears with the entry.
- [ ] Update the `sapienceTokenRepair` comments that reference the removed entry: line ~931
  ("including sapienceMcpServer below, which copies it into ~/.claude.json") and line ~936
  ("Ordered before sapienceMcpServer so the registration always copies a repaired value"). The
  repair is still worth doing — the per-project registration writer reads the same `token` field —
  so restate the reason in terms of the consumers that remain rather than deleting the comment.
- [ ] Update the module header comment at lines 12-14, which states that the Claude Code hooks and
  `mcp__sapience__*` grants live in `config/claude/settings.json` because `hooks` and `permissions`
  are enforced keys. State instead where those surfaces live now (the sapience extension's
  `settings-fragment.json`, merged per repository), and that the enforced-key mechanism is why
  the per-project registration `SessionStart` entry alone is kept in
  `config/claude/settings.json`.
- [ ] Update the comment at lines 49-50 inside the `optionalPayload` binding, which makes the same
  claim about `sapience_cli.py`'s hooks.
- [ ] Confirm nothing in the repository still sets or reads `programs.sapience.registerMcpServer`:
  `grep -rn 'registerMcpServer' --include='*.nix' modules/ hosts/ home.nix flake.nix` must return
  no hits. (`packages/sapience-flake/**` hits are expected and out of scope — see Non-Goals.)
- [ ] Write no record-versioning language into any comment: state the current arrangement, never
  "no longer", "previously" or "used to". See `.claude/rules/no-record-versioning-in-deliverables.md`.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for
`modules/home/services/sapience.nix` (a deploy-consumer-tree path with no mapped shell suite —
sub-case (c)), so the covering checks are `nix flake check` (whose `statix`, `deadnix --fail`,
`nixfmt --check` and `home-eval` outputs all read this exact module) together with
`bash .claude/scripts/verify-deploy.sh --only-gate 4`.

**Scope Hypothesis**: This phase asserts exactly two removable constructs (one option block, one
activation entry) and four comment sites needing reconciliation, at the line numbers above.
Confirm each by `grep -n` before editing rather than trusting the line numbers, which drift with
every edit to the file.

**Files to modify**:

- `modules/home/services/sapience.nix` - remove the `registerMcpServer` option and the `sapienceMcpServer` activation entry; reconcile four comment sites

**Verification**:

- `grep -n 'registerMcpServer\|sapienceMcpServer\|mcpServers' modules/home/services/sapience.nix`
  returns no hits.
- `grep -n 'claudeMcpServers' modules/home/core/dotfiles.nix` still finds the definition, and
  `git diff --stat` shows `dotfiles.nix` untouched.
- `nix flake check` passes (deferred in full to Phase 6, but run here for early signal).
- `git diff -- modules/home/services/sapience.nix` read through: every changed hunk is either a
  whole-construct deletion or a comment, with no unintended change to `sapiencePayload`,
  `sapienceTokenRepair` or `sapienceApiKey`.

---

### Phase 3: Retire the grants and hooks, and add the durable registration entry [NOT STARTED]

**Goal**: Make `config/claude/settings.json` carry no Sapience activation surface and exactly one
Sapience entry — the per-project MCP-registration `SessionStart` hook — with every non-Sapience
entry in that file preserved untouched.

**Tasks**:

- [ ] Remove all seven Sapience entries from `permissions.allow`: `mcp__sapience__sapience`,
  `mcp__sapience__sapience_search`, `mcp__sapience__sapience_briefing`,
  `mcp__sapience__sapience_context`, `mcp__sapience__sapience_ask`,
  `mcp__sapience__sapience_outstanding`, `mcp__sapience__sapience_papers`. Leave every other
  entry in that array exactly as it is.
- [ ] From `hooks.SessionStart`, remove ONLY the third entry (the Sapience briefing,
  `[ -f "$HOME/.sapience/mcp.py" ] && python3 "$HOME/.sapience/mcp.py" --briefing-text 2>/dev/null || true`).
  KEEP the first entry (the systemd sleep-inhibitor, `async: true`) and the second (the lean-lsp
  registration entry with `"matcher": "startup"`).
- [ ] From `hooks.SessionEnd`, remove ONLY the second entry (`mcp.py --receipt`, `async: true`).
  KEEP the first entry — the sleep-inhibitor cleanup that kills the PID in
  `/tmp/claude-inhibitor-${SESSION_ID}.pid`. `SessionEnd` therefore survives as a key with one
  entry. This corrects the research report, which recorded `SessionEnd` as Sapience-only.
- [ ] Remove the `hooks.UserPromptSubmit`, `hooks.PreToolUse` and `hooks.Stop` keys entirely. Each
  holds exactly one entry and that entry is Sapience's, so each array would otherwise be left
  empty; drop the key rather than leaving `[]`, matching the file's existing conventions.
- [ ] ADD to `hooks.SessionStart` a third entry, alongside the lean-lsp entry, in the installer's
  exact shape — no `matcher`, no `timeout`, no `async`:

  ```json
  {
    "hooks": [
      {
        "type": "command",
        "command": "bash $HOME/.claude/hooks/sapience-mcp-register-project.sh 2>/dev/null || echo '{}'"
      }
    ]
  }
  ```

  The command string must be byte-identical to the one Phase 1 extracted from the installer: both
  the installer's idempotency check and its `--remove` key off this exact string. The
  `2>/dev/null || echo '{}'` tail makes the entry inert when the hook file is absent, which is the
  same arrangement the adjacent lean-lsp entry already relies on.
- [ ] Rewrite `_SAPIENCE_NOTE` (line 178) so it states, in the current tense and with no
  record-versioning language: (a) that `hooks` and `permissions` are ENFORCED keys in
  `home.activation.claudeSettings`, so anything a vendor installer writes into the live file is
  reset on the next switch — and that this is precisely why the per-project registration
  `SessionStart` entry has to live in this repository file rather than only in the extension's
  installer; (b) that the Sapience hooks and the `mcp__sapience__*` grants are per-repository
  surfaces merged from the sapience extension's `settings-fragment.json` into each loaded
  repository's `.claude/settings.local.json`; (c) that `statusLine` belongs to
  `hooks/statusline-push.sh` and is deliberately not wired to Sapience; (d) that
  `sapience_cli.py`'s own `hook session` and `hook stop` are deliberately not wired, because each
  would duplicate an `mcp.py` hook and print a second line per turn.
- [ ] Edit by hand, preserving the file's existing indentation and key order. Do NOT pipe the
  whole file through `jq`: that reflows every record's formatting regardless of which fields the
  filter targets — see `.claude/context/patterns/jq-escaping-workarounds.md`.
- [ ] Confirm the result parses: `jq -e . config/claude/settings.json >/dev/null`.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` maps `config/claude/settings.json` to eight real
suites, so the covering check is
`bash .claude/scripts/tests/run-all.sh --only test-deploy-propagation.sh,test-gate-cache-equivalence.sh,test-gate-cache-lib.sh,test-gate-registry-resolution.sh,test-guard-git-push.sh,test-lint-hook-registration-paths.sh,test-sapience-mcp-registration.sh,test-verify-deploy-gate-selection.sh`
— of which `test-sapience-mcp-registration.sh` and `test-lint-hook-registration-paths.sh` bear
directly on this phase's edit — run together with `jq -e . config/claude/settings.json`, since
`nix flake check` never parses this file (`dotfiles.nix` interpolates it as a store path, with no
`fromJSON`).

**Scope Hypothesis**: This phase asserts exactly seven `permissions.allow` entries to remove, five
Sapience hook entries to remove, three hook keys to drop whole, one hook key (`SessionEnd`) to
retain with its surviving non-Sapience entry, and one entry to add. Re-derive each count from the
live file with `jq` before editing — in particular `jq '.hooks.SessionEnd | length'`, which must
read 2 before the edit and 1 after.

**Files to modify**:

- `config/claude/settings.json` - remove 7 grants and 5 hook entries; add the registration `SessionStart` entry; rewrite `_SAPIENCE_NOTE`

**Verification**:

- `jq -e . config/claude/settings.json >/dev/null` succeeds.
- `bash .claude/scripts/tests/run-all.sh --only test-deploy-propagation.sh,test-gate-cache-equivalence.sh,test-gate-cache-lib.sh,test-gate-registry-resolution.sh,test-guard-git-push.sh,test-lint-hook-registration-paths.sh,test-sapience-mcp-registration.sh,test-verify-deploy-gate-selection.sh`
  exits 0. If `test-sapience-mcp-registration.sh` encodes expectations about the machine-wide
  arrangement this phase retires, treat its failure as a real finding: report it and update the
  suite rather than editing the settings file to satisfy a stale expectation.
- `jq -r '.permissions.allow[] | select(startswith("mcp__sapience"))' config/claude/settings.json`
  returns nothing.
- `jq -r '.hooks | keys[]' config/claude/settings.json` returns exactly `SessionEnd` and
  `SessionStart`.
- `jq '.hooks.SessionStart | length'` is 3 and `jq '.hooks.SessionEnd | length'` is 1.
- `jq -r '.hooks.SessionStart[].hooks[].command' config/claude/settings.json | grep -c '^bash \$HOME/.claude/hooks/sapience-mcp-register-project.sh 2>/dev/null || echo .{}.$'`
  is 1 — or, equivalently, a direct byte-comparison of that command string against the one Phase 1
  extracted from the installer.
- `grep -c 'sapience/mcp.py\|sapience_cli.py' config/claude/settings.json` is 0.
- `git diff -- config/claude/settings.json` read through: no entry outside the Sapience set and
  the `_SAPIENCE_NOTE` string was altered, and the sleep-inhibitor entries in both `SessionStart`
  and `SessionEnd` are intact.

---

### Phase 4: Rewrite the documentation to state the new activation contract [NOT STARTED]

**Goal**: Leave no statement in this repository claiming that Sapience is active machine-wide,
that `mcpServers.sapience` is merged at the top level, or that there are three hooks; and document
the registration `SessionStart` entry this repository now owns.

**Tasks**:

- [ ] `docs/sapience.md`, intro (lines ~3-5): state that the MCP server reaches Claude Code
  per-repository, through the sapience extension, rather than in every session on the machine.
- [ ] "What is installed" table (lines ~33-49): rewrite the `mcpServers.sapience` in
  `~/.claude.json` row — registration is now per-project, under `.projects[<abs path>].mcpServers`,
  written by a `SessionStart` hook rather than by activation. Rewrite the "Three hooks and seven
  tool grants" row: the count was already wrong (five hooks were registered, not three), and the
  correct statement now is that the five hooks and eleven grants are merged per repository from
  the sapience extension's `settings-fragment.json`, with one registration `SessionStart` entry in
  `config/claude/settings.json`. Rewrite the "Token shape repair" row's "runs before the MCP merge"
  note to name the consumer that remains.
- [ ] First-time setup step 4 (lines ~108-120): the second switch no longer exists to put a token
  into `~/.claude.json`. State what the step now accomplishes and what `sapience status` can
  truthfully report about Claude Code registration under per-project registration.
- [ ] "Why the hooks live in the repo" section (lines ~637-651): rewrite to explain the
  enforced-key mechanism as the reason the registration `SessionStart` entry lives in
  `config/claude/settings.json`, and where the five hooks and eleven grants live instead. Preserve
  the `statusLine` ruling and the `Stop`-hook note, re-sited to the extension fragment that now
  owns that hook. Update the anchor link from the "What is installed" table if the heading changes.
- [ ] Module options table (lines ~652-685): remove the `registerMcpServer` row, and amend the
  `enable` row's purpose, which currently reads "CLI, sync unit, payload seed, MCP registration".
- [ ] Inspection recipes (line ~710): `jq '.mcpServers.sapience' ~/.claude.json` no longer inspects
  anything that exists. Replace it with the per-project form, e.g.
  `jq --arg p "$PWD" '.projects[$p].mcpServers.sapience' ~/.claude.json`, and say that the entry
  appears once a session has started in a repository whose sapience extension is active. (Not named
  in the dispatch's enumeration; found at plan time.)
- [ ] Rollback section (lines ~764-788): both statements there become false — the
  `jq 'del(.mcpServers.sapience)' ~/.claude.json` recipe and "The hooks and tool grants go away by
  deleting their entries from `config/claude/settings.json`". Rewrite to describe what disabling
  `programs.sapience` actually leaves behind, and to say that the hooks and grants go away by
  unloading the sapience extension from a repository, while the registration entry's own removal
  is `install-sapience-mcp-session-hook.sh --remove` plus deleting the entry from
  `config/claude/settings.json`. (Surfaced by the research report.)
- [ ] Add documentation of the registration entry itself: what
  `$HOME/.claude/hooks/sapience-mcp-register-project.sh` does (bidirectional — it registers
  `.projects[<abs path>].mcpServers.sapience` when the current repository's sapience extension is
  active and removes it when it is not), that it and
  `$HOME/.claude/scripts/setup-sapience-mcp.sh` are installed by the extension's own installer
  rather than by home-manager, that the `2>/dev/null || echo '{}'` tail makes the entry inert when
  they are absent, and that this repository owns the durable registration of the entry because
  `hooks` is an enforced key.
- [ ] `home.nix` line ~36: the comment "Enabling the module installs the CLI, the hourly timer and
  the MCP registration" becomes false. Correct it to name only what the module still installs.
  This is a comment-only edit, deliberately added to the dispatch's three-file target list because
  leaving a false statement in this repository contradicts the task's own documentation goal; it
  touches no behavior and no acceptance criterion depends on it.
- [ ] Across every edit: no task-number references and no record-versioning language. Describe the
  arrangement as it now stands; do not narrate what changed. See
  `.claude/rules/no-task-references-in-deliverables.md` and
  `.claude/rules/no-record-versioning-in-deliverables.md`.
- [ ] Leave `packages/sapience-flake/README.md` and `packages/README.md` untouched: both describe
  the standalone flake's own behavior, which this change does not alter.

**Timing**: 1.5 hours

**Depends on**: 2, 3

**Verification Tier**: prose

**Tier Justification**: every changed hunk is markdown prose or a nix comment with no compile or
elaboration surface, and `suite_selection_select` returns `__FULL_SWEEP__` for both paths
(deploy-consumer tree, no mapped suite — sub-case (c)), so the covering checks are the `prose`
row's diff read-through together with `bash .claude/scripts/verify-deploy.sh --only-gate 4` for the
task-reference lint that acceptance criterion 7 turns on.

**Scope Hypothesis**: This phase asserts eight stale sites in `docs/sapience.md` and one in
`home.nix`, at the line numbers above. Before editing, re-locate each by content rather than line
number, and run `grep -n -i 'mcpServers.sapience\|three hooks\|seven tool grants\|machine-wide' docs/sapience.md`
to catch any site this enumeration missed.

**Files to modify**:

- `docs/sapience.md` - rewrite the intro, the "What is installed" rows, first-time-setup step 4, the "Why the hooks live in the repo" section, the module options table, the inspection recipe, and the Rollback section; document the registration entry
- `home.nix` - correct the `programs.sapience` comment that claims the module installs MCP registration

**Verification**:

- `grep -n -i 'three hooks\|seven tool grants' docs/sapience.md` returns nothing.
- `grep -n "jq '.mcpServers.sapience'" docs/sapience.md` returns nothing.
- `grep -n 'registerMcpServer' docs/sapience.md` returns nothing.
- `grep -nE 'no longer|previously|formerly|used to|supersed' docs/sapience.md home.nix` returns
  nothing introduced by this diff.
- `bash .claude/scripts/verify-deploy.sh --only-gate 4` passes with gate 4 reported as run, not
  skipped.
- Diff read-through confirms every changed hunk lies inside prose or a comment.

---

### Phase 5: Produce the owner instruction and the cross-repo coordination record [NOT STARTED]

**Goal**: Hand the owner one exact, runnable instruction that reconciles `~/.sapience/config.json`
to the four-repository extension-loaded set across BOTH keys, with the sanctioned route named; and
record the two nvim-sited follow-ups this task must coordinate but must not perform.

**Tasks**:

- [ ] Re-read `~/.sapience/config.json` (read only — never edit) and confirm the current shape
  still matches what this plan assumes: a top-level `folders` array of five transcript-directory
  keys, `capture.mode == "opt-in"`, and a `capture.projects` array of ten
  `{path_prefix, name, target, enabled}` objects of which five are `enabled: true`. If it has
  moved, regenerate the instruction against what is actually there.
- [ ] State the route determination explicitly, with its reasoning: `sapience projects` (the
  vendor's own interactive flow, dispatched by this repository's wrapper to
  `extract_local.py --projects`) is the sanctioned route for the `capture.projects` half, and the
  interactive folder picker that runs first in a bootstrap or extraction run owns the top-level
  `folders` half. The picker cannot express the full target, however: it selects among transcript
  directories that already exist under `~/.claude/projects/`, and
  `-home-benjamin-Projects-Sapience-sapience-app` does not exist until a session has run from the
  moved checkout. Name a guarded `jq` hand-edit as the route that reconciles both keys in one
  pass, with the caveat that a later picker run persists its own selection over `folders`, so the
  owner should re-check after any `sapience-bootstrap` or interactive extraction run.
- [ ] Write the instruction as a copy-pasteable block that: operates on a temporary file and moves
  it into place atomically; preserves the top-level `token` field and every other key; restores
  mode 600 explicitly; sets `enabled: false` on `/home/benjamin/Projects/BimodalLogic`,
  `/home/benjamin/Philosophy/Papers/PossibleWorlds` and `/home/benjamin/Projects/Logos/Verification`;
  adds `/home/benjamin/Projects/abood` and `/home/benjamin/Projects/Sapience/sapience-app` as
  `enabled: true` entries matching the existing `{path_prefix, name, target, enabled}` shape with
  `target: "personal"`; and replaces the top-level `folders` array with exactly
  `-home-benjamin--config-nvim`, `-home-benjamin--dotfiles`, `-home-benjamin-Projects-abood` and
  `-home-benjamin-Projects-Sapience-sapience-app`. State that the stale pre-move
  `-home-benjamin-Projects-sapience-app` key names a different directory and must not be used.
- [ ] Include a verification line the owner can run afterwards, confirming both keys and that
  `token` and mode 600 survived.
- [ ] Write the instruction to
  `specs/138_retire_machine_wide_sapience_surface/records/02_sapience-config-owner-instruction.md`,
  and restate it verbatim in the implementation summary so it reaches the user without opening a
  file.
- [ ] Surface it as a non-blocking `user_decision` on `.return-meta.json` at implement-time
  postflight (an external action only the owner can take on owner-only state), per
  `.claude/context/standards/user-decision-contract.md`.
- [ ] Write the coordination record to
  `specs/138_retire_machine_wide_sapience_surface/records/03_nvim-sited-followups.md`, naming the
  two nvim-sited follow-ups precisely and stating that this task performs neither: (a) updating
  the sapience worked example in
  `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`, which goes stale the
  moment this task lands and should be run alongside it so the staleness window is closed; (b)
  resolving an SF-1 card worktree to its parent checkout for registration purposes, so the card
  repository's own repo-scoped retrieval is reachable inside the worktree —
  `git rev-parse --git-common-dir` does that resolution in one call, and the runner's memory sync
  already keys on the checkout path as precedent.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for both touched paths,
which lie entirely under `specs/**` (sub-case (a), where doc-lint and the task-reference lint have
no bearing), so the covering check is the `prose` row's diff read-through of the two written
records.

**Scope Hypothesis**: This phase asserts five `folders` entries and ten `capture.projects` entries
with five enabled in the live file, and that neither `abood` nor `sapience-app` appears anywhere
in it. Confirm by re-reading the file before writing the instruction; a drifted file invalidates
the generated `jq` recipe.

**Files to modify**:

- `specs/138_retire_machine_wide_sapience_surface/records/02_sapience-config-owner-instruction.md` - new; the exact runnable owner instruction and the route determination
- `specs/138_retire_machine_wide_sapience_surface/records/03_nvim-sited-followups.md` - new; the two coordinated, deliberately-not-performed follow-ups

**Verification**:

- `~/.sapience/config.json` is unmodified: its mtime and `jq -S . | sha256sum` digest match the
  values read at the start of this phase.
- The instruction block, pasted into a shell with the real file swapped for a copy, produces a
  config whose `folders` has exactly the four keys, whose `capture.projects` has exactly four
  `enabled: true` entries matching the loaded set, and whose `token` and mode 600 are intact.
  Run this rehearsal against a copy under the scratchpad directory, never against the live file.
- Both record files exist and name the sanctioned route and the two follow-ups explicitly.

---

### Phase 6: Gate, switch, and verify against live merged state [NOT STARTED]

**Goal**: Establish every acceptance criterion against the files the system actually reads after a
switch, not against repository source.

**Tasks**:

- [ ] Run `nix flake check`. It is authoritative — it runs `statix`, `deadnix --fail`,
  `nixfmt --check`, `shellcheck` and the `home-eval` evaluation of the standalone home generation
  as `checks.<system>.*` outputs. It must pass.
- [ ] Run `bash .claude/scripts/verify-deploy.sh` — the complete gate set for this repository —
  and confirm no gate reports a failure and that gate 4 (the task-reference lint) reports as run
  rather than skipped.
- [ ] Run `home-manager switch --flake .#benjamin`. If a switch is genuinely unavailable, fall
  back to `home-manager build --flake .#benjamin`, mark this phase [PARTIAL] naming every live-file
  check left outstanding, and do not claim acceptance criteria 2, 3 or 8.
- [ ] Inspect the LIVE `~/.claude/settings.json`: `jq -r '.permissions.allow[] | select(startswith("mcp__sapience"))'`
  returns nothing, and `jq -r '.hooks | keys[]'` returns exactly `SessionEnd` and `SessionStart`.
  `hooks` and `permissions` are enforced keys, so the merge must have REMOVED the stale entries
  rather than preserved them additively — confirm that directly rather than assuming it.
- [ ] Confirm the registration entry stands in the LIVE file: the command string in
  `jq -r '.hooks.SessionStart[].hooks[].command' ~/.claude/settings.json` is byte-identical to
  `bash $HOME/.claude/hooks/sapience-mcp-register-project.sh 2>/dev/null || echo '{}'`. This is the
  single check that distinguishes a correct landing from one that silently turns Sapience off
  everywhere (acceptance criterion 8).
- [ ] Confirm the live `SessionStart` sleep-inhibitor entry and the live `SessionEnd`
  inhibitor-cleanup entry both survive.
- [ ] Expect the LIVE `_SAPIENCE_NOTE` to still read as it did before the switch: that key is not
  in the enforced set (`["_NOTE","env","hooks","model","permissions","statusLine"]`), so the live
  copy wins the merge. This is expected and is not a failed switch; the repository source is the
  artifact acceptance criterion 5 is measured against.
- [ ] Inspect `~/.claude.json`: `jq -r '.mcpServers | keys[]'` must no longer list `sapience`, and
  must still list `nixos` and `playwright`. Compare the full top-level key list and the
  `.projects | keys` list against the Phase 1 baseline: nothing else may have been disturbed.
- [ ] Re-run the companion's installer
  (`bash /home/benjamin/.config/nvim/agent-system/extensions/sapience/scripts/install-sapience-mcp-session-hook.sh`)
  and confirm it reports a no-op rather than double-registering. Its idempotency check matches on
  the command string alone and ignores which writer put it there, so this is expected to pass
  without any change to the installer — confirm it, since the entry now arrives from a different
  writer.
- [ ] Negative test: start a session in `~/Projects/cslib` or `~/Projects/Logos/Theory` (both
  verified-unloaded) and confirm no `sapience_*` tools, no Sapience grants and no Sapience hook
  firing.
- [ ] Positive test: start a session in at least one of the four loaded repositories and confirm
  all nine tools, all eleven grants and all five hooks, and that
  `.projects["<that repo's abs path>"].mcpServers.sapience` appears in `~/.claude.json`. The
  registration is session-start-triggered, so repositories that have not had a session since the
  companion landed will not be registered until one runs — that is expected, not a defect.
- [ ] SF-1 card session check: if a worktree exists under
  `~/.local/state/sf1-hub-ben/hub/runner/work/`, start a session there and confirm no Sapience
  hooks fire and no Sapience grants are present. That outcome is already structurally guaranteed
  by the card repository having no tracked `.claude/` tree, independently of this change. Record
  the absence of repo-scoped retrieval tools in that worktree as the known, deliberate gap with
  the nvim-sited follow-up named in Phase 5 — never as a success condition, and never as "a card
  session will receive NONE, and that is correct", which is true of hook injection and false of
  retrieval. If no worktree exists, record that the structural guarantee was established from the
  repository-level `git ls-files .claude` result instead.
- [ ] Review `git status --short` and `git diff --staged` before committing: exactly four files
  outside `specs/**` may appear — `modules/home/services/sapience.nix`,
  `config/claude/settings.json`, `docs/sapience.md` and `home.nix`. Nothing under `packages/` and
  nothing in `modules/home/core/dotfiles.nix` may be staged.

**Timing**: 1.5 hours

**Depends on**: 2, 3, 4, 5

**Verification Tier**: full

**Files to modify**:

- `specs/138_retire_machine_wide_sapience_surface/records/04_live-verification.md` - new; the observed output of every live check above, as the evidence acceptance criteria 2, 3 and 8 are measured against

**Verification**:

- The complete gate set for this repository runs green: `nix flake check` and
  `bash .claude/scripts/verify-deploy.sh`.
- `home-manager switch --flake .#benjamin` completes, or the documented `home-manager build`
  fallback is recorded along with the named outstanding checks.
- Every live-file assertion above is recorded with its observed output in the verification record,
  not merely asserted as having passed.
- Acceptance criteria 1-8 are each addressed explicitly in the record, with criterion 6 pointing at
  Phase 1's confirmation record and criterion 4 at Phase 5's owner instruction.

---

## Testing & Validation

- [ ] `nix flake check` passes (criterion 1).
- [ ] `bash .claude/scripts/verify-deploy.sh` passes, with gate 4 run rather than skipped
  (criterion 7).
- [ ] `jq -e . config/claude/settings.json` succeeds and the file carries no `mcp__sapience__*`
  grant and no `~/.sapience/*.py` hook command.
- [ ] After a switch, the live `~/.claude/settings.json` carries no Sapience grant and no Sapience
  hook other than the registration `SessionStart` entry, whose command string is byte-identical to
  the installer's (criteria 2, 8).
- [ ] After a switch, `~/.claude.json` has no top-level `mcpServers.sapience`, still has `nixos`
  and `playwright`, and has no other key disturbed relative to the Phase 1 baseline (criterion 2).
- [ ] A verified-unloaded repository gets no tools, no grants and no hook firing; a loaded
  repository gets all nine tools, all eleven grants, all five hooks, and its own
  `.projects[<abs path>].mcpServers.sapience` entry (criteria 3, 8).
- [ ] An SF-1 card worktree fires no Sapience hooks and carries no Sapience grants, with the
  retrieval-tool absence recorded as a known gap rather than a success condition (criterion 3).
- [ ] Re-running the companion's installer reports a no-op (criterion 8).
- [ ] `docs/sapience.md` carries a correct hook count, documents the registration entry, and the
  rewritten `_SAPIENCE_NOTE` preserves the enforced-key rationale, the `statusLine` ruling and the
  deliberately-unwired-`sapience_cli.py`-hooks ruling while stating why the registration entry
  stays (criterion 5).
- [ ] No file outside `specs/**` carries a task-number reference or record-versioning language
  (criterion 7).

## Artifacts & Outputs

- `modules/home/services/sapience.nix` — `registerMcpServer` option and `sapienceMcpServer`
  activation entry removed; four comment sites reconciled.
- `config/claude/settings.json` — seven grants and five hook entries removed; three hook keys
  dropped; one registration `SessionStart` entry added; `_SAPIENCE_NOTE` rewritten.
- `docs/sapience.md` — eight sections rewritten to state the per-repository activation contract and
  to document the registration entry.
- `home.nix` — one comment corrected.
- `specs/138_retire_machine_wide_sapience_surface/records/01_companion-landing-confirmation.md`
- `specs/138_retire_machine_wide_sapience_surface/records/02_sapience-config-owner-instruction.md`
- `specs/138_retire_machine_wide_sapience_surface/records/03_nvim-sited-followups.md`
- `specs/138_retire_machine_wide_sapience_surface/records/04_live-verification.md`
- An implementation summary under `specs/138_retire_machine_wide_sapience_surface/summaries/`,
  restating the owner instruction verbatim.

## Rollback/Contingency

The change is four files in one repository plus one activation effect, and reverts cleanly.

- **Uncommitted work.** If a phase must be abandoned mid-edit, take a snapshot first and then
  roll back, per `.claude/context/contracts/recovery.md`'s rollback rung — including its
  out-of-scope override flag if the revert must reach beyond this task's declared `file_scope`.
  Never discard uncommitted changes to reach a passing gate; fix forward instead.
- **Committed work.** `git revert` the task's commits, then run
  `home-manager switch --flake .#benjamin` again. The next switch re-creates the top-level
  `mcpServers.sapience` entry and reasserts the seven grants and five hooks into the live
  `~/.claude/settings.json`, because `hooks` and `permissions` are enforced keys — so a revert
  restores the machine-wide arrangement without any manual repair of the live file.
- **Activation already applied, source not yet reverted.** `home-manager generations` lists the
  prior generation; activating it restores the previous `~/.claude/settings.json` and the
  `~/.claude.json` merge.
- **Partial landing is the dangerous state.** If the five hooks and seven grants are removed but
  the registration `SessionStart` entry is missing, per-project registration dies on the next
  switch and Sapience is off in every repository, including all four that load the extension. The
  immediate repair is to add the entry to `config/claude/settings.json` and switch again; the
  interim workaround is to re-run the companion's installer, which restores the entry to the live
  file until the next switch.
- **`~/.sapience/config.json` is never touched by this task**, so no rollback is owed for it. If
  the owner has already applied the Phase 5 instruction and wants it undone, the same `jq` shape
  with the original five-entry `folders` array and the original five `enabled: true` projects
  restores it; the pre-change values are recorded verbatim in Phase 5's record file.

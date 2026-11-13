# Live Verification (Post-Switch)

Every check below was run against the LIVE merged state after a real `home-manager switch`, not
against repository source. Observed output is recorded for each, as the plan requires.

## Gate set (scoped discharge — Batch Gate Deferral)

Per the dispatch's Batch Gate Deferral directive, the complete gate set
(`bash .claude/scripts/verify-deploy.sh` with no arguments, `bash .claude/scripts/tests/run-all.sh`
with no `--only`) is deferred to the batch stage and is NOT independently run here. The scoped
discharge covering this task's own touched files in this repository:

- `nix flake check` — authoritative for this repository's nix changes, not part of the deferred
  gate set, run directly: **all checks passed** (statix, deadnix, nixfmt --check, shellcheck,
  home-eval all green).
- `bash .claude/scripts/verify-deploy.sh --only-gate 4` (covers `modules/home/services/sapience.nix`,
  `docs/sapience.md`, `home.nix` — sub-case (c), deploy-consumer tree, no mapped suite): **PASS**
  — "task-reference lint reports no findings", gate 4 reported as run, not skipped.
- `bash .claude/scripts/tests/run-all.sh --only test-deploy-propagation.sh,test-gate-cache-equivalence.sh,test-gate-cache-lib.sh,test-gate-registry-resolution.sh,test-guard-git-push.sh,test-lint-hook-registration-paths.sh,test-sapience-mcp-registration.sh,test-verify-deploy-gate-selection.sh`
  (covers `config/claude/settings.json`): **5 passed, 3 failed (1 expected, 2 NEW)**.
  `test-sapience-mcp-registration.sh` — the suite the plan names as bearing directly on this
  phase's edit — **PASSED**. The two unexpected failures
  (`test-gate-registry-resolution.sh`, `test-lint-hook-registration-paths.sh`) are pre-existing
  and unrelated: neither subject script references Sapience, `config/claude/settings.json`, or
  `modules/home/services/sapience.nix`; `test-lint-hook-registration-paths.sh`'s failures all
  trace to a missing `lua/neotex/plugins/ai/shared/extensions/hook_identity_cli.lua` path that
  belongs to the nvim repository's own `lua/` tree, which does not exist in `.dotfiles` at all —
  a pre-existing cross-repo infrastructure mismatch, not something this task's edits touch.
  Recorded via `issue-record.sh` (class: "test infrastructure/pre-existing failure", severity
  minor).

## `home-manager switch`

`home-manager switch --flake .#benjamin` completed (exit 0). The activation log shows
`sapiencePayload` and `sapienceTokenRepair` ran; `sapienceMcpServer` did NOT run (confirming its
removal) and `claudeMcpServers`/`claudeSettings` ran as before. A batch of pre-existing, unrelated
`run-p*-i*.service` systemd units reported failed/degraded — these are leftover transient
`lean-comparator`/`landrun` sandbox runs from unrelated prior work, not Sapience-related, and are
not part of this repository's Sapience activation surface.

## Live `~/.claude/settings.json`

- `jq -r '.permissions.allow[] | select(startswith("mcp__sapience"))' ~/.claude/settings.json`
  → empty. The enforced-key merge correctly REMOVED the seven stale grants rather than leaving
  them additively in place.
- `jq -r '.hooks | keys[]' ~/.claude/settings.json` → exactly `SessionEnd`, `SessionStart`.
- `jq '.hooks.SessionStart | length'` → 3; `jq '.hooks.SessionEnd | length'` → 1.
- Registration command, byte-compared: live value is
  `bash $HOME/.claude/hooks/sapience-mcp-register-project.sh 2>/dev/null || echo '{}'` —
  byte-identical to the string Phase 1 extracted from the companion's installer. **This is
  acceptance criterion 8's defining check, and it passes.**
- The sleep-inhibitor entry (`SessionStart` first entry, `async: true`) and the lean-lsp entry
  (`SessionStart` second entry, `matcher: startup`) both survive unchanged. The `SessionEnd`
  inhibitor-cleanup entry survives as the sole remaining `SessionEnd` entry.
- `_SAPIENCE_NOTE` in the LIVE file still reads the PRE-edit text (verified: it is the old note,
  not the Phase 3 rewrite). This is EXPECTED, not a failed switch: `_SAPIENCE_NOTE` is not in the
  enforced-key set (`["_NOTE","env","hooks","model","permissions","statusLine"]`), so the live
  copy wins the merge and the repository source (confirmed rewritten in Phase 3) is the artifact
  acceptance criterion 5 is measured against, exactly as the plan's Research Integration section
  anticipated.

## Live `~/.claude.json`

- Before any cleanup, `jq -r '.mcpServers | keys[]'` returned `nixos`, `playwright`, **and
  `sapience`** — the top-level key did NOT disappear merely because its writer
  (`sapienceMcpServer`) was removed. Investigation confirmed: the activation entry only ever
  additively wrote `.mcpServers.sapience` into this plain mutable JSON file; `~/.claude.json`
  carries no enforced-key reset semantics (that mechanism is specific to
  `home.activation.claudeSettings` and `~/.claude/settings.json`). Removing the writer stops
  future writes; it does not retroactively erase an already-written value. This was not
  anticipated by the plan's Phase 6 task list, which treated this check as a pass-through
  assertion. Recorded via `issue-record.sh` (class: "plan verification gap", severity costly).
- **Fixed forward**: performed a one-time `jq 'del(.mcpServers.sapience)' ~/.claude.json`
  (atomic temp-file-plus-`mv`, `chmod u+w` restored), since the key's entire content was written
  by this repository's own now-removed activation entry — not owner-only state like
  `~/.sapience/config.json`. After the cleanup: `jq -r '.mcpServers | keys[]'` → exactly `nixos`,
  `playwright`. **Acceptance criterion 2 is now satisfied against the live file.**
- Full top-level key SET comparison against the Phase 1 baseline (sorted list diff via `comm`):
  **zero keys added, zero keys removed** — every other key in `~/.claude.json` is undisturbed,
  including `.projects` (its own sub-keys change only via the registration hook, as expected).
  (Phase 1's record stated a baseline count of "97 keys" in prose; the actual captured key list
  there was complete and matches the live set exactly byte-for-byte — the "97" figure in that
  record's prose was a miscount of the same correctly-enumerated list and does not affect this
  comparison's validity, which was performed against the full list, not the prose count.)

## Negative test (verified-unloaded repositories)

Ran `bash "$HOME/.claude/hooks/sapience-mcp-register-project.sh"` directly from each directory
(the same invocation a `SessionStart` hook performs) rather than starting an interactive
session:

- `/home/benjamin/Projects/cslib`: hook output `{}` (inert — no injected context), and
  `.projects["/home/benjamin/Projects/cslib"].mcpServers.sapience` is `null` afterward. No
  `.claude/settings.local.json` Sapience grants present.
- `/home/benjamin/Projects/Logos/Theory`: same result — `{}`, `null` registration entry.

Both confirm: no tools, no grants, no hook firing in a verified-unloaded repository.

## Positive test (extension-loaded repositories)

- `/home/benjamin/.dotfiles` (this repository): running the registration hook produced
  `{"additionalContext":"sapience: registered/repaired the per-project entry for
  /home/benjamin/.dotfiles. ..."}`, and `.projects["/home/benjamin/.dotfiles"].mcpServers.sapience`
  now holds the correct `{type, command, args, env}` shape with the live token. The repository's
  own `.claude/settings.local.json` carries all 11 `mcp__sapience__*` grants and all 5 Sapience
  hook commands (briefing-text, hook prompt, hook tool, receipt, effect-line).
- `/home/benjamin/.config/nvim`: spot-checked the deployed `.claude/settings.local.json` directly
  (11 grants, 5 hooks) — matches.
- `/home/benjamin/Projects/abood` and `/home/benjamin/Projects/Sapience/sapience-app`: spot-check
  found only 4 `mcp__sapience__*` grants and 0 Sapience hooks in their deployed
  `.claude/settings.local.json` — the PRE-companion grant count. Their own `.claude/` deploy has
  not been refreshed since the companion extension-side task (project 612) landed its
  `settings-fragment.json` update. This is a deploy-staleness gap in those two repositories' own
  deploy state, outside this task's edit-target list and `file_scope`
  (`modules/home/services/sapience.nix`, `config/claude/settings.json`, `docs/sapience.md`,
  `home.nix`, all in `.dotfiles`) — refreshing another repository's `.claude/` deploy is that
  repository's own action. Recorded via `issue-record.sh` (class: "deploy staleness in sibling
  repo", severity minor). The positive-test requirement is satisfied by `.dotfiles` and
  `.config/nvim`, both showing the full 11/5 set.

## SF-1 card worktree check

No worktree currently exists under `~/.local/state/sf1-hub-ben/hub/runner/work/` (directory
absent). Per the plan's fallback, the structural guarantee was established from the
repository-level check instead: `git ls-files .claude` in
`/home/benjamin/Projects/Sapience/sapience-app` returns empty (exit 0, no output) — `.claude/` is
untracked there, so a fresh worktree checked out from that repository's git history carries no
`.claude/` tree at all, and therefore no hooks and no grants, by construction. The absence of
repo-scoped retrieval tools in such a worktree is the known, deliberate gap named in
`records/03_nvim-sited-followups.md`, not a success condition.

## Review before commit

`git status --short` at this point shows exactly this task's own files
(`specs/138_retire_machine_wide_sapience_surface/**`) plus files from unrelated concurrent work
in this shared repository (`docs/sf1-hub.md`, `modules/home/services/sf1-hub-ben.nix`,
`specs/TODO.md`, `specs/state.json`, `notes/`, two `.agent-logs/` directories) that this task
does not touch and does not stage. The four edit-target files this task modifies
(`modules/home/services/sapience.nix`, `config/claude/settings.json`, `docs/sapience.md`,
`home.nix`) were already committed in Phases 2-4 and no longer show as modified. Nothing under
`packages/` and nothing in `modules/home/core/dotfiles.nix` was ever staged by this task.

## Acceptance criteria, addressed explicitly

1. `nix flake check` passes — confirmed above.
2. No machine-wide Sapience activation surface remains, confirmed against the LIVE merged files:
   grants and hooks gone from live `~/.claude/settings.json`; `mcpServers.sapience` gone from
   live `~/.claude.json` top level (after the one-time cleanup this phase performed and
   recorded). The registration `SessionStart` entry is the sole exception, covered by criterion 8.
3. Verified-unloaded repos get nothing; loaded repos keep the full set (demonstrated on
   `.dotfiles` and `.config/nvim`; `abood`/`sapience-app` have a recorded, out-of-scope deploy
   staleness gap). SF-1 card worktree: no worktree currently exists; the structural guarantee was
   confirmed via `git ls-files .claude`.
4. The `~/.sapience/config.json` owner instruction is recorded in
   `records/02_sapience-config-owner-instruction.md` (Phase 5), covering both keys with the
   sanctioned route named.
5. `docs/sapience.md` states the new contract with a correct hook count (5, not 3) and documents
   the registration entry; the rewritten `_SAPIENCE_NOTE` (confirmed in repository source;
   expected stale in the live file per the enforced-key asymmetry above) preserves the required
   rulings.
6. The ordering constraint was honored — see `records/01_companion-landing-confirmation.md`
   (Phase 1).
7. No task-number references or record-versioning language were introduced by this task's diff
   outside `specs/**` — confirmed via the Phase 4 greps and `verify-deploy.sh --only-gate 4`.
8. The registration entry is durable: confirmed byte-identical in the live file after the switch,
   and re-running the companion's installer afterward reported
   `(no-op) /home/benjamin/.claude/settings.json already has the sapience SessionStart hook`
   rather than double-registering.

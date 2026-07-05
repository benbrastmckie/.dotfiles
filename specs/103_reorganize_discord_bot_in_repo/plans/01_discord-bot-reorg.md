# Implementation Plan: Task #103

- **Task**: 103 - Reorganize the opencode-discord-bot in-repo (host-wiring fix + repo-root declutter)
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: None (follows task 89 packaging + task 86 module convention, both complete)
- **Research Inputs**: specs/103_reorganize_discord_bot_in_repo/reports/01_discord-bot-reorg-research.md
- **Artifacts**: plans/01_discord-bot-reorg.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Task 103 has two independent, mechanical goals against the Discord bot subsystem, both fully
grounded by research against live repo + host state. **Goal 1 (host-wiring drift)**: hamsa is
running `discord-bot.service`/`opencode-serve.service` on a stale pre-task-86/89 unit, yet
`hosts/hamsa/` has no `default.nix`, so `services.discordBot.enable` does not exist in hamsa's
tracked config -- the next `nixos-rebuild switch --flake .#hamsa` would silently kill both
services. The module `modules/system/optional/discord-bot.nix` is already host-agnostic, so the
fix is host wiring only: a new `hosts/hamsa/default.nix` mirroring `hosts/nandi/default.nix` plus
one `extraModules` line in `flake.nix`. Keep nandi enabled. **Goal 2 (repo-root declutter)**:
`git mv` the 14 tracked files under root `opencode-discord-bot/` to
`packages/opencode-discord-bot/` (co-located with `packages/opencode-discord-bot.nix`) and update
`src = ../opencode-discord-bot` -> `./opencode-discord-bot` at `packages/opencode-discord-bot.nix:27`.

Definition of done: `nix flake check` + `nixos-rebuild build --flake .#hamsa` pass on the updated
tree (the automatable inertness gate), all five docs reflect the new source path and host wiring,
and the user has a clearly documented MANUAL `sudo nixos-rebuild switch` + runtime-verification
step (sudo is sandbox-denied in agent context).

### Research Integration

Key findings integrated from `reports/01_discord-bot-reorg-research.md`:
- Module needs **no changes** -- goal 1 is purely a new `hosts/hamsa/default.nix` + one
  `flake.nix` line (confirmed: `hosts/nandi/default.nix` is a 2-line imports+enable pair;
  `flake.nix:132` currently reads `hamsa = mkHost { hostname = "hamsa"; };` with no `extraModules`).
- Goal 2 is a pure `git mv` of the whole directory + one `src =` line change
  (`packages/opencode-discord-bot.nix:27`) + two header-comment path mentions in the same file
  (lines 1, 7-8). `git ls-files opencode-discord-bot/` = 14 tracked entries (authoritative; the
  task's "16" counted untracked `__pycache__`/`data/sessions.json`).
- **No root `.gitignore` edit needed** -- the nested `opencode-discord-bot/.gitignore` moves with
  the directory and resolves relative to its new location. Untracked build artifacts
  (`data/sessions.json`, `__pycache__/**`) are gitignored and irrelevant to the Nix build; leave
  them alone.
- `packages/opencode-discord-bot.nix` file and `packages/opencode-discord-bot/` dir sharing a stem
  is NOT a filesystem/git conflict -- only a readability note worth one line in `packages/README.md`.
- Docs to touch: `docs/discord-bot.md`, `packages/README.md`, `modules/README.md`, `README.md`
  (tree diagram ~line 43) -- all 4 task-named -- plus `hosts/hamsa/README.md` (its line saying
  hamsa "does not currently have" a `default.nix` becomes stale once goal 1 lands; research flags
  it as the likely-missed fifth touch).
- Behavior delta on hamsa is intended and positive: the switch will replace the stale
  PYTHONPATH-based unit with the current packaged nix-store console-script unit.

### Prior Plan Reference

No prior plan. This is the first plan for task 103.

### Roadmap Alignment

No ROADMAP.md consulted for this run (no `--roadmap` flag / roadmap_path in delegation context).
Task advances the Discord bot infrastructure line begun in tasks 53/55/56/57/58/86/89.

## Goals & Non-Goals

**Goals**:
- Make `services.discordBot.enable` cleanly enableable on any host and enable it on hamsa so the
  tracked flake config matches the service actually running there.
- Keep nandi enabled (no evidence found to disable it).
- Relocate root `opencode-discord-bot/` (14 tracked files) to `packages/opencode-discord-bot/`,
  co-located with its derivation, and update the derivation `src`.
- Update all five docs to reflect the new source path and host wiring.
- Verify inertness via `nix flake check` + `nixos-rebuild build --flake .#hamsa`.
- Hand the user a documented MANUAL `sudo nixos-rebuild switch --flake .#hamsa` + runtime
  verification step.

**Non-Goals**:
- No changes to `modules/system/optional/discord-bot.nix` (already host-agnostic) -- its sops
  secrets, systemd wiring (opencode-serve + discord-bot, LoadCredential, StateDirectory,
  watchdog), and `../../../packages/opencode-discord-bot.nix` callPackage path all stay as-is.
- No extraction to a standalone flake-input repo (explicitly rejected by the task).
- No root `.gitignore` edits (nested ignore moves with the directory).
- No enablement on garuda/iso/usb-installer (out of scope).
- No `sudo nixos-rebuild switch` from the agent (sandbox-denied; documented as a manual step).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Live switch/runtime verification needs sudo (sandbox-denied) | M | H (certain) | Treat `nix flake check` + `nixos-rebuild build --flake .#hamsa` as the automatable gate; document the `sudo` switch + `systemctl`/`journalctl` checks as an explicit MANUAL user step (Phase 4). |
| `git mv` breaks the derivation `src` / `pythonImportsCheck` | H | L | Update `src = ./opencode-discord-bot` in the same phase as the move; verify by building the derivation / `nix flake check` before considering Phase 1 done. `pyproject.toml` + `pythonImportsCheck` are `src`-relative and need no change. |
| Untracked `__pycache__`/`data/sessions.json` create `git status` noise after move | L | M | Leave them alone (gitignored, build-irrelevant); confirm `git status` shows only the intended rename + edits before commit. |
| hamsa switch is behavior-changing (replaces stale PYTHONPATH unit with packaged unit) | M | H (intended) | Call out explicitly in the manual-step doc and summary as an expected, positive closure of the drift -- not a regression. |
| Doc references to old path missed | L | M | Phase 3 works from the research report's file/line table; `git grep opencode-discord-bot` (excluding historical `specs/**`) as a completeness check. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel (Phases 1 and 2 touch disjoint files). A
single agent executing sequentially should do Phase 1 (the move) before Phase 2 per the research
recommendation, so the Phase 4 combined build exercises both changes in one pass.

### Phase 1: Relocate source directory + update derivation src (Goal 2) [COMPLETED]

**Goal**: Move root `opencode-discord-bot/` to `packages/opencode-discord-bot/` and repoint the
derivation, with the Nix build still green.

**Tasks**:
- [x] `git mv opencode-discord-bot packages/opencode-discord-bot` (moves the 14 tracked files;
      the nested `.gitignore` and `data/.gitkeep` move with it).
- [x] Update `packages/opencode-discord-bot.nix:27`: `src = ../opencode-discord-bot;` ->
      `src = ./opencode-discord-bot;`.
- [x] Update the two header-comment path mentions in `packages/opencode-discord-bot.nix`
      (lines 1 and 7-8) that reference `../opencode-discord-bot` / `opencode-discord-bot/` prose.
- [x] Do NOT `git mv` untracked artifacts (`data/sessions.json`, `__pycache__/**`); leave them or
      let the plain filesystem move carry them -- either is harmless (gitignored, build-irrelevant).
- [x] Confirm `git status` shows only the intended renames + the one-file edit (no stray adds).

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `opencode-discord-bot/` -> `packages/opencode-discord-bot/` - directory relocation (14 tracked files)
- `packages/opencode-discord-bot.nix` - `src =` line 27 + header-comment path mentions (lines 1, 7-8)

**Verification**:
- `nix flake check` passes (no eval/syntax error from the moved `src`).
- Derivation builds and `pythonImportsCheck = [ "opencode_discord_bot" ]` still passes -- verify
  via `nix build .#nixosConfigurations.nandi.config.systemd.services` path or by building the
  package standalone (`nix-build`/`callPackage` in a `nix repl`) -- a cheap, sudo-free check.
- `git status --short` shows renames (`R`) for the 14 tracked files + `M` for
  `packages/opencode-discord-bot.nix` only.

---

### Phase 2: Wire discord bot into hamsa (Goal 1) [NOT STARTED]

**Goal**: Make `services.discordBot.enable` exist and be `true` for hamsa in the tracked config,
mirroring nandi; keep nandi enabled.

**Tasks**:
- [ ] Create `hosts/hamsa/default.nix` mirroring `hosts/nandi/default.nix`:
      `imports = [ ../../modules/system/optional/discord-bot.nix ]; services.discordBot.enable = true;`
      with a host-appropriate header comment.
- [ ] Add `extraModules = [ ./hosts/hamsa/default.nix ];` to the `hamsa = mkHost { ... };` call in
      `flake.nix` (currently `flake.nix:132` reads `hamsa = mkHost { hostname = "hamsa"; };`),
      matching nandi's `flake.nix:127-130` shape (multi-line `{ hostname = "hamsa"; extraModules = [...]; }`).
- [ ] Leave `hosts/nandi/default.nix` and its `flake.nix` entry unchanged (nandi stays enabled).
- [ ] Make no edits to `modules/system/optional/discord-bot.nix`.

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `hosts/hamsa/default.nix` - NEW file (imports module + enables the service)
- `flake.nix` - add `extraModules` line to the `hamsa` `mkHost` call (~line 132)

**Verification**:
- `nix eval .#nixosConfigurations.hamsa.config.services.discordBot.enable` returns `true`
  (previously errored "does not provide attribute").
- `nix eval .#nixosConfigurations.nandi.config.services.discordBot.enable` still returns `true`.
- `nix flake check` passes for all `nixosConfigurations`.

---

### Phase 3: Update documentation (both goals) [NOT STARTED]

**Goal**: Bring all five docs in line with the new source path and hamsa host wiring.

**Tasks**:
- [ ] `docs/discord-bot.md` - update prose references to `opencode-discord-bot/`,
      `../opencode-discord-bot`, `~/.dotfiles/opencode-discord-bot/` to the new
      `packages/opencode-discord-bot/` path (research lists lines 26-27, 36, 53, 62-63, 113, 269,
      308, 328, 406) and reflect that hamsa now runs the bot.
- [ ] `packages/README.md` - update the `opencode-discord-bot.nix` section (lines ~37-44) to the
      new `./opencode-discord-bot` src path, and add a one-line note explaining the
      `opencode-discord-bot.nix` file + `opencode-discord-bot/` dir stem pairing (first such
      co-located source dir in `packages/`).
- [ ] `modules/README.md` - update the host-wiring sentence so it no longer says hamsa does not
      import the module (hamsa is now wired in alongside nandi).
- [ ] `README.md` - update the tree diagram (~line 43): add a `packages/opencode-discord-bot/`
      child entry under the `packages/` subtree next to `opencode-discord-bot.nix`.
- [ ] `hosts/hamsa/README.md` - update the line noting hamsa "does not currently have" a
      `default.nix` (now stale after Phase 2).
- [ ] Completeness check: `git grep -n opencode-discord-bot` across the live tree (exclude
      historical `specs/**` artifacts) to confirm no stale live references remain.

**Timing**: 45 minutes

**Depends on**: 1, 2

**Files to modify**:
- `docs/discord-bot.md` - source path + hamsa wiring prose
- `packages/README.md` - src path + stem-pairing note
- `modules/README.md` - host-wiring sentence
- `README.md` - tree diagram entry (~line 43)
- `hosts/hamsa/README.md` - remove stale "no default.nix" line

**Verification**:
- `git grep -n "\.\./opencode-discord-bot\|~/.dotfiles/opencode-discord-bot" -- ':!specs/**'`
  returns no live-tree hits pointing at the old root path.
- `modules/README.md` and `hosts/hamsa/README.md` no longer claim hamsa lacks bot wiring.

---

### Phase 4: Inertness gate + manual switch handoff [NOT STARTED]

**Goal**: Prove the tree is internally consistent with both changes, and hand the user a precise
MANUAL runtime-verification procedure (sudo is sandbox-denied in agent context).

**Tasks**:
- [ ] Run `nix flake check` -- must pass for nandi/hamsa/garuda/iso + usb-installer.
- [ ] Run `nixos-rebuild build --flake .#hamsa` (build-only, no sudo) -- must succeed and produce a
      generation whose `discord-bot`/`opencode-serve` units use the packaged
      `${opencodeDiscordBot}/bin/opencode-discord-bot` console script (not the stale PYTHONPATH form).
- [ ] Document the MANUAL user step in the implementation summary (and, if appropriate, in
      `docs/discord-bot.md`): `sudo nixos-rebuild switch --flake .#hamsa`, then
      `systemctl status discord-bot opencode-serve` and `journalctl -u discord-bot -b` to confirm
      both services come back on the new packaged unit. Flag the expected, intended behavior delta
      (stale PYTHONPATH unit -> packaged console-script unit).
- [ ] Record that agent-side verification stops at the build gate; runtime confirmation is the
      user's responsibility.

**Timing**: 30 minutes

**Depends on**: 1, 2, 3

**Files to modify**:
- (verification only; optional note added to `docs/discord-bot.md` if not already covered in Phase 3)

**Verification**:
- `nix flake check` exit 0.
- `nixos-rebuild build --flake .#hamsa` exit 0.
- Manual step is written down with exact commands and the behavior-delta caveat.

## Testing & Validation

- [ ] `nix flake check` passes on the updated tree.
- [ ] `nixos-rebuild build --flake .#hamsa` succeeds (sudo-free build).
- [ ] `nix eval .#nixosConfigurations.hamsa.config.services.discordBot.enable` == `true`.
- [ ] `nix eval .#nixosConfigurations.nandi.config.services.discordBot.enable` == `true`.
- [ ] Discord bot derivation builds with the relocated `src` (`pythonImportsCheck` green).
- [ ] `git grep` confirms no stale live-tree references to the old `../opencode-discord-bot` path.
- [ ] All five docs updated; `hosts/hamsa/README.md` + `modules/README.md` no longer say hamsa
      lacks bot wiring.
- [ ] MANUAL `sudo nixos-rebuild switch` + `systemctl`/`journalctl` procedure is documented for
      the user (not executed by the agent).

## Artifacts & Outputs

- `packages/opencode-discord-bot/` - relocated source tree (14 tracked files)
- `packages/opencode-discord-bot.nix` - updated `src` + header comments
- `hosts/hamsa/default.nix` - NEW host wiring file
- `flake.nix` - hamsa `extraModules` entry
- `docs/discord-bot.md`, `packages/README.md`, `modules/README.md`, `README.md`,
  `hosts/hamsa/README.md` - updated docs
- `specs/103_reorganize_discord_bot_in_repo/summaries/01_discord-bot-reorg-summary.md` -
  implementation summary (includes the MANUAL switch/verify procedure for the user)

## Rollback/Contingency

- All changes are on tracked files in one branch; if the build gate (Phase 4) fails, fix forward
  (never discard uncommitted work per git-workflow.md). The `git mv` is reversible with an inverse
  `git mv packages/opencode-discord-bot opencode-discord-bot` + reverting the `src =` line.
- Because the agent never runs `nixos-rebuild switch`, no live hamsa state is mutated by
  implementation -- the running (stale) units stay up until the user performs the documented
  manual switch, so there is no window where the repo change alone breaks the host.
- If the user's manual switch misbehaves, `sudo nixos-rebuild switch --rollback` restores the
  prior generation.

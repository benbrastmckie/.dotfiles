# Implementation Summary: Task #103

**Completed**: 2026-07-05
**Duration**: ~1 hour

## Overview

Executed both goals of the Discord bot reorg plan against a live-verified tree: (1) fixed
host-wiring drift by giving hamsa a tracked `services.discordBot.enable = true` config that
matches the discord-bot/opencode-serve units already running there, and (2) decluttered the repo
root by relocating the 14 tracked files under `opencode-discord-bot/` to
`packages/opencode-discord-bot/`, co-located with its derivation. All four plan phases completed
and verified; `nandi` stays enabled and unchanged.

## What Changed

- `opencode-discord-bot/` -> `packages/opencode-discord-bot/` — `git mv` of all 14 tracked files
  (source package, `pyproject.toml`, nested `.gitignore`, `data/.gitkeep`).
- `packages/opencode-discord-bot.nix` — `src = ../opencode-discord-bot;` -> `src =
  ./opencode-discord-bot;`, plus header-comment path mentions (lines 1, 7-8).
- `hosts/hamsa/default.nix` — NEW file mirroring `hosts/nandi/default.nix`: imports
  `modules/system/optional/discord-bot.nix` and sets `services.discordBot.enable = true`.
- `flake.nix` — added `extraModules = [ ./hosts/hamsa/default.nix ];` to the `hamsa = mkHost
  { ... };` call (was previously a bare `mkHost { hostname = "hamsa"; };`).
- `docs/discord-bot.md` — updated all path references to the new `packages/opencode-discord-bot/`
  location; setup step 4 and troubleshooting/rollback/"Related Documentation" entries updated;
  noted hamsa now runs the bot alongside nandi.
- `packages/README.md` — updated `src` path reference; added a note explaining the
  `opencode-discord-bot.nix` file / `opencode-discord-bot/` directory stem pairing.
- `modules/README.md` — updated the host-wiring sentence to list both `hosts/nandi/default.nix`
  and `hosts/hamsa/default.nix`; `garuda`/`iso` still excluded.
- `README.md` — added a `packages/opencode-discord-bot/` child entry to the repo tree diagram.
- `hosts/hamsa/README.md` — replaced the stale "hamsa does not currently have a `default.nix`"
  line with a description of the new file and what it enables.
- `modules/system/optional/discord-bot.nix` — comment-only fix (lines 3, 32): updated a stale
  root-path reference (`~/.dotfiles/opencode-discord-bot/...`) surfaced by the Phase 3
  completeness-check grep, plus mentioned `hosts/hamsa/default.nix` alongside nandi's. No
  functional change — sops config, systemd units, and the `callPackage` path are untouched.

## Decisions

- Kept the relocation target at `packages/opencode-discord-bot/` (co-located with
  `packages/opencode-discord-bot.nix`) per the plan's research — confirmed this file/directory
  stem pairing is not a git or filesystem conflict, just a readability note now documented in
  `packages/README.md`.
- Left `modules/system/optional/discord-bot.nix`'s functional structure (sops secrets, systemd
  units, `callPackage` path) entirely untouched, per the plan's non-goal — only touched two
  comment lines to close out a stale-reference hit from the completeness-check grep.
- No root `.gitignore` changes — the nested `opencode-discord-bot/.gitignore` moved with the
  directory and resolves correctly at its new location.

## Plan Deviations

- **Phase 3, completeness-check task** altered: in addition to the five docs the plan named, also
  fixed a stale root-path comment (lines 3, 32) in `modules/system/optional/discord-bot.nix` that
  the `git grep` completeness check surfaced. This is a comment-only edit — no change to the
  module's sops/systemd/callPackage structure, consistent with the plan's non-goal for that file.

No other deviations; all four phases executed as planned.

## Verification

- `nix flake check`: **Success** (all NixOS configurations — nandi, hamsa, garuda, iso,
  usb-installer — plus formatter/devShells outputs evaluate cleanly).
- `nix eval .#nixosConfigurations.hamsa.config.services.discordBot.enable`: **true** (previously
  errored "does not provide attribute").
- `nix eval .#nixosConfigurations.nandi.config.services.discordBot.enable`: **true** (unchanged).
- `nixos-rebuild build --flake .#hamsa`: **Success** — built
  `/nix/store/bshfpc03x2r3zyaawwxw01vr6b0gdndw-nixos-system-hamsa-26.05.20260622.3426825`.
  Inspected the generated `discord-bot.service` unit:
  `ExecStart=/nix/store/fi6z2vi7a5s17c5rv039yxcihfhv7lin-opencode-discord-bot-0.1.0/bin/opencode-discord-bot`
  — confirms the packaged nix-store console-script unit, not the stale PYTHONPATH form.
- `git grep -n "\.\./opencode-discord-bot\|~/.dotfiles/opencode-discord-bot" -- ':!specs/**'`:
  **zero hits** — no stale live-tree references to the old root path remain.
- `git status --short` after Phase 1: showed only the 14 intended renames (`R`) plus the one
  `packages/opencode-discord-bot.nix` edit (`M`) — no stray adds from untracked
  `__pycache__`/`data/sessions.json` artifacts.

## MANUAL User Step (NOT executed by the agent — sudo is sandbox-denied)

The agent-side gate stops at `nixos-rebuild build`. To actually apply this on hamsa and confirm
runtime behavior, run the following **as the user, on hamsa**:

```bash
# 1. Apply the new generation (replaces the stale PYTHONPATH-based unit with the
#    packaged nix-store console-script unit built above — this is the expected,
#    intended behavior delta, not a regression).
sudo nixos-rebuild switch --flake .#hamsa

# 2. Confirm both services come back up on the new unit.
systemctl status discord-bot opencode-serve

# 3. Tail logs to confirm clean startup (Discord connect, OpenCode server bind).
journalctl -u discord-bot -b
journalctl -u opencode-serve -b

# 4. Spot-check the running unit's ExecStart resolves to the packaged store path
#    (not a working-tree PYTHONPATH invocation):
systemctl cat discord-bot | grep ExecStart
```

**Expected behavior delta**: hamsa's `discord-bot`/`opencode-serve` units switch from whatever
pre-task-86/89 ad-hoc PYTHONPATH-based invocation was previously running to the current packaged
`buildPythonApplication` console-script unit. This is the intended closure of the host-wiring
drift this task set out to fix, not a regression — if `systemctl status` shows both services
`active (running)` and logs show normal startup (Discord gateway connect, OpenCode server bind on
`127.0.0.1:4096`), the switch succeeded.

If anything misbehaves, `sudo nixos-rebuild switch --rollback` restores the prior generation
(no repo changes are required to roll back — this task never mutated live hamsa state).

## Notes

- No changes were needed to `modules/system/optional/discord-bot.nix`'s functional
  configuration — it was already host-agnostic, confirming the research's characterization of
  this as a pure host-wiring + relocation task.
- `packages/opencode-discord-bot/data/sessions.json` and `__pycache__/**` directories remain
  present but untracked (gitignored) at the new location — harmless, build-irrelevant runtime
  artifacts that moved along with the plain filesystem `git mv`.

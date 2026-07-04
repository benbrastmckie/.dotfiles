# Research Report: Repository Organization Review (Seed)

**Task**: 81 — Design and orchestrate a systematic reorganization of the NixOS/Home Manager dotfiles repository
**Date**: 2026-07-04
**Type**: Seed research report (comprehensive repo review conducted at task creation)
**Scope**: Every top-level directory and loose root file; cross-referenced against actual imports/usage in `*.nix`.

## Context

Task 66 (2026-06-24) completed a semantically-inert modular refactor: `configuration.nix`
went from 954 to 31 lines and `home.nix` from 1680 to 64 lines, with logic moved into
`modules/system/`, `modules/home/`, `overlays/`, `lib/`, and `hosts/`. This task is the
follow-up: directory-level reorganization, dead-code removal, documentation sync, and
convention decisions for everything that refactor left in place. Related open tasks:
**69** (consolidate dual home-manager config — flagged in `docs/dual-home-manager.md`),
**68** (broken zfs-kernel blocks iso/usb-installer builds), **67** (migrate R env to stable).

## Findings by Directory

### modules/ — LIVE, well-factored, but convention gaps

43 files, all with good header comments (many citing their governing spec task).
No `default.nix` aggregator anywhere; imports are two hand-maintained flat lists:
`configuration.nix:12-26` (system) and `home.nix:9-51` (home, grouped by comment banners).

Issues:
- **`modules/opencode.nix` is dead AND broken**: never imported, and its
  `default = ../../config/opencode.json` (line 21) resolves above the repo root.
- **`modules/home/services/gmail-oauth2.nix`** is imported (home.nix:46) but its entire
  body is commented out — evaluates to `{}` (kept deliberately as a one-block revert).
- **Style: zero active modules use the options pattern.** Only dead `opencode.nix` uses
  `mkOption`/`mkEnableOption`. This contradicts the repo's own `.claude/rules/nix.md`
  (options + `mkIf cfg.enable` pattern, uniform `{ config, lib, pkgs, ... }:` signature).
  A decision is needed: adopt options pattern (at least for optional modules), or amend
  the rule to bless plain config sets for this repo.
- **`modules/system/optional/discord-bot.nix`** is imported unconditionally by
  `configuration.nix` despite the `optional/` naming — every host gets it. No per-host
  module selection exists even though `hosts/*/default.nix` is the natural place.
- **Size outliers**: `modules/home/email/agent-tools.nix` (761 lines, 5 wrapper binaries —
  split candidate), `mbsync.nix` (310), `aerc.nix` (273), `system/packages.nix` (228).
- **Tiny fragments** (merge candidates): `packages/fonts.nix` (8), `packages/lean-math.nix`
  (8), `packages/ai-tools.nix` (10), `email/protonmail.nix` (9), `core/git.nix` (10),
  `system/users.nix` (13), `desktop/mako.nix` (16), `system/shell.nix` (17). The memory
  system is split across `scripts/memory-monitor.nix` + `services/memory-services.nix`.
- **No README at any level inside modules/** — the system/home split, the no-aggregator
  convention, and the meaning of `optional/` are undocumented.

Out-of-tree references (coupling map, all confirmed):
- `home/core/shell.nix` → 17 references into `../../../config/` (lines 21-57)
- `system/desktop.nix:33` → `../../wallpapers/riverside.jpg`
- `system/optional/discord-bot.nix:25` → `../../../secrets/secrets.yaml`
- `system/optional/discord-bot.nix:105` → runtime `PYTHONPATH=~/.dotfiles/opencode-discord-bot`
- `system/shell.nix:12-13` → runtime `/run/secrets/link_api_token`

### home-modules/ — DEAD (delete)

2 files: `mcp-hub.nix` (HM module for mcp-hub, superseded by lazy.nvim approach) and a
README that itself admits it is unused. Sole reference is the commented-out import at
`home.nix:6`. No duplication with `modules/home/`. Safe to delete the directory plus the
comment line, plus two stale comments that reference the old feature:
`modules/home/core/shell.nix:8` and `modules/home/packages/email-tools.nix:38`.

### config/ — LIVE (one dead file); naming collision with Nix `config`

14 root files + `config/claude/` (2) + `config/sioyek/` (2) + README. All deployed from
`modules/home/core/shell.nix` via three mechanisms:
1. `home.file.*.source` store symlinks (fastfetch, opencode, sioyek, niri, fish, kitty,
   zathura, alacritty, wezterm, himalaya, tmux, latexmkrc, zuliprc);
2. `builtins.readFile` copies mirrored into `~/.config/config-files/`;
3. an activation script `cp` for `config/claude/{settings,keybindings}.json` into
   `~/.claude/` (deliberately writable — cannot be store symlinks).

Dead: **`config/rclone.conf`** (unreferenced; listed in .gitignore as a secret — verify
whether the tracked copy should exist at all).
Design question for the refactor: `config/` (raw dotfiles) vs `modules/` (nix) is a
sound split, but the directory name shadows the ubiquitous Nix `config` argument and its
deployment logic is buried in `shell.nix` (a misnomer — it manages far more than shell).

### hosts/ — LIVE but inconsistent

All four hosts' `hardware-configuration.nix` are loaded via `lib/mkHost.nix:31`. Inconsistencies:
- `garuda/default.nix` is an **empty placeholder** yet explicitly passed via
  `extraModules` (flake.nix:113); nandi/hamsa have no `default.nix` at all and work fine.
- `hamsa/` lacks a README; `usb-installer/default.nix` is the only substantive host module.
- `hosts/README.md:28-37` documents an **obsolete pattern** (inline `nixosSystem`) that
  predates the `mkHost` factory.
Decision needed: standardize on every host having a (possibly empty) `default.nix`
auto-imported by mkHost, or none unless needed.

### lib/ — LIVE, minimal, correct

Single file `mkHost.nix`, used by all four mkHost hosts (flake.nix:93). The `iso` config
(flake.nix:118-175) deliberately bypasses it and carries ~60 lines of inline module —
a candidate for extraction to `hosts/iso/` for symmetry.

### overlays/ — LIVE, clean

All three overlays (`claude-squad`, `unstable-packages` [curried], `python-packages`)
imported at flake.nix:57-60 and applied at :70-74. No dead overlays.

### packages/ — mostly LIVE; two orphans

12 packages wired via the two overlays. Orphans:
- **`packages/neovim.nix`** — `wrapNeovimUnstable` derivation, referenced nowhere. Dead.
- **`packages/test-mcphub.sh`** — stale test script for the already-removed MCPHub overlay.
- `packages/README.md` (12.9 KB) exists but see README drift below.

### secrets/ — LIVE, correctly wired

`secrets/secrets.yaml` (sops-encrypted) + root `.sops.yaml` (one age recipient, rule
scoping `secrets/*.yaml`). Consumed by `modules/system/optional/discord-bot.nix:25-95`
and read at runtime by `modules/system/shell.nix:12-13`. No changes needed beyond
possibly relocating `.sops.yaml` documentation.

### wallpapers/ — one live asset + 5 cruft files

`riverside.jpg` (~1.1 MB) is used (`modules/system/desktop.nix:23-33`,
`modules/home/desktop/gnome.nix:45-52`). Cruft: `IMPLEMENTATION_COMPLETE.md`, `README.md`,
`SETUP_INSTRUCTIONS.md`, `verify-setup.sh`, `SAVE_IMAGE_HERE.txt` — leftover scaffolding
from when the image was being added. Consider a general `assets/` directory if more
static assets are anticipated.

### opencode-discord-bot/ — structurally misplaced (worst-of-both-worlds)

2,392 lines of Python (Nextcord bot relaying to OpenCode serve) with **no packaging
metadata** (no pyproject/setup/requirements, no own git repo). Not built by nix: the
systemd unit in `discord-bot.nix` runs `python -m opencode_discord_bot.src.bot` with
`PYTHONPATH=~/.dotfiles/opencode-discord-bot` (line 105) — the service imports live
working-tree source. Untracked runtime files (`data/sessions.json`, `__pycache__/`) mix
with tracked source. Minor drift: comment at `discord-bot.nix:20` cites `opencode-discord-bot/src/bot.py`
but the real path is `opencode_discord_bot/src/bot.py`.
Two coherent destinations: (a) package as `buildPythonApplication` with a `pyproject.toml`
(under `packages/`), service runs from the nix store; or (b) extract to its own repo,
consume as a flake input. Current state is neither.

### Root files

| File | Verdict |
|------|---------|
| `configuration.nix` | LIVE — shared system entrypoint, injected by `mkHost.nix:30` AND imported directly by iso path (flake.nix:121). Could move to `hosts/common.nix` or `modules/system/default.nix` in a reorg. |
| `home.nix` | LIVE — HM entrypoint (flake.nix:135,197; mkHost.nix:44). Clean aggregator; stale bits: commented mcp-hub import (:6), fish/OMF comments (:59-60), old stateVersion lines (:63-64). |
| `update.sh` | LIVE, canonical (referenced by README, docs/testing.md). Cosmetic: mangled shebang `#\!/bin/bash` and `complete\!` from a heredoc write. |
| `install.sh` | Valid bootstrap, unreferenced by docs. Keep; consider a `scripts/` dir. |
| `build-usb-installer.sh` | LIVE (docs/usb-installer.md). Same `scripts/` candidate. |
| `test-sasl.sh` | Orphaned one-off diagnostic. Remove. |
| `test-update.md` | Stale point-in-time `.claude/` diff report (2026-04-14), unrelated to nix. Remove. |
| `TODO.md` (root) | Polluted/abandoned (stale checklist + joke text + stray dd snippet); superseded by `specs/TODO.md`. Remove. |
| `opencode.json` | Tracked file pointing at now-gitignored `.opencode/agent/...` prompts — internally inconsistent. Relocate or remove with the agent tooling. |
| `.sops.yaml`, `.gitignore` | LIVE and correct. Gap: `specs/tmp/` not ignored (see below). |

### Documentation drift

- **Root `README.md` is structurally stale**: its Module Map (lines 28-84) still labels
  `overlays/`, `lib/`, `modules/system/` as "(planned: task 66 Phase 2/3/4)" though task 66
  completed; its `packages/` listing omits `neovim.nix`, `piper-bin.nix`, `piper-voices.nix`.
- **`docs/README.md` index is incomplete**: `dual-home-manager.md`, `email-workflow.md`,
  `how-to-add-package.md`, `how-to-add-service.md`, `gnome-settings.md`, `video-editing.md`
  exist on disk but are unlisted.
- `hosts/README.md` documents the pre-mkHost pattern.
- No `modules/README.md` at all.

### Git hygiene

`specs/tmp/claude-tts-notify.log`, `specs/tmp/claude-tts-last-notify`, and `specs/tmp/lit.md`
are **tracked** runtime/scratch files that mutate constantly and perpetually dirty the tree.
Fix: `git rm --cached specs/tmp/*` + add `specs/tmp/` to `.gitignore`.

## Candidate Subtask Decomposition (for the design phase to refine)

Ordered roughly by independence and risk (1-4 are near-zero-risk deletions/hygiene;
5+ require design decisions). Each should get its own seed research report extracted
from the sections above, and each nix-touching task must verify inertness via
`nix flake check` + `nixos-rebuild build --flake .#nandi/.#hamsa` +
`nix build .#homeConfigurations.benjamin.activationPackage` (the task-66 harness).

1. **Dead code removal**: `home-modules/` (+ `home.nix:6` comment + 2 stale comments),
   `modules/opencode.nix`, `packages/neovim.nix`, `packages/test-mcphub.sh`,
   `config/rclone.conf` (verify), wallpapers scaffolding (5 files), `test-sasl.sh`,
   `test-update.md`, root `TODO.md`, stale comments in `home.nix`.
2. **Git hygiene**: untrack `specs/tmp/*`, extend `.gitignore`; fix `update.sh` shebang.
3. **Documentation sync**: root README Module Map + package list, `docs/README.md` index,
   `hosts/README.md` mkHost pattern, add `modules/README.md` (+ per-subdir conventions).
4. **Root shell scripts**: decide `scripts/` directory for `install.sh`, `update.sh`,
   `build-usb-installer.sh`; update doc references.
5. **hosts/ standardization**: uniform per-host `default.nix` convention (auto-import via
   mkHost or drop garuda's placeholder), extract iso inline config to `hosts/iso/`,
   decide whether `configuration.nix`/`home.nix` move under `hosts/common/` or stay at root.
6. **Module granularity pass**: split `agent-tools.nix` (761 lines), merge tiny fragments,
   co-locate memory scripts+services, rename/split `home/core/shell.nix` (it deploys all
   of `config/`, not shell config).
7. **Module convention decision**: options pattern vs plain config sets; make
   `optional/discord-bot.nix` actually optional (per-host opt-in); align or amend
   `.claude/rules/nix.md`.
8. **opencode-discord-bot packaging**: add `pyproject.toml`, package via
   `buildPythonApplication` (or extract to own repo + flake input); run service from the
   nix store instead of `PYTHONPATH` into the working tree; resolve `opencode.json`.
9. **config/ deployment clarity**: dedicated module (e.g. `modules/home/core/dotfiles.nix`)
   documenting the three deployment mechanisms; optionally rename `config/` → `dotfiles/`
   or `configs/` to avoid shadowing the Nix `config` argument (touch-everything rename —
   weigh cost/benefit).

Cross-cutting constraint: tasks 68 (zfs installer), 69 (dual home-manager), and 67 are
adjacent — the design should sequence around them, not duplicate them.

## Verification Baseline

All reorganization subtasks should reuse the task-66 behavioral-equivalence harness:
`nix store diff-closures` against pre-change baseline for nandi, hamsa, and standalone
home; iso/usb-installer excluded until task 68 lands.

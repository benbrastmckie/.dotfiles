# Implementation Summary: Task #86

**Completed**: 2026-07-05
**Duration**: ~1 hour

## Overview

Adopted the two-tier NixOS module convention (always-on aggregators vs. optional/host-toggled
modules) and made the Discord bot a genuine per-host opt-in. Root cause fixed: `configuration.nix`
previously imported `modules/system/optional/discord-bot.nix` unconditionally, so every
`nixosConfigurations` host (nandi, hamsa, garuda, iso, usb-installer) silently ran the bot. Now
only `nandi` opts in explicitly via `hosts/nandi/default.nix` + `extraModules` in `flake.nix`.

## What Changed

- `.claude/rules/nix.md` — added "Always-On Modules" and "Optional / Host-Toggled Modules"
  scoping subsections to the Module Patterns section (additive only; existing code samples
  relabeled, not rewritten). This file is gitignored in this repo, so the edit is on disk but
  not git-tracked.
- `modules/system/default.nix` (new) — aggregator for the 11 always-on system modules, explicitly
  excluding `optional/discord-bot.nix`.
- `modules/home/default.nix` (new) — aggregator for all 31 home-manager modules (order and
  comment-delimited groups preserved).
- `configuration.nix` — collapsed to `imports = [ ./modules/system ];` plus unchanged
  `system.stateVersion`.
- `home.nix` — collapsed to `imports = [ ./modules/home ];`, preserving `home.username`,
  `home.homeDirectory`, `home.stateVersion`.
- `modules/system/optional/discord-bot.nix` — added the missing `lib` function arg,
  `options.services.discordBot.enable` (`lib.mkEnableOption`), a `cfg` binding, and wrapped the
  existing `sops` + `systemd.services` blocks in `config = lib.mkIf cfg.enable { ... };`. Service
  internals (PYTHONPATH, secrets path) are unchanged (task 89 scope).
- `hosts/nandi/default.nix` (new) — imports `optional/discord-bot.nix` and sets
  `services.discordBot.enable = true`.
- `flake.nix` — added `extraModules = [ ./hosts/nandi/default.nix ]` to nandi's `mkHost` call;
  collapsed garuda's `mkHost` call (no longer needs `extraModules`); `hamsa` unchanged (its
  absence of `extraModules` is what drops the bot).
- `hosts/garuda/default.nix` — deleted (`git rm`); was an empty placeholder only used for the
  now-removed `extraModules` wiring.
- `docs/discord-bot.md` — file table (lines 25-26) now names
  `modules/system/optional/discord-bot.nix` and describes explicit per-host opt-in instead of
  "module import on all 4 hosts".
- `docs/dual-home-manager.md` — rewrote the `extraSpecialArgs divergence` paragraph (lines 31-33)
  to describe the actual, intentional `lectic` value divergence between the NixOS-integrated and
  standalone home-manager paths (citing `flake.nix:199-207`'s comment) instead of claiming full
  unification. Closes out task 69's documentation correction; the Option-A recommendation
  (lines 60-67) is unchanged.

## Decisions

- Single `services.discordBot.enable` option gates both `opencode-serve` and `discord-bot`
  systemd services (per plan; no split into two options).
- Reused the existing garuda `extraModules` shape for nandi's opt-in rather than introducing a
  new auto-discovery mechanism.
- Left `modules/README.md`, root `README.md` Module Map, and `hosts/README.md` untouched
  (deferred to tasks 91/87 per the plan's tier boundary).

## Plan Deviations

- Phase 2: home aggregator has 31 entries, not the plan's estimated 27 — a corrected count, not
  a scope change (confirmed 1:1 match against the pre-change `home.nix` list).
- Phase 6: staging was performed incrementally per phase-commit rather than as one batch at
  Phase 6 (functionally equivalent; every path was committed before verification ran).
  `.claude/rules/nix.md` could not be staged/committed because it is gitignored in this repo
  (`/.claude/` in `.gitignore`) — the edit is on disk but outside git's purview here.
- Phase 6: the `sudo nixos-rebuild switch --flake .#hamsa` live-switch step and its post-switch
  `systemctl`/`journalctl` re-check were **not performed** — `sudo` is hard-denied by this agent's
  execution sandbox (confirmed denied even with `dangerouslyDisableSandbox`), and an agent cannot
  self-authorize bypassing that permission gate. This is the one incomplete verification item;
  everything else in Phase 6 is green. See "Verification" and "Outstanding Manual Step" below.

## Verification

- `nix flake check`: **Success** (only the two pre-existing `boot.zfs.forceImportRoot` warnings
  on garuda/usb-installer, matching baseline).
- Cross-build `nixos-rebuild build --flake .#nandi`: **Success**. Closure inspection
  (`nix-store -qR | grep nextcord`) confirms `python3.13-nextcord-3.2.0` **present**.
- Cross-build `nixos-rebuild build --flake .#hamsa`: **Success**. Closure inspection confirms
  `nextcord` **absent** (0 matches).
- Cross-build `nixos-rebuild build --flake .#garuda`: **Success**. Closure inspection confirms
  `nextcord` **absent** (0 matches).
- HM activation build (`nix build .#homeConfigurations.benjamin.activationPackage`): **Success**.
- hamsa live `switch` + `systemctl`/`journalctl`: **Not performed** — blocked by sandbox `sudo`
  denial (see Plan Deviations). Pre-switch baseline captured instead: both
  `discord-bot.service` and `opencode-serve.service` are currently `active (running)` on hamsa
  (`discord-bot.service` since 2026-06-30 09:40:25 PDT — the pre-existing asyncio crash-loop
  documented in research; this task removes an unintended service, it does not fix that bug).
- `iso` and `usb-installer` were not cross-built (excluded from the build harness per plan,
  "not reliably buildable"); both also lose the bot as an intended, desirable side effect of the
  aggregator refactor (they only ever got it via `configuration.nix`'s prior unconditional
  import, which no longer exists).

## Outstanding Manual Step

To fully close out Phase 6's runtime verification on this machine (hamsa), a human with sudo
access should run:

```bash
sudo nixos-rebuild switch --flake .#hamsa
systemctl status discord-bot.service opencode-serve.service   # expect not-found/inactive
journalctl -u discord-bot.service -n 20                        # expect no new activity
```

nandi cannot be runtime-verified from hamsa (not reachable); its behavior change is already
confirmed via cross-build + closure inspection above, which is the plan's sanctioned method for
the unreachable host.

## Notes

- Non-goal (per plan): the pre-existing `discord-bot.service` asyncio crash-loop on hamsa is
  unrelated to this task and was not touched. Removing the service from hamsa's default closure
  resolves the symptom only as a side effect of it no longer being installed by default, not as a
  fix to the underlying bug.
- Behavior change confirmed at BUILD level: nandi keeps the bot; hamsa and garuda legitimately
  lose it; iso and usb-installer also legitimately lose it (not independently build-verified, but
  structurally guaranteed by the aggregator excluding the optional module and neither host having
  an `extraModules` opt-in).

# Modules

This directory holds the two module trees that drive the repository's Nix configuration:
`system/` for NixOS (`configuration.nix`) and `home/` for Home Manager (`home.nix`). The split
mirrors the same System Configuration / User Environment distinction described in the root
[`README.md`](../README.md#overview): `system/` is "what the machine provides", `home/` is "what
the user's session looks like".

## The system/ + home/ split

```
modules/
├── system/     # NixOS modules — always-on system config + optional/ (host-toggled)
└── home/       # Home Manager modules — always-on user config, grouped by category
```

Both subtrees follow the same aggregator convention (below): a `default.nix` per subtree imports
every always-on module in that subtree, and hosts/profiles wire the subtree in as a single unit
rather than importing individual module files directly.

## The aggregator convention (task 86)

Each subtree has one `default.nix` that lists its always-on modules as `imports`, grouped and
commented by category. This is a real convention already documented in the files themselves —
read the header comments directly rather than treating this README as a paraphrase:

- **`modules/system/default.nix`**: states the always-on/optional split explicitly in its header
  comment — "Optional/host-toggled modules (e.g. `optional/discord-bot.nix`) are deliberately NOT
  imported here — they are opt-in per host via `hosts/<name>/default.nix` + `extraModules` in
  `flake.nix`." It imports 12 flat files (`boot.nix networking.nix locale.nix desktop.nix
  services.nix audio.nix power.nix users.nix nix.nix display.nix packages.nix shell.nix`) and
  nothing from `optional/`.
- **`modules/home/default.nix`**: imports are grouped by inline section comments already present
  in the file — Core, Desktop, Email, Packages, Scripts, Services, Memory, plus the top-level
  `misc.nix` — one import per module (or, for `email/agent-tools`, one import for the whole
  directory, which itself has its own `default.nix`).

When adding a new always-on module, add exactly one import line to the relevant `default.nix`
under its category's comment block; do not wire new always-on modules directly into
`configuration.nix`/`home.nix` or into a host's `default.nix`.

## Always-on vs. optional

Most modules in both subtrees are **always-on**: plain attribute sets with no `options`/`mkIf`,
imported unconditionally by their subtree's `default.nix` aggregator. A module only needs the
optional/host-toggled pattern (`options.<path>.enable` + `config = lib.mkIf cfg.enable { ... }`)
when it should apply to some hosts but not others.

`modules/system/optional/` is the current home for that pattern, and today it contains exactly
one file: `discord-bot.nix`. It defines `options.services.discordBot.enable` (an
`mkEnableOption`) and gates its entire `config` block under `lib.mkIf cfg.enable`. It is
deliberately excluded from `modules/system/default.nix` and wired in explicitly per host:
`hosts/nandi/default.nix` and `hosts/hamsa/default.nix` each import it and set
`services.discordBot.enable = true;`, and `flake.nix`'s `extraModules` for the `nandi` and
`hamsa` `mkHost` calls carry it through; `garuda` and `iso` do not import it and so never
evaluate it.

**There is no `modules/home/optional/` yet.** The optional/host-toggled convention currently
exists on the system side only — do not assume Home Manager modules have an equivalent opt-in
mechanism until one is actually introduced.

For the full policy on when and how to write an optional module (including the required NixOS
and Home Manager option-structure templates), see `.claude/rules/nix.md`'s "Optional /
Host-Toggled Modules" section — that is the authoritative source; this README only summarizes the
concrete example already present in this tree.

## Per-subdirectory index

**`system/`** — 12 always-on flat files (`boot.nix`, `networking.nix`, `locale.nix`,
`desktop.nix`, `services.nix`, `audio.nix`, `power.nix`, `users.nix`, `nix.nix`, `display.nix`,
`packages.nix`, `shell.nix`) plus `default.nix` (the aggregator) plus `optional/` (see above).

**`home/`** — `default.nix` (the aggregator) plus:
- `core/` — `dotfiles.nix`, `git.nix`, `neovim.nix`, `xdg.nix`
- `desktop/` — `gnome.nix`, `kanshi.nix`, `mako.nix`, `swaylock.nix`, `waybar.nix`
- `email/` — `aerc.nix`, `mbsync.nix`, `notmuch.nix`, `protonmail.nix`, plus `agent-tools/`
  (`census.nix`, `classify.nix`, `archive-confirmed.nix`, `delete-confirmed.nix`,
  `unsubscribe-extract.nix`, `lib.nix`, its own `default.nix`)
- `memory/` — `monitor.nix`, `services.nix`
- `packages/` — `dev-tools.nix`, `email-tools.nix`, `media-dictation.nix`, `misc.nix`,
  `python.nix`
- `scripts/` — `gmail-oauth2.nix`, `sioyek-theme.nix`, `whisper.nix`
- `services/` — `cache-cleanup.nix`, `gmail-oauth2.nix`, `screenshot.nix`, `ydotool.nix`
- `misc.nix` — top-level miscellaneous settings (activation, autoExpire, sessionVariables,
  startServices)

## Verified Health Notes

These are one-line "checked, no action needed" records from task 91's final regression pass, so a
future verification pass does not have to rediscover them as false positives:

- **`flake.lock`**: schema `version: 7`, 26 nodes total, including multiple nixpkgs-family pins
  (`nixpkgs`, `nixpkgs_2`, `nixpkgs-old`, `nixpkgs-older`, `nixpkgs-unstable`) and transitive
  `systems`/`utils` duplicates pulled in by independently-versioned flake inputs (e.g. `lean4`,
  `niri`, `nix-ai-tools` each pin their own `nixpkgs` transitively). This is expected transitive
  duplication, not lock corruption or an unintended duplicate — checked, no action needed.
- **`stateVersion`**: `system.stateVersion = "24.11";` in `configuration.nix` and
  `home.stateVersion = "24.11";` in `home.nix` — matched, frozen since original install per the
  standard NixOS/Home Manager convention (never bump an existing `stateVersion` to "update"; it is
  a compatibility marker, not a version pin). No system/home-manager skew — checked, no action
  needed.

[← Back to main README](../README.md)

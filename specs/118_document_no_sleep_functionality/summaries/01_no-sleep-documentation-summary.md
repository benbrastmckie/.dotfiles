# Implementation Summary: Task #118

**Completed**: 2026-07-14
**Duration**: ~1.5 hours

## Overview

Created a single consolidated user-facing documentation page, `docs/no-sleep-agents.md`,
explaining the four layered mechanisms that keep the system awake for long-running AI agent
sessions (Claude Code session inhibitors, GNOME/logind settings, the niri swayidle equivalent,
and the battery-level suspend backstop). Trimmed the pre-existing partial coverage in
`docs/gnome-settings.md` and `docs/niri.md` to avoid duplication, and wired the new page into
the repository's documented cross-reference conventions (README index entry plus nix comment
trailers). No configuration behavior was changed — this was a pure documentation task built on
already-implemented functionality.

## What Changed

- `docs/no-sleep-agents.md` — new consolidated page covering all four mechanisms, a
  composed-scenario table, a command-based activation/verification checklist, and a
  "why not just X" rejected-alternatives section.
- `docs/gnome-settings.md` — Power Management and Lid-Close Behavior sections trimmed to a
  short summary of GNOME-dconf-scoped facts plus a cross-reference to the new page; the
  unverified Neovim `<leader>rz` inhibitor Note was removed.
- `docs/niri.md` — the swayidle feature bullet and the lid-close paragraph trimmed to brief
  statements plus cross-references to the new page.
- `docs/README.md` — added an index entry for `no-sleep-agents.md` under "Applications &
  Desktop".
- `modules/system/power.nix` — added two comment-only `# See docs/no-sleep-agents.md.`
  trailers (logind lid settings banner, battery-suspend-backstop banner).
- `modules/home/desktop/gnome.nix` — added one comment-only `# See docs/no-sleep-agents.md.`
  trailer near the `sleep-inactive-*` dconf keys.

## Decisions

- Placed the new page under the "Applications & Desktop" category in `docs/README.md`,
  adjacent to `gnome-settings.md`/`niri.md`, since it primarily documents desktop-session power
  behavior those pages already partially covered (rather than "Development & Hardware", even
  though it also touches logind/systemd-timer content).
- Dropped the Neovim `<leader>rz` sleep-inhibitor claim entirely rather than propagating it:
  Phase 1 grepped all `.lua` files in the repo tree for `rz`, `systemd-inhibit`, and `inhibit`
  and found zero matches, so the claim (previously present in `docs/gnome-settings.md`) could
  not be corroborated against source and was removed rather than carried forward.
- Skipped a root `README.md` mention/link, matching the plan's default and the precedent set by
  the underlying configuration work.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Live `busctl get-property org.freedesktop.login1 … HandleLidSwitch` re-checked at write time:
  still returns `"suspend"`, not `"lock"` — the logind activation gap persists on the live
  system. This is documented prominently in the new page's "Activation & verification" section
  (as a command to run, not a hardcoded status) along with the `sudo systemctl restart
  systemd-logind` / reboot fix, per the plan's non-goal of not remediating the gap here.
- `battery-suspend-backstop.timer` confirmed `active`; `sleep-inactive-ac-type` /
  `sleep-inactive-battery-type` / `sleep-inactive-battery-timeout` confirmed matching committed
  config (`'nothing'` / `'suspend'` / `3600`).
- `grep -rn "specs/117\|task 117\|task-117" docs/no-sleep-agents.md docs/gnome-settings.md
  docs/niri.md` — zero matches.
- `git diff modules/system/power.nix modules/home/desktop/gnome.nix` — confirmed only added
  `#` comment lines changed, no config values touched.
- `nix flake check --no-build` — passed ("all checks passed!"), unrelated pre-existing
  `boot.zfs.forceImportRoot` evaluation warnings only.

## Notes

The live logind lid-activation gap identified in the research report was re-confirmed still
present at write time (not yet resolved by a `systemd-logind` restart or reboot since the last
`nixos-rebuild switch`). Per the plan's explicit non-goal, no remediation was performed here —
the new page documents the verification command and the fix, and flags it as a live, checkable
fact rather than an assumption.

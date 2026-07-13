# Implementation Summary: Task #97

**Completed**: 2026-07-05
**Duration**: ~7 minutes

## Overview

Extracted three inline `writeShellScriptBin` wrappers (`zathura` X11-forcing, `sioyek`
Wayland-CSD-disabling, `polkit-gnome-authentication-agent-1` PATH-exposing) out of the always-on
`modules/system/packages.nix` `environment.systemPackages` list into dedicated `packages/*.nix`
files, wired them through `overlays/unstable-packages.nix`, and deleted a stale/contradictory
MCPHub comment in `flake.nix`. All 4 phases completed with no deviations from the wiring pattern
(one optional, plan-flagged sub-task was skipped per explicit file-scope constraints — see Plan
Deviations).

## What Changed

- `packages/zathura-x11.nix` — new file. Positional-import signature (`zathura: writeShellScriptBin:
  ...`), matching the `packages/kooha.nix` precedent, since the wrapper output name collides with
  the wrapped nixpkgs package name.
- `packages/sioyek-wayland.nix` — new file. Same positional-import shape as zathura, same
  self-referential-name rationale.
- `packages/polkit-gnome-agent-wrapper.nix` — new file. Standard `{ lib, writeShellScriptBin,
  polkit_gnome }:` callPackage-style signature (no name collision with `polkit_gnome`).
- `overlays/unstable-packages.nix` — added 3 overlay attributes: `zathura` and `sioyek` wired via
  `import ../packages/X.nix prev.X final.writeShellScriptBin` (NOT `callPackage`/`final.X`, which
  would cause infinite recursion); `polkit-gnome-authentication-agent-1` wired via
  `final.callPackage ../packages/polkit-gnome-agent-wrapper.nix { }`.
- `modules/system/packages.nix` — deleted all 3 inline `writeShellScriptBin` blocks (previously
  lines ~199-224). Left the pre-existing bare `zathura` entry (line 136) untouched — it now
  resolves through the overlay. Added a new bare `sioyek` entry next to `zathura` (PDF/Document
  Tools section) and a new bare `polkit-gnome-authentication-agent-1` entry where the old inline
  block used to sit.
- `flake.nix` — deleted the stale `# Note: MCPHub is now handled via official flake input instead
  of custom overlay` comment (was line 62) and collapsed the resulting double blank line to a
  single blank line. The accurate comment at line 33 (`# Note: MCPHub is loaded via lazy.nvim, not
  as a flake input`) and the adjacent dead `home-manager`/release-23.11 block (lines 34-36) were
  left untouched, as scoped.

## Decisions

- Followed the `kooha.nix` positional-import precedent exactly for the two self-referential
  wrappers (zathura, sioyek), using `prev.X` (not `final.X`, not `callPackage`) as the load-bearing
  anti-recursion mechanism.
- New package files (`packages/zathura-x11.nix`, `packages/sioyek-wayland.nix`,
  `packages/polkit-gnome-agent-wrapper.nix`) plus the modified `overlays/unstable-packages.nix` had
  to be `git add`-ed (staged, not committed) before `nix flake check` would recognize them — this
  is standard Nix-flake git-tracking behavior (untracked files are invisible to a flake
  evaluation), not a defect. Per the orchestrator instruction, no commit was made.

## Plan Deviations

- **Task 1.4** (optional `packages/README.md` subsections for the 3 new files) skipped: the
  orchestrator's explicit FILE SCOPE constraint for this task prohibits touching `docs/*.md` or
  README files, and the plan itself already marked this sub-task optional/non-required.

## Verification

- `nix-instantiate --parse` on all 3 new package files: succeeded.
- `nix flake check` (run after Phase 2, Phase 3, and Phase 4): all passed, "all checks passed!"
  each time. No infinite-recursion/stack-overflow error at any point, confirming the `prev.X`
  wiring is correct.
- `nix eval` on `nixosConfigurations.hamsa.config.environment.systemPackages` names: after Phase 2
  (pre-cleanup intermediate state), `zathura` appeared twice (bare entry + still-present inline
  block) and `sioyek`/`polkit-gnome-authentication-agent-1` once each (inline block only, no bare
  entry yet) — matching the plan's documented benign intermediate state. After Phase 3, each of
  `zathura`, `sioyek`, `polkit-gnome-authentication-agent-1` appeared **exactly once**.
- `nixos-rebuild build --flake .#hamsa`: completed successfully (`Done. The new configuration is
  /nix/store/bfy9w1q04vck6fknm1f107si945j3287-nixos-system-hamsa-26.05.20260622.3426825`), force
  building the `environment.systemPackages` profile join.
- Inspected the built wrapper scripts directly from the `nixos-rebuild build` result
  (`$RESULT/sw/bin/{zathura,sioyek,polkit-gnome-authentication-agent-1}`): all three preserve their
  original env vars (`GDK_BACKEND=x11`, `QT_WAYLAND_DISABLE_WINDOWDECORATION=1`) and exec targets
  (`.../bin/zathura`, `.../bin/sioyek`, `.../libexec/polkit-gnome-authentication-agent-1`)
  byte-identical to the pre-extraction inline blocks.
- `grep -n writeShellScriptBin modules/system/packages.nix`: no matches (all 3 inline blocks
  fully removed).
- `grep -n "official flake input" flake.nix`: no matches (stale comment gone).
- `grep -n "loaded via lazy.nvim" flake.nix`: line 33 (accurate comment preserved).

## Notes

- This was run in `orchestrator_mode`; no git commit was made. Changed/new files were `git add`-ed
  (staged only) as required for `nix flake check` to see the new `packages/*.nix` files — this
  staging is a build-visibility requirement, not a commit.
- Task 98 (documented as depending on this task since both touch `flake.nix`) can now proceed
  without conflicting with the MCPHub comment cleanup.
- File scope was respected throughout: only `modules/system/packages.nix`, the 3 new
  `packages/*.nix` files, `overlays/unstable-packages.nix`, and `flake.nix` were touched. No
  `docs/*.md` or README files were modified.

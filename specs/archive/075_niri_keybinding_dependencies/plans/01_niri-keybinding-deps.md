# Implementation Plan: Task #75

- **Task**: 75 - niri_keybinding_dependencies
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/075_niri_keybinding_dependencies/reports/01_niri-keybinding-deps.md
- **Artifacts**: plans/01_niri-keybinding-deps.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/nix.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Make every niri keybinding in `config/config.kdl` resolve to an installed binary, without touching the GNOME session. Three targeted fixes: (1) rewrite the two `grimshot` screenshot binds (Mod+Shift+S line 169, Print line 170) to the `grim`/`slurp`/`satty` form already used by the working Mod+Shift+A bind (line 171) — grim, slurp, and satty are already home-manager-owned in `modules/home/packages/media-dictation.nix`, so this adds zero new dependencies; (2) add `pkgs.playerctl` to `modules/home/packages/media-dictation.nix` so the media-transport keys (lines 184-186) resolve; (3) change the Mod+C bind (line 165) from `spawn "code"` to `spawn "codium"` since only `codium` exists on this system. Definition of done: `nix flake check` and `home-manager build --flake .#benjamin` both succeed with the edits, and every affected bind references a binary that is present in the home-manager closure. Live exercising of the keys in a niri session is a manual user step post-switch, out of scope for the implementer.

### Research Integration

The research report (`reports/01_niri-keybinding-deps.md`) verified all three fixes directly against this repo's exact pinned nixpkgs commit:
- **grimshot**: `pkgs.sway-contrib.grimshot` and `pkgs.playerctl` both evaluate cleanly at the locked revision, but the report recommends **rewriting** the two grimshot binds to `grim`/`slurp`/`satty` rather than adding grimshot — for consistency with the existing Mod+Shift+A bind and to avoid a new dependency (grim/slurp/satty are already present at `media-dictation.nix:14-16`). Adding `pkgs.sway-contrib.grimshot` is recorded below as the documented alternative.
- **playerctl**: not present anywhere; recommended addition to `media-dictation.nix` (home-manager owns all other niri-session media/screenshot/clipboard tooling).
- **Mod+C**: confirmed empirically that `codium` exists (`/run/current-system/sw/bin/codium`) and no `code` binary or symlink exists on PATH; `vscodium` is installed via `modules/system/packages.nix:123`.

The volume/mute binds (lines 181-183) already use `wpctl` correctly and are explicitly out of scope.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found (roadmap flag not set for this task).

## Goals & Non-Goals

**Goals**:
- Every niri keybinding in `config/config.kdl` resolves to an installed binary.
- Screenshot binds (Mod+Shift+S, Print) use the already-present grim/slurp/satty toolchain, consistent with Mod+Shift+A.
- Media-transport keys (XF86AudioPlay/Next/Prev) resolve via a newly-added `pkgs.playerctl`.
- Mod+C launches VSCodium (`codium`).
- Changes verified by `nix flake check` and `home-manager build --flake .#benjamin`.

**Non-Goals**:
- No change to the GNOME session or GNOME-owned tooling.
- No change to the volume/mute binds (lines 181-183; already correct with `wpctl`).
- No change to `modules/system/packages.nix` (system package list) — not required under the recommended path.
- No live/manual in-session key testing by the implementer (that is a post-switch user step).
- Not adding `pkgs.sway-contrib.grimshot` (recorded as the documented alternative, not the chosen path).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Mod+Shift+S rewrite duplicates Mod+Shift+A behavior (both area+annotate), making the binds redundant | L | M | Use the report's differentiated forms: Mod+Shift+S = area+annotate (matching Mod+Shift+A), Print = full-screen+annotate (`grim - \| satty -f -`, no slurp). If the user later prefers quick-save-to-disk semantics, the direct-save variant in the report (Item 1, second code block) integrates with the existing `screenshot-path-copy` service — noted but not implemented here. |
| `sh -c` inline scripts embed escaped quotes in KDL strings, fragile to hand-edit | M | L | Copy the exact escaping pattern already proven working at config.kdl:171 and :178; verify the build parses the config. |
| `playerctl play-pause` no-ops if no MPRIS player is active | L | L | Expected behavior, not a bug; no mitigation needed. Manual verification (user) should launch an MPRIS client (Spotify via Mod+M) first. |
| Editing the standalone home-manager file but building the wrong attr | L | L | Confirmed attr is `benjamin` (flake.nix:193-194); build command is `home-manager build --flake .#benjamin`. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Rewrite config.kdl keybindings (screenshots + Mod+C) [COMPLETED]

- **Goal:** Every keybinding in `config/config.kdl` references a binary that is (or will be) installed; screenshot binds standardized on grim/slurp/satty; Mod+C launches codium.
- **Tasks:**
  - [x] Edit `config/config.kdl:165` — change `Mod+C { spawn "code"; }      // VSCode` to `Mod+C { spawn "codium"; }      // VSCodium` (bind + comment).
  - [x] Edit `config/config.kdl:169` — change `Mod+Shift+S { spawn "grimshot" "save" "area"; }  // Screenshot area` to `Mod+Shift+S { spawn "sh" "-c" "grim -g \"$(slurp)\" - | satty -f -"; }  // Screenshot area (annotate)`.
  - [x] Edit `config/config.kdl:170` — change `Print { spawn "grimshot" "save" "screen"; }       // Screenshot full` to `Print { spawn "sh" "-c" "grim - | satty -f -"; }  // Screenshot full (annotate)`.
  - [x] Confirm Mod+Shift+A (line 171) is left unchanged (regression guard — it now shares the grim/slurp/satty primitive with the two rewritten binds).
  - [x] Confirm no `grimshot` reference remains anywhere in `config/config.kdl` (`grep -n grimshot config/config.kdl` returns nothing).
  - [x] Match the exact escaped-quote pattern already used at config.kdl:171 and :178 for the `sh -c` inline scripts.
- **Timing:** ~20 minutes
- **Depends on:** none
- **Files to modify:**
  - `config/config.kdl` — lines 165, 169, 170 (bind rewrites + comment updates)

### Phase 2: Add playerctl to media-dictation.nix [COMPLETED]

- **Goal:** `playerctl` is present in the home-manager closure so the XF86AudioPlay/Next/Prev binds (config.kdl:184-186, already correct) resolve.
- **Tasks:**
  - [x] Edit `modules/home/packages/media-dictation.nix` — add `playerctl # MPRIS media-transport control (for niri XF86Audio Play/Next/Prev binds)` to the `home.packages` list, alongside the existing niri-session media tools (natural placement near `wl-clipboard`/`cliphist` or the screenshot group).
  - [x] Preserve 2-space indentation and one-item-per-line list formatting per `.claude/rules/nix.md`.
  - [x] Confirm no change is needed to `config/config.kdl:184-186` (the `playerctl` binds are already correct once the binary exists).
  - [x] Do NOT touch `modules/system/packages.nix` (playerctl belongs in home-manager per the ownership convention).
- **Timing:** ~10 minutes
- **Depends on:** none
- **Files to modify:**
  - `modules/home/packages/media-dictation.nix` — add `pkgs.playerctl` to `home.packages`

### Phase 3: Build verification [COMPLETED]

- **Goal:** Confirm the edited config and package addition evaluate and build cleanly (headless; no live session).
- **Tasks:**
  - [x] Run `nix flake check` from the repo root; confirm it succeeds (config.kdl is consumed by the niri home-manager module, so a KDL parse/eval error surfaces here or in the build below).
  - [x] Run `home-manager build --flake .#benjamin` (attr confirmed at flake.nix:193-194); confirm the build succeeds and the result closure includes `playerctl`, `grim`, `slurp`, `satty`, and `vscodium`/`codium`. (`codium` confirmed present system-wide at `/run/current-system/sw/bin/codium`, not in the home-manager closure — consistent with research findings that vscodium is installed via `modules/system/packages.nix`.)
  - [x] Optionally confirm `playerctl` resolves in the built closure (e.g. `nix eval` / inspect the built `home-path`), or simply rely on a green `home-manager build`.
  - [x] Record verification output in the implementation summary.
  - [x] NOTE: exercising the actual keys (area+full screenshot, play/next/prev, Mod+C launching VSCodium) in a live niri session is a MANUAL user step AFTER `home-manager switch`, and is explicitly NOT performed by the implementer.
- **Timing:** ~15-30 minutes (dominated by build time; expected mostly cache hits since grim/slurp/satty/vscodium are already in the closure and only playerctl is new)
- **Depends on:** 1, 2
- **Files to modify:** none (verification only)

## Testing & Validation

- [x] `nix flake check` succeeds.
- [x] `home-manager build --flake .#benjamin` succeeds.
- [x] `grep -n grimshot config/config.kdl` returns no matches (grimshot fully removed from binds).
- [x] `grep -n 'spawn "code"' config/config.kdl` returns no matches (Mod+C no longer references `code`).
- [x] `playerctl` appears in `modules/home/packages/media-dictation.nix` `home.packages`.
- [x] Mod+Shift+A bind (config.kdl:171) is unchanged.
- [x] Volume/mute binds (config.kdl:181-183) are unchanged.
- [ ] MANUAL (user, post-switch, not implementer): in a niri session confirm Mod+Shift+S area screenshot, Print full screenshot, Mod+Shift+A (regression), XF86AudioPlay/Next/Prev with an MPRIS player active, and Mod+C opening VSCodium.

## Artifacts & Outputs

- `specs/075_niri_keybinding_dependencies/plans/01_niri-keybinding-deps.md` (this plan)
- `specs/075_niri_keybinding_dependencies/summaries/01_niri-keybinding-deps-summary.md` (produced at implementation)
- Modified: `config/config.kdl` (lines 165, 169, 170)
- Modified: `modules/home/packages/media-dictation.nix` (playerctl addition)

## Rollback/Contingency

- All changes are confined to two files (`config/config.kdl`, `modules/home/packages/media-dictation.nix`). Revert via `git checkout -- config/config.kdl modules/home/packages/media-dictation.nix` (clean tree) or `git revert` the implementation commit.
- **Documented alternative for Item 1 (grimshot)**: if the maintainer prefers grimshot's UX (auto-notify, one-liner, default save-to-`~/Pictures/Screenshots` + clipboard) over satty annotation, instead of rewriting lines 169-170, add `pkgs.sway-contrib.grimshot` to `modules/home/packages/media-dictation.nix` (verified to evaluate at the pinned nixpkgs revision) and leave the two binds unchanged. This path is reversible against the recommended one and requires no config.kdl bind change.
- If `home-manager build` fails on the KDL edits, the most likely cause is quote-escaping in the `sh -c` strings; compare against the proven working patterns at config.kdl:171 and :178.

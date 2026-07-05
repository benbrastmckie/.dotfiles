# Implementation Plan: Task #97

- **Task**: 97 - Extract 3 inline writeShellScriptBin wrappers from modules/system/packages.nix into packages/*.nix, and fix the contradictory MCPHub comment pair in flake.nix
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None (task 98 depends on this task — both touch flake.nix; complete 97 first)
- **Research Inputs**: specs/097_refactor_dead_comment_cleanup/reports/01_wrapper-extraction-mcphub-fix.md
- **Artifacts**: plans/01_wrapper-extraction-mcphub-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Move three inline `writeShellScriptBin` wrappers (`zathura` force-X11, `sioyek` Wayland-CSD-off,
`polkit-gnome-authentication-agent-1` libexec-on-PATH) out of the always-on
`modules/system/packages.nix` `environment.systemPackages` list into dedicated `packages/*.nix`
files, wire them through `overlays/unstable-packages.nix`, then delete a stale/contradictory
MCPHub comment in `flake.nix`. The load-bearing subtlety is that `zathura` and `sioyek` are
self-referential (wrapper output name collides with the wrapped nixpkgs package), so they MUST use
the `kooha.nix` positional-`import`-with-`prev.X` pattern, never `callPackage`, to avoid infinite
recursion. Because `nix flake check` alone does not force-build `environment.systemPackages`,
verification requires an actual `nixos-rebuild build --flake .#hamsa` in addition to
`nix flake check`.

### Research Integration

Key findings from `01_wrapper-extraction-mcphub-fix.md` that drive this plan:
- **Self-recursion (findings a, c, Risks)**: `final.callPackage` for `zathura`/`sioyek` would
  resolve their own name from `final` → infinite recursion. Precedent `packages/kooha.nix` is
  wired as `kooha = import ../packages/kooha.nix prev.kooha final.gst_all_1;` — use `prev.X`.
  `polkit-gnome-authentication-agent-1` output name does NOT collide with `polkit_gnome`, so plain
  `callPackage` is safe there.
- **systemPackages membership (findings a.1, a.2, c, Recommendations 3)**: `zathura` already has a
  bare list entry at `packages.nix:136`; routing the wrapper through the overlay makes that bare
  entry resolve to the wrapper, so its inline block can simply be deleted (no new entry). `sioyek`
  has NO bare entry — deleting its inline block without adding a bare `sioyek` entry silently drops
  the binary. `polkit-gnome-authentication-agent-1` likewise needs a bare entry added.
- **Verification sufficiency (finding e, Risks)**: `nix flake check` catches the recursion mistake
  (eval error) but NOT a silently-dropped `sioyek` binary or a same-name buildEnv collision — those
  need `nixos-rebuild build` (or `nix eval` on `config.environment.systemPackages`).
- **MCPHub (finding d)**: `flake.nix:33` is correct (MCPHub via lazy.nvim); `flake.nix:62` ("now
  handled via official flake input") is stale/dead — no MCPHub flake input has ever existed. Delete
  line 62 and collapse the double blank line to a single blank line.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md provided in delegation context; no roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Extract all 3 inline wrappers into `packages/zathura-x11.nix`, `packages/sioyek-wayland.nix`,
  `packages/polkit-gnome-agent-wrapper.nix`, preserving script bodies verbatim (no behavior change).
- Wire all 3 through `overlays/unstable-packages.nix` (zathura/sioyek via `prev.X` positional
  import; polkit via `callPackage`).
- Leave `environment.systemPackages` providing exactly one `zathura`, one `sioyek`, and one
  `polkit-gnome-authentication-agent-1`, each resolving to its wrapper.
- Delete the stale `flake.nix:62` MCPHub comment and collapse the blank-line gap.
- Verify with both `nix flake check` and `nixos-rebuild build --flake .#hamsa`.

**Non-Goals**:
- No behavior change to any wrapper (pure extraction — identical shebang/env-var/exec lines).
- Do NOT touch the adjacent dead `home-manager`/release-23.11 commented block at flake.nix:34-36
  (out of scope; task names only the 33/62 pair).
- Do NOT reorganize `packages.nix` beyond the minimal edits (minimal-diff placement is acceptable).
- `packages/README.md` subsections for the 3 new files are optional (see Phase 1) — not required by
  the task description.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Using `callPackage` for zathura/sioyek → infinite recursion at eval | H | M | Use `import ../packages/X.nix prev.X final.writeShellScriptBin` (kooha precedent). Phase 2 isolates this: `nix flake check` fails loudly on recursion before packages.nix is touched. |
| Deleting inline `sioyek` block without adding a bare entry → binary silently dropped (no eval error) | M | M | Phase 3 explicitly adds a bare `sioyek` entry and verifies membership via `nixos-rebuild build` / `nix eval`, not `nix flake check` alone. |
| New duplicate `sioyek`/`polkit` entry → buildEnv same-binary collision at build (not eval) time | M | L | Phase 3 verifies each of the 3 names appears exactly once in the final list and runs a real `nixos-rebuild build`. |
| Behavior drift from paraphrasing script bodies | M | L | Copy shebang/env-var/exec lines verbatim from packages.nix:202-206/213-217/221-224. |
| Editing live flake.nix breaks eval | L | L | Comment-only deletion; re-run `nix flake check` after (Phase 4). |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phase 4 (flake.nix comment fix) is independent of the wrapper-extraction chain (1→2→3) and touches
a different file, so it may run in parallel with Phase 1. Phases within the same wave can execute in
parallel.

---

### Phase 1: Create the 3 wrapper package files [COMPLETED]

**Goal**: Add three net-new `packages/*.nix` files with script bodies copied verbatim from the
current inline blocks. No wiring yet — files are not imported anywhere, so this phase cannot break
eval.

**Tasks**:
- [x] Create `packages/zathura-x11.nix` using the positional-import (kooha) signature. Copy the exec
      body verbatim from `packages.nix:202-206`:
      ```nix
      # Custom zathura wrapper: force GDK_BACKEND=x11 for consistent server-side
      # window decorations (the Unite GTK extension does not decorate Wayland clients).
      # Self-referential: wraps nixpkgs `zathura` under the same name, so it is wired in
      # overlays/unstable-packages.nix via `prev.zathura` (NOT callPackage) to avoid recursion.
      zathura: writeShellScriptBin:

      writeShellScriptBin "zathura" ''
        #!/bin/sh
        export GDK_BACKEND=x11
        exec ${zathura}/bin/zathura "$@"
      ''
      ```
- [x] Create `packages/sioyek-wayland.nix` with the same positional-import shape. Copy the exec body
      verbatim from `packages.nix:213-217`:
      ```nix
      # Custom sioyek wrapper: disable Qt client-side decorations on Wayland (GNOME 49 ignores
      # _MOTIF_WM_HINTS for XWayland, so use native Wayland + QT_WAYLAND_DISABLE_WINDOWDECORATION).
      # Self-referential: wraps nixpkgs `sioyek` under the same name, so it is wired via
      # `prev.sioyek` (NOT callPackage) to avoid recursion.
      sioyek: writeShellScriptBin:

      writeShellScriptBin "sioyek" ''
        #!/bin/sh
        export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
        exec ${sioyek}/bin/sioyek "$@"
      ''
      ```
- [x] Create `packages/polkit-gnome-agent-wrapper.nix` using the standard `callPackage` signature
      (no name collision with `polkit_gnome`). Copy the exec body verbatim from `packages.nix:221-224`:
      ```nix
      # Polkit authentication agent for the niri session: polkit_gnome ships the agent under
      # libexec/ (not linked onto PATH), so expose it on PATH under its conventional bin name.
      { lib, writeShellScriptBin, polkit_gnome }:

      writeShellScriptBin "polkit-gnome-authentication-agent-1" ''
        #!/bin/sh
        exec ${polkit_gnome}/libexec/polkit-gnome-authentication-agent-1 "$@"
      ''
      ```
- [ ] (Optional, low-risk) Add matching `### <file>.nix` subsections to `packages/README.md` for the
      3 new files, following the existing per-file convention. *(deviation: skipped — orchestrator
      FILE SCOPE constraint for this task explicitly prohibits touching docs/*.md or README files;
      this sub-task was already marked optional/non-required by the plan itself)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `packages/zathura-x11.nix` - new file (zathura X11 wrapper, `prev.X`-style signature)
- `packages/sioyek-wayland.nix` - new file (sioyek Wayland wrapper, `prev.X`-style signature)
- `packages/polkit-gnome-agent-wrapper.nix` - new file (polkit agent wrapper, callPackage-style)
- `packages/README.md` - optional: 3 new documentation subsections

**Verification**:
- All 3 files exist and are non-empty.
- Each parses: `nix-instantiate --parse packages/zathura-x11.nix`,
  `... packages/sioyek-wayland.nix`, `... packages/polkit-gnome-agent-wrapper.nix` all succeed.
- Script bodies match the originals character-for-character (diff the exec/env-var/shebang lines
  against `packages.nix:202-206/213-217/221-224`).

---

### Phase 2: Wire all 3 wrappers into overlays/unstable-packages.nix [COMPLETED]

**Goal**: Add the three overlay attributes so `pkgs.zathura`, `pkgs.sioyek`, and
`pkgs.polkit-gnome-authentication-agent-1` become the wrappers. This phase isolates the
self-recursion risk: if the wrong (`callPackage`) pattern is used for zathura/sioyek, `nix flake
check` fails here, before `packages.nix` is touched.

**Tasks**:
- [x] In `overlays/unstable-packages.nix`, inside the `pkgs-unstable: final: prev: { ... }` attrset
      (alongside the existing `kooha = import ...` line ~16), add:
      ```nix
      # Custom wrappers extracted from modules/system/packages.nix (task 97).
      # zathura/sioyek are self-referential (wrapper name == wrapped package name), so use
      # positional import with prev.X — NOT callPackage — to avoid infinite recursion (kooha pattern).
      zathura = import ../packages/zathura-x11.nix prev.zathura final.writeShellScriptBin;
      sioyek = import ../packages/sioyek-wayland.nix prev.sioyek final.writeShellScriptBin;
      polkit-gnome-authentication-agent-1 = final.callPackage ../packages/polkit-gnome-agent-wrapper.nix { };
      ```
- [x] Confirm `prev.zathura` / `prev.sioyek` (NOT `final.` and NOT `callPackage`) are used for the
      two self-referential wrappers.

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `overlays/unstable-packages.nix` - add 3 overlay attributes (zathura/sioyek positional import,
  polkit callPackage)

**Verification**:
- `nix flake check` succeeds (this specifically exercises overlay attribute resolution and would
  raise an infinite-recursion / stack-overflow error if `callPackage` or `final.X` were used for
  zathura/sioyek). At this point the inline blocks still exist in packages.nix — that is a benign
  pre-existing double-provision (bare zathura at line 136 now resolves to the wrapper), acceptable
  as an intermediate state; the cleanup happens in Phase 3.
- `nix eval .#nixosConfigurations.hamsa.pkgs.zathura.name` (or `nix eval` on the overlay output)
  resolves without recursion error.

---

### Phase 3: Clean up modules/system/packages.nix inline blocks and list membership [COMPLETED]

**Goal**: Delete the 3 now-redundant inline `writeShellScriptBin` blocks and make the
`environment.systemPackages` list provide exactly one entry each for zathura, sioyek, and the polkit
agent — each resolving to its overlay wrapper.

**Tasks**:
- [x] Delete the inline `zathura` block (`packages.nix:199-206`, comment + `writeShellScriptBin`).
      Leave the existing bare `zathura` entry at line 136 unchanged — it now resolves to the wrapper.
- [x] Delete the inline `sioyek` block (`packages.nix:208-217`) AND add a new bare `sioyek` entry to
      the list (suggested: next to `zathura` in the "PDF and Document Tools" section near line 136).
      Without this, `sioyek` disappears from the system profile with no eval error.
- [x] Delete the inline `polkit-gnome-authentication-agent-1` block (`packages.nix:219-224`) AND add
      a bare `polkit-gnome-authentication-agent-1` entry to the list (minimal-diff placement where
      the block used to sit is acceptable — hyphenated bare identifiers are valid Nix in `with pkgs;`).
- [x] Verify no leftover `writeShellScriptBin` calls remain in `packages.nix`:
      `grep -n writeShellScriptBin modules/system/packages.nix` returns nothing.

**Timing**: 0.75 hours

**Depends on**: 2

**Files to modify**:
- `modules/system/packages.nix` - delete 3 inline wrapper blocks; add bare `sioyek` and
  `polkit-gnome-authentication-agent-1` entries; leave bare `zathura` entry intact

**Verification**:
- `nix flake check` succeeds.
- `nixos-rebuild build --flake .#hamsa` completes successfully (REQUIRED — this force-builds the
  `environment.systemPackages` profile join, which `nix flake check` does not; catches a dropped
  binary or a same-name buildEnv collision).
- Each name appears exactly once in the built profile. Spot-check via:
  `nix eval --raw .#nixosConfigurations.hamsa.config.environment.systemPackages --apply 'ps: builtins.concatStringsSep "\n" (map (p: p.name or "") ps)' | grep -E 'zathura|sioyek|polkit-gnome'`
  should show one zathura, one sioyek, one polkit-gnome-authentication-agent wrapper.
- `zathura`, `sioyek`, and `polkit-gnome-authentication-agent-1` binaries resolve to the wrapped
  derivations (env vars / libexec exec preserved).

---

### Phase 4: Delete the stale flake.nix MCPHub comment [COMPLETED]

**Goal**: Remove the contradictory dead comment at `flake.nix:62` and collapse the resulting
double-blank-line gap, leaving the accurate comment at line 33 as the single source of truth.

**Tasks**:
- [x] Delete the line `# Note: MCPHub is now handled via official flake input instead of custom
      overlay` (currently `flake.nix:62`), which sits alone between blank lines 61 and 63 inside the
      `let` block after the 3 overlay imports (lines 57-59) and before `nixpkgsConfig`.
- [x] Collapse the resulting double blank line to a single blank line (delete either line 61 or 63)
      so exactly one blank line separates the overlay-import block from `nixpkgsConfig`.
- [x] Do NOT touch line 33 (accurate) or the adjacent dead `home-manager`/release-23.11 block at
      lines 34-36 (out of scope).

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `flake.nix` - delete stale MCPHub comment line + one adjacent blank line

**Verification**:
- `grep -n "official flake input" flake.nix` returns nothing (stale comment gone).
- `grep -n "loaded via lazy.nvim" flake.nix` still returns line ~33 (accurate comment preserved).
- `nix flake check` succeeds (live file, comment-only change, no eval impact expected).

---

## Testing & Validation

- [x] `nix flake check` passes after Phase 2, Phase 3, and Phase 4.
- [x] `nixos-rebuild build --flake .#hamsa` completes successfully after Phase 3.
- [x] `environment.systemPackages` provides exactly one each of `zathura`, `sioyek`,
      `polkit-gnome-authentication-agent-1`, all resolving to the wrappers.
- [x] No `writeShellScriptBin` calls remain in `modules/system/packages.nix`.
- [x] Wrapper script bodies are byte-identical to the originals (env vars / exec paths preserved).
- [x] `flake.nix` has no MCPHub "official flake input" comment; line 33 preserved.

## Artifacts & Outputs

- `packages/zathura-x11.nix`, `packages/sioyek-wayland.nix`,
  `packages/polkit-gnome-agent-wrapper.nix` (new)
- Edited `overlays/unstable-packages.nix`, `modules/system/packages.nix`, `flake.nix`
- Optional: 3 new `packages/README.md` subsections
- Implementation summary in `specs/097_refactor_dead_comment_cleanup/summaries/`

## Rollback/Contingency

- All changes are on a git working tree; `git checkout -- <file>` (or restore from a
  `git-snapshot.sh` snapshot if the tree is dirty) reverts any single file.
- If Phase 2 `nix flake check` reports infinite recursion, the wiring used `callPackage`/`final.X`
  for zathura or sioyek — switch to `import ../packages/X.nix prev.X final.writeShellScriptBin`.
- If Phase 3 `nixos-rebuild build` shows a missing or duplicated binary, re-check that `sioyek` and
  `polkit-gnome-authentication-agent-1` each have exactly one bare list entry and that `zathura`'s
  single bare entry (line 136) was not duplicated.
- The 3 new package files are inert until wired in Phase 2, so Phase 1 can be safely left in place
  even if later phases are deferred.

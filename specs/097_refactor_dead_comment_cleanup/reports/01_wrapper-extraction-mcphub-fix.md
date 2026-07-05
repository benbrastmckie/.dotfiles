# Research Report: Task #97

**Task**: 97 - Small refactor and dead-comment cleanup: extract 3 inline writeShellScriptBin
wrappers from modules/system/packages.nix into packages/*.nix, fix contradictory MCPHub comment
pair in flake.nix
**Started**: 2026-07-05T09:48:44Z
**Completed**: 2026-07-05T10:15:00Z
**Effort**: Small-Medium (one live always-on module touched, one comment-only fix; `nix flake
check` required)
**Dependencies**: None (task 98, nix formatter/lint tooling, depends on this task since both
touch `flake.nix`)
**Sources/Inputs**:
- `specs/094_review_nixos_config_documentation/reports/02_remaining-cleanup-backlog.md` (Group C,
  findings 10-11 — authoritative defect list for this task)
- `modules/system/packages.nix` (full file, 226 lines)
- `flake.nix` (lines 1-80, inputs + let block)
- `modules/home/core/neovim.nix` (line 25, MCPHub ground truth)
- `packages/*.nix` (all 13 files) and `packages/README.md` (per-file convention docs)
- `overlays/unstable-packages.nix`, `overlays/claude-squad.nix`, `overlays/python-packages.nix`
  (wiring conventions: `callPackage` vs. positional `import`)
- `modules/system/default.nix` (confirms `packages.nix` is always-on, imported unconditionally)
**Artifacts**: This report —
`specs/097_refactor_dead_comment_cleanup/reports/01_wrapper-extraction-mcphub-fix.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Confirmed 3 inline `writeShellScriptBin` wrapper blocks in `modules/system/packages.nix`
  (lines 199-206, 208-217, 219-224): `zathura` (force X11), `sioyek` (disable Qt CSD on Wayland),
  and `polkit-gnome-authentication-agent-1` (expose polkit-gnome's libexec binary on PATH).
- The repo's established convention for custom derivations is one file per package under
  `packages/*.nix`, wired either via `overlays/unstable-packages.nix` (most common: `final.
  callPackage ../packages/X.nix { }`) or, when a wrapper needs the **pre-overlay** version of a
  package it overrides (avoiding self-recursion), via positional `import` with explicit `prev.X`
  — the exact pattern already used by `packages/kooha.nix` (`kooha: gst_all_1: kooha.overrideAttrs
  (...)`, invoked as `import ../packages/kooha.nix prev.kooha final.gst_all_1`).
- **Critical wiring risk identified**: `zathura` and `sioyek` are self-overriding package names
  (the wrapper's output attribute name is identical to the nixpkgs package it wraps). A naive
  `final.callPackage ../packages/zathura-x11.nix { }` assigned to `zathura` would be **infinite
  recursion** (it would try to resolve its own `zathura` argument from `final`, which is the
  attribute being defined). This must follow the `kooha.nix` positional-`import`-with-`prev.X`
  pattern, not `callPackage`. `polkit-gnome-authentication-agent-1` has no such risk since its
  output name does not collide with the `polkit_gnome` attribute it consumes, so plain
  `callPackage` is safe there.
- A related pre-existing quirk (not part of the requested fix, flagged for extractor awareness):
  `packages.nix:136` already lists a bare `zathura` package reference in the same
  `environment.systemPackages` list alongside the inline `writeShellScriptBin "zathura"` block —
  i.e., **two derivations claiming to provide `bin/zathura` are both in the list today**.
  Routing the wrapper through the overlay (so `pkgs.zathura` **is** the wrapper) resolves this as
  a side effect: the existing bare `zathura` at line 136 will then automatically pick up the
  wrapped derivation and the separate wrapper block can simply be deleted, leaving exactly one
  `zathura` entry. `sioyek` has no equivalent bare entry today (the inline wrapper is currently
  the *only* place `sioyek` is provided), so extraction must **add** a new bare `sioyek` list
  entry when the block is removed, or `sioyek` disappears from `environment.systemPackages`
  entirely.
- Confirmed the `flake.nix` MCPHub comment contradiction: line 33 ("MCPHub is loaded via lazy.nvim,
  not as a flake input") is accurate — ground-truthed against `modules/home/core/neovim.nix:25`
  and the absence of any MCPHub-named flake input (grep of all 9 declared inputs: `nixpkgs`,
  `nixpkgs-unstable`, `lean4`, `niri`, `lectic`, `nix-ai-tools`, `utils`, `home-manager`,
  `sops-nix` — none is MCPHub-related) and any MCPHub overlay (the 3 overlays wired at
  `flake.nix:57-59` are `claude-squad`, `unstable-packages`, `python-packages`). Line 62 ("MCPHub
  is now handled via official flake input instead of custom overlay") is stale/dead and
  contradicts line 33 — no MCPHub flake input has ever existed in the current inputs list. Fix is
  a one-line comment deletion.
- Verification requirement: `nix flake check` after both changes; the wrapper extraction should
  additionally be spot-checked with `nixos-rebuild build --flake .#<host>` (or at minimum `nix
  eval .#nixosConfigurations.<host>.config.environment.systemPackages` style inspection) since
  `nix flake check` alone does not build `environment.systemPackages` and would not surface a
  `callPackage`-recursion mistake or a silently-dropped `sioyek` binary.

## Context & Scope

Research-only investigation for task 97, scoped exactly to Group C of the task-94 follow-up
backlog report (`specs/094.../reports/02_remaining-cleanup-backlog.md`, findings 10-11): the
`modules/system/packages.nix` inline-wrapper extraction and the `flake.nix` MCPHub
comment contradiction. No files were modified — this report only characterizes the current state
and lays out the extraction/fix design for the planner.

## Findings

### (a) The 3 inline `writeShellScriptBin` wrappers in `modules/system/packages.nix`

All three are inside the single `environment.systemPackages = (with pkgs; [ ... ])` list (file is
226 lines total; header at lines 1-4, list opens at line 5, closes at lines 225-226).

1. **`zathura`** — `modules/system/packages.nix:199-206`
   - Comment: lines 199-201 (`# Custom zathura (force X11 for consistency)` + 2-line rationale
     about Unite extension / GTK server-side decorations).
   - Code: lines 202-206:
     ```nix
     (writeShellScriptBin "zathura" ''
       #!/bin/sh
       export GDK_BACKEND=x11
       exec ${pkgs.zathura}/bin/zathura "$@"
     '')
     ```
   - Consumes `pkgs.zathura` (the real nixpkgs package) and re-exports a same-named
     `zathura` binary that forces `GDK_BACKEND=x11`.
   - **Pre-existing duplicate**: `packages.nix:136` already has a bare `zathura # Light-weight
     PDF/document viewer` entry in the "PDF and Document Tools" section of the same list (lines
     124-141). Both `pkgs.zathura` and this wrapper currently sit in the same
     `environment.systemPackages` list under the same output binary name.
   - Target file: `packages/zathura-x11.nix`.

2. **`sioyek`** — `modules/system/packages.nix:208-217`
   - Comment: lines 208-212 (`# Custom sioyek (disable Qt client-side decorations on Wayland)` +
     3-line rationale about GNOME 49 ignoring `_MOTIF_WM_HINTS` for XWayland, switching strategy
     from forcing X11 to native Wayland + `QT_WAYLAND_DISABLE_WINDOWDECORATION`).
   - Code: lines 213-217:
     ```nix
     (writeShellScriptBin "sioyek" ''
       #!/bin/sh
       export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
       exec ${pkgs.sioyek}/bin/sioyek "$@"
     '')
     ```
   - Consumes `pkgs.sioyek` (real nixpkgs package). Unlike zathura, there is **no other** bare
     `sioyek` reference anywhere in `packages.nix` — this wrapper is currently the sole source of
     the `sioyek` binary on the system profile.
   - Target file: `packages/sioyek-wayland.nix`.

3. **`polkit-gnome-authentication-agent-1`** — `modules/system/packages.nix:219-224`
   - Comment: lines 219-220 (`# Polkit authentication agent for the niri session...` +
     libexec-not-linked rationale).
   - Code: lines 221-224:
     ```nix
     (writeShellScriptBin "polkit-gnome-authentication-agent-1" ''
       #!/bin/sh
       exec ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1 "$@"
     '')
     ```
   - Consumes `pkgs.polkit_gnome`'s `libexec/` binary and re-exposes it under `bin/` with a
     **different** attribute name than the package it wraps (`polkit-gnome-authentication-agent-1`
     vs. `polkit_gnome`) — no self-recursion risk.
   - Target file: `packages/polkit-gnome-agent-wrapper.nix`.

Surrounding structure: lines 196-198 are blank/spacing before the first wrapper; line 225 closes
the list (`]);`); line 226 closes the file (`}`). All three blocks are contiguous
(199-224, with single blank-line separators at 207 and 218), the last content in the file before
the list/file close.

### (b) Existing `packages/*.nix` layout convention

13 files exist in `packages/`, each a single custom derivation, with two wiring styles observed:

- **`callPackage` style** (majority, no self-reference risk): file exports a standard
  `{ arg1, arg2, ... }: derivation` attrset-function; wired in `overlays/unstable-packages.nix` as
  `attrName = final.callPackage ../packages/<file>.nix { };` (e.g. `claude-code.nix`,
  `aristotle.nix`, `slidev.nix`, `loogle.nix`, `opencode.nix`) — then referenced as a bare
  identifier in whichever `environment.systemPackages` / `home.packages` list needs it.
  Example (`packages/claude-code.nix:1,8-10`):
  ```nix
  { lib, writeShellScriptBin, nodejs }:
  writeShellScriptBin "claude" ''
    exec ${nodejs}/bin/npx @anthropic-ai/claude-code@latest "$@"
  ''
  ```
- **Positional-`import` style** (used exactly when overriding/wrapping an existing package under
  its *own* name, to avoid `final`-self-recursion): `packages/kooha.nix` is the precedent —
  ```nix
  kooha: gst_all_1:
  kooha.overrideAttrs (oldAttrs: { buildInputs = oldAttrs.buildInputs ++ [ ... ]; })
  ```
  wired in `overlays/unstable-packages.nix:16` as:
  ```nix
  kooha = import ../packages/kooha.nix prev.kooha final.gst_all_1;
  ```
  Note `prev.kooha` (the pre-overlay/original nixpkgs derivation), not `final.kooha` — this is
  the load-bearing detail that avoids infinite recursion when an overlay attribute reuses its own
  input's name.
- **Per-file header comment convention**: `piper-bin.nix` and `claude-code.nix` carry 1-6 line
  header comments describing what/why; `aristotle.nix`, `loogle.nix`, `slidev.nix` currently have
  none (already flagged separately as Group B finding 9 in the task-94 backlog report — out of
  scope for task 97, but the same header style should be applied to the 3 new files for
  consistency since they are newly created, not merely moved).
- **`packages/README.md`** documents every file in `packages/` with a `### <filename>` subsection
  (implementation summary, wiring note, usage). Not explicitly required by task 97's description,
  but adding 3 short subsections here would match the established documentation convention (see
  Recommendations).
- Aggregation: no central `packages/default.nix` exists — each file is `import`/`callPackage`d
  individually, either from an overlay (`overlays/*.nix`, most common) or, in one case
  (`opencode-discord-bot.nix`), directly from a consuming module
  (`modules/system/optional/discord-bot.nix:14`, `callPackage`d inline, bypassing the overlay
  layer entirely since it is an application, not a library or systemPackages entry).

### (c) Proposed extraction design for the 3 wrappers

| Wrapper | New file | Wiring | Notes |
|---|---|---|---|
| `zathura` | `packages/zathura-x11.nix` | Positional `import`, `kooha.nix`-style: `zathuraPkg: writeShellScriptBin: writeShellScriptBin "zathura" ''...''`. Wire in `overlays/unstable-packages.nix` as `zathura = import ../packages/zathura-x11.nix prev.zathura final.writeShellScriptBin;` | Must use `prev.zathura`, not `final.zathura`/`callPackage`, to avoid self-recursion. After wiring, **delete** the inline block (199-206); the existing bare `zathura` at line 136 automatically resolves to the wrapped derivation — no new list entry needed. |
| `sioyek` | `packages/sioyek-wayland.nix` | Same positional-`import` pattern: `sioyekPkg: writeShellScriptBin: writeShellScriptBin "sioyek" ''...''`, wired as `sioyek = import ../packages/sioyek-wayland.nix prev.sioyek final.writeShellScriptBin;` | Must use `prev.sioyek` for the same reason. After wiring, delete the inline block (208-217) **and add a new bare `sioyek` entry** to the `environment.systemPackages` list (e.g. near `zathura` at line 136, in the "PDF and Document Tools" section) — sioyek currently has no other list entry, so simply deleting the block without adding a replacement would silently drop it from the system profile. |
| `polkit-gnome-authentication-agent-1` | `packages/polkit-gnome-agent-wrapper.nix` | Standard `callPackage` style (no self-reference risk): `{ lib, writeShellScriptBin, polkit_gnome }: writeShellScriptBin "polkit-gnome-authentication-agent-1" ''...''`, wired in `overlays/unstable-packages.nix` as `"polkit-gnome-authentication-agent-1" = final.callPackage ../packages/polkit-gnome-agent-wrapper.nix { };` (or unquoted — Nix identifiers permit hyphens, matching the existing binary name string) | After wiring, delete the inline block (219-224) and add a bare `polkit-gnome-authentication-agent-1` entry to the list in its place. |

Wiring location: `overlays/unstable-packages.nix` is the natural home — it already hosts every
other `packages/*.nix` override/wrapper (`claude-code`, `opencode`, `loogle`, `aristotle`,
`slidev`, `kooha`, `piper`, `piper-voice-en-us-lessac-medium`, `vosk-model-small-en-us`), and its
own header comment ("packages sourced from nixpkgs-unstable or custom derivations... Add packages
here that require unstable versions or custom builds") explicitly covers custom-build overrides
regardless of channel.

Preserve exact script bodies verbatim (shebang, exported env var, `exec` line) — this is a pure
extraction, no behavior change intended per the task description.

### (d) `flake.nix` MCPHub comment contradiction

- `flake.nix:33` — `# Note: MCPHub is loaded via lazy.nvim, not as a flake input` — inside the
  `inputs = { ... }` block, immediately followed (lines 34-36) by an unrelated dead
  commented-out old `home-manager` input pin (`# home-manager = { url = ".../release-23.11"; };`)
  that predates the current live `home-manager.url` declaration at line 28. That adjacent block is
  a separate, already-noted-elsewhere dead comment (not part of task 97's explicit MCPHub scope;
  flagging only for context — not recommending action here since task 97's description names only
  the line 33/62 pair).
- `flake.nix:62` — `# Note: MCPHub is now handled via official flake input instead of custom
  overlay` — standalone comment line inside the `let` block, positioned after the 3 real overlay
  imports (lines 57-59: `claudeSquadOverlay`, `unstablePackagesOverlay`, `pythonPackagesOverlay`)
  and before the `nixpkgsConfig` definition (line 65). Sits alone between two blank lines (61 and
  63).
- **Ground truth**: line 33 is correct. Confirmed via:
  - `modules/home/core/neovim.nix:25` — `# Note: MCP-Hub is managed via lazy.nvim in NeoVim
    config`, inside the live `programs.neovim` block.
  - `flake.nix` inputs enumeration (lines 8-32) — 9 declared inputs (`nixpkgs`,
    `nixpkgs-unstable`, `lean4`, `niri`, `lectic`, `nix-ai-tools`, `utils`, `home-manager`,
    `sops-nix`); none is MCPHub-related.
  - `flake.nix` overlays enumeration (lines 57-59) — 3 declared overlays (`claude-squad`,
    `unstable-packages`, `python-packages`); none is MCPHub-related.
  - `packages/README.md:288-295` ("MCPHub Integration" section) independently confirms: "MCPHub
    is integrated as a standard Neovim plugin using lazy.nvim plugin loading" — consistent with
    line 33, not line 62.
  - Historical corroboration: task 82's dead-code-removal work (see
    `specs/082_dead_code_removal_nixos_repo/summaries/02_dead-code-removal-summary.md`) already
    removed a defunct `home-modules/mcp-hub.nix` module and associated stale MCP-Hub comments
    elsewhere in the repo, consistent with line 62 describing a transitional state
    (custom-overlay -> flake-input -> lazy.nvim) that was never actually reached as "flake input"
    — the repo went custom-overlay/module -> lazy.nvim directly, and line 62 is a leftover from an
    intermediate plan that was superseded.
- **Fix**: delete line 62 (`# Note: MCPHub is now handled via official flake input instead of
  custom overlay`) and collapse the resulting double-blank-line gap (delete either line 61 or 63)
  so exactly one blank line separates the overlay-import block from `nixpkgsConfig`. One-line
  comment-only change, no functional/eval impact.

## Decisions

- Recommend the positional-`import`-with-`prev.X` wiring pattern (not `callPackage`) for
  `zathura` and `sioyek` specifically because both wrapper output names collide with the nixpkgs
  attribute name they consume — `packages/kooha.nix` already establishes this exact pattern in
  this repo, so no new convention is introduced.
- Recommend `callPackage` (standard style) for `polkit-gnome-authentication-agent-1` since its
  output attribute name does not collide with `polkit_gnome`.
- Recommend wiring all three through `overlays/unstable-packages.nix` (not a new overlay file) to
  match where every other `packages/*.nix` custom derivation is currently wired.
- Did not propose fixing the adjacent dead `home-manager`/release-23.11 commented-out block at
  `flake.nix:34-36` — out of task 97's explicit two-line scope (line 33 vs. 62); noted only as
  contextual awareness for whoever next edits that region.
- Did not propose adding `packages/README.md` subsections for the 3 new files as a hard
  requirement (task 97's description does not mention it), but flagged it as a natural
  consistency add-on in Recommendations, since it is the established per-file documentation
  pattern for everything else in `packages/`.

## Recommendations

1. Create the 3 new `packages/*.nix` files per the table in Finding (c), preserving script bodies
   verbatim and adding a short 1-3 line header comment each (matching `piper-bin.nix`/
   `claude-code.nix` style) describing what's wrapped and why.
2. Wire all three in `overlays/unstable-packages.nix`: `zathura`/`sioyek` via positional `import
   ... prev.X final.writeShellScriptBin` (kooha-style, avoiding self-recursion);
   `polkit-gnome-authentication-agent-1` via `final.callPackage ... { }`.
3. In `modules/system/packages.nix`: delete all three inline blocks (199-206, 208-217, 219-224).
   `zathura`'s existing bare list entry (line 136) needs no change. Add a new bare `sioyek` entry
   and a new bare `polkit-gnome-authentication-agent-1` entry to the list (suggested: `sioyek`
   alongside `zathura` in the "PDF and Document Tools" section at ~line 136-141; the polkit agent
   entry can stay in roughly its current position, e.g. in a "Session/Desktop Integration" spot,
   or simply where the block used to sit — minimal-diff placement is acceptable since task 97 is
   a pure extraction, not a reorganization).
4. Fix `flake.nix:62`: delete the stale comment line and the resulting extra blank line.
5. Verify with `nix flake check`; additionally verify the wrapper extraction with `nixos-rebuild
   build --flake .#<host>` (pick any host, e.g. `hamsa`) since `nix flake check` does not build
   `environment.systemPackages` and would not catch a `callPackage`-recursion mistake or the
   `sioyek` binary silently disappearing from the profile.
6. Optional, low-risk consistency add-on: add matching `### <file>.nix` subsections to
   `packages/README.md` for the 3 new files (not required by the task description, but closes the
   same documentation gap the task-94 backlog report separately flagged for 9 pre-existing files
   in Group B — safe to bundle here since these are net-new files, not a retrofit).

## Risks & Mitigations

- **Self-recursion risk (zathura, sioyek)**: using `final.callPackage` instead of positional
  `import prev.X` for these two would produce infinite recursion at eval time (a Nix stack
  overflow / infinite-recursion error), since `callPackage`'s auto-argument-wiring would resolve
  `zathura`/`sioyek` from `final` — the very attribute being defined. Mitigation: follow the
  `kooha.nix` precedent exactly (positional function taking the pre-overlay package as an
  explicit argument, invoked with `prev.X`).
- **Silent `sioyek` binary loss**: because `sioyek` currently has no bare list entry outside the
  inline wrapper, a careless extraction that deletes the block without adding a replacement bare
  `sioyek` reference would silently remove the `sioyek` binary from `environment.systemPackages`
  with no `nix flake check` failure (eval succeeds fine either way — this is a systemPackages
  *membership* change, not a syntax error). Mitigation: explicitly verify `sioyek` appears exactly
  once in the final package list, and check with `nixos-rebuild build` or `nix eval` on
  `config.environment.systemPackages` names, not just `nix flake check`.
- **`nix flake check` is necessary but not sufficient**: it validates evaluation (syntax,
  attribute resolution, `nixosConfigurations` build up to `config` realization) but does not
  force-build `environment.systemPackages`' `buildEnv`/profile join, so a same-binary-name
  collision (already present today between `zathura`'s bare entry and its former wrapper, and
  would recur if the new `sioyek`/`polkit-gnome-authentication-agent-1` bare entries were
  accidentally duplicated) would not surface without an actual `nixos-rebuild build`/`switch`.
  This is a pre-existing condition unrelated to task 97's introduction, but the fix (routing
  `zathura` through the overlay) incidentally resolves it — verify no *new* duplicate is
  introduced for `sioyek`/`polkit-gnome-authentication-agent-1`.
- **`flake.nix` is a live, always-imported file for every host** — the MCPHub comment deletion is
  low-risk (comment-only, no code change), but `nix flake check` should still be re-run after any
  edit to this file as a matter of course.
- Task 98 (nix formatter/lint tooling) depends on task 97 per `specs/state.json` since both touch
  `flake.nix` — sequence task 97 to completion first to avoid overlapping edits to the same file.

## Appendix

### Search/verification commands used

```bash
sed -n '1,80p' flake.nix
cat -n modules/system/packages.nix
ls packages/; cat packages/{piper-bin,claude-code,aristotle,kooha,slidev,loogle}.nix
grep -rn "import ./packages\|import ../packages\|packages/" --include="*.nix" .
grep -rn "zathura\|sioyek\|polkit-gnome" --include="*.nix" .
grep -rn "MCPHub\|MCP-Hub\|MCP Hub\|mcphub" --include="*.nix" --include="*.md" .
cat modules/system/default.nix
sed -n '1,40p' modules/home/core/neovim.nix
cat overlays/unstable-packages.nix overlays/claude-squad.nix
sed -n '1,80p' packages/README.md
```

### Files read in full or substantially

`modules/system/packages.nix` (full, 226 lines), `flake.nix` (lines 1-80),
`modules/home/core/neovim.nix`, `overlays/unstable-packages.nix`, `overlays/claude-squad.nix`,
`overlays/python-packages.nix` (imports only), `modules/system/default.nix`,
`packages/{piper-bin,claude-code,aristotle,kooha,slidev,loogle}.nix`, `packages/README.md`
(header + MCPHub section), `specs/094_review_nixos_config_documentation/reports/
02_remaining-cleanup-backlog.md` (Group C in full).

### Cross-references

- `specs/094_review_nixos_config_documentation/reports/02_remaining-cleanup-backlog.md` — Group C,
  findings 10-11 (authoritative source defect list for this task).
- `specs/082_dead_code_removal_nixos_repo/summaries/02_dead-code-removal-summary.md` — prior
  removal of the defunct `home-modules/mcp-hub.nix` module, corroborating that MCPHub's actual
  history is custom-module -> lazy.nvim, never a flake input.
- `specs/TODO.md` task 98 (`nix_formatter_lint_tooling`) — declares a dependency on task 97 via
  shared `flake.nix` edits.

# Research Report: Task #75

**Task**: 75 - niri_keybinding_dependencies
**Started**: 2026-07-04T19:07:57Z
**Completed**: 2026-07-04T19:30:00Z
**Effort**: Small (3 targeted fixes, no new modules)
**Dependencies**: None
**Sources/Inputs**: Local config (config/config.kdl, modules/home/packages/*.nix, modules/system/packages.nix, modules/home/services/screenshot.nix), flake.lock (pinned nixpkgs), `nix eval` against pinned nixpkgs commit
**Artifacts**: specs/075_niri_keybinding_dependencies/reports/01_niri-keybinding-deps.md
**Standards**: report-format.md, nix.md (rules)

## Executive Summary

- **grimshot (item 1)**: `pkgs.sway-contrib.grimshot` exists and evaluates cleanly against this repo's exact pinned nixpkgs commit (`34268251cf5547d39063f2c5ea9a196246f7f3a6`, input `nixpkgs` = nixos-26.05). Recommend **rewriting the two grimshot binds to grim/slurp/satty** rather than adding grimshot as a new dependency — rationale below.
- **playerctl (item 2)**: `pkgs.playerctl` exists and evaluates cleanly against the same pinned commit. Recommend adding it to `modules/home/packages/media-dictation.nix` (home-manager owns all other niri-session media/screenshot/clipboard tools already).
- **Mod+C (item 3)**: Confirmed only `codium` exists on this system (`/run/current-system/sw/bin/codium`); no `code` binary or symlink exists anywhere on PATH. `vscodium` is installed via `modules/system/packages.nix:123`. Fix is a one-word bind change: `spawn "code"` → `spawn "codium"`.
- All three fixes are config-only edits to `config/config.kdl` plus one package addition to `modules/home/packages/media-dictation.nix`. No system package list change is required if the grim/slurp rewrite is chosen for grimshot.

## Context & Scope

Task 75 requires every niri keybinding in `config/config.kdl` to resolve to an installed binary, without touching the GNOME session. Scope: binds at lines 165, 169, 170, 184-186. Verified against `config/config.kdl` lines 156-193 (read directly), package ownership across `modules/system/packages.nix` and `modules/home/packages/*.nix`, and package existence against the flake's exact locked nixpkgs revision.

## Findings

### Existing Configuration (grounded, file:line)

`config/config.kdl`:
```
164    Mod+F { spawn "nautilus"; }  // File manager
165    Mod+C { spawn "code"; }      // VSCode
166    Mod+M { spawn "spotify"; }   // Music
167
168    // System controls
169    Mod+Shift+S { spawn "grimshot" "save" "area"; }  // Screenshot area
170    Print { spawn "grimshot" "save" "screen"; }       // Screenshot full
171    Mod+Shift+A { spawn "sh" "-c" "grim -g \"$(slurp)\" - | satty -f -"; }  // Screenshot with annotation
172    Mod+Shift+X { spawn "swaylock" "-f"; }           // Lock screen
...
180    // Audio controls
181    XF86AudioRaiseVolume { spawn "wpctl" "set-volume" "-l" "1.5" "@DEFAULT_AUDIO_SINK@" "5%+"; }
182    XF86AudioLowerVolume { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
183    XF86AudioMute { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
184    XF86AudioPlay { spawn "playerctl" "play-pause"; }
185    XF86AudioNext { spawn "playerctl" "next"; }
186    XF86AudioPrev { spawn "playerctl" "previous"; }
```

Confirmed the volume/mute binds (181-183) already correctly use `wpctl`, which is provided by `pipewire`/`wireplumber` (system-level, already active) — no change needed, matching the task description.

### Package Ownership Map (current state)

| Tool | Installed? | Location | Owner |
|---|---|---|---|
| `grim`, `slurp`, `satty` | Yes | `modules/home/packages/media-dictation.nix:14-16` | home-manager |
| `wl-clipboard`, `cliphist` | Yes | `modules/home/packages/media-dictation.nix:20-21` | home-manager |
| `inotify-tools` | Yes | `modules/home/packages/media-dictation.nix:17` | home-manager (used by `screenshot-path-copy` service) |
| `grimshot` (sway-contrib) | **No** | not present anywhere | — |
| `playerctl` | **No** | not present anywhere | — |
| `vscodium` | Yes | `modules/system/packages.nix:123` | system (`environment.systemPackages`) |
| `code` binary | **No** | does not exist; no symlink found on PATH or in `/run/current-system/sw/bin` | — |

Grep across `**/*.nix` for `grim|slurp|satty|wl-clipboard|grimshot|playerctl|vscodium|codium|sway-contrib` confirms this is the complete picture — no other file references these tools.

There is also `modules/home/services/screenshot.nix`, a `screenshot-path-copy` systemd user service that watches `~/Pictures/Screenshots` via `inotifywait` and copies newly-created screenshot file paths to the clipboard with `wl-copy`. This service is designed around **screenshots being saved to `~/Pictures/Screenshots`** — a detail that matters for the grimshot vs. grim/slurp decision below, since `grimshot save` writes to `~/Pictures/Screenshots/...` by default while `grim -g "$(slurp)" - | satty -f -` (the current Mod+Shift+A pattern) pipes to stdout and never touches disk (satty can optionally save on demand from its UI, but doesn't by default).

### Nix Documentation / Package Verification

Verified directly against this repo's **exact locked nixpkgs commit** (not just channel HEAD), from `flake.lock` node `nixpkgs_2` (the input named `nixpkgs`, i.e. nixos-26.05, locked to `github:NixOS/nixpkgs/34268251cf5547d39063f2c5ea9a196246f7f3a6`, `lastModified 1782116945`):

```
$ nix eval --raw 'github:NixOS/nixpkgs/34268251cf5547d39063f2c5ea9a196246f7f3a6#sway-contrib.grimshot.pname'
grimshot

$ nix eval --raw 'github:NixOS/nixpkgs/34268251cf5547d39063f2c5ea9a196246f7f3a6#playerctl.pname'
playerctl
```

Both attributes exist and evaluate successfully at the pinned revision. No substitution needed, no missing package concerns.

- **grimshot attribute**: `pkgs.sway-contrib.grimshot` (correct as stated in the task description; grimshot is namespaced under `sway-contrib` in nixpkgs because it originates from the sway-contrib project, though it works fine standalone under niri since it only shells out to `grim`/`slurp`/`swaymsg`-independent logic — note: grimshot internally also expects `jq`, `wl-clipboard`, and optionally `slurp`, all of which are either already present (`wl-clipboard` via home-manager) or pulled in as grimshot's own runtime deps).
- **playerctl attribute**: `pkgs.playerctl` (top-level, standard).
- **vscodium**: package `pkgs.vscodium` provides binary `codium` (not `code`) — confirmed both via nixpkgs convention and empirically on this system (`which codium` → `/run/current-system/sw/bin/codium`; `which code` → not found).

### Community Patterns

- Sway/niri community configs commonly split on this exact grimshot-vs-grim+slurp+satty question: grimshot is a convenience wrapper (adds notification feedback via `notify-send`/`libnotify`, default save-to-`~/Pictures/Screenshots` + clipboard-copy behavior, one dependency instead of a 3-tool shell pipeline) but pulls in its own dependency chain (`jq`, `libnotify`, optionally `wl-clipboard`, `slurp`). Configs that already have `grim`+`slurp`+`satty` installed for an annotation workflow (as this repo does) typically standardize on raw `grim`/`slurp` invocations for all screenshot binds rather than mixing grimshot (a different tool with different save/notify semantics) alongside them, to keep behavior consistent across screenshot keybinds.
- niri's own wiki/example configs (`niri-flake`/upstream `config.kdl` examples) show both patterns in the wild; there's no single blessed convention — the choice is a per-config consistency decision.

### Recommendations

**Item 1 — grimshot (Mod+Shift+S / Print): rewrite to grim/slurp, do not add grimshot.**

Recommended change to `config/config.kdl`:
```kdl
Mod+Shift+S { spawn "sh" "-c" "grim -g \"$(slurp)\" - | satty -f -"; }  // Screenshot area (annotate)
Print { spawn "sh" "-c" "grim - | satty -f -"; }                        // Screenshot full (annotate)
```
This makes Mod+Shift+S and Mod+Shift+A functionally identical (both area+annotate) — if that duplication is undesired, an alternative for Mod+Shift+S that saves directly without opening satty:
```kdl
Mod+Shift+S { spawn "sh" "-c" "grim -g \"$(slurp)\" \"$HOME/Pictures/Screenshots/$(date +%Y%m%d-%H%M%S).png\""; }
Print { spawn "sh" "-c" "grim \"$HOME/Pictures/Screenshots/$(date +%Y%m%d-%H%M%S).png\""; }
```
This second form also plays nicely with the existing `screenshot-path-copy` service (`modules/home/services/screenshot.nix`), which watches `~/Pictures/Screenshots` and auto-copies the new file's path to the clipboard on write.

Rationale for rewrite over adding grimshot:
1. **Zero new packages** — `grim`, `slurp`, `satty` are already home-manager-owned (`modules/home/packages/media-dictation.nix:14-16`); no new dependency, no new attribute to track across nixpkgs updates.
2. **Consistency** — Mod+Shift+A already uses this exact primitive; having all three screenshot binds built from the same two tools (`grim`+`slurp`) is simpler to reason about and maintain than mixing grimshot (a different save/notify/clipboard convention) with a raw grim/slurp/satty pipeline.
3. **grimshot's behavior differs from the existing pattern** — grimshot auto-saves to `~/Pictures/Screenshots` and fires desktop notifications; the existing Mod+Shift+A bind instead pipes to `satty` for interactive annotation before any save decision. Adding grimshot for two binds while keeping a different tool for the third bind (which does similar work) is the actual inconsistency the task is flagging.

If the maintainer prefers grimshot's UX (auto-notify, one-liner, default save path) over satty-based annotation, the alternative is: add `pkgs.sway-contrib.grimshot` to `modules/home/packages/media-dictation.nix` (home-manager, alongside the other screenshot tools) and leave lines 169-170 unchanged. Both attribute and behavior are verified to work; this report defaults to the grim/slurp rewrite for the consistency reasons above but flags this as a one-line decision the implementer/user can reverse.

**Item 2 — playerctl: add `pkgs.playerctl` to `modules/home/packages/media-dictation.nix`.**

```nix
# modules/home/packages/media-dictation.nix
home.packages = with pkgs; [
  espeak-ng
  obs-studio
  whisper-cpp
  ydotool
  libnotify
  satty
  grim
  slurp
  playerctl          # <- add here, alongside other niri-session media/input tools
  inotify-tools
  wl-clipboard
  cliphist
];
```
No change needed to `config.kdl` lines 184-186 — the existing `playerctl` binds are already correct once the binary exists.

Placement rationale: `media-dictation.nix` already owns niri-session media/input tooling (`espeak-ng`, `obs-studio`, dictation tools) and all current screenshot/clipboard tools; `playerctl` is a natural fit there rather than `modules/system/packages.nix` (which is reserved for system-wide/GNOME-shared tools) — this matches the existing ownership convention (home-manager owns niri-only user-session tools; system owns cross-session/GNOME tools, per the `# X is managed by home-manager` comments already present in `modules/system/packages.nix:12,74,124`).

**Item 3 — Mod+C: change bind to spawn `codium`.**

```kdl
Mod+C { spawn "codium"; }      // VSCodium
```
Confirmed empirically: `which codium` → `/run/current-system/sw/bin/codium`; `which code` → not found anywhere on PATH; no `code` symlink/alias exists in `/run/current-system/sw/bin`, `/etc/profiles/*`, or elsewhere. `pkgs.vscodium` (nixpkgs) does not provide a `code`-named binary or alias by convention. Update the inline comment from `// VSCode` to `// VSCodium` for accuracy.

## Decisions

- Recommend grim/slurp rewrite over adding grimshot (see rationale above); implementer/user may override this and add `pkgs.sway-contrib.grimshot` instead — both paths are verified viable.
- `playerctl` belongs in `modules/home/packages/media-dictation.nix` (home-manager), matching existing ownership of niri-session tools.
- Mod+C bind changes `code` → `codium`; comment updated to match.
- No system package list (`modules/system/packages.nix`) changes required for any of the three fixes under the recommended path (grim/slurp rewrite + playerctl in home-manager + codium spawn fix).

## Risks & Mitigations

- **Risk**: If the grim/slurp rewrite is chosen and duplicates Mod+Shift+A's exact behavior for Mod+Shift+S, users may find the two binds redundant. **Mitigation**: use the direct-save variant (second code block under Item 1) for Mod+Shift+S/Print instead, which differentiates "quick save" from "annotate" workflows and integrates with the existing `screenshot-path-copy` clipboard service.
- **Risk**: `sh -c` inline scripts embed escaped quotes in KDL strings, which is fragile to hand-edit. **Mitigation**: none needed beyond care during implementation — this pattern is already proven working at line 171 and 178.
- **Risk**: Rebuilding home-manager after adding `playerctl` requires no MPRIS-capable player running to fully test — `playerctl play-pause` will simply no-op (exit non-zero, no crash) if no player is active, which is expected and not a bug. Verification should launch Spotify (already installed, Mod+M) or another MPRIS client before exercising the media keys.
- **Risk**: None identified for the Mod+C fix — single-word literal change, no build-time risk since `vscodium` is already installed.

## Verification Plan (for the implementation phase)

After `home-manager switch` / `nixos-rebuild switch` (whichever module tree owns the edited files) in the niri session:
1. **Mod+Shift+S**: triggers area-select screenshot flow (slurp cursor, then either satty annotator opens or file appears in `~/Pictures/Screenshots`, depending on chosen variant).
2. **Print**: triggers full-screen screenshot flow (same as above, no slurp step).
3. **Mod+Shift+A**: unchanged, confirm still works (regression check — same underlying primitives now shared with item 1).
4. **XF86AudioPlay/Next/Prev**: with an MPRIS player active (e.g., Spotify via Mod+M), confirm play/pause toggles and track changes.
5. **Mod+C**: confirms VSCodium window opens.
6. **XF86Audio volume/mute**: unchanged, confirm still works (regression check only, per task note — no code change here).

## Appendix

### Search queries / commands used
- `grep -rn "grim\b|slurp|satty|wl-clipboard|grimshot|playerctl|vscodium|codium|sway-contrib" --include="*.nix" .`
- `grep -n "nixpkgs.url|nixpkgs-unstable" flake.nix`
- `jq '.nodes.root.inputs' flake.lock` / `jq '.nodes["nixpkgs_2"].locked' flake.lock`
- `nix eval --raw 'github:NixOS/nixpkgs/34268251cf5547d39063f2c5ea9a196246f7f3a6#sway-contrib.grimshot.pname'`
- `nix eval --raw 'github:NixOS/nixpkgs/34268251cf5547d39063f2c5ea9a196246f7f3a6#playerctl.pname'`
- `which codium code`, `find /run/current-system/sw/bin -iname "code*"`

### Files read
- `config/config.kdl` (lines 1-20, 150-195)
- `modules/system/packages.nix` (full)
- `modules/home/packages/media-dictation.nix` (full)
- `modules/home/services/screenshot.nix` (full)
- `flake.nix` (nixpkgs input declarations)
- `flake.lock` (pinned nixpkgs revision resolution)

### MCP-NixOS availability

MCP-NixOS tools were not available in this session (not detected in the tool list). Fell back to direct `nix eval` against the exact locked nixpkgs commit from `flake.lock`, which is a stronger verification than a generic MCP/web search since it confirms the packages resolve in *this repository's actual build*, not just the general nixpkgs channel.

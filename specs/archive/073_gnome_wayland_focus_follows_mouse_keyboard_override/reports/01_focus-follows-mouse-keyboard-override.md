# Research Report: Task #73

**Task**: 73 - GNOME/Wayland focus-follows-mouse overrides keyboard focus switches
**Started**: 2026-07-03T00:00:00Z
**Completed**: 2026-07-03T00:00:00Z
**Effort**: ~2 hours (research only)
**Dependencies**: None
**Sources/Inputs**: GNOME GitLab issues/MRs, gsettings-desktop-schemas source, Mutter source, GNOME Shell Extensions site, GitHub extension repos, nixpkgs search
**Artifacts**: - specs/073_gnome_wayland_focus_follows_mouse_keyboard_override/reports/01_focus-follows-mouse-keyboard-override.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The prior fix attempt (`focus-mode = "sloppy"` + `focus-change-on-pointer-rest = false`) failed because **neither key controls the behavior being fought**. `focus-change-on-pointer-rest` only delays the *initial* focus grab while the pointer is still moving through/into a window; it does nothing once the pointer is already stationary over a window, which is exactly the reported scenario (mouse rests over window A, keyboard switches to window B, focus snaps back to A).
- The root cause is architectural, not a misconfigured setting: Mutter's "sloppy"/"mouse" focus modes maintain an invariant — "whatever window is under the pointer has focus" — and **re-assert that invariant on internal events** (workspace switches, Alt-Tab completions, window raises), not only on genuine pointer motion. This is a long-standing, largely by-design limitation tracked upstream (GNOME Shell issue #134, Mutter issues #318/#2058/#888), with only narrow sub-cases patched (Mutter MR !2828, merged for GNOME 44, fixed a specific Wayland Alt-Tab regression, not the general "keyboard focus should persist until real mouse motion" behavior).
- **There is no native dconf/GSettings key that implements the desired hybrid** (hover-to-focus, but keyboard-selected focus persists until the next real pointer motion). This must be approximated with a GNOME Shell extension.
- **Recommended approach**: keep `focus-mode = "sloppy"` (hover-to-focus preserved) and add the **`mouse-follows-focus` GNOME Shell extension** (`pkgs.gnomeExtensions.mouse-follows-focus`, extensions.gnome.org #4642), which warps the pointer to the center of any window that gains focus via keyboard. This sidesteps the conflict entirely: because the pointer is moved to be *over* the keyboard-focused window, Mutter's sloppy-focus invariant is already satisfied when it re-evaluates, so it does not snap back. This is installable via the existing Home Manager dconf pattern already used in this repo (`modules/home/desktop/gnome.nix` + `modules/home/packages/dev-tools.nix`).
- The exact "yield to keyboard until next real motion, no cursor movement" behavior is **not fully achievable natively on Wayland** without either (a) a Mutter patch, or (b) accepting a visible pointer warp (the recommended extension) or (c) giving up hover-focus for keyboard-focused windows (fallback: `focus-mode = "click"` or per-window-class rules, which sacrifices focus-follows-mouse).

## Context & Scope

Researched why GNOME 46+/Mutter on Wayland, configured via Home Manager dconf in `modules/home/desktop/gnome.nix`, keeps re-focusing whatever window is under a *stationary* mouse pointer even after a keyboard shortcut explicitly switches focus to a different window — despite `focus-mode=sloppy` and `focus-change-on-pointer-rest=false` already being set. Scope: GSettings/Mutter semantics, upstream bug history, extension-based workarounds, and a concrete, dconf-expressible recommendation for `/plan`.

### Confirmed Environment

- `XDG_SESSION_TYPE=wayland`, compositor = Mutter (GNOME Shell).
- Config surface: Home Manager `dconf.settings` in `modules/home/desktop/gnome.nix` (lines 65-93 at time of research).
- `flake.nix` pins `nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05"` — a recent nixpkgs channel, implying a current GNOME release (GNOME ≥ 47) is in use, which already includes the GNOME 44-era Wayland sloppy-focus fix (MR !2828) but not a fix for the general keyboard-vs-hover conflict (that remains open upstream, see below).
- Existing extensions already enabled via this same dconf pattern: `activate-window-by-title@lucaswerkmeister.de`, `unite@hardpixel.eu` — confirming this repo already has a working pattern for installing + enabling GNOME Shell extensions via Home Manager (`home.packages` + `dconf.settings."org/gnome/shell".enabled-extensions`), which the recommendation below reuses directly.

## Findings

### Why the Prior Attempt Failed

**`org/gnome/mutter` `focus-change-on-pointer-rest`** — exact schema semantics (Mutter `org.gnome.mutter.gschema.xml.in`):

> Summary: "Delay focus changes until the pointer stops moving"
> Description: "If set to true, and the focus mode is either 'sloppy' or 'mouse' then the focus will not be changed immediately when entering a window, but only after the pointer stops moving."

Key phrase: **"when entering a window."** This setting only governs the transient case where the pointer is passing *through* windows in transit to somewhere else — it prevents focus flicker during that transit by waiting for the pointer to stop before committing a focus change. It has no effect once the pointer has already come to rest over a window (the steady-state case). In the reported bug, the pointer is *already resting* over window A when the keyboard switch to window B happens — there is no new "entering" event for `focus-change-on-pointer-rest` to gate. Setting it to `true` instead of `false` would not fix this symptom; it only reduces flicker while the mouse is moving across the screen. This closes off hypothesis #1 as posed in the task: **`true` would not have helped** — the setting is orthogonal to the reported bug, not merely mis-set.

**`org/gnome/desktop/wm/preferences` `focus-mode`** — exact schema semantics (`gsettings-desktop-schemas` `org.gnome.desktop.wm.preferences.gschema.xml.in`):

> "The window focus mode indicates how windows are activated. It has three possible values; 'click' means windows must be clicked in order to focus them, 'sloppy' means windows are focused when the mouse enters the window, and 'mouse' means windows are focused when the mouse enters the window and unfocused when the mouse leaves the window."

- `click`: focus only changes on explicit click (or keyboard) — no hover-focus at all.
- `sloppy`: hover-to-focus, but a window can remain focused with no window focused when pointer is over empty space/desktop.
- `mouse`: hover-to-focus *and* focus is cleared when the pointer leaves the window (stricter than sloppy).

None of the three values has any notion of "keyboard focus takes precedence until the next real pointer motion." `sloppy` is the closest to the user's base preference (hover-to-focus) and is already selected — it is the right choice to keep, but it cannot alone produce the desired hybrid.

### Root Cause (Upstream Confirmation)

- **GNOME Shell issue #134** ("mouse and sloppy focus defeat alt-tab") is the closest match to the exact symptom. Description (paraphrased from the issue): with sloppy/mouse focus enabled, keyboard shortcuts (Alt-Tab, or any keyboard-driven `activate()`) produce only a *transient* focus effect that is immediately overridden by the pointer's position, because the desired behavior — "the mouse should only trigger a focus change when it is moved sufficiently far to effect a change in focus" — is not what Mutter implements. Mutter's own event loop re-evaluates "what window is under the pointer" on internal events unrelated to genuine motion (e.g., after a keyboard-driven `Meta.Display` focus/raise call), and re-applies sloppy focus using the pointer's last known (stationary) coordinates. This has been an open, largely unaddressed design gap reported since at least GNOME 3.14.
  https://gitlab.gnome.org/GNOME/gnome-shell/-/work_items/134
- **Mutter issue #2058** ("Sloppy focus was broken when Alt-Tab with a different workspace") documents the same conflict specifically for cross-workspace Alt-Tab, on both X11 and Wayland (reported against Mutter 41.2). No fix confirmed in the fetched content.
  https://gitlab.gnome.org/GNOME/mutter/-/issues/2058
- **Mutter issue #318** ("3.30 alt+tab sloppy window focus") — same family of regression reported in the 3.30 era, renamed at the time to "focus on hover."
  https://gitlab.gnome.org/GNOME/mutter/-/issues/318
- **Mutter issue #888 / merge request !2828** ("Fix Sloppy/mouse focus mode on Wayland", merged for **GNOME 44**) fixed a related-but-narrower Wayland-specific regression where sloppy/mouse focus was broken more fundamentally on Wayland compositors. Since this repo tracks nixpkgs `nixos-26.05` (GNOME ≥ 47), this specific fix is already present — which is consistent with the user's baseline hover-focus otherwise working correctly, and *only* the keyboard-override case remaining broken (the narrower #134/#2058 class of bug, not the #888 class).
  https://www.mail-archive.com/debian-bugs-dist@lists.debian.org/msg1902641.html (references #888 / !2828)
- **Mutter issue #3103** ("Using key binding to lower window retains focus") — additional evidence that keybinding-driven focus/stacking changes and Mutter's continuous pointer-based re-evaluation are known to interact in surprising, still-being-litigated ways in current Mutter.
  https://gitlab.gnome.org/GNOME/mutter/-/issues/3103

**Conclusion**: the exact symptom described in this task (keyboard switch instantly overridden by a *stationary* pointer) is a recognized upstream architectural gap, not a misconfiguration. There is no GSettings/dconf key — current or historical — that changes this invariant-re-assertion behavior. It has never been fixed at the "give keyboard focus a grace period against a stationary pointer" level; only narrower regressions (full breakage of sloppy focus on Wayland; specific Alt-Tab-across-workspace glitches) have upstream fixes.

### Candidate Approaches (Ranked)

#### 1. RECOMMENDED — `mouse-follows-focus` GNOME Shell extension (warp pointer to keyboard-focused window)

- **Mechanism**: Extension listens for `global.display` focus-window-changed events. When focus changes via a non-pointer path (keyboard shortcut, `wmctrl`/`activate-window-by-title`, etc.) and the pointer is not already inside the newly focused window's bounds, it warps the pointer to the window's center.
- **Why it fixes the reported bug**: Mutter's sloppy-focus invariant ("pointer is over the focused window") is never violated in the first place — the pointer is moved to match keyboard-driven focus instead of fighting Mutter's re-assertion of focus based on stale pointer position. This is a workaround for the exact upstream gap in GNOME Shell #134, using a different lever (move the mouse) rather than trying to suppress Mutter's re-evaluation (which has no exposed toggle).
- **Package / keys**:
  - `pkgs.gnomeExtensions.mouse-follows-focus` (confirmed present in nixpkgs — same install pattern as `gnomeExtensions.activate-window-by-title` already used in `modules/home/packages/dev-tools.nix`).
  - Add `"mouse-follows-focus@leon-marker.github.io"` (verify exact extension UUID once installed — GNOME extension UUIDs are author-domain-based, confirm via `gnome-extensions list` or the extracted extension's `metadata.json` before writing the dconf key) to `org/gnome/shell.enabled-extensions` in `modules/home/desktop/gnome.nix`, alongside the existing `activate-window-by-title@lucaswerkmeister.de` and `unite@hardpixel.eu` entries.
  - Keep `focus-mode = "sloppy"` (hover-focus preserved for genuine mouse-driven navigation).
  - `focus-change-on-pointer-rest` can stay `false` (or optionally `true` — harmless either way; only affects transit flicker, not this bug).
- **Wayland feasibility**: GNOME Shell extensions run inside the Mutter/GNOME Shell compositor process itself, so they have access to privileged Clutter/Mutter pointer-warp APIs unavailable to ordinary Wayland clients (which cannot warp the pointer due to Wayland's security model). This is confirmed by two independently-maintained implementations:
  - `LeonMatthes/mousefollowsfocus` (extensions.gnome.org #4642), GNOME Shell 41–47 support, in-process warp, no external helper binary needed. https://github.com/LeonMatthes/mousefollowsfocus , https://extensions.gnome.org/extension/4642/mouse-follows-focus/
  - `crisidev/mouse-follows-focus`, GNOME Shell 45/46+, multi-monitor aware, but this fork chose to shell out to an external `input-emulator` tool for relative pointer movement (citing unreliable absolute positioning); notes a known limitation with mismatched-resolution multi-monitor layouts and that some XWayland windows don't obey normal focus rules. https://github.com/crisidev/mouse-follows-focus
  - A third-party blog post on implementing this independently confirms Wayland pointer-warping is restrictive for ordinary apps but documents both the in-process Clutter approach and the external-emulator fallback. https://sebastian-hans.de/blog/mouse-follows-window-gnome-extension/
  - **Recommendation**: prefer `LeonMatthes/mousefollowsfocus` (the one packaged in nixpkgs as `gnomeExtensions.mouse-follows-focus`) since it needs no extra runtime dependency/permission (no uinput device access), which fits better with a declarative Home Manager setup.
- **Expected behavior vs. desired hybrid**: Matches the desired behavior closely — mouse-driven hover-focus is unchanged; keyboard-driven focus switches "win" because the pointer relocates to match. The one visible deviation from the literal request ("focus must stay... and NOT jump back... " with no mention of the cursor itself moving) is that **the mouse cursor visibly jumps to the window center** on every keyboard-driven focus change. This is a cosmetic side effect, not a functional gap — no hover-then-instant-refocus fighting occurs.
- **Tradeoffs/risks**: Cursor warps on every keyboard focus switch (may feel intrusive to users who don't want the cursor to move at all); multi-monitor edge cases per the crisidev fork's notes; verify the exact UUID/options exposed by the nixpkgs-packaged version before writing the plan (some forks expose config for exclusion zones / warp thresholds, others do not).

#### 2. Fallback — switch to `focus-mode = "click"` (or `"mouse"`) for keyboard-heavy workflows

- **Mechanism**: `click` disables hover-to-focus entirely; only explicit clicks (or keyboard shortcuts) change focus. `mouse` is stricter than `sloppy` (unfocuses on leave) but shares the same underlying re-assertion behavior and therefore does **not** fix the reported bug — it would still snap back to whatever (if any) window is under a resting pointer, and additionally unfocuses everything when the pointer is over the desktop/gaps.
- **Wayland feasibility**: Fully native, one dconf key, already in the schema the repo uses.
- **Expected behavior vs. desired hybrid**: `click` fully satisfies "keyboard focus must not be overridden by the pointer," but at the cost of losing hover-to-focus entirely — this is not a hybrid, it is abandoning half the requirement. `mouse` does not solve the bug at all (still re-asserts on a resting pointer) and is strictly worse than `sloppy` for this use case.
- **Tradeoffs/risks**: `click` is the "safe, fully native, zero extra dependency" fallback if the extension approach (#1) proves unreliable, but it changes daily hover-focus behavior repo-wide, which the user explicitly wants to keep.

#### 3. Not recommended — try to tune existing Mutter/WM keys further (auto-raise, raise-on-click)

- **Mechanism/keys examined**: `org/gnome/desktop/wm/preferences` `auto-raise` ("If true, and focus-mode is sloppy/mouse, the focused window is automatically raised after `auto-raise-delay` ms — unrelated to click-to-raise or drag-and-drop"), `auto-raise-delay` (ms), `raise-on-click` ("if false, clicking a window's client area does not raise it; Super-click or frame-click still does — useful with many overlapping windows"). None of these are currently set in `gnome.nix` (repo relies on schema defaults).
- **Why it doesn't help**: These three keys govern window *stacking/raising* on top of an already-decided focus state; they do not affect *which* window is chosen as focused when the pointer is stationary after a keyboard switch. They are orthogonal to the reported bug and were investigated (per the task's research question #7) and ruled out as a fix, though `auto-raise=true` (if ever enabled) could compound *visual* confusion by raising the hover window without focusing it, which is a separate, minor risk worth noting if these keys are touched for unrelated reasons later.
- **Verdict**: Ruled out. No plan action needed on these keys.

#### 4. Not recommended — patch/rebuild Mutter

- **Mechanism**: Since the root cause is in Mutter's C source (focus re-evaluation is not gated on "genuine pointer motion since last keyboard focus change"), a from-source Mutter patch adding that gate would be the most "correct" fix.
- **Feasibility**: Technically possible via a nixpkgs overlay (`mutter.overrideAttrs` with a custom patch), but high effort/high risk: no known existing patch was found upstream (the GNOME Shell #134 issue remains open with no attached MR), so this would require writing and maintaining novel Mutter C code and rebuilding a core system compositor package — clearly disproportionate for a desktop-experience preference. Rejected for this task; only worth reconsidering if extension-based approaches prove unworkable and the user is willing to maintain an out-of-tree Mutter patch across GNOME upgrades.

### Honest Assessment of Full Native Feasibility

The **exact** desired hybrid — "hover changes focus, but a keyboard-selected focus is fully inert to the stationary pointer and only yields on the next *genuine* pointer motion, with no other side effects (e.g., no cursor warp)" — is **not achievable natively** on current GNOME/Mutter via any GSettings/dconf key, on Wayland or X11. This is a confirmed, still-open upstream gap (GNOME Shell #134), not a documentation or configuration miss. The closest practical approximation is the `mouse-follows-focus` extension (candidate #1), which achieves the same practical outcome (keyboard switches "stick") at the cost of a visible, intentional cursor warp — a different, but from a workflow perspective equivalent-or-better, side effect than the current bug (an *invisible* refocus that silently defeats keyboard navigation).

## Decisions

- Treat `focus-change-on-pointer-rest` and `focus-mode` as correctly-set-but-insufficient; do not re-tune them further as part of the fix.
- Do not pursue a Mutter source patch (disproportionate effort/risk for a desktop preference).
- Recommend the `mouse-follows-focus` extension as the primary fix path for `/plan`, with `focus-mode = "click"` documented as an explicit, low-risk fallback if the extension is rejected by the user (e.g., due to disliking cursor warps) or proves buggy in practice.

## Risks & Mitigations

- **Risk**: Exact extension UUID/package name mismatch (multiple similarly-named "mouse follows focus" projects exist: `LeonMatthes/mousefollowsfocus` vs. `crisidev/mouse-follows-focus`, and the nixpkgs attribute may package only one of them). **Mitigation**: during `/plan`/implementation, confirm via `nix eval` / `gnome-extensions info` after installing which UUID and version nixpkgs' `gnomeExtensions.mouse-follows-focus` actually provides, before hardcoding the UUID into `enabled-extensions`.
- **Risk**: Cursor-warp side effect may be undesirable to the user (task description does not explicitly rule this out but also does not ask for it). **Mitigation**: flag this explicitly for user confirmation before implementation; offer `focus-mode = "click"` as a no-side-effect fallback.
- **Risk**: Multi-monitor / mismatched-resolution warp glitches reported by the `crisidev` fork. **Mitigation**: since nixpkgs likely packages `LeonMatthes/mousefollowsfocus` (in-process Clutter warp, simpler, more actively the "canonical" extensions.gnome.org listing), this specific risk is lower, but should be verified against the user's actual monitor layout during implementation testing.
- **Risk**: GNOME version drift (`nixos-26.05` channel) could ship a GNOME/Mutter version where extension APIs (`global.display` signals, Clutter seat warp) have changed. **Mitigation**: verify extension "supported GNOME Shell versions" metadata matches the installed `gnome-shell --version` before enabling; nixpkgs will already refuse to build an incompatible extension pairing in most cases.

## Appendix

### Search Queries Used

- `mutter focus-change-on-pointer-rest gsettings semantics`
- `gitlab.gnome.org mutter focus-mode sloppy keyboard focus overridden by pointer wayland`
- `mutter sloppy focus alt-tab fixed 2024 2025 gitlab merge request`
- `extensions.gnome.org focus follows mouse extension keyboard override`
- `gnome mutter "auto-raise" "raise-on-click" focus-mode wm preferences dconf`
- `org.gnome.desktop.wm.preferences focus-mode schema description "sloppy" "mouse" "click" gsettings`
- `"mousefollowsfocus" gnome extension wayland warp pointer global.display.set_input_focus`
- `search.nixos.org gnomeExtensions mouse-follows-focus package`

### Primary References

- Mutter GSettings schema (source of truth for `focus-change-on-pointer-rest`): https://github.com/GNOME/mutter/blob/main/data/org.gnome.mutter.gschema.xml.in
- gsettings-desktop-schemas (source of truth for `focus-mode`, `auto-raise`, `auto-raise-delay`, `raise-on-click`): https://github.com/GNOME/gsettings-desktop-schemas/blob/master/schemas/org.gnome.desktop.wm.preferences.gschema.xml.in
- GNOME Shell issue #134 (root cause, open): https://gitlab.gnome.org/GNOME/gnome-shell/-/work_items/134
- Mutter issue #2058 (sloppy focus vs. cross-workspace Alt-Tab): https://gitlab.gnome.org/GNOME/mutter/-/issues/2058
- Mutter issue #318 (3.30-era regression): https://gitlab.gnome.org/GNOME/mutter/-/issues/318
- Mutter issue #888 / MR !2828 (Wayland sloppy/mouse focus fix, merged GNOME 44): https://www.mail-archive.com/debian-bugs-dist@lists.debian.org/msg1902641.html
- Mutter issue #3103 (keybinding-driven focus/lower interaction): https://gitlab.gnome.org/GNOME/mutter/-/issues/3103
- `mouse-follows-focus` extension (recommended): https://extensions.gnome.org/extension/4642/mouse-follows-focus/ , https://github.com/LeonMatthes/mousefollowsfocus
- Alternative fork with external-emulator Wayland warp approach: https://github.com/crisidev/mouse-follows-focus
- Independent technical writeup of the warp mechanism and Wayland caveats: https://sebastian-hans.de/blog/mouse-follows-window-gnome-extension/
- nixpkgs packaging confirmation: https://mynixos.com/nixpkgs/package/gnomeExtensions.mouse-follows-focus

### Local Repo Grounding

- `modules/home/desktop/gnome.nix` lines 65-93 (current focus-related dconf state, read verbatim during this research).
- `modules/home/packages/dev-tools.nix` line 12 (existing pattern: `gnomeExtensions.activate-window-by-title` installed as a package, then enabled via dconf — same pattern to reuse for `mouse-follows-focus`).
- `flake.nix` line 8 (`nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05"` — confirms a recent GNOME release, meaning the GNOME 44 Wayland sloppy-focus fix is already present, isolating the remaining bug to the narrower keyboard-override case documented above).

## Next Steps for `/plan`

1. Add `pkgs.gnomeExtensions.mouse-follows-focus` to the relevant Home Manager package list (likely alongside `gnomeExtensions.activate-window-by-title` in `modules/home/packages/dev-tools.nix`, or directly in `gnome.nix` if that's the established convention — check both before choosing).
2. Add the extension's UUID to `dconf.settings."org/gnome/shell".enabled-extensions` in `modules/home/desktop/gnome.nix`, verifying the exact UUID string post-install (do not guess it blindly into the plan).
3. Leave `focus-mode = "sloppy"` and `focus-change-on-pointer-rest = false` unchanged (both are correct/harmless; neither is the bug).
4. Document `focus-mode = "click"` as the fallback in the plan, to be applied only if the user rejects the cursor-warp behavior after testing.
5. During implementation, test explicitly: (a) hover-to-focus still works for pure mouse navigation, (b) a keyboard focus switch (e.g., existing `cycle-windows` / `<Super>space` keybinding already defined in `gnome.nix`) to a window not under the pointer results in focus *staying* there, with the cursor visibly warping to it, (c) repeat with the pointer resting over a *third*, uninvolved window to confirm the original bug (instant snap-back) no longer reproduces.
6. Flag to the user during planning that the fix necessarily introduces a visible cursor warp on keyboard focus changes, since this is a behavioral trade-off, not just an implementation detail.

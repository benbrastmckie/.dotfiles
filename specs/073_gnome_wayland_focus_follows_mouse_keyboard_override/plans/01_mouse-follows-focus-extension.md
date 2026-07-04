# Implementation Plan: Task #73

- **Task**: 73 - GNOME/Wayland focus-follows-mouse overrides keyboard focus switches
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/073_gnome_wayland_focus_follows_mouse_keyboard_override/reports/01_focus-follows-mouse-keyboard-override.md
- **Artifacts**: plans/01_mouse-follows-focus-extension.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, nix.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Fix the GNOME/Wayland bug where a stationary mouse pointer re-asserts sloppy focus and overrides keyboard-driven focus switches. Per the research report and the user's LOCKED decision, the fix installs and enables the `mouse-follows-focus` GNOME Shell extension (`pkgs.gnomeExtensions.mouse-follows-focus`), which warps the pointer to any window that gains focus via a non-pointer path (keyboard shortcut). This satisfies Mutter's sloppy-focus invariant instead of fighting it, so focus "sticks". The existing `focus-mode = "sloppy"` and `focus-change-on-pointer-rest = false` settings are correct and are intentionally left unchanged; the rejected `focus-mode = "click"` fallback is NOT applied. The plan follows the repo's established two-file pattern (package in `dev-tools.nix`, UUID in `gnome.nix` `enabled-extensions`), and requires the exact extension UUID to be verified from the built package rather than hardcoded blindly.

### Research Integration

Key findings integrated from `reports/01_focus-follows-mouse-keyboard-override.md`:
- Root cause is an upstream Mutter/GNOME Shell architectural gap (GNOME Shell issue #134, Mutter #318/#2058), not a misconfiguration. No native dconf/GSettings key implements the desired hybrid.
- `focus-change-on-pointer-rest` only gates focus while the pointer is *entering/moving through* a window; it has no effect on a stationary pointer, which is exactly the reported scenario. Re-tuning it would not help. Leave it as `false`.
- Recommended fix (report candidate #1): keep `focus-mode = "sloppy"` and add the `mouse-follows-focus` extension, which warps the pointer to the keyboard-focused window.
- The repo already enables extensions via the exact pattern to reuse: `home.packages` (`gnomeExtensions.activate-window-by-title` in `dev-tools.nix`) plus `dconf.settings."org/gnome/shell".enabled-extensions` in `gnome.nix` (currently `activate-window-by-title@lucaswerkmeister.de`, `unite@hardpixel.eu`).
- The exact UUID must be verified post-install (report Next Steps #2 and Risks): multiple similarly-named projects exist (`LeonMatthes/mousefollowsfocus` vs `crisidev/mouse-follows-focus`); do not hardcode a guessed UUID.
- Known behavioral trade-off (report finding, flagged to user): the cursor visibly warps to the focused window on every keyboard focus change. This is intentional and accepted per the user's decision.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this dispatch (no roadmap flag provided).

## Goals & Non-Goals

**Goals**:
- Install `pkgs.gnomeExtensions.mouse-follows-focus` via the existing package-install pattern in `modules/home/packages/dev-tools.nix`.
- Discover the exact extension UUID from the built package (not a guess) and enable it in `dconf.settings."org/gnome/shell".enabled-extensions` in `modules/home/desktop/gnome.nix`.
- Verify the Home Manager configuration builds/switches cleanly.
- Confirm via manual testing that keyboard focus switches now "stick" (cursor warps to the focused window) and that the original snap-back bug no longer reproduces, while hover-to-focus still works.

**Non-Goals**:
- Do NOT apply `focus-mode = "click"` (explicitly rejected fallback).
- Do NOT change `focus-mode = "sloppy"` or `focus-change-on-pointer-rest = false`.
- Do NOT patch/rebuild Mutter or touch `auto-raise`/`raise-on-click` keys.
- Do NOT alter the existing `unite`/`activate-window-by-title` extension entries or their settings.

## Preserved Assets

The following are intentionally left AS-IS and must not be modified by this implementation:
- `org/gnome/desktop/wm/preferences`.`focus-mode = "sloppy"` (gnome.nix line ~66) — hover-to-focus is a deliberate base preference and is correct.
- `org/gnome/mutter`.`focus-change-on-pointer-rest = false` (gnome.nix line ~88) — orthogonal to this bug; leaving it as-is is deliberate.
- Existing `enabled-extensions` entries `activate-window-by-title@lucaswerkmeister.de` and `unite@hardpixel.eu` (gnome.nix lines ~9-10) — only append the new UUID; do not reorder or remove.
- The existing `gnomeExtensions.activate-window-by-title` package line in dev-tools.nix — new package is added alongside it.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Wrong/guessed UUID written to `enabled-extensions` (multiple similarly-named projects) | M | M | Phase 2 obtains the real UUID from the built package's `metadata.json` / `gnome-extensions list`; the UUID is a filled-in placeholder, never hardcoded blindly |
| Extension incompatible with installed GNOME Shell version (nixpkgs channel drift) | M | L | Check `gnome-shell --version` against the extension's `shell-version` in `metadata.json` during Phase 2; nixpkgs generally refuses incompatible pairings |
| Cursor-warp side effect undesirable to user | L | L | Already flagged and accepted per user's LOCKED decision; documented in Overview. `focus-mode = "click"` remains a documented (unapplied) fallback only if user later rejects |
| Extension enabled but not active until GNOME Shell reload on Wayland | L | H | Phase 5 notes that a GNOME Shell restart / re-login is required on Wayland before behavioral testing |
| Multi-monitor / mismatched-resolution warp glitch | L | L | Verify against actual monitor layout during Phase 5; nixpkgs packages the in-process Clutter variant (lower risk) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |

Phases within the same wave can execute in parallel. This plan is a strictly sequential chain (each phase depends on the artifact of the prior), so waves are single-phase.

### Phase 1: Add the mouse-follows-focus package [IN PROGRESS]

**Goal**: Install the extension package following the repo's established package convention.

**Tasks**:
- [x] In `modules/home/packages/dev-tools.nix`, under the `# GNOME Shell Extensions` comment block (currently line ~11-12), add `gnomeExtensions.mouse-follows-focus` on its own line alongside the existing `gnomeExtensions.activate-window-by-title`. *(deviation: altered — the exact attribute name in the pinned nixpkgs is `gnomeExtensions.mouse-follows-focus-2`, not `mouse-follows-focus`; `nix eval` confirmed `mouse-follows-focus` is missing and suggested `mouse-follows-focus-2`, which resolves to `gnome-shell-extension-mouse-follows-focus` v12, homepage `https://extensions.gnome.org/extension/7656/mouse-follows-focus/` — the correct, actively packaged extension)*
- [x] Add a brief inline comment (e.g. `# Warp pointer to keyboard-focused window (task 73: focus-follows-mouse vs keyboard fix)`).
- [x] Preserve 2-space indentation and existing formatting per nix.md.

**Timing**: 0.2 hours

**Depends on**: none

**Files to modify**:
- `modules/home/packages/dev-tools.nix` - add one package line in the GNOME Shell Extensions group.

**Verification**:
- The new line is present, correctly indented, and does not disturb existing entries.
- `nix eval .#homeConfigurations.benjamin.config.home.packages --apply builtins.length` (or a later full build) resolves the attribute without an "attribute missing" error, confirming `gnomeExtensions.mouse-follows-focus` exists in the pinned nixpkgs. *(Verified with `gnomeExtensions.mouse-follows-focus-2`: eval returned `83`, no error.)*

---

### Phase 2: Resolve the exact extension UUID [IN PROGRESS]

**Goal**: Obtain the real extension UUID from the built package before enabling it — never guess.

**Tasks**:
- [x] Build just the package to get its store path: `nix build --no-link --print-out-paths .#homeConfigurations.benjamin.config.home.path` OR more directly inspect the package: `nix eval --raw nixpkgs#gnomeExtensions.mouse-follows-focus.outPath` (use the repo's pinned nixpkgs input, e.g. via `nix build .#homeConfigurations.benjamin.pkgs.gnomeExtensions.mouse-follows-focus` if exposed, otherwise `nix-build '<nixpkgs>' -A gnomeExtensions.mouse-follows-focus` is discouraged — prefer the flake-pinned path). *(deviation: altered — command form used was `nix build --no-link --print-out-paths --impure --expr 'let flake = builtins.getFlake (toString ./.); pkgs = flake.homeConfigurations.benjamin.pkgs; in pkgs.gnomeExtensions.mouse-follows-focus-2'`, which resolved to `/nix/store/q435hvdx4kf22hj079r04bbsd6lvshfb-gnome-shell-extension-mouse-follows-focus-12`)*
- [x] From the store path, locate the extension directory and read its UUID: `ls <storePath>/share/gnome-shell/extensions/` and/or `cat <storePath>/share/gnome-shell/extensions/*/metadata.json` and read the `"uuid"` field. Directory found: `mouse-follows-focus@crisidev.org`; metadata.json confirms `"uuid": "mouse-follows-focus@crisidev.org"`, `"url": "https://github.com/crisidev/mouse-follows-focus"` — this is the `crisidev/mouse-follows-focus` project (not `LeonMatthes/mousefollowsfocus`).
- [ ] Alternatively/additionally, after a switch (Phase 4), confirm with `gnome-extensions list | grep -i mouse`. *(deviation: deferred to Phase 4/5 — requires live switch + re-login, not yet performed)*
- [x] Record the exact verified UUID string here before Phase 3:
  - **VERIFIED UUID**: `mouse-follows-focus@crisidev.org` (from `metadata.json`, package `gnomeExtensions.mouse-follows-focus-2`, version 12 / version-name 0.0.11).
- [x] While reading `metadata.json`, note the supported `shell-version` array and compare against `gnome-shell --version` to confirm compatibility. **Result: metadata.json `shell-version` = `["45","46","47","48","49"]`; installed `gnome-shell --version` = `50.1` — the installed shell major version (50) is NOT listed in the extension's declared compatible versions.** This is a flagged risk (see plan Risks table row 2); nixpkgs still builds/exposes the package, but GNOME Shell may refuse to load it, or may load it with a version-mismatch warning depending on shell leniency. This must be confirmed during Phase 5 behavioral verification (`gnome-extensions info <UUID>` state) after re-login; if the shell refuses to enable it due to version mismatch, this is a blocker requiring a follow-up task (e.g., nixpkgs override to patch `shell-version`, or waiting for upstream/nixpkgs update) — NOT something this implementation silently works around.

**Timing**: 0.3 hours

**Depends on**: 1

**Files to modify**:
- None (read-only discovery; the UUID is recorded in this plan for Phase 3).

**Verification**:
- The `metadata.json` `uuid` value is captured verbatim. **Captured: `mouse-follows-focus@crisidev.org`.**
- The extension's `shell-version` includes the installed GNOME Shell major version. **NOT satisfied** — installed shell is 50.1, extension declares support through 49 only. Flagged for Phase 5 behavioral verification; proceeding per user's LOCKED decision to install/enable regardless, with this risk explicitly surfaced in the summary/handoff.

---

### Phase 3: Enable the extension in gnome.nix [IN PROGRESS]

**Goal**: Add the verified UUID to the enabled-extensions list, preserving all focus settings.

**Tasks**:
- [x] In `modules/home/desktop/gnome.nix`, in the `"org/gnome/shell"` block's `enabled-extensions` list (lines ~8-11), append the VERIFIED UUID from Phase 2 as a new list element after `"unite@hardpixel.eu"`. Added `"mouse-follows-focus@crisidev.org"`.
- [x] Confirm `focus-mode = "sloppy"` (line ~66) is UNCHANGED. Verified at line 67, unchanged.
- [x] Confirm `focus-change-on-pointer-rest = false` (line ~88) is UNCHANGED. Verified at line 89, unchanged.
- [x] Do NOT add `focus-mode = "click"`. Confirmed not added.
- [x] Preserve 2-space indentation and existing entry order.

**Timing**: 0.2 hours

**Depends on**: 2

**Files to modify**:
- `modules/home/desktop/gnome.nix` - append one UUID string to `enabled-extensions`.

**Verification**:
- The list contains exactly three entries: `activate-window-by-title@lucaswerkmeister.de`, `unite@hardpixel.eu`, and the new verified UUID. **Confirmed.**
- `focus-mode` and `focus-change-on-pointer-rest` are byte-for-byte unchanged. **Confirmed via grep.**

---

### Phase 4: Build and switch verification [IN PROGRESS]

**Goal**: Confirm the configuration evaluates and applies cleanly.

**Tasks**:
- [x] Run `nix flake check` to confirm the flake evaluates (syntax/type errors surface here). Result: `all checks passed!` (nixosConfigurations nandi/hamsa/garuda/iso/usb-installer + homeConfigurations all evaluated; only pre-existing unrelated `boot.zfs.forceImportRoot` warnings, no errors).
- [x] Run `home-manager build --flake .#benjamin` to build the standalone Home Manager config without activating. Result: succeeded, built 4 derivations (hm-dconf.ini, home-manager-path, activation-script, home-manager-generation); `result -> /nix/store/1mnyykg3889d6lsyb65igrqa5rr3pak2-home-manager-generation`. Verified generated `hm-dconf.ini` contains `enabled-extensions=@as ['activate-window-by-title@lucaswerkmeister.de','unite@hardpixel.eu','mouse-follows-focus@crisidev.org']` and unchanged `focus-mode='sloppy'` / `focus-change-on-pointer-rest=false`.
- [x] Apply with `home-manager switch --flake .#benjamin` (standalone home-manager; no sudo). (Note: gnome.nix and dev-tools.nix are imported via `home.nix`, which is used by both the standalone `homeConfigurations.benjamin` and the NixOS-integrated home-manager; the standalone switch is sufficient to apply these dconf + package changes.) Result: activation succeeded (`installPackages`, `dconfSettings`, `linkGeneration` etc. all activated with no errors).
- [x] Confirm the dconf key applied: `gsettings get org.gnome.shell enabled-extensions` (or `dconf read /org/gnome/shell/enabled-extensions`) includes the new UUID. Result: `['activate-window-by-title@lucaswerkmeister.de', 'unite@hardpixel.eu', 'mouse-follows-focus@crisidev.org']`. Also confirmed `focus-mode` = `'sloppy'` and `focus-change-on-pointer-rest` = `false` live. Note: `gnome-extensions list --enabled` (run in the still-running pre-switch GNOME Shell process) does NOT yet show the new extension — expected, since Wayland GNOME Shell cannot hot-reload; this is deferred to Phase 5 after re-login.

**Timing**: 0.3 hours

**Depends on**: 3

**Files to modify**:
- None (build/activation only).

**Verification**:
- `nix flake check` and `home-manager build --flake .#benjamin` succeed with no evaluation errors. **Confirmed.**
- `home-manager switch --flake .#benjamin` completes successfully. **Confirmed.**
- `enabled-extensions` in live dconf lists the new UUID. **Confirmed.**

---

### Phase 5: Behavioral verification [NOT STARTED — pending user action]

**Goal**: Manually confirm the fix resolves the reported bug without regressing hover-to-focus.

**Tasks** — *(deviation: deferred to user — these are manual, physically-interactive tests that cannot be performed headlessly by the implementing agent; the code/config change and build/switch are complete and verified, but this checklist is pending user action)*:
- [ ] Trigger a GNOME Shell reload so the newly-enabled extension activates. On Wayland, GNOME Shell cannot be restarted in place — **log out and log back in** (or reboot). Note: a re-login is required for a newly-enabled extension to take effect on Wayland. *(pending user verification after re-login)*
- [ ] Confirm the extension is active: `gnome-extensions list --enabled | grep -i mouse` and `gnome-extensions info mouse-follows-focus@crisidev.org` shows state ENABLED. *(pending user verification after re-login — also re-check the shell-version 50 vs declared max 49 compatibility flagged in Phase 2)*
- [ ] **Test (a) hover-to-focus preserved**: with pure mouse navigation (no keyboard), move the pointer over different windows and confirm focus still follows the pointer as before. *(pending user verification after re-login)*
- [ ] **Test (b) keyboard switch sticks**: with the pointer resting over window A, use the existing `<Super>space` (`cycle-windows`) keybinding to switch focus to a window B that is NOT under the pointer. Confirm focus STAYS on B and the cursor visibly warps to B. *(pending user verification after re-login)*
- [ ] **Test (c) original bug no longer reproduces**: position the pointer resting over a third, uninvolved window C, then keyboard-switch focus to B. Confirm focus does NOT snap back to C (the original instant snap-back bug is gone). *(pending user verification after re-login)*
- [ ] If multi-monitor: repeat (b)/(c) across monitors to check for warp glitches noted in the research. *(pending user verification after re-login)*

**Timing**: 0.3 hours

**Depends on**: 4

**Files to modify**:
- None (manual verification).

**Verification**:
- All three test scenarios (a), (b), (c) pass as described.
- If any scenario fails, consult the documented (but unapplied) `focus-mode = "click"` fallback in the research report before proposing further changes — do NOT apply it without user confirmation.

---

## Testing & Validation

- [x] `nix flake check` passes.
- [x] `home-manager build --flake .#benjamin` builds without error.
- [x] `home-manager switch --flake .#benjamin` applies successfully.
- [ ] `gnome-extensions list --enabled` includes the verified `mouse-follows-focus` UUID after re-login. *(pending user verification after re-login)*
- [ ] Hover-to-focus still works (test a). *(pending user verification after re-login)*
- [ ] Keyboard focus switch sticks with cursor warp (test b). *(pending user verification after re-login)*
- [ ] Original snap-back bug does not reproduce with pointer over a third window (test c). *(pending user verification after re-login)*
- [x] `focus-mode` remains `"sloppy"`; `focus-change-on-pointer-rest` remains `false`.

## Artifacts & Outputs

- Modified `modules/home/packages/dev-tools.nix` (adds `gnomeExtensions.mouse-follows-focus`).
- Modified `modules/home/desktop/gnome.nix` (adds verified UUID to `enabled-extensions`).
- Implementation summary at `summaries/01_mouse-follows-focus-extension-summary.md` (created by /implement).

## Rollback/Contingency

- **Revert**: remove the added package line from `dev-tools.nix` and the added UUID from `enabled-extensions` in `gnome.nix`, then re-run `home-manager switch --flake .#benjamin`. Because the change is two additive edits, `git checkout -- modules/home/packages/dev-tools.nix modules/home/desktop/gnome.nix` (on a clean-enough tree) cleanly reverts.
- **If the extension misbehaves** (e.g., disruptive cursor warp, multi-monitor glitch): disable it by removing only the UUID from `enabled-extensions` (leaving the package installed) and switch again. The documented no-side-effect fallback is `focus-mode = "click"`, to be applied ONLY with explicit user confirmation since it changes hover-focus behavior repo-wide (explicitly rejected as the default fix for this task).

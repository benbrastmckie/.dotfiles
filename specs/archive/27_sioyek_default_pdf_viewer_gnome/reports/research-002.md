# Supplementary Research Report: X11 Wrapper and Unite Extension

- **Task**: 27 - sioyek_default_pdf_viewer_gnome
- **Started**: 2026-02-10T12:00:00Z
- **Completed**: 2026-02-10T12:30:00Z
- **Effort**: 30 minutes
- **Dependencies**: research-001.md
- **Sources/Inputs**:
  - Unite extension GitHub issues
  - Qt/Wayland documentation
  - NixOS Discourse and nixpkgs
  - XWayland performance analysis
- **Artifacts**:
  - `/home/benjamin/.dotfiles/specs/27_sioyek_default_pdf_viewer_gnome/reports/research-002.md`
- **Standards**: report-format.md

## Executive Summary

- The X11 wrapper (`QT_QPA_PLATFORM=xcb`) is **necessary** for Unite extension to hide sioyek's title bar
- Qt6 applications on native Wayland use Client-Side Decorations (CSD) that Unite **cannot control**
- Removing X11 would require either accepting visible title bars OR finding Wayland-native alternatives
- The costs of keeping X11 are minimal for this use case; benefits of removing are marginal
- **Recommendation**: Keep the X11 wrapper; it solves a real problem with acceptable tradeoffs

## Context & Scope

This research investigates why sioyek has an X11 wrapper in configuration.nix (lines 478-486):

```nix
(writeShellScriptBin "sioyek" ''
  #!/bin/sh
  export QT_QPA_PLATFORM=xcb
  exec ${pkgs.sioyek}/bin/sioyek "$@"
'')
```

The comment explains: "Sioyek uses Qt6 with client-side decorations that Unite extension cannot hide on Wayland. Forcing X11 enables server-side decorations that Unite can control."

## Findings

### 1. What is the Unite Extension?

[Unite](https://extensions.gnome.org/extension/1287/unite/) is a GNOME Shell extension that:
- Removes window title bars to maximize screen real estate
- Moves window controls (close/minimize/maximize) to the GNOME top panel
- Shows window title in the app menu for maximized windows
- Creates a Unity-like desktop experience

This is particularly valuable for:
- Laptop users with limited vertical screen space
- Full-screen document readers like PDF viewers
- Research workflows with multiple papers open

### 2. Why Does X11 Enable Title Bar Removal?

**Server-Side Decorations (SSD) vs Client-Side Decorations (CSD)**

| Decoration Type | Who Draws Title Bar | Who Controls It | Unite Can Hide? |
|-----------------|---------------------|-----------------|-----------------|
| Server-Side (SSD) | Window Manager (Mutter) | Window Manager | **Yes** |
| Client-Side (CSD) | Application itself | Application | **No** |

On **X11**, the window manager (Mutter in GNOME) typically provides server-side decorations. The window manager draws the title bar, so extensions like Unite can modify or hide it.

On **Wayland**, GNOME's Mutter only supports client-side decorations. Each application must draw its own title bar. Unite cannot remove decorations the application draws itself.

**Qt6 on Wayland**: By default, Qt6 applications on Wayland draw their own CSD title bars. Unite has [an open GitHub issue (#167)](https://github.com/hardpixel/unite-shell/issues/167) about this problem dating back to April 2020, still unresolved.

**Qt6 on X11 (via XWayland)**: When forced to use X11 (`QT_QPA_PLATFORM=xcb`), Qt applications run through XWayland and use server-side decorations from the window manager, which Unite can hide.

### 3. Can X11 Be Removed?

**Yes, technically.** The wrapper can be removed by:
1. Removing the `writeShellScriptBin` wrapper from configuration.nix
2. Installing sioyek from Home Manager (already done in home.nix)

**But this would result in**:
- Sioyek having a visible title bar that Unite cannot remove
- Wasting ~30px of vertical screen space per window
- Inconsistent appearance with other applications using Unite

### 4. Wayland-Native Alternatives for Title Bar Removal

| Alternative | Description | Viability |
|-------------|-------------|-----------|
| **QAdwaitaDecorations** | Qt plugin for Adwaita-style CSD | Does NOT hide title bars; just makes them look GNOME-native |
| **GTK Title Bar extension** | Hide CSD for maximized windows | [Has same limitation](https://github.com/velitasali/gtktitlebar/issues/25) on native Wayland |
| **Patched Mutter** | Custom Mutter build with legacy decoration hiding | Maintenance burden, fragile |
| **CSS injection** | Hide GTK headerbar via CSS | Qt apps don't use GTK headers |
| **Accept visible title bar** | Stop using Unite for sioyek | Loses screen real estate |

**Conclusion**: There is no Wayland-native solution that preserves Unite's title bar hiding for Qt6 applications.

### 5. How Desirable Is Removing X11?

**Potential Benefits of Native Wayland:**

| Benefit | Relevance to Sioyek |
|---------|---------------------|
| Better fractional scaling | Marginal - XWayland on 100%/200% is sharp |
| Lower latency | Minimal for document viewer |
| Better touch/stylus support | Minimal - keyboard navigation preferred |
| Better multi-monitor handling | Marginal |
| Modern protocol features | Not applicable to PDF viewing |

**Reality Check**: Sioyek is a document viewer, not a latency-sensitive application. The theoretical benefits of native Wayland are **not significant** for this use case.

### 6. Costs of Keeping X11

| Cost | Severity | Notes |
|------|----------|-------|
| XWayland overhead | **Minimal** | XWayland is mature, well-optimized |
| Fractional scaling blur | **Low** | Only affects non-integer scaling (125%, 150%); 100%/200% are sharp |
| Clipboard issues | **Rare** | Copy between XWayland and Wayland works fine in practice |
| Additional process | **Negligible** | One XWayland instance shared by all X11 apps |
| Memory overhead | **~10-20MB** | For XWayland instance if not already running |

**Key Insight**: If you use ANY other XWayland application (Electron apps, some IDEs, games), XWayland is already running. The marginal cost of sioyek using XWayland is near zero.

### 7. Current Configuration Analysis

The existing comment in configuration.nix accurately explains the rationale:

```nix
# Custom sioyek (force X11 for title bar removal)
# Note: Sioyek uses Qt6 with client-side decorations that Unite extension
# cannot hide on Wayland. Forcing X11 enables server-side decorations
# that Unite can control. Original sioyek package removed to avoid conflicts.
```

This is a well-documented, intentional design decision.

## Recommendations

### Option A: Keep X11 Wrapper (Recommended)

**Rationale**:
- Title bar removal works correctly with Unite
- Costs are minimal for a document viewer
- XWayland is mature and well-tested
- No maintenance burden

**Implementation**: Proceed with implementation-001.md as planned. The desktop entry should reference `/run/current-system/sw/bin/sioyek` which is the wrapped version.

### Option B: Remove X11, Accept Title Bar

**Rationale**:
- "Pure" Wayland experience
- One less wrapper to maintain

**Trade-offs**:
- Lose ~30px vertical space to title bar
- Inconsistent with other applications using Unite
- Marginal benefits for a document viewer

### Option C: Use QAdwaitaDecorations (Not Recommended)

**Why not**: QAdwaitaDecorations provides GNOME-styled decorations but does NOT hide them. You would still have a title bar, just a prettier one. Available in nixpkgs as `qadwaitadecorations-qt6`.

## Decisions

1. **Keep the X11 wrapper** - The implementation plan correctly references `/run/current-system/sw/bin/sioyek` which uses the wrapped version with X11 forcing.

2. **No changes to configuration.nix sioyek wrapper** - The existing wrapper is well-documented and serves its purpose.

3. **Proceed with implementation-001.md** - The plan correctly uses the wrapper path.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| XWayland deprecated in future GNOME | Monitor GNOME development; this is unlikely for years |
| Unite extension discontinued | No action needed; SSD would still work on X11 |
| Fractional scaling issues | Use integer scaling (100%, 200%) or accept slight blur |

## Appendix

### References

- [Unite GNOME Extension](https://extensions.gnome.org/extension/1287/unite/)
- [Unite GitHub Issue #167: Add support for Qt client side window decorations](https://github.com/hardpixel/unite-shell/issues/167)
- [GTK Title Bar Issue #25: Titlebar doesn't hide on apps with native Wayland rendering](https://github.com/velitasali/gtktitlebar/issues/25)
- [Fedora Discussion: Qt programs can't hide titlebar on GNOME Wayland](https://discussion.fedoraproject.org/t/gnome-wayland-qt-programs-cant-hide-titlebar-or-show-tray-icon/77457)
- [QAdwaitaDecorations GitHub](https://github.com/FedoraQt/QAdwaitaDecorations)
- [NixOS nixpkgs QAdwaitaDecorations PR #360063](https://github.com/NixOS/nixpkgs/pull/360063)
- [Sioyek GitHub Repository](https://github.com/ahrm/sioyek)
- [Client-side decoration - Wikipedia](https://en.wikipedia.org/wiki/Client-side_decoration)

### Commands Used

```bash
# Check wrapper script
grep -A 10 "Custom sioyek" /home/benjamin/.dotfiles/configuration.nix

# Verify sioyek binary locations
which sioyek
ls -la ~/.nix-profile/bin/sioyek
ls -la /run/current-system/sw/bin/sioyek
```

### Environment Details

- GNOME on Wayland (Mutter compositor)
- XWayland available for X11 compatibility
- Unite extension installed for title bar management
- Qt6 applications default to Wayland backend
- X11 forcing via `QT_QPA_PLATFORM=xcb` routes through XWayland

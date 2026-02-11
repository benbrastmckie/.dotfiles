# Implementation Plan: Task #27

- **Task**: 27 - sioyek_default_pdf_viewer_gnome
- **Status**: [NOT STARTED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/27_sioyek_default_pdf_viewer_gnome/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Fix GNOME Files PDF association by creating a custom sioyek.desktop entry in the standard XDG location (`~/.local/share/applications/`) using Home Manager's `xdg.desktopEntries`. The desktop entry will reference the system wrapper that forces X11 mode for Unite extension compatibility. This is the simplest declarative solution that addresses the root cause identified in research.

### Research Integration

Key findings integrated:
- Desktop file location is the issue: `~/.nix-profile/share/applications/` is not fully respected by GNOME
- The X11 wrapper (`QT_QPA_PLATFORM=xcb`) must be preserved for Unite extension
- `xdg.desktopEntries` creates files in `~/.local/share/applications/` which GNOME fully respects

## Goals & Non-Goals

**Goals**:
- PDF files open in sioyek when double-clicked in GNOME Files
- Preserve X11 wrapper functionality for Unite extension
- Use declarative NixOS/Home Manager configuration
- Minimal changes to existing configuration

**Non-Goals**:
- Unifying the dual sioyek installation (keep both for now)
- Modifying system-wide MIME configuration
- Changing GNOME session defaults

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Desktop entry doesn't override GNOME defaults | M | L | Use xdg.mimeApps.enable with defaultApplications |
| Wrapper binary path resolution | L | L | Use absolute path from /run/current-system/sw/bin/sioyek |
| GNOME caches old association | L | M | Document need for logout/login after changes |

## Implementation Phases

### Phase 1: Configure xdg.desktopEntries and mimeApps [NOT STARTED]

**Goal**: Create sioyek.desktop in ~/.local/share/applications via Home Manager and set MIME defaults

**Tasks**:
- [ ] Read current home.nix to understand existing xdg configuration
- [ ] Add xdg.desktopEntries.sioyek configuration with correct Exec path
- [ ] Enable xdg.mimeApps and set application/pdf default
- [ ] Run home-manager switch to apply changes

**Timing**: 20 minutes

**Files to modify**:
- `home.nix` - Add xdg.desktopEntries and xdg.mimeApps configuration

**Configuration to add**:
```nix
xdg.desktopEntries.sioyek = {
  name = "Sioyek";
  genericName = "PDF Viewer";
  exec = "/run/current-system/sw/bin/sioyek %f";
  icon = "sioyek-icon-linux";
  mimeType = [ "application/pdf" ];
  categories = [ "Office" "Viewer" ];
  comment = "PDF viewer for reading research papers and technical books";
  terminal = false;
};

xdg.mimeApps = {
  enable = true;
  defaultApplications = {
    "application/pdf" = "sioyek.desktop";
  };
};
```

**Verification**:
- `home-manager switch` completes without errors
- File exists at `~/.local/share/applications/sioyek.desktop`
- `xdg-mime query default application/pdf` returns `sioyek.desktop`

---

### Phase 2: Verify and Test [NOT STARTED]

**Goal**: Confirm the fix works in GNOME Files

**Tasks**:
- [ ] Check desktop file contents are correct
- [ ] Verify MIME association with gio mime
- [ ] Test double-clicking PDF in GNOME Files (may require logout/login)
- [ ] Verify sioyek opens with X11 mode (title bar removed by Unite)

**Timing**: 10 minutes

**Verification**:
- `cat ~/.local/share/applications/sioyek.desktop` shows correct Exec path
- `gio mime application/pdf` shows sioyek.desktop
- Double-clicking PDF in GNOME Files opens sioyek
- Sioyek window has no title bar (Unite extension working)

## Testing & Validation

- [ ] `home-manager switch` succeeds without errors
- [ ] Desktop file created at `~/.local/share/applications/sioyek.desktop`
- [ ] `xdg-mime query default application/pdf` returns `sioyek.desktop`
- [ ] `gio mime application/pdf` returns `sioyek.desktop`
- [ ] Double-click PDF in GNOME Files opens sioyek
- [ ] Sioyek opens with X11 platform (no title bar via Unite extension)

## Artifacts & Outputs

- Modified: `home.nix` (xdg.desktopEntries and xdg.mimeApps configuration)
- Created: `~/.local/share/applications/sioyek.desktop` (by home-manager)
- Created: `~/.config/mimeapps.list` (by home-manager, may merge with existing)

## Rollback/Contingency

If the changes cause issues:
1. Remove the `xdg.desktopEntries.sioyek` and `xdg.mimeApps` blocks from home.nix
2. Run `home-manager switch`
3. Delete `~/.local/share/applications/sioyek.desktop` manually if it persists
4. The previous manual `~/.config/mimeapps.list` will continue to work

If GNOME still doesn't respect the association after changes:
1. Log out and log back in to clear GNOME's cache
2. If still not working, try `update-desktop-database ~/.local/share/applications`

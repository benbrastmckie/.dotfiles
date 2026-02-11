# Implementation Summary: Task #27

**Completed**: 2026-02-11
**Duration**: ~15 minutes

## Changes Made

Fixed sioyek default PDF viewer in GNOME Files by creating a custom desktop entry in the standard XDG location that GNOME fully respects.

### Key Implementation Details

1. **Used `xdg.dataFile` instead of `xdg.desktopEntries`**: The `xdg.desktopEntries` module places files in `~/.nix-profile/share/applications/` which GNOME Files does not fully respect for default application associations. By using `xdg.dataFile."applications/sioyek.desktop"`, the file is placed in `~/.local/share/applications/` which GNOME fully supports.

2. **Preserved X11 wrapper path**: The Exec path uses `/run/current-system/sw/bin/sioyek` which references the X11-wrapped version defined in configuration.nix. This ensures compatibility with the GNOME Unite extension (no title bar).

3. **Declarative MIME associations**: Added `xdg.mimeApps` configuration with the PDF default and preserved existing browser associations that were in the manual mimeapps.list.

## Files Modified

- `home.nix` - Added:
  - `xdg.enable = true` - Enable XDG base directories
  - `xdg.dataFile."applications/sioyek.desktop"` - Custom desktop entry in GNOME-respected location
  - `xdg.mimeApps` - MIME type associations for PDF and web browsers
  - `xdg.configFile."mimeapps.list".force = true` - Force Home Manager to manage the file

## Created Files (by Home Manager)

- `~/.local/share/applications/sioyek.desktop` - Desktop entry (symlink to Nix store)
- `~/.local/share/applications/mimeapps.list` - MIME associations (symlink to Nix store)
- `~/.config/mimeapps.list` - MIME associations (symlink to Nix store)

## Verification

All verification checks passed:

| Check | Result |
|-------|--------|
| `home-manager switch` | Success |
| Desktop file at `~/.local/share/applications/sioyek.desktop` | Created |
| `xdg-mime query default application/pdf` | `sioyek.desktop` |
| `gio mime application/pdf` | `sioyek.desktop` |

## Notes

- The previous `xdg.desktopEntries.sioyek` approach placed the desktop file in `~/.nix-profile/share/applications/` via `home.packages`. While this works for the application launcher, GNOME Files does not use this path when determining default applications for opening files.

- The `xdg.dataFile` approach creates the file directly in `~/.local/share/applications/` which is the standard XDG data directory that GNOME fully respects.

- If GNOME still shows the old association after switching, a logout/login may be required to clear GNOME's internal cache.

- The implementation also preserves browser associations (Brave) that were in the previous manual mimeapps.list.

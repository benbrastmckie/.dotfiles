# Research Report: Fix sioyek default PDF viewer in GNOME Files

- **Task**: 27 - sioyek_default_pdf_viewer_gnome
- **Started**: 2026-02-10T00:00:00Z
- **Completed**: 2026-02-10T00:45:00Z
- **Effort**: 45 minutes
- **Dependencies**: None
- **Sources/Inputs**:
  - Local configuration files (home.nix, configuration.nix, mimeapps.list files)
  - XDG MIME specification research
  - NixOS Discourse and GitHub issues
  - GNOME documentation
  - ArchWiki XDG MIME Applications
- **Artifacts**:
  - `/home/benjamin/.dotfiles/specs/27_sioyek_default_pdf_viewer_gnome/reports/research-001.md`
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

## Executive Summary

- The XDG MIME configuration IS correct - both `xdg-mime query` and `gio mime` return `sioyek.desktop` as the default
- GNOME session provides `gnome-mimeapps.list` which sets `application/pdf=org.gnome.Papers.desktop`
- This file appears at position 8 in XDG_DATA_DIRS, before user nix-profile (position 16)
- The user's `~/.config/mimeapps.list` SHOULD take precedence per XDG spec, but behavior varies
- There's a potential issue with sioyek installation in both home.nix (Home Manager) and configuration.nix (system wrapper)
- The sioyek desktop file references `Exec=sioyek %f` but there are two sioyek binaries in PATH

## Context & Scope

The user has installed sioyek as a PDF viewer and configured it as the default application for `application/pdf`. Despite correct configuration at the XDG level, GNOME Files (Nautilus) does not open PDF files with sioyek when double-clicking.

Configuration attempts made:
1. Declarative xdg.mimeApps in home.nix (removed)
2. Manual ~/.config/mimeapps.list configuration
3. Verified xdg-mime query returns sioyek.desktop

## Findings

### Current Configuration State

**~/.config/mimeapps.list**:
```ini
[Default Applications]
application/pdf=sioyek.desktop
text/html=brave-browser.desktop
...
```

**gio mime output**:
```
Default application for "application/pdf": sioyek.desktop
```

Both GIO and XDG-utils correctly identify sioyek.desktop as the default.

### GNOME Session MIME Defaults

The GNOME session package includes `/nix/store/.../gnome-session-49.2/share/applications/gnome-mimeapps.list` which contains:
```ini
[Default Applications]
application/pdf=org.gnome.Papers.desktop
...
```

This file is maintained by GNOME upstream at gnome-build-meta and sets GNOME's preferred applications.

### XDG_DATA_DIRS Order Analysis

The XDG_DATA_DIRS path includes (key positions):
- Position 8: `/nix/store/...-gnome-session-49.2/share` (contains gnome-mimeapps.list)
- Position 16: `/home/benjamin/.nix-profile/share` (contains sioyek.desktop)
- Position 21: `/run/current-system/sw/share` (system mimeinfo.cache, no sioyek)

The gnome-session share directory appears BEFORE the user's nix-profile in XDG_DATA_DIRS.

### Dual Sioyek Installation Issue

Sioyek is installed in two places:

1. **Home Manager (home.nix line 158)**:
   ```nix
   sioyek  # PDF viewer optimized for reading research papers
   ```
   - Creates `~/.nix-profile/bin/sioyek` -> actual sioyek binary
   - Creates `~/.nix-profile/share/applications/sioyek.desktop`
   - Creates `~/.nix-profile/share/applications/mimeinfo.cache` with `application/pdf=sioyek.desktop;`

2. **System wrapper (configuration.nix lines 478-486)**:
   ```nix
   (writeShellScriptBin "sioyek" ''
     #!/bin/sh
     export QT_QPA_PLATFORM=xcb
     exec ${pkgs.sioyek}/bin/sioyek "$@"
   '')
   ```
   - Creates `/run/current-system/sw/bin/sioyek` -> wrapper script
   - Does NOT create a desktop file
   - Purpose: Force X11 for title bar removal via Unite extension

**PATH resolution**: `~/.nix-profile/bin` comes before `/run/current-system/sw/bin`, so the unwrapped Home Manager sioyek is used, NOT the wrapper with `QT_QPA_PLATFORM=xcb`.

### Desktop File Analysis

The sioyek.desktop file content:
```ini
[Desktop Entry]
Name=Sioyek
Exec=sioyek %f
TryExec=sioyek
MimeType=application/pdf;
...
```

The `Exec=sioyek %f` uses the bare `sioyek` command, which resolves to the Home Manager binary, not the system wrapper. This means the X11 forcing is bypassed.

### System mimeinfo.cache Analysis

The system mimeinfo.cache at `/run/current-system/sw/share/applications/mimeinfo.cache` does NOT include sioyek:
```
application/pdf=brave-browser.desktop;com.brave.Browser.desktop;draw.desktop;okularApplication_pdf.desktop;org.gnome.Evince.desktop;org.gnome.Papers.desktop;org.pwmt.zathura-pdf-mupdf.desktop;vivaldi-stable.desktop;
```

The user's `~/.nix-profile/share/applications/mimeinfo.cache` correctly includes:
```
application/pdf=sioyek.desktop;
```

### Potential Root Causes

1. **GNOME Nautilus may use gnome-mimeapps.list**: According to XDG spec, `~/.config/mimeapps.list` should take precedence, but GNOME may have its own handling of `gnome-mimeapps.list` in XDG_DATA_DIRS.

2. **Desktop file location**: GNOME documentation states desktop files must be in `/usr/share/applications/` or `~/.local/share/applications/`. The sioyek.desktop is in `~/.nix-profile/share/applications/` which is in XDG_DATA_DIRS but may not be fully respected.

3. **Nautilus may cache**: Nautilus may cache MIME associations and require a session restart.

## Decisions

1. The issue is NOT with the MIME configuration itself - it is correctly set at the XDG/GIO level
2. The issue appears to be GNOME-specific behavior or caching

## Recommendations

### Priority 1: Create symlink in ~/.local/share/applications

Create a symlink to sioyek.desktop in the standard XDG user location:
```bash
mkdir -p ~/.local/share/applications
ln -sf ~/.nix-profile/share/applications/sioyek.desktop ~/.local/share/applications/
update-desktop-database ~/.local/share/applications
```

This can be done declaratively in Home Manager:
```nix
xdg.desktopEntries.sioyek = {
  name = "Sioyek";
  exec = "sioyek %f";
  icon = "sioyek-icon-linux";
  mimeType = [ "application/pdf" ];
  categories = [ "Development" "Viewer" ];
  comment = "PDF viewer for reading research papers and technical books";
};

xdg.mimeApps = {
  enable = true;
  defaultApplications = {
    "application/pdf" = "sioyek.desktop";
  };
};
```

### Priority 2: Unify sioyek installation

Remove sioyek from Home Manager packages and create a proper derivation that includes both the wrapper and desktop file:

```nix
# In configuration.nix or an overlay
let
  sioyek-wrapped = pkgs.runCommand "sioyek-wrapped" {
    nativeBuildInputs = [ pkgs.makeWrapper ];
  } ''
    mkdir -p $out/bin $out/share/applications

    # Create wrapper
    makeWrapper ${pkgs.sioyek}/bin/sioyek $out/bin/sioyek \
      --set QT_QPA_PLATFORM xcb

    # Copy and patch desktop file
    substitute ${pkgs.sioyek}/share/applications/sioyek.desktop \
      $out/share/applications/sioyek.desktop \
      --replace "Exec=sioyek" "Exec=$out/bin/sioyek"
  '';
in
```

### Priority 3: Override gnome-mimeapps

Use the NixOS system-wide MIME configuration to override GNOME defaults:
```nix
xdg.mime = {
  enable = true;
  defaultApplications = {
    "application/pdf" = "sioyek.desktop";
  };
};
```

This writes to `/etc/xdg/mimeapps.list` which should override the gnome-mimeapps.list.

### Priority 4: Log out and log back in

GNOME and Nautilus may cache MIME associations. A full logout/login may be required after making configuration changes.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Symlink approach requires session state | Use Home Manager xdg.desktopEntries for declarative management |
| Wrapper derivation complexity | Start with symlink approach, escalate if needed |
| GNOME caching | Instruct user to log out/in after changes |
| Dual installation conflict | Remove sioyek from home.nix after creating unified package |

## Appendix

### References

- [NixOS Discourse: How can I configure the default apps for GNOME?](https://discourse.nixos.org/t/how-can-i-configure-the-default-apps-for-gnome/36034)
- [NixOS Discourse: Set default application for mime type with home-manager](https://discourse.nixos.org/t/set-default-application-for-mime-type-with-home-manager/17190)
- [GitHub nixpkgs#34349: Nautilus use incorrect file associations](https://github.com/NixOS/nixpkgs/issues/34349)
- [GitHub nixpkgs#259239: VSCode is set as default for inode/directory](https://github.com/NixOS/nixpkgs/issues/259239)
- [ArchWiki: XDG MIME Applications](https://wiki.archlinux.org/title/XDG_MIME_Applications)
- [NixOS Wiki: Default applications](https://wiki.nixos.org/wiki/Default_applications)
- [GNOME Admin Guide: Override default application for individual users](https://help.gnome.org/admin/system-admin-guide/stable/mime-types-application-user.html.en)

### Debug Commands Used

```bash
# Check XDG MIME default
xdg-mime query default application/pdf

# Check GIO MIME handler
gio mime application/pdf

# Debug XDG MIME search
XDG_UTILS_DEBUG_LEVEL=2 xdg-mime query default application/pdf

# List XDG_DATA_DIRS
echo "$XDG_DATA_DIRS" | tr ':' '\n'

# Check mimeinfo.cache files
cat ~/.nix-profile/share/applications/mimeinfo.cache | grep pdf
cat /run/current-system/sw/share/applications/mimeinfo.cache | grep pdf

# Check GNOME session mimeapps
cat /nix/store/...-gnome-session-49.2/share/applications/gnome-mimeapps.list | grep pdf
```

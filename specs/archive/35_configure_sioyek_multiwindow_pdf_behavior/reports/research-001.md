# Research Report: Task #35

**Task**: 35 - configure_sioyek_multiwindow_pdf_behavior
**Started**: 2026-02-16T00:00:00Z
**Completed**: 2026-02-16T00:30:00Z
**Effort**: 30 minutes
**Dependencies**: None
**Sources/Inputs**:
  - Existing codebase: home.nix, config/sioyek/prefs_user.config
  - Previous sioyek tasks: specs/archive/27-31
  - [Sioyek Configuration Documentation](https://sioyek-documentation.readthedocs.io/en/latest/configuration.html)
  - [Sioyek prefs.config (default)](https://github.com/ahrm/sioyek/blob/main/pdf_viewer/prefs.config)
  - [Ubuntu sioyek man page](https://manpages.ubuntu.com/manpages/noble/man1/sioyek.1.html)
  - [GitHub Issue #124: One instance per file](https://github.com/ahrm/sioyek/issues/124)
  - [GitHub Issue #1297: Consider undeprecating should_launch_new_instance](https://github.com/ahrm/sioyek/issues/1297)
  - [GitHub Discussion #268: Open multiple documents](https://github.com/ahrm/sioyek/discussions/268)
**Artifacts**:
  - `/home/benjamin/.dotfiles/specs/35_configure_sioyek_multiwindow_pdf_behavior/reports/research-001.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Sioyek provides `should_launch_new_window 1` to open different PDF files in separate windows
- The `--reuse-instance` flag combined with `should_launch_new_window 1` enables the desired behavior
- However, sioyek does **not** natively support the "focus existing window for already-open file" feature - this would require an external wrapper script
- The default `q` binding closes ALL windows when using multi-window mode; needs rebinding to `close_window q`

## Context & Scope

The user wants:
1. **Different PDF files** -> Open in **separate windows**
2. **Same PDF file already open** -> **Focus that existing window** instead of opening a duplicate

Sioyek natively supports #1 but not #2. The "focus existing window" behavior requires either a custom wrapper script or acceptance that the same file will open in a new window each time.

## Findings

### Current Configuration

The existing `config/sioyek/prefs_user.config` does not set any window launch behavior options. Default behavior (`should_launch_new_window 0`) replaces the current document when opening a new file, losing the previous context.

### Key Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `should_launch_new_window` | 0 | When set to 1, opens new files in a new window within the same sioyek instance |
| `should_launch_new_instance` | 0 | Deprecated; creates entirely separate sioyek processes |

### Command-Line Flags

| Flag | Purpose |
|------|---------|
| `--new-window` | Opens file in new window (same instance) |
| `--reuse-window` | Force reuse current window even if `should_launch_new_window` is set |
| `--new-instance` | Opens file in new sioyek process |
| `--reuse-instance` | Reuse previous instance |

### Window Management Behavior Analysis

**Scenario 1: `should_launch_new_window 0` (default)**
- Opening file1.pdf: Opens in window
- Opening file2.pdf: Replaces file1.pdf in same window
- User loses file1.pdf context

**Scenario 2: `should_launch_new_window 1`**
- Opening file1.pdf: Opens in window A
- Opening file2.pdf: Opens in NEW window B
- Opening file1.pdf again: Opens in NEW window C (duplicate!)

The second scenario achieves the user's first goal (different files in different windows) but NOT the second goal (focus existing window for same file).

### Focus Existing Window: Not Natively Supported

According to [GitHub Issue #124](https://github.com/ahrm/sioyek/issues/124), a user requested "reopening it from zotero would just send the already opened instance to the foreground" (similar to Sumatra PDF behavior). The maintainer acknowledged this is "pretty difficult with our current way of handling multiple instances."

The issue was marked closed when `--new-window` was introduced, but this doesn't actually implement the "focus existing" behavior - it just enables multiple windows.

### Keybinding Issue

When `should_launch_new_window` is enabled, the default `q` binding (`quit`) closes ALL sioyek windows simultaneously. Users report needing to rebind it:

```
close_window q
```

This closes only the current window, preserving other open documents.

### Desktop Entry Configuration

The current desktop entry in `home.nix` (line 767-778) does not pass any window flags:
```
Exec=/run/current-system/sw/bin/sioyek %f
```

To ensure consistent behavior, the Exec line should be updated to include `--reuse-instance` to consolidate all windows into a single sioyek process.

## Recommendations

### Option A: Simple Multi-Window (No Focus-Existing)

**Configuration changes**:

1. Add to `config/sioyek/prefs_user.config`:
```
# Open different PDFs in separate windows
should_launch_new_window 1
```

2. Add to `config/sioyek/keys_user.config`:
```
# Close only current window (not all windows)
close_window q
```

3. Update desktop entry Exec line in `home.nix`:
```
Exec=/run/current-system/sw/bin/sioyek --reuse-instance %f
```

**Behavior**: Different PDFs open in different windows. Same PDF opened again creates a duplicate window.

### Option B: Wrapper Script for Focus-Existing (Advanced)

For the "focus existing window" behavior, a wrapper script would be needed:

```bash
#!/bin/bash
# sioyek-smart-open: Focus existing window or open new

PDF_PATH=$(realpath "$1")

# Check if sioyek is running with this file
# Use wmctrl or xdotool to find and focus existing window
EXISTING_WINDOW=$(wmctrl -l | grep -F "$(basename "$PDF_PATH")" | head -1 | awk '{print $1}')

if [ -n "$EXISTING_WINDOW" ]; then
    # Focus existing window
    wmctrl -i -a "$EXISTING_WINDOW"
else
    # Open in new window
    /run/current-system/sw/bin/sioyek --reuse-instance "$PDF_PATH"
fi
```

**Caveats**:
- Requires `wmctrl` package
- Window title matching may be unreliable (depends on how sioyek sets window titles)
- GNOME Wayland compatibility uncertain (wmctrl is X11)

### Option C: Accept Duplicate Windows

Use Option A configuration but accept that opening the same PDF will create duplicate windows. The user can manually close duplicates or use sioyek's internal `goto_window` command to navigate between open documents.

## Decisions

1. **Recommended approach**: Option A (simple multi-window) is the most reliable solution that sioyek natively supports
2. The "focus existing window" feature would require custom tooling that may be fragile
3. The `close_window q` keybinding change is essential for usable multi-window behavior

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Duplicate windows when opening same PDF | Minor UX annoyance | User can close duplicates; consider wrapper script later |
| `q` closes all windows | Data loss (loses document positions) | Rebind to `close_window q` |
| Desktop entry not using `--reuse-instance` | Inconsistent window behavior | Update Exec line |
| Multi-monitor behavior | Helper window placement | `should_use_multiple_monitors` already defaults to 0 |

## Appendix

### Implementation Files to Modify

1. `config/sioyek/prefs_user.config` - Add `should_launch_new_window 1`
2. `config/sioyek/keys_user.config` - Add `close_window q` rebinding
3. `home.nix` (line 773) - Update desktop entry Exec to include `--reuse-instance`

### References

- [Sioyek Documentation - Configuration](https://sioyek-documentation.readthedocs.io/en/latest/configuration.html)
- [Sioyek Default prefs.config](https://github.com/ahrm/sioyek/blob/main/pdf_viewer/prefs.config)
- [Ubuntu sioyek(1) man page](https://manpages.ubuntu.com/manpages/noble/man1/sioyek.1.html)
- [GitHub Issue #124: One instance per file](https://github.com/ahrm/sioyek/issues/124)
- [GitHub Issue #1297: Consider undeprecating should_launch_new_instance](https://github.com/ahrm/sioyek/issues/1297)
- [GitHub Discussion #268: Open multiple documents](https://github.com/ahrm/sioyek/discussions/268)

### Search Queries Used

- "sioyek PDF viewer new window open file separate window configuration"
- "sioyek prefs_user.config reuse window focus existing instance"
- "sioyek focus existing open PDF same file already open focus window"
- "sioyek --forward-search focus already open instance same file"
- "sioyek single instance mode same file focus bring to front 2024 2025"

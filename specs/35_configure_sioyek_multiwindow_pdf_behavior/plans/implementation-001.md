# Implementation Plan: Task #35

- **Task**: 35 - Configure sioyek multi-window PDF behavior
- **Status**: [NOT STARTED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/35_configure_sioyek_multiwindow_pdf_behavior/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

Configure sioyek PDF viewer to open different PDF files in separate windows using native configuration options. This involves adding the `should_launch_new_window` preference, rebinding `q` to close only the current window (not all windows), and updating the desktop entry to use `--reuse-instance` for consistent window management.

### Research Integration

The research report (research-001.md) identified that:
- Sioyek natively supports multi-window behavior via `should_launch_new_window 1`
- The "focus existing window for same file" feature is not natively supported (would require a custom wrapper script)
- The default `q` binding closes ALL windows when multi-window is enabled, requiring rebinding to `close_window`
- Desktop entry should use `--reuse-instance` for consistent behavior

**Decision**: Implement Option A from research (simple multi-window) as the recommended native solution.

## Goals & Non-Goals

**Goals**:
- Different PDF files open in separate windows within the same sioyek instance
- Closing one window does not close other open documents
- Desktop entry provides consistent behavior when opening PDFs

**Non-Goals**:
- Focus existing window when opening an already-open PDF (not natively supported, requires wrapper script)
- Custom wrapper script for smart open behavior (deferred for future consideration)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Duplicate windows when opening same PDF | Minor UX annoyance | High | User can close duplicates; document behavior in commit message |
| Unexpected multi-monitor behavior | Low | Low | `should_use_multiple_monitors` defaults to 0 |

## Implementation Phases

### Phase 1: Configure multi-window and keybindings [NOT STARTED]

**Goal**: Enable multi-window mode and fix the close behavior

**Tasks**:
- [ ] Add `should_launch_new_window 1` to prefs_user.config with explanatory comment
- [ ] Add `close_window q` binding to keys_user.config to close only current window
- [ ] Update desktop entry Exec line to include `--reuse-instance` flag

**Timing**: 15 minutes

**Files to modify**:
- `config/sioyek/prefs_user.config` - Add multi-window preference
- `config/sioyek/keys_user.config` - Add close_window binding
- `home.nix` (line 773) - Update desktop entry Exec line

**Verification**:
- Open two different PDFs from file manager; both should appear in separate windows
- Press `q` in one window; only that window should close, other remains open
- Open PDF from command line with `sioyek file.pdf`; should join existing instance

---

## Testing & Validation

- [ ] Rebuild Home Manager configuration: `home-manager switch --flake .#benjamin`
- [ ] Open first PDF from file manager (should open in new window)
- [ ] Open second PDF from file manager (should open in another window)
- [ ] Press `q` in one window (should close only that window)
- [ ] Verify other PDF window remains open with document intact

## Artifacts & Outputs

- `plans/implementation-001.md` - This plan file
- `summaries/implementation-summary-YYYYMMDD.md` - Post-implementation summary

## Rollback/Contingency

Revert changes to the three config files:
1. Remove `should_launch_new_window 1` from prefs_user.config
2. Remove `close_window q` from keys_user.config
3. Remove `--reuse-instance` from desktop entry in home.nix

Alternative: If multi-window causes issues, the user can pass `--reuse-window` flag when opening PDFs to force single-window behavior.

# Task List

## Active Tasks

### 35. Configure sioyek multi-window behavior for PDF files
- **Status**: [PLANNED]
- **Language**: general
- **Researched**: 2026-02-16
- **Research**: [research-001.md](specs/35_configure_sioyek_multiwindow_pdf_behavior/reports/research-001.md)
- **Plan**: [implementation-001.md](specs/35_configure_sioyek_multiwindow_pdf_behavior/plans/implementation-001.md)

**Description**: Configure sioyek to open different PDF files in separate windows instead of replacing the current window. Opening an already-open PDF should focus that existing window.

---

### 34. Fix ctrl+space tab navigation not switching to tabs in different WezTerm windows
- **Status**: [RESEARCHED]
- **Language**: general
- **Researched**: 2026-02-11
- **Research**: [research-001.md](specs/34_fix_wezterm_ctrl_space_cross_window_tab_navigation/reports/research-001.md), [research-002.md](specs/34_fix_wezterm_ctrl_space_cross_window_tab_navigation/reports/research-002.md)

**Description**: Fix ctrl+space followed by a number not switching to tabs in different WezTerm windows. The navigation should switch to the tab with that global number across all windows, but currently it does not switch to the target window and tab as expected.

---

### 33. Configure WezTerm to navigate to tabs by global number across all windows
- **Status**: [COMPLETED]
- **Language**: general
- **Researched**: 2026-02-11
- **Completed**: 2026-02-11
- **Research**: [research-001.md](specs/33_configure_wezterm_global_tab_navigation/reports/research-001.md)
- **Plan**: [implementation-001.md](specs/33_configure_wezterm_global_tab_navigation/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260211.md](specs/33_configure_wezterm_global_tab_navigation/summaries/implementation-summary-20260211.md)

**Description**: Configure WezTerm so that ctrl+space followed by a number navigates to the tab with that global number across all windows, rather than the nth tab within the current window only.

---

### 25. Configure swap space in NixOS configuration
- **Status**: [COMPLETED]
- **Language**: nix
- **Researched**: 2026-02-11
- **Completed**: 2026-02-11
- **Research**: [research-001.md](specs/25_configure_swap_space_nixos/reports/research-001.md), [research-002.md](specs/25_configure_swap_space_nixos/reports/research-002.md)
- **Plan**: [implementation-001.md](specs/25_configure_swap_space_nixos/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260211.md](specs/25_configure_swap_space_nixos/summaries/implementation-summary-20260211.md)

**Description**: Configure swap space in NixOS configuration. Add 8-16GB swap as a safety net to prevent OOM killer from terminating processes during memory spikes.

---

### 23. Research and install simple webcam recording software
- **Status**: [PLANNED]
- **Language**: nix
- **Researched**: 2026-02-09
- **Research**: [research-001.md](specs/23_install_simple_webcam_recording_software/reports/research-001.md)
- **Plan**: [implementation-001.md](specs/23_install_simple_webcam_recording_software/plans/implementation-001.md)

**Description**: Research and install the simplest video software that is free and in the nix packages that can be used to record a small video from the web camera.

---

### 19. Install and set up MCP servers for web development
- **Status**: [RESEARCHED]
- **Language**: general
- **Researched**: 2026-02-05
- **Research**: [research-001.md](specs/19_install_setup_mcp_servers_web_development/reports/research-001.md)

**Description**: Install and set up three MCP servers for use doing web development in /home/benjamin/Projects/Logos/LogosWebsite/ and other similar projects. Draw on the guide at /home/benjamin/Projects/Logos/LogosWebsite/.claude/docs/guides/mcp-server-setup.md for reference.

---

### 15. Configure timezone based on location
- **Status**: [RESEARCHED]
- **Language**: nix
- **Researched**: 2026-02-04
- **Research**: [research-001.md](specs/15_configure_timezone_location_based/reports/research-001.md)

**Description**: Configure NixOS timezone to be set based on location with California as default. Research best practices for automatic timezone detection and configuration.

---

## Completed Tasks

(archived - see specs/archive/)

## Archived Tasks

- #1: Update CLAUDE.md for dotfiles repository (completed 2026-02-03)
- #2: Update README.md for dotfiles context (completed 2026-02-03)
- #4: Manage Claude settings.json with home-manager (completed 2026-02-03)
- #5: Create Nix context directory structure (completed 2026-02-03)
- #6: Create Nix rules file (completed 2026-02-03)
- #7: Create nix-research-agent (completed 2026-02-03)
- #8: Create nix-implementation-agent (completed 2026-02-03)
- #9: Create skill-nix-research (completed 2026-02-03)
- #10: Create skill-nix-implementation (completed 2026-02-03)
- #11: Update orchestrator for nix language routing (completed 2026-02-03)
- #12: Update settings.json for Nix commands (completed 2026-02-03)
- #13: Research Nix MCP tools (completed 2026-02-03)
- #14: Review and improve documentation (completed 2026-02-03)
- #16: Troubleshoot automatic-timezoned service failure (completed 2026-02-04)
- #17: Fix leanls LSP watchdog error for missing /etc/localtime (completed 2026-02-04)
- #18: Investigate and fix gmail-oauth2-refresh.service failure (completed 2026-02-04)
- #20: Update Himalaya setup from manual guide (completed 2026-02-09)
- #21: Fix Himalaya SMTP sending for logos account (completed 2026-02-09)
- #22: Update Himalaya documentation for SMTP fix (completed 2026-02-09)
- #24: Implement Protonmail Bridge systemd autostart (completed 2026-02-10)
- #26: Set up memory monitoring systemd services (completed 2026-02-10)
- #27: Fix sioyek default PDF viewer in GNOME Files (completed 2026-02-11)
- #28: Configure sioyek night mode toggle colors (completed 2026-02-11)
- #29: Fix sioyek color toggle white/Nord issue (completed 2026-02-11)
- #30: Fix sioyek theme toggle w key Nord macro (completed 2026-02-11)
- #31: Implement sioyek w key Gruvbox/Nord toggle (completed 2026-02-11)
- #32: Remove sioyek Ctrl-T new instance mapping (completed 2026-02-11)

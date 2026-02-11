# Task List

## Active Tasks

### 28. Configure sioyek night mode toggle with soft grey-blue color scheme
- **Status**: [PLANNED]
- **Language**: general
- **Researched**: 2026-02-11
- **Research**: [research-001.md](specs/28_sioyek_night_mode_toggle_color_scheme/reports/research-001.md)
- **Plan**: [implementation-001.md](specs/28_sioyek_night_mode_toggle_color_scheme/plans/implementation-001.md)

**Description**: When pressing 'w' in sioyek, it currently toggles to black text on white background. Instead, configure it to toggle to a night mode with soft grey-blue background and lighter text, or another visually appealing nightmode color scheme.

---

### 27. Fix sioyek default PDF viewer in GNOME Files
- **Status**: [COMPLETED]
- **Language**: nix
- **Researched**: 2026-02-10
- **Research**: [research-001.md](specs/27_sioyek_default_pdf_viewer_gnome/reports/research-001.md)
- **Plan**: [implementation-001.md](specs/27_sioyek_default_pdf_viewer_gnome/plans/implementation-001.md)
- **Completed**: 2026-02-11
- **Summary**: [implementation-summary-20260211.md](specs/27_sioyek_default_pdf_viewer_gnome/summaries/implementation-summary-20260211.md)

**Description**: Sioyek not opening as default PDF viewer in GNOME Files despite correct MIME configuration.

**Problem**: After installing sioyek and configuring it as the default PDF viewer, double-clicking PDF files in GNOME Files (Nautilus) does not open them in sioyek.

**What Has Been Tried**:
1. Declarative xdg.mimeApps configuration in home.nix - `xdg-mime query` returns sioyek.desktop but GNOME Files doesn't use it
2. Removed xdg.mimeApps to allow writable mimeapps.list files - still doesn't work
3. Manually set application/pdf=sioyek.desktop in ~/.config/mimeapps.list - verified correct but GNOME ignores it

**Current State**:
- sioyek installed and in PATH
- Desktop file exists at ~/.nix-profile/share/applications/sioyek.desktop
- `xdg-mime query default application/pdf` returns sioyek.desktop
- ~/.config/mimeapps.list is writable with correct entry
- GNOME Files still does not launch sioyek for PDFs

**Possible Next Steps**:
- Check sioyek.desktop file for correct MIME type associations
- Test `gtk-launch sioyek.desktop /path/to/file.pdf`
- Check GNOME-specific dconf settings
- Investigate other MIME files taking precedence
- Test if GNOME requires session restart or cache clear
- Verify sioyek.desktop Exec line is correct

---

### 26. Set up memory monitoring systemd services in NixOS
- **Status**: [COMPLETED]
- **Language**: nix
- **Researched**: 2026-02-10
- **Research**: [research-001.md](specs/26_memory_monitoring_systemd_services_nixos/reports/research-001.md)
- **Plan**: [implementation-001.md](specs/26_memory_monitoring_systemd_services_nixos/plans/implementation-001.md)
- **Completed**: 2026-02-10
- **Summary**: [implementation-summary-20260210.md](specs/26_memory_monitoring_systemd_services_nixos/summaries/implementation-summary-20260210.md)

**Description**: Set up memory monitoring systemd services in NixOS configuration. Include continuous memory logging, threshold-based desktop alerts, and Claude process tracking to identify memory leaks and usage patterns.

---

### 25. Configure swap space in NixOS configuration
- **Status**: [NOT STARTED]
- **Language**: nix

**Description**: Configure swap space in NixOS configuration. Add 8-16GB swap as a safety net to prevent OOM killer from terminating processes during memory spikes.

---

### 24. Implement Protonmail Bridge systemd autostart in NixOS config
- **Status**: [COMPLETED]
- **Language**: nix
- **Researched**: 2026-02-10
- **Research**: [research-001.md](specs/24_protonmail_bridge_nixos_config/reports/research-001.md)
- **Plan**: [implementation-001.md](specs/24_protonmail_bridge_nixos_config/plans/implementation-001.md)
- **Completed**: 2026-02-10
- **Summary**: [implementation-summary-20260210.md](specs/24_protonmail_bridge_nixos_config/summaries/implementation-summary-20260210.md)

**Description**: Improve NixOS configuration based on Protonmail Bridge systemd autostart research at /home/benjamin/.config/nvim/specs/052_protonmail_bridge_systemd_autostart/reports/research-001.md. Excludes neovim-specific tasks which will be implemented elsewhere.

---

### 23. Research and install simple webcam recording software
- **Status**: [RESEARCHED]
- **Language**: nix
- **Researched**: 2026-02-09
- **Research**: [research-001.md](specs/23_install_simple_webcam_recording_software/reports/research-001.md)

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

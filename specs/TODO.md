# Task List

## Active Tasks

### 59. Fix Neovim rendering corruption after system sleep in WezTerm
- **Status**: [RESEARCHED]
- **Task Type**: neovim
- **Research**:
  - [059_fix_neovim_rendering_after_sleep_wezterm/reports/01_neovim-sleep-rendering.md]
  - [059_fix_neovim_rendering_after_sleep_wezterm/reports/02_yanky-alternatives.md]

**Description**: Fix Neovim rendering corruption after system sleep in WezTerm - cursor missing, syntax highlighting broken, Claude Code sidebar stale. Only affects the tab that was visible/focused when sleep occurred; background tabs recover instantly.

---

### 52. Add sleep inhibition during active Claude Code/Opencode sessions
- **Status**: [PLANNED]
- **Task Type**: nix
- **Research**: [052_sleep_inhibition_claude_opencode/reports/01_sleep_inhibition_claude_opencode.md]
- **Plan**: [052_sleep_inhibition_claude_opencode/plans/01_sleep-inhibition-implementation.md]

**Description**: Create a feature to inhibit computer sleep while Claude Code or Opencode are actively running (not idle), while allowing screen dimming per GNOME settings. Research best practices for achieving this within the current NixOS configuration. The end goal is a `<leader>ai` Neovim mapping that inhibits sleep when these tools are running. The Neovim keymapping will be handled separately in the nvim config.

---

### 50. Fix claude-sleep-inhibitor pgrep self-matching preventing sleep
- **Status**: [RESEARCHED]
- **Task Type**: nix

**Description**: Fix claude-sleep-inhibitor pgrep self-matching: `pgrep -f 'claude'` matches the inhibitor script itself, claude-memory-tracker, earlyoom --prefer pattern, and other non-session processes, causing the inhibitor to never release and permanently blocking sleep. Replace with a more specific pattern that only matches actual Claude Code session processes.

---

### 46. Investigate and fix Gmail OAuth2 token expiry
- **Status**: [RESEARCHED]
- **Language**: nix
- **Researched**: 2026-03-24
- **Research**: [01_gmail-oauth2-token-expiry.md](specs/046_investigate_fix_gmail_oauth2_token_expiry/reports/01_gmail-oauth2-token-expiry.md)

**Description**: Investigate and fix Gmail OAuth2 token expiry - tokens keep expiring requiring repeated re-authentication with `himalaya account configure gmail`.

---

### 43. Install Forgejo self-hosted git server
- **Status**: [RESEARCHED]
- **Language**: nix
- **Researched**: 2026-02-24
- **Research**: [research-001.md](specs/43_install_forgejo_self_hosted_git/reports/research-001.md)

**Description**: Install and configure Forgejo as a self-hosted private git server on NixOS via `services.forgejo` in configuration.nix. Configure with SQLite database, disable public registration, and optionally expose via Nginx with HTTPS. Migrate existing private repos (e.g., Logos/Theory) from GitLab to the self-hosted instance.

---

### 42. Re-enable jupytext once nixpkgs fixes 1.18.1 test failures
- **Status**: [BLOCKED]
- **Language**: nix
- **Blocked by**: Upstream nixpkgs bug — jupytext 1.18.1 has 2 failing tests in async/sync ContentsManager sync check

**Description**: jupytext is commented out in home.nix pending an upstream fix. When nixpkgs ships a version where the tests pass, uncomment `jupytext` in home.nix and rebuild. See commit `830fbe5` for the disable and the `# DISABLED:` comment for the exact location.

---

### 41. Re-enable pdf2docx once nixpkgs fixes cucumber-expressions/uv_build
- **Status**: [BLOCKED]
- **Language**: nix
- **Blocked by**: Upstream nixpkgs bug — cucumber-expressions 18.1.0 requires uv_build<0.10.0 but nixpkgs ships 0.10.0

**Description**: pdf2docx is commented out in home.nix because it transitively requires cucumber-expressions 18.1.0 (via python-docx 1.2.0 → behave), which needs uv_build<0.10.0 but nixpkgs has 0.10.0. When either cucumber-expressions is updated or uv_build constraint relaxed, uncomment `pdf2docx` in home.nix and rebuild. See commit `6ea088d` and the `# DISABLED:` comment for the exact location.

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

## Recommended Order


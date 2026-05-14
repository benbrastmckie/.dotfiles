# Task List

## Active Tasks

### 52. Add sleep inhibition during active Claude Code/Opencode sessions
- **Status**: [PLANNED]
- **Task Type**: nix
- **Research**: [052_sleep_inhibition_claude_opencode/reports/01_sleep_inhibition_claude_opencode.md]
- **Plan**: [052_sleep_inhibition_claude_opencode/plans/01_sleep-inhibition-implementation.md]

**Description**: Create a feature to inhibit computer sleep while Claude Code or Opencode are actively running (not idle), while allowing screen dimming per GNOME settings. Research best practices for achieving this within the current NixOS configuration. The end goal is a `<leader>ai` Neovim mapping that inhibits sleep when these tools are running. The Neovim keymapping will be handled separately in the nvim config.

---

### 51. Documentation refactor: integrate ad-hoc notes into systematic docs
- **Status**: [COMPLETED]
- **Task Type**: markdown
- **Research**: [051_documentation_refactor_integrate_adhoc_notes/reports/01_documentation-analysis.md]
- **Plan**: [051_documentation_refactor_integrate_adhoc_notes/plans/01_documentation-refactor.md]
- **Summary**: [051_documentation_refactor_integrate_adhoc_notes/summaries/01_documentation-refactor-summary.md]

**Description**: Use the `programs.neovim` / `sideloadInitLua` fix (May 2026) as a concrete worked example to drive a repo-wide documentation refactor. The fix itself: a home-manager update changed the default behavior of `programs.neovim` so that provider config (python3_host_prog, ruby_host_prog) was written to `~/.config/nvim/init.lua` as a managed nix-store symlink, overwriting the user's config. Fix was `sideloadInitLua = true` in home.nix, which routes provider config through `--cmd` wrapper args instead. Initial documentation was created as: (1) an expanded inline comment on the `sideloadInitLua` line in `home.nix`, and (2) a new "Neovim" section in `NOTES.md`. The task is to evaluate and clean up that documentation, integrate it properly into `docs/` (likely `docs/applications.md` or a new `docs/neovim.md`) and any relevant `README.md` files, and use this specific case to establish a pattern and conventions for how NixOS config decisions, gotchas, and fixes should be documented repo-wide going forward. The goal is a sustainable, navigable documentation system where inline comments capture the why briefly, and `docs/` contains the full context.

---

### 50. Fix claude-sleep-inhibitor pgrep self-matching preventing sleep
- **Status**: [RESEARCHING]
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

### 44. Review memory logs and design system optimizations
- **Status**: [PLANNED]
- **Language**: nix
- **Researched**: 2026-03-10
- **Research**:
  - [research-001.md](specs/44_review_memory_logs_design_optimizations/reports/research-001.md)
  - [044_review_memory_logs_design_optimizations/reports/02_memory-usage-update.md]
- **Plan**: [044_review_memory_logs_design_optimizations/plans/01_memory-optimization.md]

**Description**: Review memory monitor logs to identify what is consuming memory when usage reaches 80%. Analyze patterns and design system improvements that can optimize memory usage while avoiding needless complexity.

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

# Task List

## Active Tasks

### 47. Fix R/Python/Quarto environment gaps via Nix wrapper refactor
- **Status**: [COMPLETED]
- **Language**: nix
- **Completed**: 2026-04-10
- **Artifacts**:
  - [01_nix-env-wrapper-refactor.md](specs/047_fix_r_python_quarto_env_gaps/plans/01_nix-env-wrapper-refactor.md)
  - [01_nix-env-wrapper-refactor-summary.md](specs/047_fix_r_python_quarto_env_gaps/summaries/01_nix-env-wrapper-refactor-summary.md)

**Description**: Replace flat `rPackages.*` entries in `~/.dotfiles/configuration.nix` with `rWrapper.override` containing P0/P1/P2 packages (survival, MASS, nlme, lme4, tidyverse, broom, gtsummary, mice, knitr, rmarkdown, languageserver, styler, lintr) so R's `.libPaths()` actually sees them. Add scipy/statsmodels/scikit-learn/seaborn/pyarrow to `home.nix` `python312.withPackages` (note `scikit-learn` hyphen quirk requires `p.scikit-learn` dotted form). Add `quarto` to systemPackages. Rebuild and verify per F8 procedure in source report. Source report: `/home/benjamin/.config/zed/specs/027_fix_task20_env_gaps/reports/01_fix-env-gaps.md`.

---

### 46. Investigate and fix Gmail OAuth2 token expiry
- **Status**: [RESEARCHED]
- **Language**: nix
- **Researched**: 2026-03-24
- **Research**: [01_gmail-oauth2-token-expiry.md](specs/046_investigate_fix_gmail_oauth2_token_expiry/reports/01_gmail-oauth2-token-expiry.md)

**Description**: Investigate and fix Gmail OAuth2 token expiry - tokens keep expiring requiring repeated re-authentication with `himalaya account configure gmail`.

---

### 45. Add terminal email client to NixOS config
- **Status**: [COMPLETED]
- **Language**: nix
- **Researched**: 2026-03-24
- **Planned**: 2026-03-24
- **Completed**: 2026-03-24
- **Research**:
  - [01_terminal-email-clients.md](specs/045_add_terminal_email_client_to_nixos/reports/01_terminal-email-clients.md)
  - [02_aerc-vs-notmuch-comparison.md](specs/045_add_terminal_email_client_to_nixos/reports/02_aerc-vs-notmuch-comparison.md)
- **Plan**: [01_aerc-notmuch-setup.md](specs/045_add_terminal_email_client_to_nixos/plans/01_aerc-notmuch-setup.md)
- **Summary**: [01_implementation-summary.md](specs/045_add_terminal_email_client_to_nixos/summaries/01_implementation-summary.md)

**Description**: Add terminal email client to NixOS config - find and configure best vim-compatible terminal email client (e.g. neomutt, aerc, or mutt) with vim motions support as interim solution while himalaya neovim integration is developed.

---

### 44. Review memory logs and design system optimizations
- **Status**: [RESEARCHED]
- **Language**: nix
- **Researched**: 2026-03-10
- **Research**: [research-001.md](specs/44_review_memory_logs_design_optimizations/reports/research-001.md)

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

### 40. Investigate laptop running hot and optimize system
- **Status**: [COMPLETED]
- **Language**: nix
- **Researched**: 2026-02-24
- **Completed**: 2026-02-24
- **Research**: [research-001.md](specs/40_investigate_laptop_high_fan_optimize_system/reports/research-001.md), [research-002.md](specs/40_investigate_laptop_high_fan_optimize_system/reports/research-002.md)
- **Plan**: [implementation-002.md](specs/40_investigate_laptop_high_fan_optimize_system/plans/implementation-002.md)
- **Summary**: [implementation-summary-20260224.md](specs/40_investigate_laptop_high_fan_optimize_system/summaries/implementation-summary-20260224.md)

**Description**: Investigate why laptop is running hot with high fan activity during low usage. Identify processes or services causing unnecessary load and optimize system configuration to reduce resource consumption.

---

### 39. Analyze memory logs and optimize system robustness
- **Status**: [COMPLETED]
- **Language**: nix
- **Researched**: 2026-02-22
- **Completed**: 2026-02-22
- **Research**: [research-001.md](specs/39_analyze_memory_logs_optimize_system/reports/research-001.md)
- **Plan**: [implementation-001.md](specs/39_analyze_memory_logs_optimize_system/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260222.md](specs/39_analyze_memory_logs_optimize_system/summaries/implementation-summary-20260222.md)

**Description**: Investigate memory monitor logs to understand memory demands during heavy system usage. Analyze patterns and recommend improvements to make the system more robust and performant, avoiding crashes and slowdowns.

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

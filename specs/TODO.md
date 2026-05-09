# Task List

## Active Tasks

### 55. Create the Discord bot Python source code
- **Status**: [COMPLETED]
- **Task Type**: python
- **Research**: [055_create_discord_bot_python_source/reports/01_discord-bot-source.md]
- **Plan**: [055_create_discord_bot_python_source/plans/01_discord-bot-source.md]
- **Summary**: [055_create_discord_bot_python_source/summaries/01_discord-bot-source-summary.md]

**Description**: Create the Discord bot Python source code at ~/.dotfiles/opencode-discord-bot/. This is the actual Nextcord bot that bridges Discord to the headless OpenCode agent server. The discord-bot.service systemd unit (defined in configuration.nix, task 53) expects `opencode_discord_bot.src.bot` to be importable from this directory via PYTHONPATH=/home/benjamin/.dotfiles/opencode-discord-bot. Both dotfiles task 53 and nvim task 547 treated the bot source as the other's responsibility, so it was never created. The bot must implement: (1) Nextcord bot connecting to Discord with MESSAGE_CONTENT intent, (2) relay messages between Discord threads and the opencode-serve headless server at OPENCODE_SERVER_URL, (3) HTTP API endpoints for Neovim integration: POST /link (create Discord thread, return thread URL), GET /sessions (list linked sessions), POST /kill (kill a session), GET /health, (4) auth via LINK_API_TOKEN header on HTTP API, (5) read credentials from systemd LoadCredential paths (DISCORD_BOT_TOKEN, OPENCODE_SERVER_PASSWORD at %d/ paths), (6) environment variables: DISCORD_BOT_TOKEN, OPENCODE_SERVER_PASSWORD, OPENCODE_SERVER_URL, WHITELISTED_USER_IDS, LINK_API_TOKEN, LOG_LEVEL. The Python environment (nextcord, aiohttp, anyio) is already provided by the discordBotPython nix derivation. Task type: python.

---

### 54. Revise configuration.md to be renamed discord-bot.md and correctly document the Discord bot feature with proper crosslinking
- **Status**: [COMPLETED]
- **Task Type**: markdown
- **Research**: [01_discord-bot-docs.md](specs/054_revise_configuration_to_discord_bot_documentation/reports/01_discord-bot-docs.md)
- **Plan**: [054_revise_configuration_to_discord_bot_documentation/plans/01_discord-bot-docs.md]
- **Summary**: [054_revise_configuration_to_discord_bot_documentation/summaries/01_discord-bot-docs-summary.md]

**Description**: Revise /home/benjamin/.dotfiles/docs/configuration.md to be named discord-bot.md and to carefully and correctly document this feature, maintaining repo documentation standards with careful crosslinking.

---

### 53. Install NixOS prerequisites for Discord bot setup
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Research**: [01_nixos-discord-bot-prerequisites.md](specs/053_nixos_discord_bot_prerequisites/reports/01_nixos-discord-bot-prerequisites.md)
- **Research**: [02_python-discord-bot-best-practices.md](specs/053_nixos_discord_bot_prerequisites/reports/02_python-discord-bot-best-practices.md)
- **Plan**: [02_nixos-discord-bot-prerequisites.md](specs/053_nixos_discord_bot_prerequisites/plans/02_nixos-discord-bot-prerequisites.md)
- **Completed**: 2026-05-07
- **Summary**: [02_nixos-discord-bot-prerequisites-summary.md](specs/053_nixos_discord_bot_prerequisites/summaries/02_nixos-discord-bot-prerequisites-summary.md)

**Description**: Configure NixOS prerequisites for the Discord bot system (based on external research task 547). Includes: sops-nix flake input + module, dedicated Python environment (nextcord, aiohttp, anyio), `opencode-serve` systemd service (OpenCode headless server), `discord-bot` systemd service (Nextcord bot relay), `.sops.yaml` with age key, encrypted `secrets/secrets.yaml` for Discord token and OpenCode server password. Bot project source lives at `~/.dotfiles/opencode-discord-bot/` per the external plan.

---

### 52. Add sleep inhibition during active Claude Code/Opencode sessions
- **Status**: [RESEARCHED]
- **Task Type**: nix
- **Research**: [052_sleep_inhibition_claude_opencode/reports/01_sleep_inhibition_claude_opencode.md]

**Description**: Create a feature to inhibit computer sleep while Claude Code or Opencode are actively running (not idle), while allowing screen dimming per GNOME settings. Research best practices for achieving this within the current NixOS configuration. The end goal is a `<leader>ai` Neovim mapping that inhibits sleep when these tools are running. The Neovim keymapping will be handled separately in the nvim config.

---

### 51. Documentation refactor: integrate ad-hoc notes into systematic docs
- **Status**: [NOT STARTED]
- **Task Type**: markdown

**Description**: Use the `programs.neovim` / `sideloadInitLua` fix (May 2026) as a concrete worked example to drive a repo-wide documentation refactor. The fix itself: a home-manager update changed the default behavior of `programs.neovim` so that provider config (python3_host_prog, ruby_host_prog) was written to `~/.config/nvim/init.lua` as a managed nix-store symlink, overwriting the user's config. Fix was `sideloadInitLua = true` in home.nix, which routes provider config through `--cmd` wrapper args instead. Initial documentation was created as: (1) an expanded inline comment on the `sideloadInitLua` line in `home.nix`, and (2) a new "Neovim" section in `NOTES.md`. The task is to evaluate and clean up that documentation, integrate it properly into `docs/` (likely `docs/applications.md` or a new `docs/neovim.md`) and any relevant `README.md` files, and use this specific case to establish a pattern and conventions for how NixOS config decisions, gotchas, and fixes should be documented repo-wide going forward. The goal is a sustainable, navigable documentation system where inline comments capture the why briefly, and `docs/` contains the full context.

---

### 50. Fix claude-sleep-inhibitor pgrep self-matching preventing sleep
- **Status**: [NOT STARTED]
- **Task Type**: nix

**Description**: Fix claude-sleep-inhibitor pgrep self-matching: `pgrep -f 'claude'` matches the inhibitor script itself, claude-memory-tracker, earlyoom --prefer pattern, and other non-session processes, causing the inhibitor to never release and permanently blocking sleep. Replace with a more specific pattern that only matches actual Claude Code session processes.

---

### 49. Fix claude-sleep-inhibitor Nix derivation broken sh path causing tight failure loop
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Completed**: 2026-04-19
- **Artifacts**:
  - [01_sleep-inhibitor-fix.md](specs/049_fix_claude_sleep_inhibitor_nix/reports/01_sleep-inhibitor-fix.md)
  - [01_sleep-inhibitor-fix.md](specs/049_fix_claude_sleep_inhibitor_nix/plans/01_sleep-inhibitor-fix.md)
  - [01_sleep-inhibitor-fix-summary.md](specs/049_fix_claude_sleep_inhibitor_nix/summaries/01_sleep-inhibitor-fix-summary.md)

**Description**: The claude-sleep-inhibitor Nix derivation uses a bare `sh` in `systemd-inhibit ... sh -c '...'` which fails to resolve in the Nix environment ("No such file or directory"). This causes ~110 process spawns/sec, driving polkitd (8.4%), nsncd (8.3%), and dbus-daemon (4.1%) CPU usage, heating thermal zones to 89.8°C and ramping fans. Fix by replacing bare `sh` with a full Nix store path (e.g., `${pkgs.bash}/bin/bash`) and add a sleep-on-failure guard to the outer loop.

---

### 48. Replace markitdown venv wrapper with nixpkgs python312Packages.markitdown
- **Status**: [COMPLETED]
- **Language**: nix
- **Completed**: 2026-04-13
- **Artifacts**:
  - [01_markitdown-nixpkgs-migration.md](specs/048_replace_markitdown_venv_with_nixpkgs/reports/01_markitdown-nixpkgs-migration.md)
  - [01_markitdown-nixpkgs-migration.md](specs/048_replace_markitdown_venv_with_nixpkgs/plans/01_markitdown-nixpkgs-migration.md)
  - [01_markitdown-nixpkgs-migration-summary.md](specs/048_replace_markitdown_venv_with_nixpkgs/summaries/01_markitdown-nixpkgs-migration-summary.md)

**Description**: Replace the custom venv-based markitdown wrapper (`packages/markitdown.nix`) with the native `python312Packages.markitdown` from nixpkgs. Add markitdown to the existing `python312.withPackages` block in `home.nix`, remove the overlay entry from `flake.nix`, and delete the custom package file. This makes `import markitdown` work from system Python without pip or venv management.

---

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

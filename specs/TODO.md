# Task List

## Active Tasks

### 64. Clean regenerable caches and reclaim disk space
- **Status**: [NOT STARTED]
- **Task Type**: general

**Description**: Clean regenerable caches and reclaim disk space (root filesystem at 94%, 28GB free). Targets: ~/.local/share/Trash (4.2GB), ~/.cache/loogle (7.4GB), ~/.cache/pip (3GB), ~/.cache/nix (2.1GB), ~/.cache/uv (2GB), ~/.npm (8.5GB), ~/.local/share/memory-monitor logs (1.8GB), and audit ~/.local/share/opencode (11GB, mostly storage/) and ~/.local/share/protonmail (14GB local mail cache) for safe pruning. Roughly 25-30GB recoverable without touching personal files. Consider adding periodic cache cleanup (e.g. systemd-tmpfiles or a cleanup script) so these do not regrow unbounded.

---

### 63. Enable user-level Nix GC and expire old home-manager generations
- **Status**: [NOT STARTED]
- **Task Type**: nix

**Description**: Enable automatic user-level Nix garbage collection and expire old home-manager generations. 62 home-manager generations spanning Mar 13 - Jun 11 act as GC roots pinning ~3 months of unstable closures in the 99GB /nix/store; the root-level nix.gc.automatic (weekly, 30d) never touches user profiles. Add nix.gc automatic settings to home.nix (home-manager equivalent of the system GC), run a one-time home-manager expire-generations "-30 days" plus user and root nix-collect-garbage to reclaim space, and verify store size afterward.

---

### 62. Replace piper-tts with svox pico and drop onnxruntime
- **Status**: [PLANNED]
- **Report**: [specs/062_replace_piper_with_svox_pico_drop_onnxruntime/reports/01_replace-piper-svox-pico.md]
- **Plan**: [specs/062_replace_piper_with_svox_pico_drop_onnxruntime/plans/01_implementation-plan.md]
- **Task Type**: nix

**Description**: Replace piper-tts with svox pico (pico2wave) and drop onnxruntime from the system closure. DECISION: use pico. Nix changes: swap piper-tts for the svox pico package in configuration.nix:635, remove packages/piper-voices.nix and its flake.nix overlay entry (line 99), remove the home.nix:1199 .local/share/piper link, and handle the second onnxruntime consumer markitdown (home.nix:401, via magika) - remove it or run on-demand via nix shell. Agent system changes: update all 5 copies of tts-notify.sh to use pico2wave instead of piper (~/.config/nvim/.claude/hooks/, ~/.config/nvim/.claude/extensions/core/hooks/, ~/.config/nvim/.opencode/hooks/, ~/.config/nvim/.opencode/extensions/core/hooks/, ~/.dotfiles/.claude/hooks/) - replace the piper --model pipeline and PIPER_MODEL env var with pico2wave, keep the TTS_ENABLED toggle contract so which-key.lua TTS toggle keeps working unchanged. Update tts-stt-integration.md and neovim-integration.md guides in both repos to document pico. settings.json hook registrations need no change. Note: spans two git repos (.dotfiles and .config/nvim).

---

### 61. Pin nixpkgs flake input to stable channel for binary cache hits
- **Status**: [NOT STARTED]
- **Task Type**: nix

**Description**: Pin nixpkgs flake input to a stable release channel (nixos-26.05) to maximize binary cache hits and stop source-building heavy packages. The flake currently tracks nixos-unstable and update.sh runs nix flake update on every rebuild, outrunning Hydra and causing local compiles (29 packages on last update). Evaluate which inputs should stay on unstable (e.g. nix-ai-tools follows nixpkgs-unstable), align home-manager release-26.05 with the new pin, and consider making update.sh flake updates opt-in rather than automatic.

---

### 60. Add Nix build resource limits to prevent OOM during rebuilds
- **Status**: [NOT STARTED]
- **Task Type**: nix

**Description**: Add Nix build resource limits to prevent OOM during rebuilds: set nix.settings.max-jobs and nix.settings.cores in configuration.nix (24-core Ryzen AI 9 HX 370, 30GB RAM; onnxruntime builds currently exhaust memory via 24 parallel jobs x 24 cores). Choose values that balance build speed against the ~1-2GB/compile-unit cost of heavy C++ packages, and consider a --max-jobs override in update.sh.

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


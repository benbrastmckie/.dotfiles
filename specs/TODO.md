---
next_project_number: 67
---

# TODO

## Task Order

*Updated 2026-06-24. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 15,19,23,41,42,43,46,50,52,60,61,62,63,64,65 | -- | -- |
| 2 | 66 | 62,65 | nixos-config |

**Grouped by Topic** (indented = depends on parent):

### Nixos Config

66 [BLOCKED] — Systematically review all aspects of my current NixOS configurati

### Uncategorized

15 [RESEARCHED] — configure_timezone_location_based
19 [RESEARCHED] — install_setup_mcp_servers_web_development
23 [PLANNED] — install_simple_webcam_recording_software
41 [BLOCKED] — reenable_pdf2docx_nixpkgs_fix
42 [BLOCKED] — reenable_jupytext_nixpkgs_fix
43 [RESEARCHED] — install_forgejo_self_hosted_git
46 [RESEARCHED] — Investigate and fix Gmail OAuth2 token expiry - tokens keep expir
50 [RESEARCHED] — fix_sleep_inhibitor_pgrep_self_matching
52 [PLANNED] — sleep_inhibition_claude_opencode
60 [NOT STARTED] — Add Nix build resource limits to prevent OOM during rebuilds: set
61 [NOT STARTED] — Pin nixpkgs flake input to a stable release channel (nixos-26.05)
62 [IMPLEMENTING] — Replace piper-tts with svox pico (pico2wave) and drop onnxruntime
  └─ 66 [BLOCKED] — (nixos-config: Systematically review all aspects of my ) (see above)
63 [NOT STARTED] — Enable automatic user-level Nix garbage collection and expire old
64 [NOT STARTED] — Clean regenerable caches and reclaim disk space (root filesystem 
65 [IMPLEMENTING] — Migrate explicit python312 pins to the default python3 (currently
  └─ 66 [BLOCKED] — (nixos-config: Systematically review all aspects of my ) (see above)

## Tasks

### 66. Review refactor nixos configuration
- **Status**: [BLOCKED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: Task 62, Task 65
- **Research**: [066_review_refactor_nixos_configuration/reports/01_team-research.md]
- **Plan**: [066_review_refactor_nixos_configuration/plans/01_refactor-nixos-config.md]
- **Summary**: [066_review_refactor_nixos_configuration/summaries/01_refactor-nixos-config-summary.md]

**Description**: Systematically review all aspects of my current NixOS configuration, researching best practices online as of June 2026 in order to design a careful refactor that improves organization, documentation, and modularity, producing a maintainable and high performance configuration

---

### 65. Migrate python312 pins to default python3
- **Status**: [IMPLEMENTING]
- **Task Type**: nix
- **Dependencies**: None
- **Research**: [065_migrate_python312_pins_to_default_python3/reports/01_python312-to-python3-migration.md]
- **Plan**: [065_migrate_python312_pins_to_default_python3/plans/01_implementation-plan.md]
- **Summary**: [065_migrate_python312_pins_to_default_python3/summaries/01_implementation-summary.md]

**Description**: Migrate explicit python312 pins to the default python3 (currently 3.13.13 on the nixpkgs pin) for binary cache coverage: Hydra fully caches only the default python3Packages set, so the pinned 3.12 env can source-build heavy packages like torch (same failure class as onnxruntime). Change home.nix:352 python312.withPackages to python3.withPackages (env includes torch, jupyter, scipy stack, custom vosk package, z3-solver, cvc5, pynvim) and evaluate migrating the Discord bot pin at configuration.nix:10 (check the bot library against Python 3.13 PEP 594 stdlib removals: cgi, telnetlib, etc.). Verify custom vosk package and z3-solver/cvc5 bindings build on 3.13. Build-only verification; sequence after tasks 60/61 land so cache hits and memory guardrails are in place for the full env rebuild

---

### 64. Clean regenerable caches reclaim disk space
- **Status**: [NOT STARTED]
- **Task Type**: general
- **Dependencies**: None

**Description**: Clean regenerable caches and reclaim disk space (root filesystem at 94%, 28GB free). Targets: ~/.local/share/Trash (4.2GB), ~/.cache/loogle (7.4GB), ~/.cache/pip (3GB), ~/.cache/nix (2.1GB), ~/.cache/uv (2GB), ~/.npm (8.5GB), ~/.local/share/memory-monitor logs (1.8GB), and audit ~/.local/share/opencode (11GB, mostly storage/) and ~/.local/share/protonmail (14GB local mail cache) for safe pruning. Roughly 25-30GB recoverable without touching personal files. Consider adding periodic cache cleanup (e.g. systemd-tmpfiles or a cleanup script) so these do not regrow unbounded

---

### 63. User level nix gc expire home manager generations
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Dependencies**: None

**Description**: Enable automatic user-level Nix garbage collection and expire old home-manager generations. 62 home-manager generations spanning Mar 13 - Jun 11 act as GC roots pinning ~3 months of unstable closures in the 99GB /nix/store; the root-level nix.gc.automatic (weekly, 30d) never touches user profiles. Add nix.gc automatic settings to home.nix (home-manager equivalent of the system GC), run a one-time home-manager expire-generations "-30 days" plus user and root nix-collect-garbage to reclaim space, and verify store size afterward

---

### 62. Replace piper with svox pico drop onnxruntime
- **Status**: [IMPLEMENTING]
- **Task Type**: nix
- **Dependencies**: None

**Description**: Replace piper-tts with svox pico (pico2wave) and drop onnxruntime from the system closure. DECISION: use pico. Nix changes: swap piper-tts for the svox pico package in configuration.nix:635, remove packages/piper-voices.nix and its flake.nix overlay entry (line 99), remove the home.nix:1199 .local/share/piper link, and handle the second onnxruntime consumer markitdown (home.nix:401, via magika) - remove it or run on-demand via nix shell. Agent system changes: update all 5 copies of tts-notify.sh to use pico2wave instead of piper (~/.config/nvim/.claude/hooks/, ~/.config/nvim/.claude/extensions/core/hooks/, ~/.config/nvim/.opencode/hooks/, ~/.config/nvim/.opencode/extensions/core/hooks/, ~/.dotfiles/.claude/hooks/) - replace the piper --model pipeline and PIPER_MODEL env var with pico2wave, keep the TTS_ENABLED toggle contract so which-key.lua <leader> TTS toggle keeps working unchanged. Update tts-stt-integration.md and neovim-integration.md guides in both repos to document pico. settings.json hook registrations need no change. Note: spans two git repos (.dotfiles and .config/nvim)

---

### 61. Pin nixpkgs stable channel binary cache hits
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Dependencies**: None

**Description**: Pin nixpkgs flake input to a stable release channel (nixos-26.05) to maximize binary cache hits and stop source-building heavy packages. The flake currently tracks nixos-unstable and update.sh runs nix flake update on every rebuild, outrunning Hydra and causing local compiles (29 packages on last update). Evaluate which inputs should stay on unstable (e.g. nix-ai-tools follows nixpkgs-unstable), align home-manager release-26.05 with the new pin, and consider making update.sh flake updates opt-in rather than automatic

---

### 60. Add nix build resource limits prevent oom
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Dependencies**: None

**Description**: Add Nix build resource limits to prevent OOM during rebuilds: set nix.settings.max-jobs and nix.settings.cores in configuration.nix (24-core Ryzen AI 9 HX 370, 30GB RAM; onnxruntime builds currently exhaust memory via 24 parallel jobs x 24 cores). Choose values that balance build speed against the ~1-2GB/compile-unit cost of heavy C++ packages, and consider a --max-jobs override in update.sh

---

### 52. Sleep inhibition claude opencode
- **Status**: [PLANNED]
- **Task Type**: nix
- **Dependencies**: None
- **Research**: [052_sleep_inhibition_claude_opencode/reports/01_sleep_inhibition_claude_opencode.md]
- **Plan**: [052_sleep_inhibition_claude_opencode/plans/01_sleep-inhibition-implementation.md]

---

### 50. Fix sleep inhibitor pgrep self matching
- **Status**: [RESEARCHED]
- **Task Type**: nix
- **Dependencies**: None
- **Research**: [050_fix_sleep_inhibitor_pgrep_self_matching/reports/01_sleep-inhibitor-research.md]

---

### 46. Investigate fix gmail oauth2 token expiry
- **Status**: [RESEARCHED]
- **Task Type**: general
- **Dependencies**: None
- **Research_report**: [046_investigate_fix_gmail_oauth2_token_expiry/reports/01_gmail-oauth2-token-expiry.md]

**Description**: Investigate and fix Gmail OAuth2 token expiry - tokens keep expiring requiring repeated re-authentication with himalaya account configure gmail

---

### 43. Install forgejo self hosted git
- **Status**: [RESEARCHED]
- **Task Type**: general
- **Dependencies**: None
- **Research**: [43_install_forgejo_self_hosted_git/reports/research-001.md]

---

### 42. Reenable jupytext nixpkgs fix
- **Status**: [BLOCKED]
- **Task Type**: general
- **Dependencies**: None

---

### 41. Reenable pdf2docx nixpkgs fix
- **Status**: [BLOCKED]
- **Task Type**: general
- **Dependencies**: None

---

### 23. Install simple webcam recording software
- **Status**: [PLANNED]
- **Task Type**: general
- **Dependencies**: None
- **Research**: [23_install_simple_webcam_recording_software/reports/research-001.md]
- **Plan**: [23_install_simple_webcam_recording_software/plans/implementation-001.md]

---

### 19. Install setup mcp servers web development
- **Status**: [RESEARCHED]
- **Task Type**: general
- **Dependencies**: None
- **Research**: [19_install_setup_mcp_servers_web_development/reports/research-001.md]

---

### 15. Configure timezone location based
- **Status**: [RESEARCHED]
- **Task Type**: general
- **Dependencies**: None
- **Research**: [15_configure_timezone_location_based/reports/research-001.md]

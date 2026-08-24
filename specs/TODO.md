---
next_project_number: 130
---

# TODO

## Task Order

*Updated 2026-08-24. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 15,19,23,41,42,43,46,67,68,77,124,125,126,128 | -- | nixos-config, nix-infrastructure, services, ... |
| 2 | 117,120 | 77,124 | nixos-config, desktop |
| 3 | 78 | 120 | desktop |

**Grouped by Topic** (indented = depends on parent):

### Nixos Config

124 [PARTIAL] — Fix the battery-backstop wake-mark resume hook, which has never f
  └─ 117 [PARTIAL] — Configure laptop lid-close to blank screen but not sleep (keep AI
125 [PARTIAL] — Contain every Claude Code session in its own systemd user scope a
126 [NOT STARTED] — Run the flake formatter over the whole tree and commit the result
128 [NOT STARTED] — Correct this repo's Claude Code MCP registration and permission c

### Nix Infrastructure

67 [NOT STARTED] — Migrate R environment back to stable nixpkgs once nixos-26.05 fix
68 [NOT STARTED] — The iso and usb-installer nixosConfigurations fail to build becau

### Services

19 [RESEARCHED] — install_setup_mcp_servers_web_development
23 [PLANNED] — install_simple_webcam_recording_software
43 [RESEARCHED] — install_forgejo_self_hosted_git
46 [RESEARCHED] — Investigate and fix Gmail OAuth2 token expiry - tokens keep expir

### Desktop

77 [NOT STARTED] — Verify and reconcile background-service behavior in the niri+GNOM
  └─ 120 [NOT STARTED] — Give the niri session AC/battery-conditional idle suspend (12h on
    └─ 78 [NOT STARTED] — Rewrite docs/niri.md to match the actual, settled niri+GNOME-stac

### Maintenance

15 [RESEARCHED] — configure_timezone_location_based

### Packaging

41 [BLOCKED] — reenable_pdf2docx_nixpkgs_fix
42 [BLOCKED] — reenable_jupytext_nixpkgs_fix

## Tasks

### 128. Claude mcp registration and permission scope
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: None

**Description**: Correct this repo's Claude Code MCP registration and permission configuration on three counts, and register the NixOS MCP server. All four items below were empirically verified, not inferred -- do not re-derive them, but DO re-confirm before editing since this config may have moved on.

ITEM 1 -- REMOVE A FALSE DESIGN JUSTIFICATION (modules/home/core/dotfiles.nix, the activation.claudeMcpServers block, currently around lines 82-83). Its comment reads '(user scope; subagents cannot see project-scoped .mcp.json)'. That claim is FALSE and was disproven by direct experiment: a .mcp.json-registered stdio server WAS reachable from a filesystem-based subagent, confirmed twice, including via the exact custom agent class the agent system dispatches, with permission pre-granted so permission was not a confound. The earlier belief came from a confounded observation -- an already-running session cannot see a server added to .mcp.json after that session started, and this affects the MAIN session identically, so it is a session-start snapshot effect and has nothing to do with subagents or scope. Keeping playwright in user scope is still the RIGHT decision, but for different reasons that the comment should state instead: playwright-mcp is a Nix-built wrapper binary on PATH via home.packages, it depends on the machine-level ~/.cache/ms-playwright browser cache, it needs no per-project arguments, and it is useful across every repository. Fix the comment to give the true rationale; do not change the mechanism.

ITEM 2 -- REMOVE A DOMAIN-SPECIFIC GRANT FROM MACHINE SCOPE (config/claude/settings.json, deployed to ~/.claude/settings.json). It carries 'mcp__lean-lsp__*' in permissions.allow, granting a Lean-specific MCP server across EVERY repository on this machine. The agent-system repo recently removed this exact wildcard from its own domain-agnostic settings file on the grounds that a domain-specific grant does not belong there; that fix landed on the repo copy and missed this machine copy, because the two live in different git repositories with nothing linking them. Remove the entry. Note the consequence honestly before doing so: any repo that relies on lean-lsp tools without its own grant will begin prompting, which is the correct behavior but is a behavior change.

ITEM 3 -- ADD PLAYWRIGHT GRANTS AT MACHINE SCOPE (config/claude/settings.json). The playwright MCP server is registered machine-wide by the activation block in item 1 and shows Connected, but it has NO permission grant at user level anywhere. Its safe-tool grants currently live only inside two agent-system extensions that are not loaded in the nvim repo, so in practice every playwright call prompts -- and DENIES outright in headless or non-interactive runs, which is why autonomous runs stall. Add exactly these nine tools to permissions.allow, and no others: mcp__playwright__browser_navigate, mcp__playwright__browser_snapshot, mcp__playwright__browser_take_screenshot, mcp__playwright__browser_console_messages, mcp__playwright__browser_network_requests, mcp__playwright__browser_click, mcp__playwright__browser_type, mcp__playwright__browser_find, mcp__playwright__browser_wait_for. Deliberately WITHHOLD mcp__playwright__browser_evaluate, mcp__playwright__browser_file_upload, and mcp__playwright__browser_run_code_unsafe -- these execute arbitrary code or move files and MUST keep prompting. Do NOT substitute a mcp__playwright__* wildcard: a wildcard would grant those three too and reopen exactly the hole this enumeration exists to close. This asymmetry is the underlying principle to preserve: grant permissions at the same scope where the server is registered.

ITEM 4 -- REGISTER THE NIXOS MCP SERVER (modules/home/core/dotfiles.nix, activation.claudeMcpServers). Add a second jq merge alongside the playwright one, registering the server under the name 'nixos' -- NOT 'mcp-nixos'. The name matters: tools are addressed as mcp__<server-name>__<tool-name>, and the agent-system's existing grants and documentation both already use mcp__nixos__nix and mcp__nixos__nix_versions. Registering it as 'mcp-nixos' would produce mcp__mcp-nixos__* and silently break every existing grant and doc reference -- a naming mismatch that already exists in the agent-system's dead configuration and must not be carried over. Config: {"type":"stdio","command":"uvx","args":["mcp-nixos"]}. Use uvx rather than a uv tool install: uvx resolves at /run/current-system/sw/bin/uvx (system-level, reliably on PATH), whereas uv tool install places binaries in ~/.local/bin which is NOT on PATH in this configuration -- that PATH gap is exactly why setup-lean-mcp.sh needs a wrapper script. No new Nix wrapper package is required. Preserve the existing block's properties: it must remain idempotent, merge rather than overwrite (~/.claude.json also carries Claude Code OAuth, session, and project-list state that must survive every rebuild), and keep the DRY_RUN guard so home-manager switch --dry-run stays non-destructive. VERIFIED: running the server directly and requesting tools/list returns exactly two tools, nix and nix_versions, matching the existing grants -- so no grant changes are needed for this item, only registration. Consider also adding the two mcp__nixos__ grants to config/claude/settings.json so the server is usable in THIS repo (where NixOS package and option lookup is arguably most useful), applying the same grant-at-registration-scope principle as item 3.

VERIFICATION (all required): rebuild with home-manager switch --flake .#benjamin; then confirm claude mcp list shows both playwright and nixos as Connected; then confirm ~/.claude.json still contains its pre-existing OAuth/session/project keys and that the lean-lsp entry was not disturbed; then start a NEW Claude Code session (a running session will not see registration changes) and confirm a playwright navigation call and an mcp__nixos__nix search call both run without a permission prompt, while a browser_evaluate call still prompts. Also run nix flake check and nixos-rebuild build --flake .#hamsa to confirm nothing else broke.

---

### 126. Nix fmt whole tree formatter drift
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: None

**Description**: Run the flake formatter over the whole tree and commit the resulting drift so the repo is fmt-clean, making future formatter output a no-op and keeping unrelated reflow out of unrelated content commits. The drift is confirmed, not hypothetical: a repo-wide `nix fmt .` run during the task-reference cleanup reflowed the `mkQuerymap` argument list in modules/home/email/aerc.nix from a single-line attrset pattern to the multi-line form, on a line nobody had edited. That hunk was deliberately reverted to keep the cleanup commit scoped, so the drift is still present in the tree. Other files very likely carry the same class of drift and were NEVER surveyed: the cleanup pass ran the formatter once and inspected the diff only for non-comment changes, so any file it did not otherwise touch went unchecked. Scope: run the formatter over the tree, then review the ENTIRE resulting diff hunk by hunk before committing. A formatter is not a licence to skip review -- confirm specifically that no string literal, heredoc, or embedded shell block inside a nix string had its content or semantics changed, since several modules under modules/home/email/ carry substantial shell scripts inside nix strings (mail-sync.nix, mbsync.nix) whose echo output is user-visible. Commit as a single formatting-only change with no content edits mixed in. Verification (all four required): a second formatter run after committing must produce ZERO further changes -- this idempotence check is the actual proof the tree is fmt-clean and must not be skipped; `nix flake check` must pass; `nixos-rebuild build --flake .#hamsa` must succeed; `home-manager build --flake .#benjamin` must succeed. Invocation caveat: the formatter is nixfmt 1.4.0 exposed via the flake `formatter` output, and invoking it as `nix fmt .` emits a deprecation warning that passing directories or non-Nix files is going away, recommending the pkgs.nixfmt-tree wrapper or treefmt-nix instead. Determine the intended invocation BEFORE scripting the sweep so the committed result matches what a future formatter run (and CI, if it ever checks) would produce -- otherwise the idempotence check will pass locally and drift will reappear. Finally, check whether CI enforces formatting at all: .github/workflows/ci.yml currently runs statix and deadnix but the tree was found already drifted, which suggests no fmt gate exists. Decide whether adding one belongs in this task or a follow-up, and say which.

---

### 125. Claude session scope containment and reaper
- **Status**: [PARTIAL]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: None
- **Research**: [125_claude_session_scope_containment_and_reaper/reports/01_scope-containment-reaper.md]
- **Plan**: [125_claude_session_scope_containment_and_reaper/plans/01_scope-containment-reaper.md]
- **Summary**: [125_claude_session_scope_containment_and_reaper/summaries/01_scope-containment-reaper-summary.md]

**Description**: Contain every Claude Code session in its own systemd user scope and reap abandoned scopes, so a detached child process can never outlive the session that spawned it. Root cause confirmed live: all claude sessions AND their children currently share one cgroup (app-gnome-org.wezfurlong.wezterm-3725.scope), so there is no per-session boundary to clean up. This produced a runaway `python3 -u search_world_bound.py` that survived its dead session for 2d3h, burned 50h47m of CPU, and held the package at 99C (k10temp Tctl) with the fan pinned at max; a parallel case leaked ~5GB of orphaned lean-lsp workers. Mechanism is empirically proven on this host, not assumed: (1) `systemd-run --user --scope --unit=claude-<id>` contains even a `setsid nohup` double-forked child in the scope cgroup -- verified by reading cgroup.procs; (2) `systemctl --user stop <scope>` SIGKILLs everything in it -- verified the escaped child died; (3) an abandoned scope is detectable by enumerating the scope cgroup.procs and finding no live process named `claude`. BINDING SAFETY CONSTRAINT (user-stated): the reaper MUST NOT interrupt long-running work the user legitimately wants. Therefore the reap predicate MUST be liveness-based ONLY -- "the claude session that owns this scope is gone" -- and MUST NOT use any CPU-time, memory, or wall-clock threshold as a kill criterion; a child running for hours must survive untouched as long as its owning session lives. The reaper MUST only ever act on units matching the claude scope naming pattern, MUST never touch a scope containing a live claude process, and MUST NOT enumerate or kill arbitrary user processes. Implementation surface: add the scope wrapper to packages/claude-code.nix (currently a thin `exec npx @anthropic-ai/claude-code@latest`), verifying an interactive TTY session still works correctly inside a --scope; add a home-manager systemd user timer + service for the reaper; provide a documented opt-out for deliberately detaching work meant to outlive a session. Verify by launching a real claude session, confirming its children land in a distinct per-session cgroup, killing the session, and observing the orphan actually die -- never by inspecting unit files alone.

---

### 124. Fix wake mark resume hook wiring
- **Status**: [PARTIAL]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: None
- **Research**: [124_fix_wake_mark_resume_hook_wiring/reports/01_wake-mark-resume-hook.md]
- **Plan**: [124_fix_wake_mark_resume_hook_wiring/plans/01_wake-mark-resume-rewiring.md]
- **Summary**: [124_fix_wake_mark_resume_hook_wiring/summaries/01_wake-mark-resume-rewiring-summary.md]

**Description**: Fix the battery-backstop wake-mark resume hook, which has never fired. battery-backstop-wake-mark.service declares only WantedBy=post-resume.target, but post-resume.target does not exist on this system (systemctl show reports LoadState=not-found and no matching unit file), so nothing ever pulls the unit in. Confirmed against a real suspend/resume cycle: ActiveEnterTimestamp empty, no /var/lib/battery-suspend-backstop/wake-mark file. Consequence: the backstop wake-grace window is permanently inert, so a wake at <=10% to plug in a charger is re-suspended within ~60s -- the exact HIGH-severity behavior the grace window was added to prevent. Two false proofs must not be repeated: the populated post-resume.target.wants/ directory is orphaned (systemd never loads a wants dir whose target unit is absent) and is not evidence of wiring, and the cited precedent disable-speaker-amp in audio.nix actually activates via multi-user.target at boot, not on resume. Rewire to a mechanism that exists here (After=/WantedBy=suspend.target, or powerManagement.resumeCommands -- powerManagement.enable is already true at modules/system/power.nix:122) and verify by an actual suspend/resume cycle producing a wake-mark file, never by inspecting .wants/ symlinks or by a test harness that writes the wake-mark itself

---

### 120. Niri ac battery conditional idle suspend
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Topic**: desktop
- **Dependencies**: Task 119, Task 77

**Description**: Give the niri session AC/battery-conditional idle suspend (12h on AC, 1h on battery) to match the GNOME session. niri currently has zero idle auto-suspend on any power state (removed in task 117), and swayidle has no native AC/battery-conditional timeout: the single "timeout N command" clause spawned at config/config.kdl:271 applies unconditionally regardless of power source. Two candidate designs from the task 119 research: (Option A) a power-state-aware supervisor that respawns swayidle -w timeout <43200|3600> on /sys/class/power_supply/ACAD/online transitions, structurally mirroring the udev idiom already in modules/system/power.nix; (Option B) two mutually-exclusive systemd user units (swayidle-ac / swayidle-battery) gated on AC power. Known hazards either way: respawn races, two idle timers armed simultaneously, and a supervisor dying silently and leaving no idle policy at all. Must reuse the existing session-scoped systemd-inhibit mechanism from tasks 117/118 for Claude-activity awareness rather than building new detection. DO NOT resurrect the commented-out services.swayidle block in modules/home/desktop/swaylock.nix verbatim: its unconditional "timeout 600 -> systemctl suspend" example predates the AC/battery split requirement. Verification must read LIVE state after activation, not just the committed source, per the activation-lag bug class documented in task 119. Related: task 117 (partial) still owns lid-close and multi-monitor behavior; coordinate on docs/no-sleep-agents.md.

---

### 117. Laptop lid close no sleep headless
- **Status**: [PARTIAL]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: Task 124
- **Plan**: [117_laptop_lid_close_no_sleep_headless/plans/05_backstop-grace-and-live-verification.md]
- **Research**:
  - [117_laptop_lid_close_no_sleep_headless/reports/01_lid-close-no-sleep.md]
  - [117_laptop_lid_close_no_sleep_headless/reports/02_lid-close-screen-off-mechanism.md]
  - [117_laptop_lid_close_no_sleep_headless/reports/03_battery-level-backstop.md]
- **Summary**:
  - [117_laptop_lid_close_no_sleep_headless/summaries/01_lid-close-no-sleep-summary.md]
  - [117_laptop_lid_close_no_sleep_headless/summaries/02_battery-level-backstop-summary.md]
  - [117_laptop_lid_close_no_sleep_headless/summaries/05_backstop-grace-and-live-verification-summary.md]

**Description**: Configure laptop lid-close to blank screen but not sleep (keep AI agents running headless), preserving existing multi-monitor window distribution when monitors are attached, and document the setup in docs/ and relevant README.md files

---

### 78. Niri documentation rewrite
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Topic**: desktop
- **Dependencies**: Task 74, Task 75, Task 76, Task 77, Task 120

**Description**: Rewrite docs/niri.md to match the actual, settled niri+GNOME-stack configuration after tasks 74-77 land. The current doc is ~60% stale/aspirational: it is dominated by PaperWM material, cross-references archived specs (specs/reports/012_niri_with_gnome_integration.md and specs/plans/010_niri_gnome_portal_integration.md) that no longer drive the config, and its keybinding tables contradict config/config.kdl — e.g. the doc claims Mod+m = maximize and Mod+r = resize mode, but the config binds Mod+M = spotify and Mod+R = switch-preset-column-width; the doc's window-rule examples also use the old match{} block syntax instead of the current top-level window-rule blocks. Fix: (a) trim or clearly quarantine the PaperWM content so it is not presented as the active setup; (b) regenerate the keybinding reference directly from config/config.kdl so it is accurate; (c) remove dead spec cross-references; (d) add a concise 'GNOME-stack hybrid architecture' section documenting the two-layer model — GNOME services/backends (gnome-keyring, polkit-gnome, xdg portals, gnome-settings-daemon, gnome-control-center, Nautilus) vs niri surface tools (waybar, swaybg, mako, swaylock/swayidle, brightnessctl) — and how they compose. Depends on 74-77 so it documents the final state (including whatever reconciliation task 77 decides).

---

### 77. Niri gnome service reconciliation
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Topic**: desktop
- **Dependencies**: Task 74, Task 75, Task 76

**Description**: Verify and reconcile background-service behavior in the niri+GNOME hybrid session, resolving overlaps rather than leaving gaps. Depends on tasks 74-76 being applied so the session reflects its intended final state. (1) xwayland-satellite: pkgs.xwayland-satellite is installed (modules/system/packages.nix:19; the inline comment claims auto-detection since niri 25.08). Confirm it actually auto-spawns and exports DISPLAY in the niri session — run 'echo $DISPLAY' in a niri terminal and launch an X11 app (e.g. zoom-us). If DISPLAY is empty, add an explicit xwayland-satellite spawn and DISPLAY export. (2) NOTIFICATIONS: services.mako (modules/home/desktop/mako.nix) is enabled and is expected to D-Bus-activate on org.freedesktop.Notifications without explicit startup. Confirm with 'notify-send test' in the niri session; if nothing appears, add an explicit mako startup. (3) gsd/swayidle OVERLAP: gnome-settings-daemon is enabled system-wide (services.gnome.gnome-settings-daemon in modules/system/desktop.nix) while swayidle is spawned in config.kdl:261 for idle-lock/suspend/before-sleep. Some gsd helpers (notably gsd-power for lid-close and idle) may partially run under niri and double-act with swayidle/logind (e.g. double-suspend, or fighting over lid events). Confirm there is no double-suspend or conflicting idle/lid behavior; if there is, disable the overlapping gsd component for the niri session or reconcile logind/swayidle timeouts. Document findings inline and adjust configuration as needed.

---

### 68. Fix broken zfs kernel installer builds
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Topic**: nix-infrastructure
- **Dependencies**: None

**Description**: The iso and usb-installer nixosConfigurations fail to build because zfs-kernel is broken on the current kernel (7.1.1): installation-cd-minimal.nix pulls in ZFS via supportedFilesystems. Restore buildable installer images by one of: disabling ZFS in the installer (boot.supportedFilesystems exclude zfs), pinning a kernel that ZFS supports for the installer only, or waiting for upstream zfs compatibility then bumping. Pre-existing issue surfaced during task 66 final audit; affects both pre- and post-refactor trees equally (not a regression).

---

### 67. Migrate r env back to stable nixpkgs
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Topic**: nix-infrastructure
- **Dependencies**: None

**Description**: Migrate R environment back to stable nixpkgs once nixos-26.05 fixes r-V8. The R wrapper in configuration.nix (rWrapper with survival/tidyverse/gtsummary/mice/languageserver/styler/lintr etc.) is currently sourced from pkgs-unstable as a workaround: stable nixpkgs-26.05 ships r-V8 8.0.1 which expects ICU 78 but stable provides ICU 76.1, with no standalone v8 package to bridge it, causing a link failure (undefined icu_78 symbols) that cascades through gt -> gtsummary -> R-wrapper -> system-path and breaks the whole hamsa build. The fix gate is upstream: nixpkgs-26.05 must align r-V8/nodejs-slim libv8/ICU (version bump or backport). Test procedure: after a ./update.sh --update advances the 26.05 pin, flip two lines in configuration.nix back (pkgs-unstable.rWrapper -> rWrapper, pkgs-unstable.rPackages -> rPackages) and run nixos-rebuild build --flake .#hamsa; if r-V8 builds, migrate back and keep it, otherwise revert the flip and wait for the next stable advance. Restores the binary-cache-hit benefit of the task 61 stable pin for the heavy R+texlive stack. Follow-up of task 61.

---

### 46. Investigate fix gmail oauth2 token expiry
- **Status**: [RESEARCHED]
- **Task Type**: general
- **Topic**: services
- **Dependencies**: None
- **Research_report**: [046_investigate_fix_gmail_oauth2_token_expiry/reports/01_gmail-oauth2-token-expiry.md]

**Description**: Investigate and fix Gmail OAuth2 token expiry - tokens keep expiring requiring repeated re-authentication with himalaya account configure gmail

---

### 43. Install forgejo self hosted git
- **Status**: [RESEARCHED]
- **Task Type**: general
- **Topic**: services
- **Dependencies**: None
- **Research**: [43_install_forgejo_self_hosted_git/reports/research-001.md]

---

### 42. Reenable jupytext nixpkgs fix
- **Status**: [BLOCKED]
- **Task Type**: general
- **Topic**: packaging
- **Dependencies**: None

---

### 41. Reenable pdf2docx nixpkgs fix
- **Status**: [BLOCKED]
- **Task Type**: general
- **Topic**: packaging
- **Dependencies**: None

---

### 23. Install simple webcam recording software
- **Status**: [PLANNED]
- **Task Type**: general
- **Topic**: services
- **Dependencies**: None
- **Research**: [23_install_simple_webcam_recording_software/reports/research-001.md]
- **Plan**: [23_install_simple_webcam_recording_software/plans/implementation-001.md]

---

### 19. Install setup mcp servers web development
- **Status**: [RESEARCHED]
- **Task Type**: general
- **Topic**: services
- **Dependencies**: None
- **Research**: [19_install_setup_mcp_servers_web_development/reports/research-001.md]

---

### 15. Configure timezone location based
- **Status**: [RESEARCHED]
- **Task Type**: general
- **Topic**: maintenance
- **Dependencies**: None
- **Research**: [15_configure_timezone_location_based/reports/research-001.md]

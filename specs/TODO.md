---
next_project_number: 146
---

# TODO

## Task Order

*Updated 2026-11-21. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 15,19,23,41,42,43,46,67,68,77,124,125,126,131,133,145 | -- | nixos-config, nix-infrastructure, services, ... |
| 2 | 117,120 | 77,124 | nixos-config, desktop |
| 3 | 78 | 120 | desktop |

**Grouped by Topic** (indented = depends on parent):

### Nixos Config

124 [PARTIAL] — Fix the battery-backstop wake-mark resume hook, which has...
  └─ 117 [PARTIAL] — Configure laptop lid-close to blank screen but not sleep...
125 [PARTIAL] — Contain every Claude Code session in its own systemd user...
126 [NOT STARTED] — Run the flake formatter over the whole tree and commit the...
133 [NOT STARTED] — Conduct systematic research, both locally (audit current...

### Nix Infrastructure

67 [NOT STARTED] — Migrate R environment back to stable nixpkgs once nixos-26.05...
68 [NOT STARTED] — The iso and usb-installer nixosConfigurations fail to build...

### Services

19 [RESEARCHED] — install\_setup\_mcp\_servers\_web\_development
23 [PLANNED] — install\_simple\_webcam\_recording\_software
43 [RESEARCHED] — install\_forgejo\_self\_hosted\_git
46 [RESEARCHED] — Investigate and fix Gmail OAuth2 token expiry - tokens keep...
131 [NOT STARTED] — Install claude-refresh timer via home-manager and make mako...

### Desktop

77 [NOT STARTED] — Verify and reconcile background-service behavior in the...
  └─ 120 [NOT STARTED] — Give the niri session AC/battery-conditional idle suspend...
    └─ 78 [NOT STARTED] — Rewrite docs/niri.md to match the actual, settled...

### Maintenance

15 [RESEARCHED] — configure\_timezone\_location\_based

### Packaging

41 [BLOCKED] — reenable\_pdf2docx\_nixpkgs\_fix
42 [BLOCKED] — reenable\_jupytext\_nixpkgs\_fix

### Sapience

145 [NOT STARTED] — Bring this machine's Sapience client up to the repo-link...

## Tasks

### 145. Sapience client payload with repo link and capture map
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Topic**: sapience
- **Dependencies**: None

**Description**: Bring this machine's Sapience client up to the repo-link feature. The vendor payload installed in ~/.sapience by the home-manager module (the ten Python files; docs/sapience.md lines 14-18 and 47-59) predates it: mcp.py and sapience_cli.py contain neither project_cid nor resolve_repo_link, so no MCP write, search or hook call from this machine carries a project id even in a repo that holds .sapience/project.json. (1) Establish how the module pins the payload and why the installed copy lags the app's mvp branch (pinned source versus the vendor's daily self-update), then update it to the first released client that carries the link resolver; the release is named by the sapience-app task repo_link_release_state_and_two_account_walkthrough, and until then record the interim (a pinned build from that branch, or waiting). (2) Add the linked repositories to the capture map (capture.projects in ~/.sapience/config.json, written by this module): today only sapience-app under ~/Projects/Sapience is listed, so sf1-engine transcripts are never extracted and the prompt and tool hooks return early through folder_allowed. Whether a link file should imply capture opt-in is ruled in the nvim extension's linked-repo write policy task; implement whichever it rules. (3) Re-check that the per-project MCP registration hook still writes a correct entry after the payload update and that no machine path leaks into a committed file. (4) Correct docs/sapience.md where it states eleven tool grants (the fragment grants seven). Done when sapience_search in a linked repo on this machine sends project_cid and a session in sf1-engine is captured.

---

### 139. Reduce sapience classifier cost
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: sapience
- **Dependencies**: Task 136, Task 140
- **Research**: [139_reduce_sapience_classifier_cost/reports/01_reduce-classifier-cost.md]
- **Plan**: [139_reduce_sapience_classifier_cost/plans/01_reduce-classifier-cost.md]
- **Summary**: [139_reduce_sapience_classifier_cost/summaries/01_reduce-classifier-cost-summary.md]

**Description**: Reduce or accept the Sapience extraction classifier cost now that extraction is metered. The classifier re-runs across the entire not-yet-extracted backlog on every run, which was free on the Ollama backend but is now the dominant per-run cost on the anthropic backend. A measured run took 29 minutes wall clock against only 3.5s CPU (entirely network-bound) to extract 71 sources and stage 1208 knowledge objects, with the classifier phase accounting for roughly the first 20 minutes before chunk extraction began. The Known gaps section of docs/sapience.md already records that the classifier classifies every not-yet-extracted session on every run while a backlog exists. Weigh the available levers: setting NO_CLASSIFY=1 (the vendor client comment is that redaction is the privacy guarantee, not this filter, at the cost of no longer filtering personal conversations out), caching classifier verdicts across runs the way source_skip verdicts are already cached in the source_rules.json state file, or accepting the cost and documenting it. Implement whichever is right and record the per-pass cost measurement in the Cost shape section of docs/sapience.md.

---

### 136. Measure Sapience capture coverage under manual extraction and decide whether to widen the scope, the cap, or the cadence
- **Status**: [COMPLETED]
- **Task Type**: general
- **Topic**: services
- **Dependencies**: Task 138
- **Research**: [136_evaluate_sapience_coverage_and_tune_extraction_scope/reports/02_baseline-and-extraction-backend-blocked.md]
- **Record**: [136_evaluate_sapience_coverage_and_tune_extraction_scope/records/01_coverage-pass-ledger.md]
- **Plan**: [136_evaluate_sapience_coverage_and_tune_extraction_scope/plans/03_single-sitting-decision-from-ledger.md]
- **Summary**: [136_evaluate_sapience_coverage_and_tune_extraction_scope/summaries/03_extraction-scope-decision-summary.md]

**Description**: GOAL. Measure how much of this machine's session history Sapience actually captures, and decide
from that measurement whether to widen the extraction scope, raise the per-run chunk cap, put
extraction on a schedule, or leave the arrangement as it stands. The deliverable is a decision
grounded in collected numbers, not a configuration change chosen up front.

BASELINE STARTS AFTER TASK 138. Task 138 (`retire_machine_wide_sapience_surface`) rewrites
exactly what Sapience captures. Its owner-action instruction reconciles `~/.sapience/config.json`
so that `/home/benjamin/Projects/BimodalLogic`, `/home/benjamin/Philosophy/Papers/PossibleWorlds`
and `/home/benjamin/Projects/Logos/Verification` are set `enabled: false` for capture, so that
`/home/benjamin/Projects/abood` and `/home/benjamin/Projects/Sapience/sapience-app` are added as
enabled entries, and so that the top-level `folders` allowlist is reduced to the
transcript-directory keys of the four repositories that actually load the sapience extension.
That reconciliation changes the source population this task exists to measure. A coverage or
pending figure collected before it is applied characterises a corpus that is about to be
discarded, and any MAX_CHUNKS or coverage conclusion drawn from such a figure rests on the wrong
denominator. The measurement window therefore opens only once 138's reconciliation is applied on
disk; readings taken before that point are not usable as a baseline. Record in this task's
artifacts how the reconciliation was confirmed applied before the first reading was taken.

NOTHING EXTRACTS ON A SCHEDULE. `programs.sapience.backgroundSync` defaults to false and
`home.nix` does not set it, so no `sapience-sync.timer` is installed and nothing reads a
transcript unless asked -- see `docs/sapience.md`, "Nothing extracts on a schedule". The two ways
to run a pass are `sapience sync` in a terminal and `systemctl --user start
sapience-sync.service` for a detached run that logs to the journal. The measurement is therefore
a series of hand-run passes; there is no cadence to observe passively.

METHOD.

1. Measure the current backlog first, after 138 has landed. Run `sapience coverage` and record
   its "Available on disk" block verbatim: "would ingest now", "skipped (outside Nd window)",
   "skipped (headless/agent)", "skipped (subagent / harness-started transcripts)", "skipped
   (folder not chosen)", together with the "Per-run extraction cap: N chunks (MAX_CHUNKS)" line
   and the folders-selected line. Run `sapience pending` and record it too. These readings are
   the baseline; take the backlog size from this measurement rather than from any figure carried
   in from elsewhere.
2. Run at least five extraction passes by hand, spaced at least a day apart and spanning at least
   a week of ordinary work, so each pass has fresh transcripts to find and the drain rate is
   observable rather than inferred from a single run. Capture `sapience coverage` and `sapience
   pending` after every pass, along with that run's own skip counts.
3. After the series, review what the vault actually holds -- not only the counters. Read through
   `sapience review` output and spot-check that the captured material is substantive work rather
   than thread mechanics.

WHAT THE FILTERS DO. Two independent filters drop transcripts, and telling them apart is the
point of the measurement.

- An overridable interactivity predicate (`_interactive` in `~/.sapience/upload.py`) requires at
  least two DISTINCT substantive human turns -- each at least 20 characters and not beginning
  with `<`, `[` or `{`. Transcripts failing it are reported as "skipped (headless/agent)" and can
  be kept for a single run with `--include-agents` or `SAPIENCE_INCLUDE_HEADLESS=1`.
- A non-overridable rule (`source_skip` in the same file) classifies a transcript as `subagent`
  or `harness-started` and never reads it. The client says so outright: the skip message states
  that `SAPIENCE_INCLUDE_HEADLESS=1` does not override this. These appear in coverage output as
  "skipped (subagent / harness-started transcripts)".

On an orchestration-heavy workflow the second filter removes more than the first, so measured
coverage can fall far below the session counts the folder picker shows. `sapience coverage`
reports the two counts separately, and which one dominates drives the decision below.

THE CHUNK CAP. `MAX_CHUNKS` defaults to 50 per run (`~/.sapience/upload.py`,
`~/.sapience/extract_local.py`). Whether 50 chunks per hand-run pass drains the measured backlog
at a useful rate, or whether a wider pass is needed (`sapience backfill 365` raises the cap and
widens the window for one pass), is a question this task answers from the measured backlog.

CANDIDATE OUTCOMES. Any combination of these, or none:

- Add a `programs.sapience.includeAgentSessions` option wiring `SAPIENCE_INCLUDE_HEADLESS` into
  the sync unit, if the headless/agent skip count is large and that material proves worth
  keeping.
- Adjust the per-run chunk cap, or prescribe a periodic wider backfill pass, if 50 per pass
  cannot keep up with the measured backlog.
- Turn on `programs.sapience.backgroundSync` (with `syncInterval`, default "hourly") so
  extraction runs on a timer, if hand-running proves too easy to forget. This is one candidate
  outcome among several, weighed against the stated reason the default is false: extraction
  spends real money or CPU per run.
- Leave all three as they are.

This requires observation over time, not a one-shot change.

---

### 133. Restructure nix configuration layout
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: None

**Description**: Conduct systematic research, both locally (audit current split between configuration.nix, home.nix, lib/mkHost.nix, modules/, hosts, flake.nix outputs) and online (NixOS/Home Manager/flake structuring best practices, e.g. flake-parts, dendritic/aspect-oriented patterns, NixOS-integrated vs standalone home-manager, system vs home package placement), to rethink how this Nix configuration is structured; identify the best, most maintainable structure going forward, then design and implement a systematic refactor

---

### 131. Install claude-refresh timer via home-manager and make mako idle-Lean-tree prompts actionable
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Topic**: services
- **Dependencies**: None

**Description**: Install the claude-refresh hourly timer via home-manager and configure mako so its idle Lean LSP tree Kill/Keep prompts are actionable and do not auto-expire.

BACKGROUND. On 2026-09-15 /refresh found a 22h-idle Lean LSP process tree (lake serve -> lean --server -> 4-5 lean --worker) left alive by a still-open Logos/Theory Claude session; lean-lsp-mcp has no idle timeout. The agent-system side (~/.config/nvim, agent-system/extensions/core/scripts/claude-refresh.sh) is being reworked in sibling nvim tasks: PSS-based memory accounting (Pss_Anon + SwapPss via /proc/PID/smaps_rollup), CPU-delta idle tracking in ~/.local/state/claude-refresh/lean-trees.json, a 1 GB reclaimable-memory floor, and a desktop-notification prompt. The hourly run stays --dry-run; when a tree is idle >= 240 min AND >= 1 GB reclaimable it launches a detached `systemd-run --user --unit=claude-refresh-prompt-<rootpid>-<starttime>` that calls `notify-send -a claude-refresh -u critical -t 0 -A default=Kill ...`. Clicking (mako invoke-default-action) runs a re-verified targeted kill; dismissing snoozes 4h.

FINDINGS ON THIS HOST (measured 2026-09-15).
  - claude-refresh.timer is NOT installed at all (`systemctl --user list-timers` shows only claude-session-reaper.timer). The /refresh docs' "hourly cadence" therefore never runs here.
  - The generic unit shipped in ~/.config/nvim/agent-system/extensions/core/systemd/claude-refresh.service sets `Environment=PATH=/usr/bin:/bin`, which is broken on NixOS (no procps/jq/gawk/notify-send/systemd-run there) and `User=%u` is invalid in a user unit.
  - modules/home/desktop/mako.nix sets default-timeout = 5000, which would auto-dismiss the prompt after 5 s (read as "Keep"), and no dmenu-style launcher exists for `makoctl menu`, so only the default action is clickable.

WORK.
  (a) New home-manager module modules/home/services/claude-refresh.nix modeled on services/claude-session-reaper.nix (oneshot service + calendar timer, OnCalendar=hourly, RandomizedDelaySec=300, Persistent=true). ExecStart = %h/.config/nvim/.claude/scripts/claude-refresh.sh --dry-run guarded by ConditionPathExists on the same path. Export a PATH containing ~/.nix-profile/bin and /run/current-system/sw/bin (procps, gawk, jq, coreutils, libnotify, systemd). The service must never end up `failed` (see the gmail-oauth2.nix precedent). Import it in modules/home/default.nix.
  (b) The service needs the graphical session's DBus for the spawned notification: ensure DBUS_SESSION_BUS_ADDRESS / WAYLAND_DISPLAY reach the transient unit (systemd --user environment import under niri is the likely mechanism; verify, do not assume).
  (c) mako: add a criteria section for app-name=claude-refresh with default-timeout = 0 (and optionally a distinct border colour), keeping left-click = invoke-default-action and right-click = dismiss. Verify with `makoctl` and a real `notify-send -a claude-refresh -A default=Kill` round trip that the action name prints on click and nothing prints on dismiss.
  (d) Confirm the transient prompt unit name does not match `claude-*.scope`, so claude-session-reaper never stops it.

DEPENDENCY. The prompt-launching logic lands in the nvim-side notification-prompt task; (a), (c) and (d) can land first (the timer is useful for dry-run logging on its own), but end-to-end acceptance of (b) waits on it.

ACCEPTANCE.
  - After a home-manager switch, `systemctl --user list-timers` shows claude-refresh.timer; a manual `systemctl --user start claude-refresh.service` succeeds and journal output contains the Lean LSP pass report.
  - A notify-send with app-name claude-refresh stays on screen until clicked; click prints the default action, dismiss prints nothing.
  - No regression to claude-session-reaper or memory-monitor units.

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
- **Parent**: Task 119

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
- **Parent**: Task 66

**Description**: The iso and usb-installer nixosConfigurations fail to build because zfs-kernel is broken on the current kernel (7.1.1): installation-cd-minimal.nix pulls in ZFS via supportedFilesystems. Restore buildable installer images by one of: disabling ZFS in the installer (boot.supportedFilesystems exclude zfs), pinning a kernel that ZFS supports for the installer only, or waiting for upstream zfs compatibility then bumping. Pre-existing issue surfaced during task 66 final audit; affects both pre- and post-refactor trees equally (not a regression).

---

### 67. Migrate r env back to stable nixpkgs
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Topic**: nix-infrastructure
- **Dependencies**: None
- **Parent**: Task 61

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

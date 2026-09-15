---
next_project_number: 132
---

# TODO

## Task Order

*Updated 2026-09-15. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 15,19,23,41,42,43,46,67,68,77,124,125,126,128,131 | -- | nixos-config, nix-infrastructure, services, ... |
| 2 | 117,120 | 77,124 | nixos-config, desktop |
| 3 | 78 | 120 | desktop |

**Grouped by Topic** (indented = depends on parent):

### Nixos Config

124 [PARTIAL] — Fix the battery-backstop wake-mark resume hook, which has...
  └─ 117 [PARTIAL] — Configure laptop lid-close to blank screen but not sleep...
125 [PARTIAL] — Contain every Claude Code session in its own systemd user...
126 [NOT STARTED] — Run the flake formatter over the whole tree and commit the...
128 [NOT STARTED] — Correct this repo's Claude Code MCP registration and...

### Nix Infrastructure

67 [NOT STARTED] — Migrate R environment back to stable nixpkgs once nixos-26.05...
68 [NOT STARTED] — The iso and usb-installer nixosConfigurations fail to build...

### Services

19 [RESEARCHED] — installsetupmcpserverswebdevelopment
23 [PLANNED] — installsimplewebcamrecordingsoftware
43 [RESEARCHED] — installforgejoselfhostedgit
46 [RESEARCHED] — Investigate and fix Gmail OAuth2 token expiry - tokens keep...
131 [NOT STARTED] — Install claude-refresh timer via home-manager and make mako...

### Desktop

77 [NOT STARTED] — Verify and reconcile background-service behavior in the...
  └─ 120 [NOT STARTED] — Give the niri session AC/battery-conditional idle suspend...
    └─ 78 [NOT STARTED] — Rewrite docs/niri.md to match the actual, settled...

### Maintenance

15 [RESEARCHED] — configuretimezonelocationbased

### Packaging

41 [BLOCKED] — reenablepdf2docxnixpkgsfix
42 [BLOCKED] — reenablejupytextnixpkgsfix

## Tasks

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

### 130. Provision the Comparator Lean proof-verification toolchain (landrun, lean4export, comparator)
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: packaging
- **Dependencies**: None
- **Research**: [130_provision_comparator_verification_toolchain/reports/01_comparator-toolchain-provisioning.md]
- **Plan**: [130_provision_comparator_verification_toolchain/plans/01_comparator-toolchain-provisioning.md]
- **Summary**: [130_provision_comparator_verification_toolchain/summaries/01_comparator-toolchain-provisioning-summary.md]

**Description**: Provision the three (optionally four) binaries the Comparator proof-verification
toolchain needs, so that the Lean agent system's forthcoming --compare verification path has
something to call. Today none of them are installed on this host.

WHAT COMPARATOR IS AND WHY THESE BINARIES. leanprover/comparator (Apache-2.0,
github.com/leanprover/comparator, default branch master, last push 2026-08-30, its own
lean-toolchain pinned to leanprover/lean4:v4.34.0-rc2) is Lean FRO's trustworthy judge for Lean
proofs from untrusted sources, built with AIMO feedback expressly to enable trustworthy LLM Lean
evaluation. Given a trusted Challenge.lean and an untrusted Solution.lean it builds each under a
sandbox, exports both declaration environments, verifies the Solution proves the same statements
under a permitted-axiom whitelist, and replays the Solution into the Lean kernel. Its README
names its dependencies exactly:
  1. landrun (github.com/Zouuup/landrun), compiled from the main branch, present in PATH --
     the Landlock-based sandbox each build and export runs inside.
  2. lean4export (github.com/leanprover/lean4export, default branch master, last push
     2026-08-25) "at a version that is compatible with whatever Lean version your project is
     targeting", present in PATH -- the plain-text declaration exporter. Comparator deliberately
     never loads .olean files, on the stated grounds that they are mmapped into the address space
     and dereferenced and are therefore an attack surface; lean4export is how it reads an
     environment instead.
  3. nanoda (github.com/ammkrn/nanoda_lib), OPTIONAL, built with a recent Rust; cargo build
     --release places nanoda_bin in target/release, which must be in PATH. Only needed to check
     with a second, independent kernel alongside Lean's own.
  4. the comparator binary itself, built from its lakefile.toml
     (defaultTargets = ["comparator"], lean_exe comparator with root Main, requiring
     leanprover/lean4export at rev master).
Full paths may be supplied instead of PATH entries via the environment variables
COMPARATOR_LANDRUN, COMPARATOR_LEAN4EXPORT and COMPARATOR_NANODA.

MEASURED STATE ON THIS HOST, 2026-09-07.
  lake, lean, elan   present, under ~/.elan/bin
  landrun            MISSING -- but packaged in nixpkgs at version 0.1.15
  lean4export        MISSING
  nanoda_bin         MISSING
  comparator         MISSING
  kernel             Linux 7.1.3

EXISTING PRECEDENT IN THIS REPO -- read these before choosing an approach.
  - flake.nix already carries a lean4 input (url github:leanprover/lean4, nixpkgs follows).
  - packages/loogle.nix is the closest existing analogue: a Lean 4 tool with no nixpkgs package,
    handled as a self-bootstrapping writeShellScriptBin wrapper that clones into ~/.cache and
    builds via the upstream project's own flake with lake. That pattern trades reproducibility
    for not having to package a lake build in Nix. Decide deliberately whether Comparator should
    follow it or be a real derivation; state the reasoning either way. A wrapper that silently
    rebuilds on first use is a poor fit for something whose entire purpose is being a trustworthy
    checker, so this decision deserves an argument rather than a copy-paste.
  - modules/home/packages/dev-tools.nix is the conventional home.packages home for developer
    tooling.
  - modules/system/nix.nix already notes that foreign binaries (elan/Lean toolchains among them)
    need special handling on NixOS -- relevant to anything elan-built landing in PATH.

WORK.
  (a) landrun: package from nixpkgs 0.1.15, OR from the main branch if the README's "compiled
      from the main branch's source" requirement is not satisfied by 0.1.15. CHECK THIS RATHER
      THAN ASSUMING -- the README is explicit about main, and a release tag may lag. Record what
      you found.
  (b) lean4export: must be built at a version compatible with the LEAN VERSION OF THE PROJECT
      BEING CHECKED, not Comparator's own v4.34.0-rc2 and not whatever is newest. This is the
      awkward requirement: it is per-target-project, so a single fixed system-wide build is
      likely wrong. Decide and document how a caller obtains a version-matched lean4export --
      candidates include building it per project on demand, providing several pinned builds, or
      exposing a helper that resolves it from a project's lean-toolchain. Whatever is chosen, the
      consuming agent system must be able to detect a MISMATCH loudly rather than run and produce
      a confusing failure.
  (c) comparator itself, built from its lakefile.
  (d) nanoda: optional. Decide whether to include it now. Its only benefit is a second kernel,
      so it is reasonable to defer -- but say so explicitly rather than omitting it silently.
  (e) Expose the resolved paths so that COMPARATOR_LANDRUN, COMPARATOR_LEAN4EXPORT and
      COMPARATOR_NANODA can be set, since the consuming side prefers env-var resolution over PATH
      probing.

SANDBOX CAVEAT WORTH RECORDING. Comparator's README recommends wrapping invocation in
  systemd-run --property=RestrictAddressFamilies=~AF_UNIX --user --pty -E PATH="$PATH" \
    --working-directory $(pwd) -- bash -c 'lake env <comparator> <config.json>'
to guard against a landrun sandbox-escape vulnerability that the README states "will be fixed in
Linux 7.1". This host runs 7.1.3 and is therefore past that fix, but the wrapper is still
required for portability and should not be dropped on the strength of this host's kernel alone.
Note this in whatever documentation accompanies the packaging.

CONSUMER. Four sibling tasks in ~/.config/nvim/ build the agent-system side: a clean-room runner
script, a trusted-Challenge snapshot mechanism, an advisory --compare flag threaded through the
Lean implementation agent, and the trust-boundary documentation. Those tasks can make partial
progress against Comparator's own scripts/fake-landrun.sh development substitute, but their
end-to-end acceptance depends on this task. Coordinate the env-var contract with them rather
than inventing a second one.

ACCEPTANCE.
  - landrun, lean4export and comparator are all invocable after a rebuild, demonstrated by
    actually running each with a version or help flag -- not by showing the derivation evaluates.
  - Comparator runs successfully against at least one of its own tests/projects fixtures
    (tests/projects/ ships Challenge/Solution/config triples including simple_mismatch, def_hole,
    def_hole_axiom_issue, def_hole_type_mismatch, olean_issue and opaque_value), producing the
    fixture's expected verdict. A pass on a matching pair AND a rejection on a mismatching pair,
    both demonstrated -- a checker that only ever accepts proves nothing.
  - The lean4export version-matching decision from (b) is written down with its reasoning, and a
    mismatch is detectable by a caller.
  - The landrun main-branch-versus-0.1.15 question from (a) is answered with evidence.

---

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

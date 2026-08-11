---
next_project_number: 130
---

# TODO

## Task Order

*Updated 2026-08-11. Generated from state.json dependency graph.*

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

### 129. Provision zotero agent tooling
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: None
- **Research**: [129_provision_zotero_agent_tooling/reports/02_zotero-tooling-provisioning-verification.md]
- **Plan**: [129_provision_zotero_agent_tooling/plans/01_provision-zotero-agent-tooling.md]
- **Summary**: [129_provision_zotero_agent_tooling/summaries/01_provision-zotero-agent-tooling-summary.md]

**Description**: Provision the machine-level tooling that unblocks the literature extension's Zotero write-back path in the agent-system repo (~/.config/nvim — its tasks 38 and 39 are the consumers). All facts verified live on 2026-08-11 (see seed report); re-confirm before editing since the environment may have moved on.

ITEM 1 — PUT `zot` ON PATH (the single hard blocker). Package `zotero-cli-cc` (PyPI, 0.10.0 released 2026-07-15, "Zotero CLI for Claude Code — SQLite reads + Web API writes"). The consuming scripts invoke bare `zot`, so it must resolve from interactive shells AND agent-spawned bash. KNOWN PATH GAP in this configuration (recorded in task 128's research): `uv tool install` drops binaries in ~/.local/bin, which is NOT on PATH here — that gap is why setup-lean-mcp.sh needed a wrapper. Preferred: a Nix-built wrapper on home.packages (the playwright-mcp pattern), e.g. writeShellScriptBin "zot" exec-ing `uvx --from zotero-cli-cc zot "$@"` (uvx resolves at /run/current-system/sw/bin/uvx, reliably on PATH). Avoid changing global PATH policy for this.

ITEM 2 — MANAGE ZOTERO_API_KEY. It is currently hardcoded in ~/.config/fish/conf.d/private.fish (line 49), unmanaged by Nix, and therefore visible to fish sessions but NOT to non-fish login shells or systemd user services — headless/scheduled agent runs cannot see it. Verified via GET https://api.zotero.org/keys/current: full library+files+write access. Move it into the repo's secrets mechanism (secrets/) and export it to all shells plus the systemd user environment (environment.d drop-in, import-environment at session start, or home-manager session variables — match existing repo practice). The key has sat in plaintext and appeared in session logs: decide explicitly whether to rotate it at zotero.org/settings/keys during migration (a replacement needs the same library+files+write grants).

ITEM 3 — TRANSLATION-SERVER SERVICE (optional but recommended; the agent-system repo's metadata-resolution task consumes it and degrades gracefully without it). Official zotero/translation-server (Node; official Docker image; port 1969; POST /search for DOI/ISBN/PMID/arXiv → Zotero JSON, POST /web for URL). Stateless, no credentials. Provision as a localhost-only service via virtualisation.oci-containers/podman user service (or packaged Node service if container-free is preferred); disabled-by-default with a documented enable toggle is acceptable.

ITEM 4 — DO NOT REGISTER zotero-mcp YET. The adoption decision lives in the agent-system repo (its task 39). If it lands on adopt, registration belongs in the claudeMcpServers activation block in modules/home/core/dotfiles.nix with grants at the same scope, per the grant-at-registration-scope principle in task 128's description.

VERIFICATION (all required): home-manager switch and nix flake check succeed; `command -v zot` resolves and `zot --version` reports >=0.10.0 from fresh bash AND fish; ZOTERO_API_KEY non-empty in fresh bash, fish, and `systemctl --user show-environment` (or the chosen headless path demonstrated otherwise); when the translation-server toggle is enabled, a POST /search smoke test returns Zotero JSON. Do NOT run `zot add` writes against the real library as part of this task — the live write verification belongs to the agent-system repo's task and must be coordinated deliberately.

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

### 127. Add playwright mcp server to nix config
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: None
- **Research**: [127_add_playwright_mcp_server_to_nix_config/reports/01_playwright-mcp-nix-integration.md]
- **Plan**: [127_add_playwright_mcp_server_to_nix_config/plans/01_playwright-mcp-nix-declaration.md]
- **Summary**: [127_add_playwright_mcp_server_to_nix_config/summaries/01_playwright-mcp-nix-declaration-summary.md]

**Description**: Add the Playwright MCP server to the Nix configuration so Claude Code can drive a browser, declared in the same module/option style used elsewhere in the config rather than registered ad-hoc via the CLI. Reuse the existing nix-ld Chromium dependency set in modules/system/nix.nix and the already-populated ~/.cache/ms-playwright browsers instead of re-downloading them. Include concise documentation for the addition matching surrounding conventions.

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

### 123. Fix backstop polkit denial live verification
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: None
- **Research**: [123_fix_backstop_polkit_denial_live_verification/reports/01_backstop-polkit-denial.md]
- **Plan**: [123_fix_backstop_polkit_denial_live_verification/plans/01_backstop-polkit-fix.md]
- **Summary**: [123_fix_backstop_polkit_denial_live_verification/summaries/01_backstop-polkit-fix-summary.md]

**Description**: Fix the battery-suspend-backstop polkit denial and replace stubbed verification with live end-to-end checks: the login1 policy sets allow_any=auth_admin_keep on org.freedesktop.login1.suspend-ignore-inhibit, so the backstop oneshot (root, session-less, no polkit agent) is denied when it runs systemctl suspend -i, making the <=10% battery safety net a silent no-op; enable a root-scoped suspend-ignore-inhibit polkit rule in modules/system/power.nix (systemd ships 10-systemd-logind-root-ignore-inhibitors.rules.example for exactly this), then verify the suspend and notification legs without the BACKSTOP_SYSTEMCTL_BIN / BACKSTOP_NOTIFY_BIN stubs that hid both this defect and the earlier runuser #UID defect

---

### 122. Orchestrator runtime file tracking policy
- **Status**: [ABANDONED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 121

**Description**: Define and enforce a single tracking policy for orchestrator runtime scratch files, which today have no policy at all and are inconsistently committed.

VERIFIED EVIDENCE. `.gitignore` has NO coverage for any of them (verified: no matches for orchestrator, return-meta, loop-guard, or .lock). Live committed counts across specs/: 45 `.return-meta.json`, 27 `.orchestrator-handoff.json`, 3 `.orchestrator-loop-guard`, and 2 committed `.lock` entries (directories created by task-lock.sh).

SAFETY HAZARD (priority within this task). The committed `.orchestrator-loop-guard` files are an ACTIVE CORRECTNESS HAZARD, not merely noise. The loop guard carries cycle_count / max_cycles / current_state, and skill-orchestrate Stage 2 RESUMES from an existing guard rather than starting fresh. A guard committed into git - or restored by a checkout, clone, or branch switch - can make a fresh `/orchestrate` believe it is already mid-run at a stale cycle count, silently consuming its cycle budget.

ROOT CONTRADICTION. `/orchestrate` CHECKPOINT 3 in `.claude/commands/orchestrate.md` stages the WHOLE task directory (`specs/NNN_slug/`), which sweeps these runtime files in, while implementation agents treat them as uncommitted runtime state ("runtime files the orchestrator manages itself, left uncommitted per the established pattern"). The command and the agents actively contradict each other, which is why tracking is inconsistent.

USER-CHOSEN POLICY (already decided - implement this, do not re-litigate it):
- GITIGNORE and UNTRACK: `specs/*/.orchestrator-loop-guard` and `specs/*/.lock/`. These are pure ephemeral runtime state, and the committed loop-guards are the actual hazard.
- KEEP TRACKED as durable provenance: `specs/*/.orchestrator-handoff.json` and `specs/*/.return-meta.json`. These form the per-dispatch audit trail of what each dispatch reported, and the 72 already-committed files should stay.
- The task must therefore include untracking the 3 currently-committed `.orchestrator-loop-guard` files via `git rm --cached` (preserving them on disk) plus the committed `.lock` entries, and must NOT untrack handoff or return-meta files.

REQUIRED RECONCILIATION. After the policy is set, ALL of these must agree with each other and with the new .gitignore:
- `.gitignore`
- `.claude/context/standards/git-staging-scope.md` - the staging scope contract must stop implying whole-task-dir adds sweep in ephemeral files
- `.claude/commands/orchestrate.md` CHECKPOINT 3, and the multi-task Step 5 batch-commit staging, which also stages whole task dirs
- `.claude/skills/skill-orchestrate/SKILL.md` - document the loop guard as ephemeral/never-committed, reinforcing Stage 2's resume semantics and Stage 8's cleanup

DEPENDENCY RATIONALE. This task depends on task 121 because both have `.claude/skills/skill-orchestrate/SKILL.md` in their file_scope. The dependency edge exists specifically to serialize them so the file-footprint overlap rule (`.claude/context/patterns/file-footprint-overlap.md`) never places them in the same dispatch wave. They must not be created or dispatched as independent siblings.

---

### 121. Fix gate out artifact validation and status vocabulary
- **Status**: [ABANDONED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: Repair two verified defects in `.claude/scripts/command-gate-out.sh`. They are merged into one task because they share the root theme "gate-out silently does nothing" and occupy the same small region of the same file, so one agent should reason about the whole gate-out contract at once.

DEFECT 1 - validate-artifact.sh call-arity bug (silent dead code). `.claude/scripts/command-gate-out.sh:101` calls `bash .claude/scripts/validate-artifact.sh "$task_dir" --fix 2>/dev/null || true`, but validate-artifact.sh's signature is `<artifact_path> <type> [--fix] [--strict]` where type must be report|plan|summary. So `--fix` is parsed as the TYPE argument and a DIRECTORY is passed as the artifact path; it exits 3 (file not found) and prints `[FAIL] File not found: specs/NNN_slug` on every gate-out run. Consequence: the non-blocking artifact link-repair that gate-out claims to perform has NEVER run for any command, for any task. It fails silently (swallowed by `|| true`) while emitting misleading FAIL output that users see. Uniformity evidence: EVERY other caller in the system uses the correct 3-token form `validate-artifact.sh "$artifact_path" "$artifact_kind" --fix` - see `.claude/scripts/skill-base.sh:260`, `.claude/scripts/orchestrator-postflight.sh:174`, and the SKILL.md files for skill-researcher, skill-planner, skill-implementer, skill-reviser, skill-planner-hard, skill-researcher-hard. command-gate-out.sh is the lone deviant. Required approach: prefer extracting ONE shared helper (e.g. a "validate every artifact in a task dir with its correct type" function, likely belonging in skill-base.sh alongside the existing caller) over duplicating a per-type loop inline in gate-out, so this convention cannot drift again. Also investigate `.claude/commands/research.md:424`, which already documents that "the validate-artifact.sh --fix leg is dead code and cannot substitute for this check" - determine whether that is the same root cause and fix it uniformly rather than in isolation.

DEFECT 2 - .return-meta.json status vocabulary mismatch (unreachable defensive correction). `.claude/skills/skill-orchestrate/SKILL.md` Stage 8 writes `.return-meta.json` with status "completed" (clean exit) or "partial". `.claude/scripts/command-gate-out.sh:84-85` only enters its defensive status-correction branch when skill_status is one of "implemented", "researched", or "planned". Therefore for the orchestrate operation the correction branch can NEVER fire. If state.json were ever desynced after an orchestrate run, gate-out would silently fail to repair it - which is the entire stated purpose of that checkpoint. The script's own inline comment at lines 70-74 (just above the `case "$operation"` block) claims it repaired a latent bug where "orchestrate" was previously passed verbatim as target_status and "would have failed update-task-status.sh's validation had this branch ever been exercised on a desynced orchestrate run." That comment reasons about a branch that is in fact unreachable for a different reason; the comment is misleading and must be corrected along with the code. Required approach: establish ONE documented status vocabulary shared between everything that WRITES `.return-meta.json` and everything that READS it, enforced in a single place. `.claude/docs/architecture/handoff-schema.md` is the natural single source of truth. Audit for other spellings across skill-implementer, skill-researcher, skill-planner, skill-reviser, the team skills (skill-team-research/plan/implement), and the hard-mode skills (skill-orchestrate-hard, skill-researcher-hard, skill-planner-hard, skill-implementer-hard) - there may be further divergent spellings beyond the two already found.

Note the tension to resolve deliberately: `.claude/context/formats/return-metadata-file.md` explicitly states 'Never use "completed" - it triggers Claude stop behavior', yet skill-orchestrate Stage 8 writes exactly that. Whichever vocabulary is chosen must be reconciled with that constraint, not silently contradict it.

---

### 120. Niri ac battery conditional idle suspend
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Topic**: desktop
- **Dependencies**: Task 119, Task 77

**Description**: Give the niri session AC/battery-conditional idle suspend (12h on AC, 1h on battery) to match the GNOME session. niri currently has zero idle auto-suspend on any power state (removed in task 117), and swayidle has no native AC/battery-conditional timeout: the single "timeout N command" clause spawned at config/config.kdl:271 applies unconditionally regardless of power source. Two candidate designs from the task 119 research: (Option A) a power-state-aware supervisor that respawns swayidle -w timeout <43200|3600> on /sys/class/power_supply/ACAD/online transitions, structurally mirroring the udev idiom already in modules/system/power.nix; (Option B) two mutually-exclusive systemd user units (swayidle-ac / swayidle-battery) gated on AC power. Known hazards either way: respawn races, two idle timers armed simultaneously, and a supervisor dying silently and leaving no idle policy at all. Must reuse the existing session-scoped systemd-inhibit mechanism from tasks 117/118 for Claude-activity awareness rather than building new detection. DO NOT resurrect the commented-out services.swayidle block in modules/home/desktop/swaylock.nix verbatim: its unconditional "timeout 600 -> systemctl suspend" example predates the AC/battery split requirement. Verification must read LIVE state after activation, not just the committed source, per the activation-lag bug class documented in task 119. Related: task 117 (partial) still owns lid-close and multi-monitor behavior; coordinate on docs/no-sleep-agents.md.

---

### 119. Fix ac vs battery idle sleep timeouts
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: None
- **Research**: [119_fix_ac_vs_battery_idle_sleep_timeouts/reports/01_ac-battery-idle-sleep.md]
- **Plan**: [119_fix_ac_vs_battery_idle_sleep_timeouts/plans/01_ac-battery-idle-sleep.md]
- **Summary**: [119_fix_ac_vs_battery_idle_sleep_timeouts/summaries/01_ac-battery-idle-sleep-summary.md]

**Description**: Fix AC-vs-battery idle sleep so the machine stays available 12 hours on AC and 1 hour on battery with no Claude activity. Currently the computer sleeps after roughly an hour of Claude quiet even when plugged in, instead of only on battery. Revise and improve the existing power management configuration.

---

### 118. Document no sleep functionality
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: None
- **Research**: [118_document_no_sleep_functionality/reports/01_no-sleep-functionality.md]
- **Plan**: [118_document_no_sleep_functionality/plans/01_no-sleep-documentation.md]
- **Summary**: [118_document_no_sleep_functionality/summaries/01_no-sleep-documentation-summary.md]

**Description**: Research and create documentation in docs/ for the no-sleep functionality set up so AI agents can run without interruption

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

### 116. Mail specs stray tree cleanup
- **Status**: [COMPLETED]
- **Task Type**: general
- **Dependencies**: None
- **Research**: [116_mail_specs_stray_tree_cleanup/reports/01_stray-tree-investigation.md]
- **Plan**: [116_mail_specs_stray_tree_cleanup/plans/01_stray-tree-remediation.md]
- **Summary**: [116_mail_specs_stray_tree_cleanup/summaries/01_stray-tree-remediation-summary.md]

**Description**: Investigate and safely remediate a misplaced non-mail filesystem tree at ~/Mail/specs/ (8.4MB, ~219 files) discovered during task 114. It is a stray copy of task-management/email-cleanup artifacts (TODO.md, state.json, ROADMAP.md, .meta-return.json, a full archive/ of dozens of email-cleanup task dirs, task dirs 027/029/072, and email-manifests/logos/ *.jsonl manifest+state data), created ~2026-07-13/14 by email-cleanup tooling running with cwd=~/Mail and writing RELATIVE specs/... paths there instead of into the repo. Impact: because modules/home/email/notmuch.nix sets the notmuch database path to ~/Mail, every 'notmuch new' walks all ~219 files and logs 'Ignoring non-mail file' for each (minor perf/noise cost). It is NOT inside a maildir folder, so mbsync never scans it and it is NOT a sync blocker (distinct from the task-114 in-maildir 'specs,U=67297' dir, which was already removed). SCOPE: (1) Determine provenance precisely -- which tool/run wrote it (candidates: /email cleanup for logos, tasks 027/029/072 tooling); confirm whether ANY file here is the ONLY copy of real data (esp. email-manifests/logos/*.jsonl and their .state.jsonl) vs. a stale duplicate of the repo's own specs/ tree -- diff against ~/.dotfiles/specs/ before removing anything. (2) Safely relocate any unique/valuable artifacts into the repo (or an appropriate location) and remove the rest; do NOT blindly rm 8.4MB that may contain unique manifests. (3) Add a durable guard so this cannot recur: e.g. a notmuch new.ignore / exclude entry for non-mail paths under ~/Mail, and/or fix the email-cleanup tooling that writes relative specs/ paths so it always writes absolute repo paths (root-cause). SAFETY: nothing here is a maildir message and mbsync does not touch it, so there is NO Expunge-Both server-deletion risk; but treat email-manifests/ data as potentially unique until proven duplicate. NON-GOALS: re-doing task 114; any live-mail mutation; touching actual maildir folders. Task type intentionally set to 'general' (filesystem cleanup + optional notmuch.nix guard), NOT the wrapper-only 'email' type, despite mail-related keywords.

---

### 115. Aerc config consolidation refactor
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Dependencies**: None
- **Research**:
  - [115_aerc_config_consolidation_refactor/reports/01_aerc-config-consolidation-research.md]
  - [115_aerc_config_consolidation_refactor/reports/00_session-context-and-handoff.md]
- **Plan**: [115_aerc_config_consolidation_refactor/plans/01_aerc-config-consolidation.md]
- **Summary**: [115_aerc_config_consolidation_refactor/summaries/01_aerc-config-consolidation-summary.md]

**Description**: Consolidate and refactor the aerc email configuration (modules/home/email/aerc.nix, 384 lines) for maintainability and coherence, WITHOUT changing behavior unless the plan makes an explicit justified decision. A complete self-contained session hand-off brief ALREADY EXISTS at specs/115_aerc_config_consolidation_refactor/reports/00_session-context-and-handoff.md and MUST be read first by the research phase and built forward from -- do not re-derive the history. That brief documents: (1) the full 2026-07-13/14 changelog (tasks 110-113 batch + follow-up fixes: INBOX querymap real-folder, compose format-flowed, enable :archive via maildir-store+act-dir, native :send -a flat archive-on-reply + systemd mail-sync timer, folders-exclude sidebar fix, :reply -c return-to-list, <Enter> part-cycle); (2) current architecture across aerc.nix/mbsync.nix/mail-sync.nix/notmuch.nix/mail-sync-timer.nix; (3) outstanding/deferred items (task 114 Gmail/.All_Mail duplicate-UID HIGH-RISK Expunge-Both remediation; 112/113 live-mail verification still user-pending; how check-mail should treat known-vs-real failures; the -a -c parser caveat; 17 accreted Task-NN comment markers to consolidate); (4) refactor goals (consolidate task-number comment archaeology into forward-looking docs; holistically reconsider folders-exclude-vs-folders-whitelist, text/plain-vs-text/html default, Enter-binding trade-off, logos check-mail, querymap de-duplication); (5) INVARIANTS to preserve (no agent live-mail mutation, Expunge-Both deletion danger, wrapper-only /email mutation, folder: token scoping, keep home-manager build green, no double-archive/tag:inbox regressions); (6) verification (build green + rendered-config semantic-equivalence diff + manual user checklist for TUI/live-mail). NON-GOALS: task 114 maildir remediation (separate task), redesigning behavior, home-manager switch or any live-mail action. This task is safe to orchestrate: it is config-refactor + build-verify only.

---

### 114. Gmail allmail duplicate uid remediation
- **Status**: [COMPLETED]
- **Task Type**: general
- **Dependencies**: None
- **Research**: [114_gmail_allmail_duplicate_uid_remediation/reports/01_duplicate-uid-diagnosis.md]
- **Plan**: [114_gmail_allmail_duplicate_uid_remediation/plans/01_duplicate-uid-remediation.md]
- **Summary**: [114_gmail_allmail_duplicate_uid_remediation/summaries/01_duplicate-uid-remediation-summary.md]

**Description**: Safely remediate the pre-existing duplicate-UID collision in ~/Mail/Gmail/.All_Mail that makes `mbsync gmail` (and thus `mail-sync gmail`) exit non-zero, which task 113 surfaced as a recurring aerc check-mail error banner and a failing mail-sync-timer unit. Root cause (live-verified 2026-07-14): two DIFFERENT messages both carry maildir UID tag ,U=15 in Gmail/.All_Mail/cur (subjects: "eNTERTAINMENT cENTER" and "A message from our CEO Nick Slape"); .mbsyncstate has a single legit mapping `34 15 S` (far UID 34 <-> near UID 15), so one file is a stray that erroneously got ,U=15 (likely from historical email dedup/migration tooling). HIGH RISK: gmail-all channel is `Expunge Both`, so removing/moving a synced local file can permanently delete a real message from Gmail All Mail. SAFE approach (validate first): identify the stray, then RENAME (never delete) it to strip its ,U=15 suffix -- collision clears, `Create Near` means the de-UID`d local-only file is never uploaded (no server duplicate), no file removed means no Expunge propagation (no server deletion), fully reversible. See reports/01_duplicate-uid-diagnosis.md for the full grounded analysis, open questions (confirm which file is the stray via read-only IMAP FETCH 34 or notmuch corroboration; notmuch re-index after rename; optional mail-sync.nix benign-duplicate guard; sweep for OTHER duplicate UIDs), and verification steps (mbsync exits 0, both messages still present in Gmail web UI, aerc banner clears). Do NOT rm or move any maildir file out of the folder. NON-GOAL: re-doing tasks 110-113.

---

### 113. Aerc archive on reply and periodic sync
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: services
- **Dependencies**: Task 112
- **Research**: [113_aerc_archive_on_reply_and_periodic_sync/reports/01_archive-on-reply-and-periodic-sync.md]
- **Plan**: [113_aerc_archive_on_reply_and_periodic_sync/plans/01_archive-on-reply-periodic-sync.md]
- **Summary**: [113_aerc_archive_on_reply_and_periodic_sync/summaries/01_archive-on-reply-periodic-sync-summary.md]

**Description**: Deliver the end-user goal: replying to a message in aerc archives it, aerc updates immediately, and Gmail-in-the-browser stays in sync occasionally (non-immediate sync is acceptable per the user). TWO PARTS in modules/home/email/aerc.nix. (A) Archive-on-reply: a `[hooks]` `mail-sent` entry gated on the outgoing `Re:` subject prefix that runs `aerc :archive flat` on the selected (replied-to) message. This is ALREADY DRAFTED in the working tree (uncommitted) but only becomes functional once task 112 enables `:archive`. Verify it archives exactly the replied message and does nothing on a fresh `:compose` (whose subject is not `Re:`). Re-evaluate the known caveat that it archives the list-SELECTED message (correct in the normal select->r->reply->send flow) and decide whether to keep as-is or harden. (B) Periodic sync: nothing currently runs mbsync on a schedule — sync only fires via aerc's `$`/`u` keys or the notmuch preNew hook. Add occasional automatic sync through the existing serialized, flock-guarded `mail-sync` wrapper (from task 109, modules/home/email/mail-sync.nix): either aerc `[account]` `check-mail = 10m` + `check-mail-cmd = mail-sync gmail` (syncs while aerc is open) and/or a systemd user timer running `mail-sync both` (syncs even when aerc is closed). Prefer the least surprising option; document the choice. DEPENDS ON task 112 (archive must actually work for archive-on-reply to be meaningful, and for the sync to have an archive to propagate). VERIFY end-to-end: reply to a test message, confirm it leaves the aerc INBOX immediately, then let the periodic sync run (or trigger `mail-sync gmail`) and confirm in the Gmail browser that the message is archived (out of inbox, still in All Mail).

---

### 112. Aerc enable folder move archive
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: services
- **Dependencies**: Task 110
- **Research**: [112_aerc_enable_folder_move_archive/reports/01_enable-archive-action.md]
- **Plan**: [112_aerc_enable_folder_move_archive/plans/01_enable-archive-action.md]
- **Summary**: [112_aerc_enable_folder_move_archive/summaries/01_enable-archive-action-summary.md]

**Description**: Enable a real, server-propagating archive action in aerc (the `a`/`A` keys and, later, the reply hook). Currently aerc's notmuch-backend `:archive`/`:delete` are DISABLED because they require `maildir-store` to be set in accounts.conf and it is unset (modules/home/email/aerc.nix, home.file accounts.conf). So `a = :archive flat` is a silent no-op — verified: replied messages remain in Gmail/cur with tag:inbox, unmoved. FIX in accounts.conf for BOTH [gmail] and [logos]: add `maildir-store = ~/Mail`, and add `multi-file-strategy = act-dir`. The multi-file-strategy is REQUIRED, not optional: a live probe shows 35 of the 85 inbox messages ALSO have a copy in All_Mail (Gmail's label model), and aerc's default `refuse` strategy will refuse to archive multi-file messages; `act-dir` scopes the operation to the file in the current (inbox) folder. Archive semantics with this in place: `:archive flat` moves the inbox-folder file to the account's `archive=` folder (All_Mail for gmail, Archive for logos), and mbsync's `gmail-inbox` channel — which is `Expunge Both` (mbsync.nix) — propagates that as an INBOX-label removal on Gmail at the next sync. This matches the repo's already-proven mutation in email-archive-confirmed.nix (`himalaya message move All_Mail <id> -f INBOX`). DEPENDS ON task 110 so that an archived (moved-out-of-inbox) message actually disappears from the now-folder-based INBOX view. VERIFY CAREFULLY ON LIVE MAIL before trusting broadly (85 real messages, 35 multi-file): archive ONE ordinary message and ONE known multi-file message, run `mail-sync gmail`, and confirm in the Gmail browser that each left the inbox and remains in All Mail (i.e. archived, not trashed). Also review whether the existing `a`/`A` :prompt confirmations and the Proposed-* wrapper-routed gestures need any adjustment given archive is now live. Do NOT wire archive-on-reply or periodic sync here (task 113).

---

### 111. Aerc compose line wrapping
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: services
- **Dependencies**: None
- **Research**: [111_aerc_compose_line_wrapping/reports/01_aerc-compose-flowed-verification.md]
- **Summary**:
  - [111_aerc_compose_line_wrapping/plans/01_verify-compose-flowed.md]
  - [111_aerc_compose_line_wrapping/summaries/01_verify-compose-flowed-summary.md]

**Description**: Stop aerc-composed/replied email from hard-wrapping at ~72-80 columns; lines should stay soft-wrappable so recipients' clients reflow to their own width. Root cause (live-verified): the compose editor is nvim, and nvim's built-in `mail` ftplugin sets textwidth=72 and formatoptions=jtcql (the `t` flag auto-hard-wraps as you type). FIX in modules/home/email/aerc.nix `[compose]` (extraConfig.compose): (1) `editor = "nvim -c 'setlocal textwidth=0 formatoptions-=t'"` so the compose buffer never inserts hard breaks regardless of the (unmanaged) nvim config; (2) `format-flowed = true` so aerc emits RFC3676 `text/plain; format=flowed`, letting long unwrapped lines reflow on the receiving side instead of appearing broken at a fixed column. Both are complementary and both are needed. NOTE: these two edits are ALREADY DRAFTED in the working tree (uncommitted) as of this task's creation — this task is to verify and commit them, not author from scratch. Independent of the inbox/archive/sync tasks (110/112/113). VERIFY: `home-manager build --flake .#benjamin`; send a test message to yourself with a long paragraph and confirm (a) no hard line breaks were inserted and (b) the sent message carries a `Content-Type: text/plain; format=flowed` header. Then commit the aerc.nix compose changes.

---

### 110. Aerc inbox querymap real folder
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: services
- **Dependencies**: None
- **Research**: [110_aerc_inbox_querymap_real_folder/reports/01_inbox-querymap-real-folder.md]
- **Plan**: [110_aerc_inbox_querymap_real_folder/plans/01_inbox-querymap-real-folder.md]
- **Summary**:
  - [110_aerc_inbox_querymap_real_folder/plans/01_inbox-querymap-real-folder.md]
  - [110_aerc_inbox_querymap_real_folder/summaries/01_inbox-querymap-real-folder-summary.md]

**Description**: Fix the aerc INBOX virtual folder so it reflects the real inbox. In modules/home/email/aerc.nix the querymaps define `INBOX=tag:inbox AND folder:/Gmail/` (querymap-gmail) and `INBOX=tag:inbox AND folder:/Logos/` (querymap-logos). This is wrong on two counts: (1) `tag:inbox` is applied ONCE at delivery by notmuch.nix postNew (`notmuch tag +inbox`) and is never removed on archive, and (2) `folder:/Gmail/` is a notmuch regex that also matches Gmail/.All_Mail. So the INBOX tab returns everything ever tagged inbox, including the ~64k-message archive. Live-verified on 2026-07-13: `notmuch count folder:Gmail` = 85 (the true inbox) vs `notmuch count 'tag:inbox AND folder:/Gmail/'` = 12,580. This is the root cause of the user's report that replied/handled mail never leaves the aerc inbox. FIX: change the INBOX querymap entries to the exact inbox maildir folder — `INBOX=folder:Gmail` and `INBOX=folder:Logos` (bare exact-match form = INBOX-only, per CLAUDE.md's verified folder-token table and the email-census wrapper which already treats INBOX as `folder:$ACCOUNT_FOLDER`). This makes the tab show the true inbox AND makes any message moved out of the inbox folder (i.e. archived) disappear from the view. Also decide and document whether the Unread/Flagged/Proposed-* querymap entries (which also use `folder:/Gmail/` = whole-account) should remain account-wide or be scoped to the inbox — they are a separate concern from INBOX and account-wide is likely correct for search/triage. NON-GOAL: enabling archive itself (task 112) and periodic sync (task 113). VERIFY: `home-manager build --flake .#benjamin`; open aerc and confirm the INBOX tab shows ~85 messages, not ~12k. Low-risk: this is a read-only view definition change with no mail mutation.

---

### 109. Serialized group scoped mail sync wrapper
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: services
- **Dependencies**: None
- **Research**: [109_serialized_group_scoped_mail_sync_wrapper/reports/01_serialized-mail-sync-wrapper.md]
- **Plan**: [109_serialized_group_scoped_mail_sync_wrapper/plans/01_serialized-mail-sync-wrapper.md]
- **Summary**: [109_serialized_group_scoped_mail_sync_wrapper/summaries/01_serialized-mail-sync-wrapper-summary.md]

**Description**: Provide a single canonical, serialized, group-scoped, hook-safe mail-sync command in the email module (modules/home/email/) that every sync trigger invokes, eliminating the concurrent/overlapping mbsync invocations that cause `duplicate UID` Maildir corruption and abort server sync (exit 1). Root cause: multiple independent triggers run mbsync with no mutual exclusion, and some use the forbidden `mbsync -a` (all-channels) form plus hook-ful `notmuch new` — whose pre-new hook itself runs `mbsync gmail logos` — so a single action can launch two overlapping mbsync runs writing the same maildir (e.g. Gmail/.All_Mail), producing duplicate-UID errors. The dotfiles email module already codifies the correct doctrine (notmuch.nix: never `mbsync -a`, group-scoped only; aerc.nix: `$` rebound to a group-scoped + hook-bypassing form; wrappers use `notmuch new --no-hooks`), but the invariant is enforced per-caller and can still be bypassed. Current trigger inventory: the notmuch pre-new hook (`mbsync gmail logos`), aerc's `$` keybind, the Neovim `<leader>me`/`<leader>mN` mappings (which still call `mbsync -a` + hook-ful `notmuch new`), and manual invocation. Deliverable: a nix-built wrapper (e.g. `mail-sync`) that (1) takes an flock on one lockfile so no two mbsync runs can overlap regardless of trigger; (2) is group-scoped only (`mbsync gmail`/`mbsync logos`) and structurally incapable of `mbsync -a`; (3) reindexes with `notmuch new --no-hooks` to avoid re-triggering the pre-new mbsync loop; (4) on the known `duplicate UID` failure prints actionable remediation (or invokes a detector/repair helper alongside census.nix). Then repoint every trigger — the notmuch pre-new hook and aerc's `$`, plus (via a companion Neovim-repo task) `<leader>me`/`<leader>mN` — at this one wrapper, so the never-`mbsync -a`, never-concurrent, `--no-hooks` invariants cannot be bypassed from any editor, keybind, or hook. Non-goals: the one-time maildir data repair of an existing duplicate-UID collision, and the Neovim-side change to call the wrapper (separate nvim-repo task). Verify with `nix flake check` and a concurrency test: two near-simultaneous invocations must serialize rather than corrupt.

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

### 71. Design ai email management workflow
- **Status**: [EXPANDED]
- **Task Type**: general
- **Topic**: services
- **Dependencies**: Task 46
- **Research**:
  - [071_design_ai_email_management_workflow/reports/01_ai-email-workflow.md]
  - [071_design_ai_email_management_workflow/reports/02_team-research.md]
  - [071_design_ai_email_management_workflow/reports/03_team-research.md]
  - [071_design_ai_email_management_workflow/reports/02_teammate-a-findings.md]
  - [071_design_ai_email_management_workflow/reports/02_teammate-b-findings.md]
  - [071_design_ai_email_management_workflow/reports/02_teammate-c-findings.md]
  - [071_design_ai_email_management_workflow/reports/02_teammate-d-findings.md]
  - [071_design_ai_email_management_workflow/reports/03_teammate-a-findings.md]
  - [071_design_ai_email_management_workflow/reports/03_teammate-b-findings.md]
  - [071_design_ai_email_management_workflow/reports/03_teammate-c-findings.md]
  - [071_design_ai_email_management_workflow/reports/03_teammate-d-findings.md]
- **Plan**:
  - [071_design_ai_email_management_workflow/plans/04_email-workflow-implementation.md]
  - [071_design_ai_email_management_workflow/plans/02_email-workflow-implementation.md]

**Description**: Design a streamlined AI-assisted email management workflow across the existing dual-account stack (Gmail via OAuth2 + Protonmail via Bridge; Himalaya CLI, aerc TUI, notmuch, mbsync) and the connected Anthropic Gmail connector (gmail.mcp.claude.com). Goal: agents that clean up the inbox (remove junk, unsubscribe noise) and draft responses for review, with the largest task being a safe one-time purge of backlogged mail - delete junk, archive what is worth keeping, delete all else. Key finding from the seed report: the Anthropic Gmail connector is read-only + draft-creation (cannot send/archive/delete), so backlog cleanup must be driven through the local stack (notmuch/Himalaya/mbsync) under a drafts-first, human-approved, guardrailed agent harness with Gmail trash-then-expunge semantics. Follow-up /research 71 should resolve the seven open questions (harness form-factor, approval UX, account scope, backlog scale census, guardrail enforcement, classifier quality, injection hardening) before planning.

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

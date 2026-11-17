---
next_project_number: 144
---

# TODO

## Task Order

*Updated 2026-11-17. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 15,19,23,41,42,43,46,67,68,77,124,125,126,131,133,136,141,143 | -- | nixos-config, nix-infrastructure, services, ... |
| 2 | 117,120,139,142 | 77,124,136 | nixos-config, desktop, sapience |
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
143 [RESEARCHED] — Stop the oliver-ben guard's 2s/1s network defaults stalling...

### Services

19 [RESEARCHED] — install\_setup\_mcp\_servers\_web\_development
23 [PLANNED] — install\_simple\_webcam\_recording\_software
43 [RESEARCHED] — install\_forgejo\_self\_hosted\_git
46 [RESEARCHED] — Investigate and fix Gmail OAuth2 token expiry - tokens keep...
131 [NOT STARTED] — Install claude-refresh timer via home-manager and make mako...
136 [IMPLEMENTING] — Measure Sapience capture coverage under manual extraction and...

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

141 [NOT STARTED] — GOAL. Close the recurrence gap left by task 138. That task...
139 [NOT STARTED] — Reduce or accept the Sapience extraction classifier cost now...
142 [PLANNED] — Default the Sapience config hooks opt-out to false so the...

## Tasks

### 143. Stop the oliver-ben guard's 2s/1s network defaults stalling long agent runs, and report the no-retry suspend upstream
- **Status**: [RESEARCHED]
- **Task Type**: nix
- **Topic**: nix-infrastructure
- **Dependencies**: None
- **Research**: [143_guard_fail_closed_stall_config_and_upstream_retry/reports/01_guard-fail-closed-config-and-retry.md]

**Description**: The oliver-ben binding guard (packages/sf1-hub-ben/vendor/guard/guard.py, deployed via modules/home/services/sf1-hub-ben.nix) consults a hosted rules route on nearly every controlled action with a 2-second timeout, and suspends fail-closed on the first network error with no retry. Decide where its network knobs are declared durably on this machine, pick defensible values, and write up the upstream defect.

MEASURED EVIDENCE (2026-11-17, from .git/oliver-ben-guard/log.jsonl in the sapience-app checkout). Admission outcomes over the log's 3675 records: 1715 '304' (successful conditional GET), 105 'coalesced' (served from the local cache window), and 35 failures -- 24 'rules route unreachable (TimeoutError)' and 11 '(URLError)'. That is a ~2% per-call failure rate with only 5.8% of calls avoiding the network at all. Because suspension is sticky and never retried, expected survival is ~50 controlled actions; a single agent implementation dispatch performs several hundred. Two consecutive /orchestrate implement dispatches in sapience-app died mid-flight on 2026-11-17 (one after ~140 tool calls, one after ~337), each requiring a hand-run `guard.py unstop`.

The failures are transient, not an outage: hubcache.json's successful checked_at (epoch 1794944955) precedes stopped.json's write (1794944966) by 11 seconds, with the route reachable before and after.

CONFIG SURFACE. <git-dir>/oliver-ben-guard/config.json carries mode=attached, coalesce_s=1.0, net_timeout_s=2.0, deadline_s=8.0. guard.py's own module docstring states 'Network pulls are at least 10 s apart' and the source carries MIN_PULL_GAP_S=10, but attached mode's config sets coalesce_s=1.0 -- ten times tighter than the author's documented floor, which reads as an installer oversight rather than a considered choice. The same 1.0/2.0 pair is hardcoded in at least three places: the vendored install.sh (near line 27), guard.py's missing-config fallback (near line 1249), and whatever `sf1-hub-ben attach` writes. Nothing in this repository declares these values, so they are not under declarative control.

CONSTRAINT: DO NOT EDIT THE VENDORED GUARD. vendor.lock.json pins guard/guard.py by sha256 and names its upstream source as Oliver's own checkout (/Users/oz/data/oliver-ben-guard, git c813151); sf1-hub-ben.nix deliberately does not use install.sh and checks that sha256 manifest at build time, so an edited vendor file fails the build. A local behavioural fix is a deliberate fork plus a lock update, not a patch.

GOAL. (1) Decide and implement where coalesce_s/net_timeout_s are declared durably for an attached repository, given that the module does not run install.sh and that `attach` is a manual TTY-only step. Evaluate: an activation step that patches an existing config.json in place (preserving me/source/sink/since_ts), a documented post-attach manual step, or a thin wrapper around `sf1-hub-ben attach`. Whatever is chosen must write no consent marker and hold no credential -- see the module's 'What stays manual' section. (2) Choose values with stated rationale. Starting proposal: net_timeout_s=15 (the 24 TimeoutErrors are a 2s timeout against a hosted TLS endpoint), and coalesce_s=300 while the rule set is empty, dropping to ~60 once rules exist; justify against MIN_PULL_GAP_S=10 and the docstring's own claim, and state the freshness cost explicitly (a rule Oliver adds does not bind until the window expires). (3) Write up the upstream defect for Oliver rather than patching it here: hub_fetch/admit (guard.py near lines 553-607) suspend on the first network error and discard a cache validated seconds earlier, with no retry; propose one bounded retry, or a grace window that keeps enforcing from the last good cache for N seconds before suspending. Either would have prevented both of 2026-11-17's stalls. (4) Resolve the prior question, which is a conversation with Oliver and not a config change: the cached rules doc for project oliver-ben is revision 1, schema sf1-hub-rules/1, members [oliver, benjamin], n_kos=0 -- the guard has been enforcing an empty rule set, so whether attached mode should remain on in such a repository is open. Record the outcome. Note that detaching also stops the commit-event reporting consented to in CONSENT-benjamin.json (hub_commit_events, share_unpushed_branches), which Oliver may rely on. (5) Make a suspension diagnosable without reading log.jsonl -- a status-line or notification surface, consistent with the prompt-rule work in install_claude_refresh_timer_and_mako_prompt_rule. (6) Update docs/sf1-hub.md with the measured failure rate, the config surface, and the unstop procedure.

---

### 142. Default the Sapience config hooks opt-out to false so the vendor updater stops wiring machine-wide hooks
- **Status**: [PLANNED]
- **Task Type**: nix
- **Topic**: sapience
- **Dependencies**: Task 136
- **Research**:
  - [142_sapience_hooks_opt_out_default/reports/01_sapience_hooks_opt_out.md]
  - [142_sapience_hooks_opt_out_default/reports/01_sapience_hooks_opt_out.md]
- **Plan**: [142_sapience_hooks_opt_out_default/plans/01_sapience-hooks-opt-out.md]

**Description**: Stop the Sapience vendor updater from wiring machine-wide Claude Code hooks: default ~/.sapience/config.json "hooks" to false in modules/home/services/sapience.nix and preserve an explicit false across activation.

MEASURED EVIDENCE (2026-11-14). ~/.claude/settings.json carried three vendor-written user-level hooks -- SessionStart `python3 ~/.sapience/mcp.py --briefing-text`, SessionEnd `--receipt`, Stop `--effect-line` -- which are absent from config/claude/settings.json. They are written by ~/.sapience/sapience_upkeep.py's wire_hooks() on its daily auto-update whenever config.json's "hooks" is not false (hooks_opted_out()). `hooks` being a home-manager enforced key only strips them at the next switch; the updater re-adds them within a day. Effect: every repository on the machine, whether or not it loads the sapience extension, received the unfiltered cross-project SessionStart briefing, and extension repositories received it twice (once from their own merged settings.local.json). The per-repository design stated in config/claude/settings.json's _SAPIENCE_NOTE and sapience.nix's own header comments is therefore not what the machine does. The three entries were removed by hand and config.json set to "hooks": false on 2026-11-14 (backups: ~/.claude/settings.json.bak-*, ~/.sapience/config.json.bak-*), but sapience.nix's activation merge uses `.hooks = (.hooks // true)` (near line 324) -- jq's `//` treats false as absent, so the next activation resets the opt-out to true -- and the first-run mint (near line 331) writes `hooks: true`.

GOAL. (1) Both sites write/keep "hooks": false (use an explicit null test, not `//`, so an existing value is preserved; decide whether false is forced or only defaulted, and say why). (2) Confirm against the vendor client that "hooks": false does not disable the per-repository hooks the sapience extension merges (sapience_cli.py `hook prompt` / `hook tool`, mcp.py --briefing-text/--receipt/--effect-line invoked from a repository's own settings.local.json) -- it should only stop the updater touching ~/.claude/settings.json and the CLI auto-on probe. (3) Add an activation-time or verification check that fails loudly if ~/.claude/settings.json carries any ~/.sapience injection hook. (4) Rebuild, then verify after a forced `sapience_upkeep.py --update` that no user-level hook reappears. (5) Update docs/sapience.md and the sapience.nix comments to state the resulting design. Companion: the nvim agent-system repository carries the extension-side verifier/doc task (sapience_activation_surface_scoping_gaps).

---

### 141. Prevent sapience hook reinjection
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Topic**: sapience
- **Dependencies**: None

**Description**: GOAL. Close the recurrence gap left by task 138. That task removed the five machine-wide Sapience hook entries from config/claude/settings.json and verified the live file post-switch; nothing it built prevents or detects the vendor client putting them back, and the vendor client has now put three of them back. DO NOT redo 138's removal -- the source file is still correct. The work here is convergence-on-activation plus detection-between-activations.

MEASURED EVIDENCE (2026-11-14). The live ~/.claude/settings.json carries three Sapience hooks that config/claude/settings.json does not declare:
  SessionStart: python3 /home/benjamin/.sapience/mcp.py --briefing-text
  SessionEnd:   python3 /home/benjamin/.sapience/mcp.py --receipt
  Stop:         python3 /home/benjamin/.sapience/mcp.py --effect-line
The source file still contains exactly one Sapience hook entry -- the SessionStart entry invoking $HOME/.claude/hooks/sapience-mcp-register-project.sh that 138 deliberately added -- so this is live-file drift, not a source regression. Live mtime (2026-11-14 00:49) postdates source mtime (2026-11-13 01:04) and postdates 138's completion (2026-11-13 09:19), so ~/.sapience/*.py re-injected them after the last home-manager switch. Three of the original five returned; UserPromptSubmit and PreToolUse did not.

THREE CONSEQUENCES. (1) They fire in every repository, whether or not the sapience extension is loaded there -- defeating the per-repo activation design 138 and its nvim-sited companion exist to provide. (2) In a repository that HAS loaded the extension they duplicate the extension-merged copies from settings-fragment.json: a session in /home/benjamin/.config/nvim on 2026-11-14 printed the identical SessionStart briefing block twice. (3) They are unguarded, unlike the fragment's versions, each of which wraps its call in [ -f "$HOME/.sapience/mcp.py" ] && ... || true.

FOURTH, SEPARATE DEFECT. _SAPIENCE_NOTE is not in home.activation.claudeSettings' enforced-key list ["_NOTE","env","hooks","model","permissions","statusLine"], so the live file's copy is preserved across switches rather than reset from source. The live copy predates 138's rewrite and is now wrong on two counts: it claims the mcp.py hook entries are owned by modules/home/services/sapience.nix (that module defines none of them -- grep finds no --briefing-text, --receipt or --effect-line in it), and it claims they are guarded with [ -f ~/.sapience/mcp.py ] (they are not). A reader inspecting the live file is told the drifted entries are legitimate and nix-owned.

SCOPE. (a) Make home.activation.claudeSettings actively strip Sapience mcp.py hook entries the source does not declare, instead of relying only on the enforced-key reset -- which does converge the file at switch time but is undone by the next vendor run. (b) Add _SAPIENCE_NOTE to the enforced-key list in modules/home/core/dotfiles.nix so its text cannot drift from source. (c) Decide where the between-activations detector belongs -- here, or in the nvim repository's scripts/verify-sapience-mcp.sh, whose check (d) today asserts only that the registration hook is PRESENT in the live file, never that it is the ONLY Sapience hook there. Record the siting decision either way, since the nvim repository owns the companion verifier.

VENDOR CEILING. ~/.sapience/mcp.py is vendor-owned and self-updating (modules/home/services/sapience.nix seeds it only when absent, deliberately), so re-injection will recur. The target is convergence on every activation plus detection between them, not another one-time cleanup.

ACCEPTANCE. After a home-manager switch, ~/.claude/settings.json carries exactly one Sapience hook entry (the registration hook); re-running the vendor client and switching again restores that state; _SAPIENCE_NOTE in the live file matches the source verbatim; a Claude Code session in a repository with no sapience extension loaded produces no Sapience briefing, receipt, or effect line; the drift is reported rather than silent when it occurs between switches.

---

### 140. Diagnose slow local ollama inference
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: sapience
- **Dependencies**: None
- **Research**: [140_diagnose_slow_local_ollama_inference/reports/01_ollama-cpu-inference-slowdown.md]
- **Plan**: [140_diagnose_slow_local_ollama_inference/plans/01_ollama-cpu-baseline-verdict.md]
- **Summary**: [140_diagnose_slow_local_ollama_inference/records/01_controlled-benchmark.md]

**Description**: Diagnose why local llama3.1 inference runs at 0.66 tokens per second on this hardware, and decide whether local Sapience extraction can be made viable. Measured on this machine (24-core AMD Ryzen AI 9 HX 370, Radeon 890M integrated GPU, no discrete GPU, 30 GB RAM): llama3.1 emitted 58 tokens in 88 seconds with llama-server showing roughly 1830 percent CPU across 27 threads, so it is genuinely multi-threaded and still roughly 20x slower than an 8B Q4_K_M model should run on this core count. Candidate causes not yet ruled out: memory pressure (19 of 30 GB in use at measurement time, 4.9 GB model), a CPU-feature-poor or generically-built llama.cpp in the packaged ollama derivation, thermal or power limits, or a context-size default inflating per-token work. This matters beyond curiosity: extraction currently runs at a third-party provider on a metered key precisely because local inference is impractical at this rate, so a fix removes both the per-call cost and the privacy trade of sending raw transcript chunks off this machine. Note that the ROCm acceleration route for the Radeon 890M was separately considered and set aside; this task is about the CPU path. Reclaiming the 4.9 GB llama3.1 model with ollama rm would require re-pulling it before this work can proceed.

---

### 139. Reduce sapience classifier cost
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Topic**: sapience
- **Dependencies**: Task 136, Task 140

**Description**: Reduce or accept the Sapience extraction classifier cost now that extraction is metered. The classifier re-runs across the entire not-yet-extracted backlog on every run, which was free on the Ollama backend but is now the dominant per-run cost on the anthropic backend. A measured run took 29 minutes wall clock against only 3.5s CPU (entirely network-bound) to extract 71 sources and stage 1208 knowledge objects, with the classifier phase accounting for roughly the first 20 minutes before chunk extraction began. The Known gaps section of docs/sapience.md already records that the classifier classifies every not-yet-extracted session on every run while a backlog exists. Weigh the available levers: setting NO_CLASSIFY=1 (the vendor client comment is that redaction is the privacy guarantee, not this filter, at the cost of no longer filtering personal conversations out), caching classifier verdicts across runs the way source_skip verdicts are already cached in the source_rules.json state file, or accepting the cost and documenting it. Implement whichever is right and record the per-pass cost measurement in the Cost shape section of docs/sapience.md.

---

### 138. Retire the machine-wide Sapience surface so the extension's per-repo gating is the only activation path
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: sapience
- **Dependencies**: None
- **Research**: [138_retire_machine_wide_sapience_surface/reports/01_retire-machine-wide-sapience.md]
- **Plan**: [138_retire_machine_wide_sapience_surface/plans/01_retire-machine-wide-sapience.md]
- **Summary**: [modules/home/services/sapience.nix]

**Description**: GOAL. Retire every machine-wide Sapience ACTIVATION surface this repository owns, so that loading
the sapience extension into a repo is the ONLY thing that turns Sapience on there, and unloading
it is the only thing that turns it off. This is a removal task with exactly one addition: the
per-project MCP-registration SessionStart hook described below, which is the GATING mechanism
rather than an activation surface, must be ADDED here and must survive a switch.

SITING. This task belongs in /home/benjamin/.dotfiles because every one of its edit targets is
owned by this repository's own tree, not by the agent-system source store:
`modules/home/services/sapience.nix`, `config/claude/settings.json` and `docs/sapience.md`. Per
`.claude/rules/source-store-deploy-boundary.md`'s Task Siting subsection, a task is filed in the
repository whose local filesystem contains its edit target. The companion extension-side task is
sited in /home/benjamin/.config/nvim because its targets live under that repo's
`agent-system/extensions/sapience/` source store.

ORDERING CONSTRAINT, HARD. This is the second half of a two-part change. The first half, sited in
/home/benjamin/.config/nvim under the project name `gate_sapience_activation_behind_extension`,
builds the per-repo activation surface in the extension's source store. This task MUST NOT land
before that companion task has landed and been verified. Removing the machine-wide surface first
leaves Sapience off in EVERY repository, including those that should have it. The constraint
cannot be expressed as a state.json dependency edge, because the companion lives in a different
repository's numbering space -- so it is recorded here in prose and the companion is referred to
by its durable project name. Before starting implementation, confirm the companion has completed;
if it has not, the correct action is to stop and report, not to proceed.

COMPANION STATUS: LANDED. Confirmed on 2026-11-13 by reading the companion's own artifacts in
/home/benjamin/.config/nvim -- project 612, `gate_sapience_activation_behind_extension`, status
[COMPLETED], summary at
`specs/612_gate_sapience_activation_behind_extension/summaries/01_gate-sapience-activation-extension-summary.md`
-- and by inspecting the artifacts it installed on this machine (both files present under
`$HOME/.claude/`, mode 755; all eleven grants present in the extension's
`settings-fragment.json`). Acceptance criterion 6 below asks for exactly this record. Re-confirm
at implementation time rather than relying on this note alone.

=== THE ONE MACHINE-WIDE SURFACE THAT MUST STAY -- AND THIS TASK MUST ADD IT ===

READ THIS BEFORE TOUCHING THE `hooks` OBJECT. This task is NOT "delete five hooks and add none."
It does BOTH of the following to `config/claude/settings.json`'s `hooks` object:

  - REMOVES the five Sapience hooks enumerated at item 3 below (SessionStart briefing,
    UserPromptSubmit, PreToolUse, SessionEnd, Stop);
  - ADDS a durable user-level `SessionStart` entry invoking the companion's per-project
    MCP-registration hook.

The registration hook IS a machine-wide surface, and it is the one machine-wide surface that must
stay, because it is the mechanism that makes per-repo gating work at all. It must run in EVERY
session in EVERY directory -- including a directory with no repository `.claude/` deploy at all --
because it is bidirectional: it registers `.projects["<abs path>"].mcpServers.sapience` in
`~/.claude.json` when the current repo's sapience extension is active, and REMOVES that entry when
it is not. Nothing else can retract a per-project entry on unload, because the settings-merge
engine governs only in-tree merge targets, never `~/.claude.json`.

WHY THIS TASK OWNS IT. The companion's installer
(`agent-system/extensions/sapience/scripts/install-sapience-mcp-session-hook.sh`, in
/home/benjamin/.config/nvim) registers that `SessionStart` entry in `$HOME/.claude/settings.json`
ONLY. It deliberately omits the second `.dotfiles` write target that the lean extension's
equivalent installer has, because the companion's own acceptance criteria forbade it from touching
`.dotfiles`. The companion's Decisions section records the consequence verbatim: the registration
in `$HOME/.claude/settings.json` "is wiped by the next `home-manager switch` and must be re-run
until a separate task takes ownership of a durable user-level entry." Its Follow-ups section names
this task as that owner. The wiping mechanism is the SAME enforced-key mechanism this task already
documents at item 4 below: `hooks` and `permissions` are ENFORCED keys in
`home.activation.claudeSettings`, so home-manager reasserts `config/claude/settings.json`'s version
of those keys on every switch and discards anything else written into the live file.

HAZARD, STATED PLAINLY. Removing this entry along with the other five -- or simply never adding it
-- leaves per-project registration dying on the next `home-manager switch`: Sapience off in EVERY
repository, including all four that load the extension. That is precisely the failure mode the
ORDERING CONSTRAINT section above exists to prevent, arriving by a different route.

EXACT VALUES, VERIFIED ON DISK 2026-11-13 against the companion's installed artifacts. Use these
rather than re-deriving them:

  - Command string, byte-for-byte (the installer's idempotency check and its `--remove` both key
    off this exact string, so it must match character for character):

        bash $HOME/.claude/hooks/sapience-mcp-register-project.sh 2>/dev/null || echo '{}'

  - Entry shape the installer writes:
    `{"hooks": [{"type": "command", "command": "<the string above>"}]}` -- NO `matcher`, NO
    `timeout`, NO `async`. The adjacent lean `SessionStart` entry in this same file does carry
    `"matcher": "startup"`; the installer's idempotency check matches on the command string alone
    and ignores `matcher`, so adding one would not break recognition. Absent a reason, mirror the
    installer's shape exactly.

  - Installed files the command depends on -- both live outside every repository tree, and both
    are seeded by the companion's installer, NOT by home-manager (verified present, mode 755,
    dated 2026-11-12):

        $HOME/.claude/hooks/sapience-mcp-register-project.sh   (the hook)
        $HOME/.claude/scripts/setup-sapience-mcp.sh            (the writer the hook calls)

    The `2>/dev/null || echo '{}'` tail makes the entry inert if either file is absent. This is
    the same arrangement the lean `SessionStart` entry in this file already relies on -- that entry
    likewise names `$HOME/.claude/hooks/lean-lsp-register-project.sh`, a file this repository does
    not install -- so it is an established precedent here, not a new pattern.

After this task lands, re-running the companion's installer must report a no-op against the live
file rather than double-registering. Confirm that, since the durable entry now arrives from a
different writer than the one whose idempotency check it must satisfy.

=== THE EXTENSION-LOADED REPO SET (verified on disk 2026-11-13) ===

Every `.claude-extensions.json` under /home/benjamin (maxdepth 4) was read and filtered for an
`extensions.sapience.status == "active"` entry. FOUR repositories load the sapience extension:

  /home/benjamin/.config/nvim
  /home/benjamin/.dotfiles
  /home/benjamin/Projects/abood
  /home/benjamin/Projects/Sapience/sapience-app

This set is load-bearing in two places and must be propagated to both: the per-project
`.projects[<path>].mcpServers` registration list this task produces, and acceptance criterion 3
below.

Path note: the sapience-app checkout MOVED. It now lives at
`/home/benjamin/Projects/Sapience/sapience-app` (alongside a `sf1-engine` clone under the same
`Sapience/` parent); `/home/benjamin/Projects/sapience-app` no longer exists. Every absolute-path
keying -- the `.projects[...]` keys in ~/.claude.json and the transcript-directory keys discussed
below -- must use the new path.

`~/Projects/cslib` and `~/Projects/Logos/Theory` were re-checked and remain genuinely unloaded;
they are the negative-test candidates for the verification section.

=== WHAT IS BEING REMOVED, AND WHY EACH IS SAFE TO REMOVE ONLY AFTER THE COMPANION LANDS ===

1. TOP-LEVEL MCP REGISTRATION. `modules/home/services/sapience.nix`'s `claudeMcpServers`
   activation entry (around lines 787-1055) merges `mcpServers.sapience` into the TOP LEVEL of
   ~/.claude.json, so all nine `sapience_*` tools load in every session in every directory. The
   option that controls it is documented at that file's line ~787 ("Merge mcpServers.sapience
   into ~/.claude.json at user scope ... Set false to leave ~/.claude.json untouched"), and the
   activation entry is deliberately ordered against the token-shape repair entry that writes the
   same file (see that file's comment at line ~1017) -- preserve that ordering relationship in
   whatever replaces it. Note that the same file already contains a worked precedent for the
   per-project shape: ~/.claude.json's `.projects[<path>].mcpServers` carries `lean-lsp` for four
   Lean repos today.

2. SEVEN READ-TOOL GRANTS -- AND THE 11 / 7 / 4 ACCOUNTING.
   `config/claude/settings.json`'s `permissions.allow` lists exactly seven Sapience entries:
   `mcp__sapience__sapience`, `mcp__sapience__sapience_search`, `_briefing`, `_context`, `_ask`,
   `_outstanding`, `_papers`. home-manager merges this file into ~/.claude/settings.json with
   `permissions` as an ENFORCED key, so these are reasserted machine-wide on every switch. All
   seven are removed here.

   WHICH FILE HOLDS WHAT, verified on disk 2026-11-13. All ELEVEN grants now live in the
   extension's `settings-fragment.json`: the FOUR pre-existing write-tool grants
   (`mcp__sapience__sapience_remember`, `_wrapup`, `_handoff`, `_adddoc`, already repo-scoped
   before the companion ran) plus the SEVEN read-tool grants the companion added, which are
   byte-identical to the seven this task removes. So the seven removed here are not lost -- they
   are already present at per-repo scope, which is why removing them is safe now and was not
   safe before.

   KNOWN RESIDUAL, NOT THIS TASK'S TO FIX. The companion's verification found that the FOUR
   pre-existing write-tool grants SURVIVE an extension unload, because `.claude-extensions.json`'s
   merge-tracking record for them
   (`merged_sections.settings.permissions.children.allow.items`) has been empty since before the
   companion existed. The seven read-tool grants the companion added DO retract cleanly on
   unload. The four-grant residual is a merge-engine defect that the companion explicitly scoped
   out and named as a separate, differently-scoped follow-up. Do not mistake it for something this
   task introduced, and do not widen this task to close it.

3. FIVE HOOKS, in the same file's `hooks` object:
   - SessionStart     -> `[ -f "$HOME/.sapience/mcp.py" ] && python3 "$HOME/.sapience/mcp.py" --briefing-text 2>/dev/null || true`
   - UserPromptSubmit -> `[ -f "$HOME/.sapience/sapience_cli.py" ] && python3 "$HOME/.sapience/sapience_cli.py" hook prompt 2>/dev/null || true` (timeout 3)
   - PreToolUse, matcher `Edit|Write|MultiEdit` -> `... sapience_cli.py hook tool ...` (timeout 3)
   - SessionEnd       -> `... mcp.py --receipt ...` (async true)
   - Stop             -> `... mcp.py --effect-line ...` (timeout 3)
   Each is guarded by a `[ -f ~/.sapience/<file> ]` test and `|| true`, so it is already inert
   when the payload is absent -- but the guard tests for the PAYLOAD, not for the repository,
   which is exactly the gap this change closes. These five go; a SIXTH `SessionStart` entry is
   ADDED to this same object -- see "THE ONE MACHINE-WIDE SURFACE THAT MUST STAY" above. The net
   change to `hooks.SessionStart` is therefore one entry out and one different entry in, not a
   bare deletion.

4. THE `_SAPIENCE_NOTE` in `config/claude/settings.json` must be rewritten rather than deleted.
   Its current text records a correct and still-load-bearing reason for the present arrangement --
   `hooks` and `permissions` are ENFORCED keys in `home.activation.claudeSettings`, so a vendor
   installer's write to the live file would be reverted on the next switch -- plus two deliberate
   rulings worth carrying forward: `statusLine` belongs to `hooks/statusline-push.sh` and is
   deliberately NOT wired to Sapience, and `sapience_cli.py`'s own `hook session` and `hook stop`
   are deliberately NOT wired because each would duplicate an `mcp.py` hook and print a second
   line per turn. The rewritten note must state where each surface now lives and why the
   enforced-key hazard no longer forces them into this file. It must also state why the
   registration `SessionStart` entry is the one Sapience entry that stays, naming the enforced-key
   mechanism as the reason it has to live here rather than in the extension's installer.

=== THE OWNER ACTION THIS TASK MUST SPECIFY BUT CANNOT PERFORM ===

`~/.sapience/config.json` (mode 600) carries, as read on disk 2026-11-13:

- A TOP-LEVEL `folders` key -- note it sits at the top level, NOT under `capture` -- holding a
  five-entry transcript-directory allowlist: `-home-benjamin--config-nvim`,
  `-home-benjamin--dotfiles`, `-home-benjamin-Philosophy-Papers-PossibleWorlds`,
  `-home-benjamin-Projects-BimodalLogic`, `-home-benjamin-Projects-Logos-Verification`.
- `capture.mode: "opt-in"`.
- `capture.projects`: a 10-entry list of objects shaped `{path_prefix, name, target, enabled}`.
  Five are `enabled: true` -- `/home/benjamin/Projects/BimodalLogic`, `/home/benjamin/.dotfiles`,
  `/home/benjamin/Philosophy/Papers/PossibleWorlds`, `/home/benjamin/.config/nvim`,
  `/home/benjamin/Projects/Logos/Verification`. Five are present but `enabled: false` --
  `/home/benjamin/Projects/Logos/Vision`, `/home/benjamin/Projects/Logos/Theory`,
  `/home/benjamin/Documents/Personal/Wedding`, `/home/benjamin/Projects/PersonalWebsite`,
  `/home/benjamin/Documents/Employment/Applications`.
- Neither `abood` nor `sapience-app` appears anywhere in that file.

Measured against the four-repo extension-loaded set above, `BimodalLogic`, `PossibleWorlds` and
`Verification` are being read and uploaded WITHOUT the extension loaded, while `abood` and
`sapience-app` are extension-loaded but not captured at all.

`~/.sapience/**` is outside every repository's tree and is a genuine OWNER ACTION -- never an
agent edit -- and note that the payload SELF-UPDATES DAILY, so a hand-patch to a vendor `.py`
file there would be overwritten. This task's deliverable for that surface is an EXACT, RUNNABLE
instruction handed to the user, not a description of one and not an edit. The instruction must
reconcile BOTH keys to exactly the four-repo set:

- `capture.projects`: set `enabled: false` on `/home/benjamin/Projects/BimodalLogic`,
  `/home/benjamin/Philosophy/Papers/PossibleWorlds` and
  `/home/benjamin/Projects/Logos/Verification`; ADD `/home/benjamin/Projects/abood` and
  `/home/benjamin/Projects/Sapience/sapience-app` as enabled entries matching the existing
  `{path_prefix, name, target, enabled}` shape.
- top-level `folders`: reduce to the transcript-directory keys of the four loaded repos --
  `-home-benjamin--config-nvim`, `-home-benjamin--dotfiles`, `-home-benjamin-Projects-abood` and
  `-home-benjamin-Projects-Sapience-sapience-app`. The last of these does not exist under
  `~/.claude/projects/` yet (it is created on the first session run from the moved checkout); the
  stale `-home-benjamin-Projects-sapience-app` key from the pre-move path, if the owner's
  allowlist ever acquires it, is not the same directory and must not be used.

Preserve the top-level `token` field and the file's 600 mode. Determine and state whether
`sapience-bootstrap`'s own folder picker is the sanctioned route for this reconciliation rather
than a hand-edit, and say which.

=== VERIFICATION THIS TASK OWNS ===

- `nix flake check` is authoritative and must pass; it runs `statix`, `deadnix`, `nixfmt --check`
  and `shellcheck` as `checks.<system>.*` outputs. Run it, not merely a build. Note `deadnix`
  exits 0 on findings unless `--fail` is passed.
- A `home-manager switch` (or at minimum `home-manager build --flake .#benjamin`) must succeed,
  and the resulting ~/.claude/settings.json must be inspected to confirm the seven grants and five
  hooks are GONE from the live merged file -- not merely absent from the repo source. The merge is
  additive for non-enforced keys, so confirm the enforced-key path actually removes them rather
  than leaving stale entries behind.
- THE SAME SWITCH MUST LEAVE THE REGISTRATION ENTRY STANDING. After the switch, the live
  ~/.claude/settings.json's `hooks.SessionStart` must still contain an entry whose command is
  byte-identical to the string recorded above. This is the specific property the companion could
  not provide and this task exists to supply; it is the one check that distinguishes a correct
  landing from one that silently turns Sapience off everywhere.
- ~/.claude.json must be inspected to confirm `mcpServers.sapience` is gone from the top level and
  that no other key in that file was disturbed -- the activation entry merges rather than
  overwrites, and that property must survive the change.
- A session in a repo WITHOUT the extension (`~/Projects/cslib` and `~/Projects/Logos/Theory` are
  verified-unloaded candidates) must show no `sapience_*` tools, no Sapience grants and no
  Sapience hook firing. A session in any of the four loaded repos must still show all nine tools,
  all eleven grants and all five hooks, and must still acquire its own
  `.projects[<abs path>].mcpServers.sapience` entry in ~/.claude.json.
- SF-1 CARD SESSIONS -- TWO CHANNELS WITH DIFFERENT CORRECT ANSWERS. Recorded here so that neither
  the desired half nor the gap is later mistaken for the other. This repository packages the SF-1
  hub runner (`modules/home/services/sf1-hub-ben.nix`, `packages/sf1-hub-ben/`, `docs/sf1-hub.md`;
  already landed, and with NO file overlap with this task's edit targets). That runner starts
  Claude Code inside throwaway git worktrees under `~/.local/state/sf1-hub-ben/hub/runner/work/`,
  which is not any registered project path. Two distinct Sapience channels reach such a session,
  and they differ in whether they can be scoped to a repository at all.

  CHANNEL 1 -- HOOK-INJECTED CONTEXT (`SessionStart`, `UserPromptSubmit`, `PreToolUse`). CANNOT be
  scoped, so a card session must NOT have it. Direct live measurement, recorded in the
  agent-system source store at
  `agent-system/extensions/sapience/context/project/sapience/domain/injection-site-scoping.md`
  under /home/benjamin/.config/nvim, established that none of the three primary-session injection
  sites can be scoped from this side: `POST /v1/cli/context` ignores the `project` field
  `UserPromptSubmit` already sends, and its response carries no per-item attribution a local
  wrapper could filter or label by. That work therefore did NOT make injection repo-scoped; it
  recorded the residual and adopted a label-never-suppress ruling. For cards the consequence is
  decisive: any card session that fired those hooks would receive cross-repo vault content --
  material from unrelated repositories, and personal material -- inside a session executing a task
  card written by a collaborator, whose output posts back to a shared room. Zero is the right
  answer here, and it is ALREADY STRUCTURALLY GUARANTEED independently of this task: hooks and
  grants reach a repo only via the extension's `settings-fragment.json` merged into that repo's
  `.claude/settings.local.json`, and `.claude/` is untracked in the card repo (verified:
  `git ls-files .claude` is empty in /home/benjamin/Projects/Sapience/sapience-app), so a fresh
  worktree has no `.claude/` tree at all and therefore no hooks and no grants, by construction.
  This task neither creates nor must preserve that property.

  CHANNEL 2 -- MCP RETRIEVAL (`sapience_search`, and the dispatch-time `sapience-retrieve.sh`).
  CAN be scoped, IS already scoped, and a card session SHOULD have it.
  `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` builds
  `GET {host}/v1/search?q=...&source=[repo:<slug>]&...` -- a hard pre-filter on the literal
  `[repo:<slug>]` provenance substring (`&project=` is a dead end, silently ignored, and that
  script's own header says so). Repo-tagged knowledge objects for the card repo are precisely the
  accumulated decisions and findings about that repo, which is exactly what a card doing work
  there should be able to draw on.

  WHAT ACTUALLY HAPPENS, AND WHY ZERO-FOR-BOTH ARRIVES BY ACCIDENT. Per-project MCP registration
  keys on the repo's absolute path and on whether that repo's extension is active. A worktree path
  matches no registered project and carries no `.claude-extensions.json`, so it gets no
  registration and therefore no tools -- including the scoped retrieval tools that SHOULD be
  available. Zero-for-both is thus reached by accident rather than by design, and the useful half
  is lost along with the unsafe half. Do NOT record "a card session will receive NONE, and that is
  correct and desired" as a blanket statement: it is true of hook injection and false of
  retrieval.

  THE GAP AND ITS FOLLOW-UP -- NOT THIS TASK'S WORK. The absence of retrieval tools in a card
  worktree is a known, deliberate gap that this task does NOT close and must not be read as
  closing. The follow-up's shape: a card worktree should resolve to its PARENT CHECKOUT for
  Sapience registration purposes, so the card repo's own repo-scoped retrieval is available inside
  the worktree. The mechanism already has a precedent in the runner itself -- its memory sync keys
  on the CHECKOUT path, not the worktree path -- and `git rev-parse --git-common-dir` resolves a
  worktree to its checkout in one call. The registration logic lives in
  `agent-system/extensions/sapience/` under /home/benjamin/.config/nvim, so per
  `.claude/rules/source-store-deploy-boundary.md`'s Task Siting subsection that follow-up is
  created THERE, not here. It is deliberately NOT in this task's `file_scope` or edit-target list.

  VERIFY, for this task: start a session in a worktree path under that directory and confirm no
  Sapience hooks fire and no Sapience grants are present. Record the absence of retrieval tools
  there as the known gap above, not as a success condition.

  Independently of all of the above, the runner's memory sync is keyed on the CHECKOUT path, not
  the worktree path, so room rulings still land under the card repo's own Claude Code memory
  directory regardless of this change.

=== DOCUMENTATION THIS TASK OWNS ===

`docs/sapience.md` carries several statements that become false and must be rewritten, not merely
appended to:
- Its "What is installed" table rows `mcpServers.sapience in ~/.claude.json` ("Merged on
  activation, preserving every other key") and `Three hooks and seven tool grants` ("In
  config/claude/settings.json").
- That row's hook count is ALREADY WRONG: it says three hooks; five are registered.
- Its "why the hooks live in the repo" section, and the first-time-setup step 4 narrative
  explaining that a second switch is what puts the token into ~/.claude.json and that
  "`sapience status` keeps reporting Claude Code as not registered" without it -- per-repo
  registration changes what that step means and what `sapience status` can truthfully report.
- Any statement that Sapience is active machine-wide once bootstrapped.
- It must additionally document the one entry that stays: what the registration `SessionStart`
  hook does, that the two files it invokes are installed by the extension's own installer rather
  than by home-manager, and that this repository owns the durable registration of that entry.

=== A CROSS-REPO FOLLOW-UP THIS TASK MUST COORDINATE BUT MUST NOT PERFORM ===

`core/context/patterns/mcp-server-ownership.md` carries a sapience worked example that holds only
while both surfaces coexist. It goes stale the moment this task removes the dotfiles-level
seven-tool read allow-list and the top-level `mcpServers.sapience` merge: the example then
describes a machine-wide arrangement that exists nowhere. The companion's own Follow-ups name that
update as something to do "together with" this task's removal.

That file lives in the agent-system source store under /home/benjamin/.config/nvim, not in
.dotfiles. Per `.claude/rules/source-store-deploy-boundary.md`'s Task Siting subsection, the edit
belongs to an nvim-sited task. THIS TASK MUST NOT EDIT IT, and it is deliberately NOT in this
task's edit-target list (`config/claude/settings.json`, `modules/home/services/sapience.nix`,
`docs/sapience.md`). The coordination requirement is: an nvim-side task for that worked example
should be created and run alongside this one, so the two land together and the window of staleness
is closed rather than left open.

=== ACCEPTANCE CRITERIA ===

1. `nix flake check` passes.
2. No machine-wide Sapience ACTIVATION surface remains in this repository: no top-level
   `mcpServers.sapience` merge, no Sapience entry in `permissions.allow`, no Sapience activation
   hook in the `hooks` object -- each confirmed absent from the LIVE merged files after a switch,
   not just from the repo source. The per-project registration `SessionStart` entry is the single
   deliberate exception and is covered by criterion 8, not by this one.
3. A verified-unloaded repo gets no tools, no grants and no hook firing; all four extension-loaded
   repos -- `/home/benjamin/.dotfiles`, `/home/benjamin/.config/nvim`,
   `/home/benjamin/Projects/abood` and `/home/benjamin/Projects/Sapience/sapience-app` -- keep all
   nine tools, all eleven grants and all five hooks. An SF-1 card session in a worktree under
   `~/.local/state/sf1-hub-ben/hub/runner/work/` fires no Sapience hooks and carries no Sapience
   grants -- the correct outcome, and one already structurally guaranteed by that worktree having
   no `.claude/` tree at all. The absence of repo-scoped retrieval tools in that same worktree is
   recorded as a known, deliberate gap with a named nvim-sited follow-up, NOT as a success
   condition.
4. The `~/.sapience/config.json` reconciliation is handed over as an exact, runnable owner
   instruction covering BOTH `capture.projects` and the top-level `folders` allowlist, with the
   sanctioned route (hand-edit versus `sapience-bootstrap`'s picker) named.
5. `docs/sapience.md` states the new activation contract with a correct hook count and documents
   the registration `SessionStart` entry this repository now owns; the rewritten `_SAPIENCE_NOTE`
   preserves the enforced-key rationale, the `statusLine` ruling and the
   deliberately-unwired-`sapience_cli.py`-hooks ruling, and states why the registration entry
   stays.
6. The ordering constraint was honored: the companion extension-side task landed and was verified
   first. Record in this task's own artifacts how that was confirmed.
7. Files outside specs/** carry no task-number references and no record-versioning language
   (`.claude/rules/no-task-references-in-deliverables.md`,
   `.claude/rules/no-record-versioning-in-deliverables.md`).
8. THE REGISTRATION ENTRY IS DURABLE. After a `home-manager switch`, the live
   ~/.claude/settings.json still carries a `hooks.SessionStart` entry whose command is
   byte-identical to the string recorded above, and a session started in a loaded repo still
   produces that repo's `.projects[<abs path>].mcpServers.sapience` entry in ~/.claude.json.
   Re-running the companion's installer afterwards reports a no-op rather than double-registering.

---

### 137. Sapience standalone flake and nixpkgs blockers
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: packaging
- **Dependencies**: None
- **Research**: [137_sapience_standalone_flake_and_nixpkgs_blockers/reports/01_standalone-flake-nixpkgs-blockers.md]
- **Plan**: [137_sapience_standalone_flake_and_nixpkgs_blockers/plans/01_standalone-flake-nixpkgs-blockers.md]
- **Summary**: [packages/sapience-flake/flake.nix]

**Description**: Build a standalone, shareable Nix flake for the Sapience client inside this repo, isolated from the live home-manager config, plus a README.md documenting what stands in the way of a nixpkgs submission. Deliverable is a self-contained directory (e.g. packages/sapience-flake/) carrying its own flake.nix, a generalized copy of the sapience home-manager module, and the README, shareable with the Sapience vendor (CoreTx Inc. / Sapience Labs, app.spnc.ai) as-is. Scope: (1) flake outputs homeManagerModules.sapience plus packages.<system>.{sapience,sf1,sapience-bootstrap} for non-home-manager users, built from a vendored copy of modules/home/services/sapience.nix; (2) generalize the repo-specific choices so a stranger gets working vendor defaults instead of this machine's -- backend default relay (not ollama), memoryFiles default true (not false), model default empty, and drop the hardcoded home-path example string; (3) gate the ollama-journal progress ticker in sapience-bootstrap on backend == "ollama" so it is not dead code on the relay/anthropic/openai backends or against a system-level ollama; (4) document the Claude Code hooks/statusline gap, since those live in config/claude/settings.json outside the module and a flake consumer gets the MCP server but no per-turn visibility; (5) README.md stating why nixpkgs is impossible today with the gathered evidence -- no license grant anywhere (no headers in the ten client .py files, no LICENSE or ToS on app.spnc.ai, patents claimed, and PyPI reservations sapience-ai and spnc both 0.0.1 "Reserved by CoreTx Inc." declared License: Proprietary), nothing hashable upstream (app.spnc.ai serves cache-control: no-cache with no ETag, no Last-Modified and no version/manifest/install endpoint; sapience_upkeep.py treats a per-file sha256 the server compares as the version, self-updates daily and honours a server CLIENT_AUTO_UPDATE=0 kill switch, so a fetchurl hash breaks for every user on the vendor's next edit), and invite-only private beta with macOS-only official support failing nixpkgs' userbase and testability bars; plus the two concrete asks that would unblock it (publish versioned checksummed artifacts to the already-reserved PyPI names, and state a license permitting redistribution of the build output so it can be unfreeRedistributable rather than unfree). Constraint: must not alter the live modules/home/services/sapience.nix or home.nix behaviour on this machine.

---

### 136. Measure Sapience capture coverage under manual extraction and decide whether to widen the scope, the cap, or the cadence
- **Status**: [IMPLEMENTING]
- **Task Type**: general
- **Topic**: services
- **Dependencies**: Task 138
- **Research**: [136_evaluate_sapience_coverage_and_tune_extraction_scope/reports/02_baseline-and-extraction-backend-blocked.md]
- **Plan**: [136_evaluate_sapience_coverage_and_tune_extraction_scope/plans/02_coverage-measurement-series-and-decision.md]
- **Record**: [136_evaluate_sapience_coverage_and_tune_extraction_scope/records/01_coverage-pass-ledger.md]

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

### 134. Pin aeneas charon to verification revision
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: None
- **Research**: [134_pin_aeneas_charon_to_verification_revision/reports/01_pin-aeneas-charon-revision.md]
- **Plan**: [134_pin_aeneas_charon_to_verification_revision/plans/01_pin-aeneas-charon-revision.md]
- **Summary**: [134_pin_aeneas_charon_to_verification_revision/summaries/01_pin-aeneas-charon-revision-summary.md]

**Description**: Update the aeneas flake input so the installed charon and aeneas (exposed as aeneas-charon/aeneas-aeneas via flake.nix and lib/mkHost.nix, installed in modules/home/packages/misc.nix) match the pin used by ~/Projects/Logos/Verification: aeneas 227f4e7ac70d687a6b1a4871b3304f5a1c6994bf, with charon a5591f6b94c8575a6ba2ae71090614a722f2b011 (the charon revision that aeneas pins). flake.lock currently locks aeneas at 86158eb2e18944c5225959712efb96bce188f40d and the installed charon reports b104e24, so Verification framed_channel/check.sh refuses to run with "the extraction's pinned revisions disagree". Pin aeneas.url to the exact revision (github:AeneasVerif/aeneas/227f4e7ac70d687a6b1a4871b3304f5a1c6994bf) rather than following the default branch, so future drift is deliberate; confirm the resulting charon matches a5591f6. Also consider adding hacl.cachix.org (key hacl.cachix.org-1:FzsZ2xsByOwKwIWNPII7yMOelJNDZ12mDAj3d1eGX0c=) as a trusted substituter in nix.settings so these packages are fetched instead of compiled from source (hours), and update the flake.nix comment that says no public binary cache exists. Acceptance: after rebuild, `aeneas --version`/`charon version` on PATH report the pinned revisions and Verification check.sh passes its aeneas revision coherence stage without a scratch Nix store.

---

### 133. Restructure nix configuration layout
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: None

**Description**: Conduct systematic research, both locally (audit current split between configuration.nix, home.nix, lib/mkHost.nix, modules/, hosts, flake.nix outputs) and online (NixOS/Home Manager/flake structuring best practices, e.g. flake-parts, dendritic/aspect-oriented patterns, NixOS-integrated vs standalone home-manager, system vs home package placement), to rethink how this Nix configuration is structured; identify the best, most maintainable structure going forward, then design and implement a systematic refactor

---

### 132. Add aeneas rust to lean verification tooling
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: nixos-config
- **Dependencies**: None
- **Research**: [132_add_aeneas_rust_to_lean_verification_tooling/reports/01_aeneas-rust-lean-tooling.md]
- **Plan**: [132_add_aeneas_rust_to_lean_verification_tooling/plans/01_aeneas-rust-lean-tooling.md]
- **Summary**: [132_add_aeneas_rust_to_lean_verification_tooling/summaries/01_aeneas-rust-lean-tooling-summary.md]

**Description**: Add Aeneas Rust-to-Lean verification tooling (Charon and Aeneas) to support formal verification of Rust in Lean for the Verification project at /home/benjamin/Projects/Logos/Verification. Decide between two integration approaches: (1) a NixOS system-level flake input (aeneas.url = github:AeneasVerif/aeneas, without inputs.nixpkgs.follows since Aeneas pins its own Rust nightly and OCaml versions, exposing aeneas.packages.${pkgs.system}.charon and .aeneas via whichever of home.packages or environment.systemPackages this config already uses for dev tools, checked against real output names from `nix flake show github:AeneasVerif/aeneas`), or (2) a project-local flake.nix dev shell in the Verification repo pinning the same two packages via `nix develop`. Leave Lean (managed via elan) and the existing Rust toolchain (cargo/rustc/rustfmt/clippy) untouched; do not add lean4 or rustup. Check whether Aeneas or Charon document a binary cache (e.g. Cachix) and add it to nix.settings.substituters/trusted-public-keys only if documented. Verify with `charon --help` and `aeneas -help` after rebuild. Survey the existing NixOS config's dev-tooling conventions to integrate Aeneas naturally, and produce specific instructions for what should be configured locally in the Verification repo instead (e.g. the Lean side of Aeneas, which Lake fetches per-project via `require aeneas from git ... / backends/lean`, not via this NixOS config). A pending recommendation task in the Verification repo may bear on which of the two integration approaches (system-wide vs project-local) to choose

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
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: None
- **Research**: [128_claude_mcp_registration_and_permission_scope/reports/01_mcp-registration-permission-scope.md]
- **Plan**: [128_claude_mcp_registration_and_permission_scope/plans/01_mcp-registration-permission-scope.md]
- **Summary**: [modules/home/core/dotfiles.nix]

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

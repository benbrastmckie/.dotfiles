# Implementation Plan: AI-Assisted Email Management Workflow

- **Task**: 71 - Design AI-assisted email management workflow
- **Status**: [NOT STARTED]
- **Effort**: ~34 hours (14 phases)
- **Plan Version**: 3 (2nd revision; supersedes plans/02_email-workflow-implementation.md)
- **Dependencies**: Task 46 (Gmail OAuth2 refresh-token expiry) — resolved or absorbed in Phase 1 before any live/bulk run
- **Research Inputs**:
  - reports/03_team-research.md (round-3 synthesis — PRIMARY for this revision: extension packaging, loader source-of-truth, hook guardrail gap)
  - reports/03_teammate-a-findings.md (nvim `<leader>al` loader + canonical source mapping)
  - reports/03_teammate-b-findings.md (`email/` extension authoring: manifest/routing/doc-lint)
  - reports/03_teammate-c-findings.md (reconcile 4 surfaces + guardrail gap)
  - reports/03_teammate-d-findings.md (cross-system source-of-truth, migration, selective loading)
  - reports/02_team-research.md (round-2 synthesis — integrated in v2, carried forward, not re-derived)
  - reports/02_teammate-{a,b,c,d}-findings.md (command mechanics, hook enforcement, aerc UX, prior-art ~/Mail)
  - reports/01_ai-email-workflow.md (seed)
- **Reports Integrated**:
  - reports/03_team-research.md (integrated_in_plan_version: 3)
  - reports/03_teammate-a-findings.md (integrated_in_plan_version: 3)
  - reports/03_teammate-b-findings.md (integrated_in_plan_version: 3)
  - reports/03_teammate-c-findings.md (integrated_in_plan_version: 3)
  - reports/03_teammate-d-findings.md (integrated_in_plan_version: 3)
- **Artifacts**: plans/04_email-workflow-implementation.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: general (nix implementation surface + a Claude Code extension authored in the nvim-config library)

## Overview

Design and build a guardrailed, human-in-the-loop workflow for cleaning a large Gmail backlog
(64,316 messages in All_Mail, 2,301 in Inbox — counted live) and keeping the inbox clean going
forward. The architecture keeps two access paths: a **read-only Anthropic Gmail connector** for
daily triage/summarize/draft (Path A), and the **local Himalaya/notmuch/mbsync stack** for all
mutations (Path B). The build is deliberately split (per round-2 Teammate D) into a **heavy,
one-time, closely-supervised backlog-purge tool** plus a **minimal ongoing hygiene loop**
(institutionalized Gmail filters + notmuch `postNew` rules doing the passive work).

**Round-3 change (this revision):** the agent-facing pieces (harvested preferences doc,
`mail-guard.sh` hook, `skill-email-cleanup`, plus a new safety-critical
`email-implementation-agent` and its `skill-email-implementation`) are no longer hand-written into
`.dotfiles/.claude/`. They are the `provides:` of a single **`email/` Claude Code extension
authored CANONICALLY in `~/.config/nvim/.claude/extensions/email/`** — round-3 live inspection
confirmed that directory is the master extension library that the `<leader>al` loader file-copies
into consuming repos; `~/.dotfiles/.claude/extensions/` is a **sync target, not the source**. The
extension is **OFF by default** and enabled per-machine/project via `<leader>al`. The nix wrapper
scripts remain nix-owned and unchanged; the extension references them by name but never bundles or
installs nix files.

Definition of done: the `email/` extension exists in the canonical library, passes
`check-extension-docs.sh`, and is loaded into `.dotfiles/.claude/`; the backlog purge has run once
end-to-end on Gmail behind every safety gate with an explicit undo window reported; standing rules
are dual-written; and the ongoing loop is documented — with Protonmail/Logos explicitly deferred to
phase 2.

Every destructive phase sits behind five gates, in order: (1) the Phase 0 prior-art audit, (2) the
OAuth gate (Phase 1), (3) the safety infrastructure (Phases 2, 3, 5), (4) the extension packaging &
load (Phase 6, which installs the hardened hook so enforcement is actually active), and (5) a
single-message dry-run delete verification (Phase 7) that proves a message actually leaves All_Mail
before any bulk delete runs.

### Research Integration (round-3 deltas folded into this version)

1. **Retargeted authoring paths** — Phase 0 preferences output, Phase 3 hook, Phase 4 skill are now
   authored under `~/.config/nvim/.claude/extensions/email/` and installed via the loader.
2. **New Phase 6** — author the `email/` extension (manifest.json, EXTENSION.md, README,
   index-entries.json, `email-implementation-agent`, `skill-email-implementation`) and pass
   `check-extension-docs.sh`, then load into `.dotfiles/.claude/`.
3. **Hardened mail-guard hook** — switched from token-gating raw commands to an **allowlist** of the
   five wrapper binaries, denying raw `himalaya message (delete|move|send)` and `folder expunge`
   outright (Phase 3), closing the round-3 gap where `himalaya message delete`/`move` slipped through.
4. **Corrected Phase 0 verdicts** — five (not four) prior-art Python scripts; explicit
   HARVEST/RETIRE/DISCARD verdicts replacing the open resume/retire/partition question.
5. **Keybind-collision check** — new email keybinds must not shadow the pre-existing nvim Himalaya
   plugin's `<leader>me/mS/mf`; "task 45" referenced in earlier context does not exist as a numbered
   task (the real 4th surface is that nvim Himalaya plugin).

### User-Decision Assumptions

Two working assumptions remain open and are each marked at the point of use as
**"ASSUMPTION — confirm with user before the first destructive phase (Phase 7/10) executes"**:

1. **DELETE = mix**: archive keepers to All_Mail, true-delete junk to reclaim Gmail storage.
2. **SCOPE = split**: one-time guardrailed backlog-purge tool + a minimal ongoing hygiene loop
   (NOT one permanent unified write-capable agent).

The round-2 third assumption (PRIOR-ART = audit-then-decide) is now **RESOLVED** into explicit
verdicts in Phase 0 (harvest data / retire harness / discard checkbox UX + opus pin), per round-3
Teammate C.

### Recorded Decisions (round-3)

- **Extension source of truth**: authored in `~/.config/nvim/.claude/extensions/email/` (canonical
  library), installed into `.dotfiles/.claude/`, `~/Mail/.claude/`, and any project via `<leader>al`;
  OFF by default. (Confirm the location with the user before Phase 0 — round-3 open USER question.)
- **Backlog-review UI stays in aerc** (Phase 9 tagged-view querymap), as planned in v2. Surfacing the
  Proposed-Delete/Archive/Unsure review inside the pre-existing nvim Himalaya plugin's `ui/` layer is
  a **DEFERRED phase-2 option** — document, do not build.
- **4th email surface / "task 45"**: there is no `.dotfiles` task numbered 45. The real 4th surface is
  the pre-existing nvim Himalaya plugin (`~/.config/nvim/lua/neotex/plugins/tools/himalaya/` +
  `mail.lua`, keybinds `<leader>me` aerc float, `<leader>mS` mbsync+notmuch, `<leader>mf` notmuch
  telescope). Any new email keybind MUST NOT shadow `<leader>m*`.

### nix-vs-.claude Ownership Line (explicit, round-3 corrected)

This is a NixOS/home-manager repo. The design draws a hard line so behavior does not drift out of
the reproducibility guarantee. **Extensions provide `.claude`-owned files only; nix files are never
bundled or installed by an extension — they are referenced by name.**

| Concern | Owner | Location |
|---------|-------|----------|
| Wrapper scripts (`email-census`, `email-classify`, `email-archive-confirmed`, `email-delete-confirmed`, `email-unsubscribe-extract`) | **nix** (`writeShellScriptBin`) | `modules/home/packages/email-tools.nix` (extend) or new `modules/home/email/agent-tools.nix` — referenced by the extension, NOT bundled |
| notmuch `index.header.List` config + `postNew` junk rules | **nix** | `modules/home/email/notmuch.nix` |
| aerc querymap entries + review keybinds | **nix** | `modules/home/email/aerc.nix` |
| mbsync freeze/thaw + SyncState-backup helper | **nix** | `modules/home/email/mbsync.nix` (+ a `writeShellScriptBin` helper) |
| PreToolUse mail-guard hook (allowlist wrappers, deny raw mutations) | **.claude via `email/` extension** | authored `~/.config/nvim/.claude/extensions/email/hooks/mail-guard.sh`; registered via `provides.hooks` + `merge_targets.settings`; installed to `.dotfiles/.claude/hooks/` by loader |
| `skill-email-cleanup` (ad-hoc `/email`; teach agent to call wrappers) | **.claude via extension** | `~/.config/nvim/.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` |
| `skill-email-implementation` + `email-implementation-agent` (safety-critical `/implement` target) | **.claude via extension** | `~/.config/nvim/.claude/extensions/email/skills/skill-email-implementation/SKILL.md`, `.../agents/email-implementation-agent.md` |
| Classification preferences / rules doc (harvested from `~/Mail` in Phase 0) | **.claude via extension** | `~/.config/nvim/.claude/extensions/email/context/project/email/email-preferences.md` |
| Extension packaging (manifest, EXTENSION.md, README, index-entries) | **.claude via extension** | `~/.config/nvim/.claude/extensions/email/{manifest.json,EXTENSION.md,README.md,index-entries.json}` |
| Audit/approval manifests | **.dotfiles git** | `specs/071_design_ai_email_management_workflow/manifests/` |

**Manifest location decision** (unchanged from v2): manifests live in
`.dotfiles/specs/071_.../manifests/` (same git history as the tooling), NOT `~/Mail/specs/`.

### Preserved Assets

Plan v3 is a scoped structural revision of v2; no prior task-71 implementation exists in `.dotfiles`
(only research + plan artifacts). The following existing configuration is complete and MUST NOT
regress:

| Component | File | Status | Notes |
|-----------|------|--------|-------|
| mbsync channel config (gmail-inbox/all/sent/drafts/trash/spam) | modules/home/email/mbsync.nix | [COMPLETED] | Do not alter channel semantics without the single-message verification (Phase 7) |
| notmuch postNew tagging + index config | modules/home/email/notmuch.nix | [COMPLETED] | Phase 11 extends, never rewrites |
| aerc querymap + visual-select keybinds | modules/home/email/aerc.nix | [COMPLETED] | Phase 9 adds entries, preserves existing |
| Himalaya config + folder aliases (`[Gmail].Trash`, Drafts) | docs/himalaya.md, config | [COMPLETED] | Wrappers call Himalaya, do not reconfigure |
| Existing PreToolUse `Write` hook + permissionDecision pattern | .claude/settings.json | [COMPLETED] | Phase 3 adds a `Bash` matcher alongside (installed via extension merge_targets), does not replace |
| Pre-existing nvim Himalaya plugin + `<leader>me/mS/mf` keybinds | ~/.config/nvim/lua/neotex/plugins/tools/himalaya/, mail.lua | [PRESERVE] | The real 4th email surface; new email keybinds must NOT shadow `<leader>m*` |
| Canonical nvim extension library + `<leader>al` loader | ~/.config/nvim/.claude/extensions/, shared/extensions/loader.lua | [PRESERVE] | The `email/` extension is authored here; do not fork it into `.dotfiles` |
| Dormant `~/Mail/.claude` prior-art system (28 tasks) | ~/Mail (separate git repo) | [PRESERVE REPO; RETIRE FORKED .claude] | Phase 0 harvests data then retires the harness; `~/Mail` the repo persists as runtime maildir + specs history |

### Source-to-Implementation Mapping (H3 reference grounding)

Every load-bearing decision cites the report that grounds it. This task is **Tier 2 (docs/code)**:
sources are live-verified local command mechanics + this repo's own config, not external literature.

| Design decision | Grounded in | Verification requirement |
|-----------------|-------------|--------------------------|
| Extension authored in `~/.config/nvim/.claude/extensions/email/` (canonical source); `.dotfiles/.claude` is a loader sync target | R3 Teammate A/D, R3 synthesis conflict #1 | `<leader>al` load copies `email/` into `.dotfiles/.claude/` + appends to extensions.json |
| Extension `provides:` = the hook + skills + agent + preferences (the same deliverable as v2 Phase 0/3/4) | R3 Teammate B/C | `check-extension-docs.sh` passes |
| Hook = **allowlist** the 5 wrappers, DENY raw `himalaya message (delete\|move\|send)` + `folder expunge` | R3 Teammate C (guardrail gap), R2 Teammate B §1 | Phase 3 tests: raw `himalaya message delete` denied; wrapper allowed |
| Delete = IMAP-level `himalaya message delete --folder INBOX <ids>` then `folder expunge Trash`; never local Maildir/notmuch-tag+Expunge | R2 Teammate A §4, R2 Teammate D Finding 2 | Phase 7 single-message dry-run must prove message leaves All_Mail (64,316 baseline) |
| Sender census = `notmuch address --output=sender --output=count --deduplicate=address` | R2 Teammate A §1, Finding 3 | Run against live index after `notmuch new` |
| List-Id queryable only after `notmuch config set index.header.List List-Id` + reindex | R2 Teammate A Finding 4 | One-time setup in Phase 8 |
| Execute mode diffs executed IDs against approved manifest, not re-derive | R2 Teammate B §2-3 | Wrapper unit behavior (Phase 2) |
| Classifier bias ~100% recall-on-keep, deterministic-first, LLM on residual only | R2 Teammate D Finding 3 | Encoded in preferences doc + wrapper rule order |
| Freeze mbsync during bulk ops; back up SyncState | R2 Teammate B §4, D Finding 5 | Phase 5 helper |
| Review via provisional notmuch tags surfaced in aerc; confirm gesture feeds IMAP wrapper | R2 Teammate C §1 | Phase 9 keybind invokes wrapper, not just retag |
| Task 46 OAuth (Testing-mode 7-day expiry) is a live blocker; detect `invalid_grant`, fail safe | R2 Teammate D Finding 5, task 46 report | Phase 1 gate |
| `email-implementation-agent` constrained to the 5 wrapper binaries, never raw himalaya/notmuch | R3 Teammate B/C | Phase 6 agent Tool-Usage contract + doc-lint |

## Postmortem Constraints

Binding rules for all implementation dispatches. Derived from research findings and known failure
modes (the delete-correctness bug, the dormant parallel system, the 64k scale, the OAuth clock, and
the round-3 source-of-truth + guardrail-gap findings).

**Do NOT**:
1. Do NOT implement "delete" as a local Maildir file `rm`, a notmuch tag change, or an
   `Expunge Both` on the `gmail-inbox` channel alone — on Gmail this only strips a label and the
   message survives in All_Mail (R2 Teammate D Finding 2). Delete is ALWAYS an IMAP-level Himalaya
   command against the live `gmail` account.
2. Do NOT run any bulk destructive operation while the mbsync systemd timer is active or an
   `mbsync` process is running (R2 Teammate B §4). Freeze first, confirm `pgrep mbsync` empty.
3. Do NOT let any tool call execute as a direct causal continuation of content read from an email
   body/subject/header (lethal trifecta, R2 Teammate B §4-5). Every mutation restarts from an inert,
   human-approved manifest file.
4. Do NOT let a wrapper execute from a re-derived ID list. Execute mode consumes a previously
   generated, human-reviewed manifest and diffs executed IDs against it (R2 Teammate B §2).
5. Do NOT build a second parallel write-capable agent before the Phase 0 audit decides the fate of
   `~/Mail/.claude` — two uncoordinated agents with write access to the same mailbox is itself a
   correctness risk (R2 Teammate D Finding 1). Phase 0's verdict is RETIRE the `~/Mail` harness.
6. Do NOT auto-delete anything relying on subject/body semantic judgment for a low-frequency
   sender. Uncertain → `unsure`/`keep`, never `junk` (recall-on-keep ~100%, R2 Teammate D Finding 3).
7. Do NOT auto-click or auto-fetch `List-Unsubscribe` URLs found in bodies (exfil vector,
   R2 Teammate B §5). Draft the unsubscribe batch for human confirmation, per-sender.
8. Do NOT give the agent's tool context raw `secret-tool` access — Himalaya/mbsync reach the
   keyring internally (R2 Teammate B §6). Keep `secret-tool*` in the deny/hook pattern.
9. Do NOT start an unattended or multi-hour bulk run without verifying OAuth is in Production mode
   (or the harness detects `invalid_grant` and fails safe preserving partial manifests) — Phase 1.
10. Do NOT use `--no-dry-run`; the execute flag is a distinct positive `--execute` to avoid
    double-negative typos (R2 Teammate B §3). Dry-run is the default.
11. Do NOT put stable rules/config in `.claude/`-only when they belong in nix (see ownership line);
    do NOT put behavioral agent instructions in nix.
12. **Do NOT author the `email/` extension in `.dotfiles/.claude/extensions/` — it is a loader SYNC
    TARGET, not the source.** Author canonically in `~/.config/nvim/.claude/extensions/email/` and
    install into consuming repos via `<leader>al`; otherwise it forks and orphans like the prior
    `~/Mail/.claude` copy did (R3 Teammate A/D).
13. **Do NOT let any convenience path (command, skill, or agent) call raw `himalaya message
    delete/move/send` or `himalaya folder expunge`.** The mail-guard hook allowlists ONLY the five
    wrapper binaries and denies those raw mutations outright — the round-2 hook missed
    `himalaya message delete`/`move`, which are the actual bulk mutations run before expunge
    (R3 Teammate C guardrail gap). Route every mutation through the wrappers.

**MUST preserve**:
- Existing mbsync channel semantics, notmuch postNew tagging, aerc keybinds, Himalaya folder
  aliases, the nvim Himalaya plugin's `<leader>m*` keybinds, and the canonical nvim extension library
  (see Preserved Assets). Extend, never rewrite; never shadow `<leader>m*`.
- Gmail's 30-day Trash undo window as a real safety net — never target hard/permanent delete that
  bypasses Trash.
- `~/Mail` the repo (maildir + specs history) untouched; only its hand-forked `.claude/` retires.

**Design decisions are SETTLED** (do not re-open without a concrete counterexample):
- Delete mechanism = IMAP-level Himalaya (local tag+Expunge rejected — no-ops on Gmail All_Mail).
- Gmail-first; Logos/Protonmail deferred to phase 2 (dual-account-now rejected).
- Enforcement = PreToolUse hook, now an **allowlist** (permissions.deny alone rejected, #18846 gaps;
  raw-command token-gating rejected — R3 guardrail gap).
- Harness form = nix wrappers + a loadable `email/` extension (write-capable Gmail MCP rejected).
- Extension authored in the canonical nvim library, OFF by default (authoring in `.dotfiles` rejected
  — it is a sync target).
- Backlog-review UI in aerc; nvim-Himalaya-plugin surfacing deferred to phase 2.

## Goals & Non-Goals

- **Goals**:
  - A loadable `email/` Claude Code extension (canonical nvim library, OFF by default) that packages
    the mail-guard hook, the cleanup skill, and a wrapper-only implementation agent.
  - A guardrailed one-time Gmail backlog purge that archives keepers and IMAP-deletes junk with
    human approval at every irreversible step, run once end-to-end.
  - A minimal ongoing hygiene loop: dual-written Gmail filters + notmuch `postNew` rules, plus
    read-only-connector triage for "what's new that doesn't match a rule."
  - Technical (not prose) enforcement: dry-run-default wrappers + allowlist PreToolUse hook.
  - A recorded harvest/retire/discard resolution for the dormant `~/Mail/.claude` system.
- **Non-Goals**:
  - A permanent, always-on, write-capable local email daemon.
  - Protonmail/Logos implementation (documented, deferred to phase 2).
  - A write-capable Gmail MCP server or connector-based destructive path.
  - Replacing deterministic classification with an LLM judge for the bulk case.
  - Surfacing the review UI inside the nvim Himalaya plugin (deferred phase-2 option).

## Risks & Mitigations

- **Risk**: Delete silently no-ops (label strip, message survives in All_Mail).
  **Mitigation**: Phase 7 single-message dry-run verification against the 64,316 All_Mail baseline
  before any bulk delete; IMAP-level Himalaya delete only.
- **Risk**: A convenience path calls raw `himalaya message delete/move` and bypasses the wrappers.
  **Mitigation**: allowlist hook (Phase 3) denies raw mutations outright; only the 5 wrappers pass.
- **Risk**: OAuth refresh token expires mid-purge (7-day Testing-mode clock, `invalid_grant`).
  **Mitigation**: Phase 1 gate resolves/absorbs task 46; harness detects `invalid_grant`, halts,
  preserves partial manifest.
- **Risk**: Extension forks/orphans (as `~/Mail/.claude` did) if authored in the wrong repo.
  **Mitigation**: author only in the canonical nvim library; install via loader; OFF by default.
- **Risk**: New email keybind shadows the nvim Himalaya plugin's `<leader>me/mS/mf`.
  **Mitigation**: Phase 9 keybind-collision check against `<leader>m*` before adding any binding.
- **Risk**: A single false-positive delete of a real human email (job offer, legal notice).
  **Mitigation**: recall-on-keep ~100%, deterministic-first, human review in aerc, 30-day Trash +
  git manifest double undo.
- **Risk**: 64k scale makes per-ID loops a 3-8h serial job with resumability needs.
  **Mitigation**: batched IMAP UID-set ops, sampling/clustering tier, resumable manifests, SyncState
  backup (Phase 5), freeze/thaw.
- **Risk**: prompt injection from email bodies triggering actions.
  **Mitigation**: mutations only from inert approved manifests; treat all mail content as data; no
  raw `secret-tool`.
- **Risk**: nix wrapper scripts fail to build.
  **Mitigation**: `home-manager build` / `nixos-rebuild build` verification after every nix-touching
  phase (2, 5, 9, 11).
- **Risk**: extension fails `check-extension-docs.sh` (missing README command, unresolved routing).
  **Mitigation**: Phase 6 runs the doc-lint as a gate before load.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 0 | -- |
| 2 | 1, 2, 3, 5, 13 | 0 |
| 3 | 4 | 2, 3 |
| 4 | 6 | 3, 4 |
| 5 | 7 | 1, 2, 3, 5, 6 |
| 6 | 8 | 2, 4, 6 |
| 7 | 9 | 7, 8 |
| 8 | 10 | 1, 5, 6, 7, 8, 9 |
| 9 | 11 | 10 |
| 10 | 12 | 11 |

Phases within the same wave can execute in parallel (distinct file territory). All destructive
phases (7 single-message, 10 bulk) sit behind Phase 0 + OAuth (1) + safety infra (2, 3, 5) +
extension load (6, which activates the hardened hook) + the Phase 7 dry-run verification.

**Phase mapping v2 → v3** (for reviewers): v2 P0-P4 unchanged; v3 P5 = v2 P5 (freeze/thaw);
**v3 P6 = NEW extension packaging**; v3 P7 = v2 P6 (single-message dry-run); v3 P8 = v2 P7 (census);
v3 P9 = v2 P8 (aerc review); v3 P10 = v2 P9 (bulk purge); v3 P11 = v2 P10; v3 P12 = v2 P11;
v3 P13 = v2 P12.

### Phase 0: Prior-art audit, harvest, and retirement verdicts [NOT STARTED]
- **Goal:** Audit the dormant `~/Mail/.claude` email-agent system and record binding
  HARVEST/RETIRE/DISCARD verdicts plus a harvested rules inventory written into the extension
  source. Blocking; non-destructive; NO new tooling until complete.
- **Tasks:**
  - [ ] `git -C ~/Mail log --oneline` and read `~/Mail/specs/state.json` (confirm last commit
    2026-02-19, task 27 `planned` but never implemented, `next_project_number` = 29).
  - [ ] Read `~/Mail/.claude/{commands/email.md, skills/skill-email/, agents/email-agent.md}` and the
    **five** Python wrappers (`email_list.py`, `email_analyze.py`, `email_triage.py`,
    `email_filter.py`, `email_execute.py` in `~/Mail/.claude/scripts/email/`).
  - [ ] Read `~/Mail/.claude/context/project/email/email-preferences.md` and the task-2/14/28
    summaries (Trash-first policy, batch-limit=50, checkbox approval UX, `pass`/Bridge fix).
  - [ ] Record explicit verdicts (round-3 Teammate C):
    - **HARVEST**: `email-preferences.md` rule taxonomy + JSON schema, and the `MAX_BATCH_SIZE=50`
      constant (encode later as a wrapper/hook limit).
    - **RETIRE**: the harness — `commands/email.md`, `skills/skill-email`, `agents/email-agent.md`,
      and all five Python scripts — superseded by the nix-wrapper+hook+aerc design; reusing it
      recreates the "second uncoordinated agent" postmortem risk.
    - **DISCARD**: the checkbox-approval UX (churned across `~/Mail` tasks 014/022/023, superseded by
      the aerc tagged-view + git-manifest review) and the retired command's `model: claude-opus-4-5`
      pin (follow this repo's tiered policy — worker/implementation agents = Sonnet).
    - **PRESERVE**: `~/Mail` the repo as a runtime data dir (maildir + specs history); only its
      forked `.claude/` retires.
  - [ ] Write the harvested-rules inventory (sender patterns, batch limit, approval-UX lessons) to
    **`~/.config/nvim/.claude/extensions/email/context/project/email/email-preferences.md`** (the
    extension source; installed into `.dotfiles/.claude/` in Phase 6 via the loader).
- **Timing:** ~2 hours
- **Depends on:** none
- **Done when:** the HARVEST/RETIRE/DISCARD verdicts + harvested preferences exist in the extension
  source; no tooling files created yet. Estimated output: ~150 lines.

### Phase 1: OAuth gate (task 46) [NOT STARTED]
- **Goal:** Verify current Gmail OAuth consent-screen mode and either resolve task 46 (publish app
  to Production) or declare it a hard blocking dependency of the destructive phases.
- **Tasks:**
  - [ ] Verify current OAuth status: is the consent screen still in Testing mode (7-day refresh-token
    expiry, `invalid_grant`)? Check `specs/046_.../reports/01_gmail-oauth2-token-expiry.md` and live
    token state / systemd logs for `refresh-gmail-oauth2`.
  - [ ] Decision branch: **(a) absorb** — publish the OAuth app to Production mode and re-authenticate,
    documenting the steps; or **(b) block** — mark task 46 a hard dependency and stop here. Record
    which branch was taken.
  - [ ] Specify the harness fail-safe: wrappers must detect `invalid_grant` on any IMAP call, halt
    cleanly, and preserve the partial manifest (feeds Phase 2 wrapper error handling). **ASSUMPTION #1
    (delete=mix) — confirm before Phase 7/10.**
- **Timing:** ~2 hours
- **Depends on:** 0
- **Done when:** OAuth mode is verified and either fixed-to-Production or declared a blocker in
  writing; the `invalid_grant` fail-safe contract is specified. Estimated output: ~120 lines.

### Phase 2: nix-declared wrapper scripts (dry-run default) [NOT STARTED]
- **Goal:** Declare the five `writeShellScriptBin` wrappers, dry-run-by-default, each owning one verb,
  requiring `--execute` + `--confirm-manifest <sha256>` for mutation, with execute mode diffing
  executed IDs against the approved manifest. These are the ONLY binaries the hook allowlists.
- **Tasks:**
  - [ ] Add `email-census` (calls `notmuch address --output=sender --output=count
    --deduplicate=address`, folder/date buckets, `himalaya envelope list -o json`); read-only.
  - [ ] Add `email-classify` (deterministic rules → provisional notmuch tags; emits a manifest;
    enforce the harvested `MAX_BATCH_SIZE=50` limit); dry-run-only.
  - [ ] Add `email-archive-confirmed` and `email-delete-confirmed`: default dry-run; `--execute`
    requires `--confirm-manifest <sha256>`; execute mode reads the approved manifest, diffs executed
    IDs against it, and issues IMAP-level Himalaya commands (`message move All_Mail` / `message delete
    --folder INBOX`). Detect `invalid_grant` → halt + preserve manifest (Phase 1 contract).
  - [ ] Add `email-unsubscribe-extract` (per-sender List-Unsubscribe extraction to a review list;
    never auto-POSTs).
  - [ ] Wire into `modules/home/packages/email-tools.nix` (or new `modules/home/email/agent-tools.nix`).
  - [ ] `home-manager build` (or `nixos-rebuild build`) to verify the derivations evaluate.
- **Timing:** ~3 hours
- **Depends on:** 0
- **Done when:** five wrappers build; `--help`/dry-run output verified; execute path refuses without a
  matching manifest hash; batch limit enforced. Estimated output: ~350 lines nix + shell.

### Phase 3: PreToolUse mail-guard hook — ALLOWLIST design [NOT STARTED]
- **Goal:** Add technical enforcement authored in the extension source: a `Bash`-matcher hook that
  **allowlists the five wrapper binaries and DENIES raw mail mutations outright**. This closes the
  round-3 gap where the v2 regex missed `himalaya message delete` and `himalaya message move` (the
  actual bulk move-to-Trash/archive commands run before expunge).
- **Tasks:**
  - [ ] Write **`~/.config/nvim/.claude/extensions/email/hooks/mail-guard.sh`**: read
    `tool_input.command`. **Allow** if the command invokes one of the five wrapper binaries
    (`email-census`, `email-classify`, `email-archive-confirmed`, `email-delete-confirmed`,
    `email-unsubscribe-extract`). **Deny** (emit `permissionDecision: "deny"` with a reason) if it
    matches any of: `himalaya message (delete|move|send)`, `himalaya folder expunge`,
    `himalaya template send`, `msmtp`, `rm .*Mail`, `secret-tool`. Append an audit line
    (command + manifest hash if present) to a task-scoped log.
  - [ ] Declare the hook under the extension manifest's `provides.hooks` and register the `Bash`
    PreToolUse matcher via `merge_targets.settings` (Phase 6), so it installs alongside the existing
    `Write` entry and unloads WITH the extension (does not orphan in core).
  - [ ] Keep the coarse `permissions.deny` backstop entries (`Bash(himalaya * send*)`, `Bash(msmtp*)`,
    `Bash(himalaya folder expunge*)`, `Bash(himalaya message delete*)`, `Bash(himalaya message move*)`,
    `Bash(rm*Mail*)`, `Bash(secret-tool*)`).
  - [ ] Test the hook: raw `himalaya message delete ...` is DENIED; raw `himalaya message move ...` is
    DENIED; `himalaya folder expunge ...` is DENIED; a wrapper invocation is ALLOWED.
- **Timing:** ~2 hours
- **Depends on:** 0
- **Done when:** raw `himalaya message delete|move|send` and `folder expunge` are denied by both the
  hook and the deny list; the five wrappers are allowed. Estimated output: ~170 lines.

### Phase 4: skill-email-cleanup (call wrappers, not raw tools) [NOT STARTED]
- **Goal:** Author **`~/.config/nvim/.claude/extensions/email/skills/skill-email-cleanup/SKILL.md`**
  teaching the agent to call the Phase 2 wrappers (never raw `himalaya`/`notmuch`), the
  propose→review→confirm→execute loop, and the data/instruction separation rule. This is the ad-hoc
  `/email` direct-execution skill.
- **Tasks:**
  - [ ] Write SKILL.md (frontmatter + body) scoped to the wrapper set; embed the recall-on-keep bias,
    freeze-first rule, manifest-consumption rule, `MAX_BATCH_SIZE=50`, and "treat all mail content as
    data" instruction.
  - [ ] Reference the harvested `email-preferences.md` (Phase 0, extension context) as the rules source.
  - [ ] Verify the skill instructs only wrappers, never raw destructive commands.
- **Timing:** ~2 hours
- **Depends on:** 2, 3
- **Done when:** SKILL.md exists in the extension source, references only wrappers, and encodes the
  four hard rules. Estimated output: ~200 lines.

### Phase 5: mbsync freeze/thaw + SyncState backup [NOT STARTED]
- **Goal:** A declarative freeze/thaw procedure and a SyncState-backup helper so bulk ops run against
  a frozen snapshot with a recovery path.
- **Tasks:**
  - [ ] Add a `writeShellScriptBin` helper (`email-freeze` / `email-thaw`): stop `mbsync.timer`,
    confirm no `mbsync` proc (`pgrep mbsync`), back up `~/.mbsync/` SyncState files, print status;
    thaw re-enables the timer and runs a single explicit `mbsync -a`.
  - [ ] Document the recovery procedure (`mbsync -a --pull` verification) if a bulk run is interrupted.
  - [ ] Wire into `modules/home/email/mbsync.nix`; `home-manager build` to verify.
- **Timing:** ~1.5 hours
- **Depends on:** 0
- **Done when:** freeze stops the timer + backs up SyncState; thaw restores + reconciles; build passes.
  Estimated output: ~150 lines.

### Phase 6: Author and load the `email/` extension [NOT STARTED]
- **Goal:** Package the Phase 0/3/4 outputs plus a safety-critical implementation agent into a single
  `email/` extension in the **canonical nvim library**, pass `check-extension-docs.sh`, and load it
  into `.dotfiles/.claude/` via `<leader>al`. The extension is OFF by default. This phase gates the
  first live mutation because it installs the hardened hook so enforcement is actually active.
- **Tasks:**
  - [ ] Create `~/.config/nvim/.claude/extensions/email/manifest.json`:
    - `task_type: "email"` with **ASYMMETRIC routing**: `research → skill-researcher`,
      `plan → skill-planner` (shared, like every other extension), `implement → skill-email-implementation
      → email-implementation-agent` (custom, safety-critical wrapper-only executor).
    - `keyword_overrides`: keywords `inbox, email, gmail, himalaya, notmuch, unsubscribe, "junk mail",
      "draft reply", mbsync, aerc, "mail triage"`; aliases `mail, mailbox` (aliases only — bare
      "mail"/"draft" would false-positive).
    - `provides`: the `hooks` (mail-guard.sh), `skills` (skill-email-cleanup, skill-email-implementation),
      `agents` (email-implementation-agent), and `context`; plus `merge_targets.settings` (register the
      PreToolUse `Bash` matcher so the hook travels/unloads WITH the extension),
      `merge_targets.claudemd`, and `merge_targets.index`.
  - [ ] Author `agents/email-implementation-agent.md` whose **Tool Usage** section constrains it to
    call the five wrapper binaries by name (`email-census`, `email-classify`, `email-archive-confirmed`,
    `email-delete-confirmed`, `email-unsubscribe-extract`) and NEVER raw `himalaya`/`notmuch`; encode
    the confirmation-token/manifest contract. Model = Sonnet (tiered policy; NOT the retired opus pin).
  - [ ] Author `skills/skill-email-implementation/SKILL.md` (the `/implement` lifecycle target that
    dispatches to `email-implementation-agent`).
  - [ ] Author `EXTENSION.md` (≤60 lines, slim standard), `README.md` (must mention EVERY provided
    command for doc-lint — including the optional `/email`), and `index-entries.json`
    (`load_when.task_types: ["email"]`).
  - [ ] (Optional, mark optional) an ad-hoc direct-execution `/email` command (like `/literature`)
    backed by `skill-email-cleanup` for "clean up my inbox now".
  - [ ] Run `bash .claude/scripts/check-extension-docs.sh` and fix until it exits 0 (provides exist on
    disk, routing block present, routing targets resolvable, deployed skills reference existing agents,
    README lists every command).
  - [ ] Load into `.dotfiles/.claude/` via `<leader>al` (file-copy sync + append to
    `.dotfiles/.claude/extensions.json`); confirm the hook + skills + agent + preferences landed and
    the PreToolUse matcher registered in `.dotfiles/.claude/settings.json`. Confirm OFF-by-default
    semantics (enabled per-machine via the loader).
- **Timing:** ~3 hours
- **Depends on:** 3, 4
- **Done when:** `check-extension-docs.sh` passes; the extension loads into `.dotfiles/.claude/` with
  the hardened hook active and the wrapper-only agent registered. Estimated output: ~300 lines
  (manifest + agent + skill + EXTENSION.md + README + index-entries).

### Phase 7: Delete-mechanism single-message dry-run verification [NOT STARTED]
- **Goal:** Prove, on ONE message, that the IMAP-level delete path actually removes the message from
  All_Mail (64,316 baseline) before any bulk delete — de-risking the label-model resurrection bug.
  First live-IMAP mutation; single message only, behind the now-active allowlist hook.
  **ASSUMPTION #1 (delete=mix) — confirm with user before executing.**
- **Tasks:**
  - [ ] Freeze sync (Phase 5). Record baseline `~/Mail/Gmail/.All_Mail/cur | wc -l` = 64,316.
  - [ ] Pick one disposable junk message; run `email-delete-confirmed` in dry-run, review manifest,
    then `--execute --confirm-manifest <sha256>`: `himalaya message delete --folder INBOX <id>` →
    `[Gmail].Trash`; after approval `himalaya folder expunge Trash`; then `mbsync gmail` reconcile.
  - [ ] Verify the message is gone from BOTH Inbox and All_Mail locally and server-side, and the
    All_Mail count dropped by exactly one. If it survives in All_Mail, STOP — the mechanism is wrong.
  - [ ] Record the verified command sequence as the canonical delete recipe for Phase 10.
- **Timing:** ~2 hours
- **Depends on:** 1, 2, 3, 5, 6
- **Done when:** the single message provably left All_Mail (count 64,316 → 64,315) via the IMAP path;
  recipe recorded. Estimated output: ~120 lines.

### Phase 8: Census and classification [NOT STARTED]
- **Goal:** Produce real census numbers and a deterministic-first bucketed classification biased to
  ~100% recall-on-keep, with a sampling/clustering tier for the large `unsure` residual.
  Non-destructive (provisional tags + manifest only).
- **Tasks:**
  - [ ] One-time `notmuch config set index.header.List List-Id` + `notmuch new`/reindex to enable
    `List:` queries (R2 Teammate A Finding 4).
  - [ ] Run `email-census`: real counts by folder, age, top bulk senders. Emit the compact census
    summary.
  - [ ] Deterministic bucketing → provisional tags `+proposed-delete` / `+proposed-archive` /
    `+proposed-unsure` (List-Unsubscribe / `precedence:bulk` / sender-domain / reply-history / VIP).
  - [ ] Sampling/clustering tier for the ~6-13k `unsure` residual: classify a per-sender/cluster
    sample, extrapolate, route whole clusters; batched IMAP UID-set ops, resumable.
  - [ ] LLM only on the final residual + human-readable justifications. Emit companion manifest.
- **Timing:** ~3 hours
- **Depends on:** 2, 4, 6
- **Done when:** census summary produced; every in-scope message carries exactly one `+proposed-*`
  tag; manifest emitted; no message deleted. Estimated output: ~300 lines.

### Phase 9: Review UX (aerc tagged views → wrapper) [NOT STARTED]
- **Goal:** Surface the `+proposed-*` buckets as aerc querymap views with a bulk-confirm gesture that
  feeds the IMAP-level wrapper (not just a local retag). Backlog review stays in aerc (nvim-Himalaya
  surfacing is a deferred phase-2 option).
- **Tasks:**
  - [ ] **Keybind-collision check FIRST**: enumerate the nvim Himalaya plugin's existing bindings
    (`<leader>me`, `<leader>mS`, `<leader>mf`) and confirm no new aerc/email keybind shadows
    `<leader>m*`.
  - [ ] Add querymap entries (`Proposed-Delete`, `Proposed-Archive`, `Proposed-Unsure`) to
    `modules/home/email/aerc.nix`.
  - [ ] Add per-view keybinds: confirm retags `+confirmed-*` AND queues the message ID into the
    approved manifest consumed by `email-delete-confirmed`/`email-archive-confirmed`; reject rescues to
    `+proposed-keep`. The confirm gesture must NOT perform the delete inline — it feeds the manifest.
  - [ ] `home-manager build` to verify aerc config; confirm existing keybinds/querymaps preserved.
- **Timing:** ~2 hours
- **Depends on:** 7, 8
- **Done when:** the three views open in aerc; bulk-confirm writes to the approved manifest; existing
  aerc config intact; no `<leader>m*` collision. Estimated output: ~150 lines.

### Phase 10: Backlog-purge execution (Gmail, one-time, supervised) [NOT STARTED]
- **Goal:** Run the full supervised pipeline once on Gmail. **ASSUMPTION #1 & #2 — confirm with user
  before executing.** Human-supervised; batched; resumable. (The wall-clock purge runtime is separate
  supervised runtime; the agent's authored surface here is the orchestration driver + report.)
- **Tasks:**
  - [ ] Freeze → census (real numbers) → bucket → sample/cluster → tag proposals → aerc review →
    execute via wrappers (archive keepers to All_Mail, IMAP-delete junk to Trash) → `folder expunge
    Trash` (only after per-bucket approval) → `mbsync gmail` reconcile.
  - [ ] Batched IMAP UID-set ops (not per-ID loops); resumable via partial manifests; detect
    `invalid_grant` → halt + preserve.
  - [ ] Produce the final report: counts (archived / deleted / left-unsure), explicit undo window
    (Gmail 30-day Trash + expiry date), and the git-tracked manifest path. Gmail-only.
- **Timing:** ~4 hours (agent-authored orchestration + report; supervised run separate)
- **Depends on:** 1, 5, 6, 7, 8, 9
- **Done when:** the pipeline has run once end-to-end; report states counts + undo window + expiry;
  manifest committed to `specs/071_.../manifests/`. Estimated output: ~250 lines.

### Phase 11: Institutionalize rules (dual-write) [NOT STARTED]
- **Goal:** Convert confirmed junk rules into durable passive enforcement: server-side Gmail filters
  AND `notmuch.nix` `postNew` hook rules; plus a per-sender unsubscribe review.
- **Tasks:**
  - [ ] For each high-confidence confirmed sender/domain, add a `notmuch tag +junk -inbox --
    from:...` line to the `postNew` hook in `modules/home/email/notmuch.nix` (extend, never rewrite).
  - [ ] Produce the matching Gmail filter definitions for human application (agent proposes; human
    approves in Gmail UI).
  - [ ] Run `email-unsubscribe-extract` → per-sender review list; human approves once per sender.
  - [ ] `home-manager build`; confirm every `notmuch new` re-applies the rules.
- **Timing:** ~2 hours
- **Depends on:** 10
- **Done when:** postNew rules build and apply; Gmail filter list produced; unsubscribe review list
  generated. Estimated output: ~180 lines.

### Phase 12: Ongoing hygiene loop (minimal) [NOT STARTED]
- **Goal:** Document and wire the deliberately-minimal ongoing loop: read-only connector triage +
  passive filters/tags, with the "draft in connector, send in aerc via `:recall`" seam. Explicitly
  NOT a permanent write-capable daemon.
- **Tasks:**
  - [ ] Document the two-phase daily loop (Path A read-only triage/draft anywhere; Path B terminal
    mutations only) and the draft-in-A / send-in-B (`:recall`) handoff.
  - [ ] Specify that the loop applies institutionalized rules automatically for the mechanical bulk and
    tags only genuinely-new/ambiguous senders `+proposed-*` for the same aerc review UX at daily scale.
  - [ ] Add a short usage doc (extend `docs/himalaya.md` or a new `docs/email-workflow.md`); note the
    deferred phase-2 option to surface the review UI in the nvim Himalaya plugin's `ui/` layer.
- **Timing:** ~2 hours
- **Depends on:** 11
- **Done when:** the loop is documented with the connector/local seam; no permanent daemon introduced.
  Estimated output: ~150 lines.

### Phase 13: Protonmail/Logos deferred (document only) [NOT STARTED]
- **Goal:** Document the phase-2 extension to Protonmail/Logos without implementing it.
- **Tasks:**
  - [ ] Document the deferral rationale (no 30-day Trash undo, Bridge-uptime dependency, 58 vs 64k
    volume) and the extension path (second querymap, Bridge-alive precheck, reuse the same
    tag-rule/filter pattern).
  - [ ] Cross-reference the Phase 0 verdict: the `~/Mail` harness is retired; the Logos/Bridge lessons
    from `~/Mail` are partitioned into this deferral doc as pointers only.
- **Timing:** ~1.5 hours
- **Depends on:** 0
- **Done when:** a phase-2 deferral doc exists; no Proton/Logos mutation performed. Estimated output:
  ~120 lines.

## Testing & Validation

- [ ] `home-manager build` (or `nixos-rebuild build --flake .#<host>`) passes after every
  nix-touching phase (2, 5, 9, 11).
- [ ] Phase 3: raw `himalaya message delete`, `himalaya message move`, and `himalaya folder expunge`
  are DENIED by both the hook and the deny list; a wrapper invocation is ALLOWED.
- [ ] Phase 6: `bash .claude/scripts/check-extension-docs.sh` exits 0; `<leader>al` load copies the
  extension into `.dotfiles/.claude/` and registers the PreToolUse matcher; extension is OFF by default.
- [ ] Phase 6: `email-implementation-agent` Tool-Usage section references only the five wrapper
  binaries; README lists every provided command.
- [ ] Phase 7: single-message delete drops `~/Mail/Gmail/.All_Mail/cur` count by exactly one
  (64,316 → 64,315) server-side and locally — the go/no-go gate for all bulk delete.
- [ ] Wrappers refuse `--execute` without a matching `--confirm-manifest` hash; execute mode diffs
  IDs against the approved manifest; `MAX_BATCH_SIZE=50` enforced.
- [ ] `invalid_grant` is detected and halts cleanly, preserving the partial manifest.
- [ ] Phase 9: no new email keybind shadows `<leader>me/mS/mf`.
- [ ] Phase 10 report states archived/deleted/unsure counts + explicit undo window + expiry date.
- [ ] Phase 11 `postNew` rules re-apply on `notmuch new`.

## Artifacts & Outputs

Extension source (authored canonically; installed into `.dotfiles/.claude/` via `<leader>al`):
- ~/.config/nvim/.claude/extensions/email/manifest.json (Phase 6)
- ~/.config/nvim/.claude/extensions/email/EXTENSION.md, README.md, index-entries.json (Phase 6)
- ~/.config/nvim/.claude/extensions/email/hooks/mail-guard.sh (Phase 3, hardened allowlist)
- ~/.config/nvim/.claude/extensions/email/skills/skill-email-cleanup/SKILL.md (Phase 4)
- ~/.config/nvim/.claude/extensions/email/skills/skill-email-implementation/SKILL.md (Phase 6)
- ~/.config/nvim/.claude/extensions/email/agents/email-implementation-agent.md (Phase 6)
- ~/.config/nvim/.claude/extensions/email/context/project/email/email-preferences.md (harvested, Phase 0)
- (optional) ~/.config/nvim/.claude/extensions/email/commands/email.md (Phase 6, optional)

nix-owned (referenced by the extension, NOT bundled):
- modules/home/packages/email-tools.nix or modules/home/email/agent-tools.nix (wrappers, Phase 2)
- modules/home/email/mbsync.nix (freeze/thaw helper, Phase 5)
- modules/home/email/aerc.nix (querymap + keybinds, Phase 9)
- modules/home/email/notmuch.nix (index config + postNew rules, Phases 8 & 11)

Task-scoped (this repo):
- plans/04_email-workflow-implementation.md (this file)
- specs/071_design_ai_email_management_workflow/manifests/ (audit/approval manifests)
- docs/email-workflow.md or docs/himalaya.md extension (Phase 12)
- summaries/04_email-workflow-implementation-summary.md (on completion)

## Rollback/Contingency

- The `email/` extension unloads cleanly because the hook + settings entry travel with it
  (`provides.hooks` + `merge_targets.settings`); removing the extension from `.dotfiles/.claude/`
  de-registers the PreToolUse matcher. Re-authoring only touches the canonical library.
- Nix changes revert via git + `home-manager switch` to the prior generation; each nix phase is a
  separate commit.
- Deleted mail is recoverable from Gmail's 30-day Trash AND the git-tracked approval manifests
  (double undo) until `folder expunge` + retention.
- If Phase 7 verification fails (message survives in All_Mail), STOP: the delete mechanism is wrong;
  do not proceed to Phase 10. Re-open the delete-mechanism decision with the failing evidence.
- If Phase 6 `check-extension-docs.sh` fails, fix the manifest/README/routing before loading; do not
  hand-copy files into `.dotfiles/.claude/` to bypass the loader.
- If OAuth cannot be moved to Production (Phase 1 branch b), the destructive phases (7, 10) are BLOCKED
  until task 46 is resolved; the non-destructive phases (0, 2, 3, 4, 5, 6, 8 census/tagging, 13) may
  still proceed.
- mbsync SyncState corruption: restore the Phase 5 backup and re-run `mbsync -a --pull` verification.

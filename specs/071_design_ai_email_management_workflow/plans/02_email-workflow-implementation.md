# Implementation Plan: AI-Assisted Email Management Workflow

- **Task**: 71 - Design AI-assisted email management workflow
- **Status**: [NOT STARTED]
- **Effort**: ~31 hours (13 phases)
- **Dependencies**: Task 46 (Gmail OAuth2 refresh-token expiry) — resolved or absorbed in Phase 1 before any live/bulk run
- **Research Inputs**:
  - reports/02_team-research.md (synthesis)
  - reports/02_teammate-a-findings.md (command mechanics, live-verified)
  - reports/02_teammate-b-findings.md (hook enforcement, confirmation token, lethal trifecta)
  - reports/02_teammate-c-findings.md (aerc review UX, dual-write institutionalization)
  - reports/02_teammate-d-findings.md (prior-art ~/Mail system, delete-correctness bug, 64k scale, task 46)
  - reports/01_ai-email-workflow.md (seed)
- **Artifacts**: plans/02_email-workflow-implementation.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: general (substantial nix implementation surface)

## Overview

Design and build a guardrailed, human-in-the-loop workflow for cleaning a large Gmail backlog
(64,316 messages in All_Mail, 2,301 in Inbox — counted live) and keeping the inbox clean going
forward. The architecture keeps two access paths: a **read-only Anthropic Gmail connector** for
daily triage/summarize/draft (Path A), and the **local Himalaya/notmuch/mbsync stack** for all
mutations (Path B). The build is deliberately split (per Teammate D) into a **heavy, one-time,
closely-supervised backlog-purge tool** plus a **minimal ongoing hygiene loop** (institutionalized
Gmail filters + notmuch `postNew` rules doing the passive work). Definition of done: the backlog
purge has run once end-to-end on Gmail behind every safety gate with an explicit undo window
reported, standing rules are dual-written, and the ongoing loop is documented — with Protonmail/
Logos explicitly deferred to phase 2.

Every destructive phase sits behind four gates, in order: (1) the Phase 0 prior-art audit, (2) the
OAuth gate (Phase 1), (3) the safety infrastructure (Phases 2, 3, 5), and (4) a single-message
dry-run delete verification (Phase 6) that proves a message actually leaves All_Mail before any
bulk delete runs.

### User-Decision Assumptions

The plan is built against three working assumptions. Each is marked at the point of use as
**"ASSUMPTION — confirm with user before the first destructive phase (Phase 6/9) executes"**:

1. **DELETE = mix**: archive keepers to All_Mail, true-delete junk to reclaim Gmail storage.
2. **SCOPE = split**: one-time guardrailed backlog-purge tool + a minimal ongoing hygiene loop
   (NOT one permanent unified write-capable agent).
3. **PRIOR-ART = audit-then-decide**: audit `~/Mail/.claude` in Phase 0, then choose
   resume / retire / partition.

### nix-vs-.claude Ownership Line (explicit)

This is a NixOS/home-manager repo. The design draws a hard line so behavior does not drift out of
the reproducibility guarantee (Teammate D, Finding 5):

| Concern | Owner | Location |
|---------|-------|----------|
| Wrapper scripts (`email-census`, `email-classify`, `email-archive-confirmed`, `email-delete-confirmed`, `email-unsubscribe-extract`) | **nix** (`writeShellScriptBin`) | `modules/home/packages/email-tools.nix` (extend) or new `modules/home/email/agent-tools.nix` |
| notmuch `index.header.List` config + `postNew` junk rules | **nix** | `modules/home/email/notmuch.nix` |
| aerc querymap entries + review keybinds | **nix** | `modules/home/email/aerc.nix` |
| mbsync freeze/thaw + SyncState-backup helper | **nix** | `modules/home/email/mbsync.nix` (+ a `writeShellScriptBin` helper) |
| PreToolUse mail-guard hook + deny backstop | **.claude** | `.claude/hooks/mail-guard.sh` + `.claude/settings.json` |
| Claude Code Skill (teach agent to call wrappers, not raw himalaya/notmuch) | **.claude** | `.claude/skills/skill-email-cleanup/SKILL.md` |
| Classification preferences / rules doc | **.claude** (harvested from `~/Mail` in Phase 0) | `.claude/context/project/email/email-preferences.md` |
| Audit/approval manifests | **.dotfiles git** (decision below) | `specs/071_design_ai_email_management_workflow/manifests/` |

**Manifest location decision**: manifests live in `.dotfiles/specs/071_.../manifests/` (same git
history as the tooling), NOT `~/Mail/specs/`. Rationale: avoids splitting the audit trail across two
unconnected git repos (Teammate D, Finding 7 Q5). The `~/Mail/specs/` location is used only if
Phase 0 decides to *resume* the `~/Mail` system as the ongoing-hygiene tool.

### Preserved Assets

No prior implementation exists for task 71 in `.dotfiles` (this is plan v2; v1 = `01_*`; only research
artifacts exist). The following existing configuration is complete and MUST NOT regress:

| Component | File | Status | Notes |
|-----------|------|--------|-------|
| mbsync channel config (gmail-inbox/all/sent/drafts/trash/spam) | modules/home/email/mbsync.nix | [COMPLETED] | Do not alter channel semantics without the single-message verification (Phase 6) |
| notmuch postNew tagging + index config | modules/home/email/notmuch.nix | [COMPLETED] | Phase 10 extends, never rewrites |
| aerc querymap + visual-select keybinds | modules/home/email/aerc.nix | [COMPLETED] | Phase 8 adds entries, preserves existing |
| Himalaya config + folder aliases (`[Gmail].Trash`, Drafts) | docs/himalaya.md, config | [COMPLETED] | Wrappers call Himalaya, do not reconfigure |
| Existing PreToolUse `Write` hook + permissionDecision pattern | .claude/settings.json | [COMPLETED] | Phase 3 adds a `Bash` matcher alongside, does not replace |
| Dormant `~/Mail/.claude` prior-art system (28 tasks) | ~/Mail (separate git repo) | [PRESERVE UNTIL AUDITED] | Phase 0 decides fate; do not delete or reactivate before the decision |

### Source-to-Implementation Mapping (H3 reference grounding)

Every load-bearing decision below cites the report that grounds it. This task is a **Tier 2
(docs/code)** grounding: the sources are live-verified local command mechanics plus this repo's own
config, not external literature.

| Design decision | Grounded in | Verification requirement |
|-----------------|-------------|--------------------------|
| Delete = IMAP-level `himalaya message delete --folder INBOX <ids>` then `folder expunge Trash`; never local Maildir/notmuch-tag+Expunge | Teammate A §4, Teammate D Finding 2, synthesis conflict #1 | Phase 6 single-message dry-run must prove message leaves All_Mail (64,316 baseline) |
| Sender census = `notmuch address --output=sender --output=count --deduplicate=address` (NOT `search --output=sender`, which errors on notmuch 0.40) | Teammate A §1, Finding 3 | Run against live index after `notmuch new` |
| List-Id queryable only after `notmuch config set index.header.List List-Id` + reindex | Teammate A Finding 4 | One-time setup in Phase 7 |
| Enforcement = PreToolUse hook + confirmation token, not permissions.deny alone | Teammate B §1, claude-code#18846 | Reuse in-repo hook pattern (settings.json line 31+) |
| Execute mode diffs executed IDs against approved manifest, not re-derive | Teammate B §2-3 | Wrapper unit behavior (Phase 2) |
| Classifier bias ~100% recall-on-keep, deterministic-first, LLM on residual only | Teammate D Finding 3, synthesis #4 | Encoded in preferences doc + wrapper rule order |
| Freeze mbsync during bulk ops; back up SyncState | Teammate B §4, Teammate D Finding 5 | Phase 5 helper |
| Review via provisional notmuch tags surfaced in aerc; confirm gesture feeds IMAP wrapper | Teammate C §1, synthesis conflict #1 | Phase 8 keybind must invoke wrapper, not just retag |
| Task 46 OAuth (Testing-mode 7-day expiry) is a live blocker; detect `invalid_grant`, fail safe | Teammate D Finding 5, task 46 report | Phase 1 gate |

## Postmortem Constraints

Binding rules for all implementation dispatches. Derived from research findings and known failure
modes (no prior `.dotfiles` implementation exists; rules come from the delete-correctness bug, the
dormant parallel system, the 64k scale, and the OAuth clock).

**Do NOT**:
1. Do NOT implement "delete" as a local Maildir file `rm`, a notmuch tag change, or an
   `Expunge Both` on the `gmail-inbox` channel alone — on Gmail this only strips a label and the
   message survives in All_Mail (Teammate D Finding 2). Delete is ALWAYS an IMAP-level Himalaya
   command against the live `gmail` account.
2. Do NOT run any bulk destructive operation while the mbsync systemd timer is active or an
   `mbsync` process is running (Teammate B §4). Freeze first, confirm `pgrep mbsync` empty.
3. Do NOT let any tool call execute as a direct causal continuation of content read from an email
   body/subject/header (lethal trifecta, Teammate B §4-5). Every mutation restarts from an inert,
   human-approved manifest file.
4. Do NOT let a wrapper execute from a re-derived ID list. Execute mode consumes a previously
   generated, human-reviewed manifest and diffs executed IDs against it (Teammate B §2).
5. Do NOT build a second parallel write-capable agent in `.dotfiles/.claude` before the Phase 0
   audit decides the fate of `~/Mail/.claude` — two uncoordinated agents with write access to the
   same mailbox is itself a correctness risk (Teammate D Finding 1).
6. Do NOT auto-delete anything relying on subject/body semantic judgment for a low-frequency
   sender. Uncertain → `unsure`/`keep`, never `junk` (recall-on-keep ~100%, Teammate D Finding 3).
7. Do NOT auto-click or auto-fetch `List-Unsubscribe` URLs found in bodies (exfil vector,
   Teammate B §5). Draft the unsubscribe batch for human confirmation, per-sender.
8. Do NOT give the agent's tool context raw `secret-tool` access — Himalaya/mbsync reach the
   keyring internally (Teammate B §6). Add `secret-tool*` to the deny/hook pattern.
9. Do NOT start an unattended or multi-hour bulk run without verifying OAuth is in Production mode
   (or the harness detects `invalid_grant` and fails safe preserving partial manifests) — Phase 1.
10. Do NOT use `--no-dry-run`; the execute flag is a distinct positive `--execute` to avoid
    double-negative typos (Teammate B §3). Dry-run is the default.
11. Do NOT put stable rules/config in `.claude/`-only when they belong in nix (see ownership line);
    do NOT put behavioral agent instructions in nix.

**MUST preserve**:
- Existing mbsync channel semantics, notmuch postNew tagging, aerc keybinds, Himalaya folder
  aliases (see Preserved Assets). Extend, never rewrite.
- Gmail's 30-day Trash undo window as a real safety net — never target hard/permanent delete that
  bypasses Trash.
- The `~/Mail/.claude` system untouched until Phase 0's decision is recorded.

**Design decisions are SETTLED** (do not re-open without a concrete counterexample):
- Delete mechanism = IMAP-level Himalaya (alternative: local tag+Expunge — rejected, proven to
  no-op on Gmail All_Mail).
- Gmail-first; Logos/Protonmail deferred to phase 2 (alternative: dual-account now — rejected: no
  30-day Trash undo on Proton, Bridge-uptime dependency, 58 vs 64k volume).
- Enforcement = PreToolUse hook + token (alternative: permissions.deny alone — rejected, #18846
  bypass gaps).
- Harness form = nix wrappers + Claude Code Skill (alternative: write-capable Gmail MCP server —
  rejected: second OAuth client, network-bound at 64k, first-class bulk-delete, cannot cover Proton).

## Goals & Non-Goals

- **Goals**:
  - A guardrailed one-time Gmail backlog purge that archives keepers and IMAP-deletes junk with
    human approval at every irreversible step, run once end-to-end.
  - A minimal ongoing hygiene loop: dual-written Gmail filters + notmuch `postNew` rules, plus
    read-only-connector triage for "what's new that doesn't match a rule."
  - Technical (not prose) enforcement: dry-run-default wrappers + confirmation-token PreToolUse hook.
  - A recorded resume/retire/partition decision for the dormant `~/Mail/.claude` system.
- **Non-Goals**:
  - A permanent, always-on, write-capable local email daemon.
  - Protonmail/Logos implementation (documented, deferred to phase 2).
  - A write-capable Gmail MCP server or connector-based destructive path.
  - Replacing deterministic classification with an LLM judge for the bulk case.

## Risks & Mitigations

- **Risk**: Delete silently no-ops (label strip, message survives in All_Mail).
  **Mitigation**: Phase 6 single-message dry-run verification against the 64,316 All_Mail baseline
  before any bulk delete; IMAP-level Himalaya delete only.
- **Risk**: OAuth refresh token expires mid-purge (7-day Testing-mode clock, `invalid_grant`).
  **Mitigation**: Phase 1 gate resolves/absorbs task 46; harness detects `invalid_grant`, halts,
  preserves partial manifest.
- **Risk**: Two uncoordinated agents (`~/Mail` + `.dotfiles`) with write access to the same mailbox.
  **Mitigation**: Phase 0 blocking audit + explicit reconciliation decision before any tooling.
- **Risk**: A single false-positive delete of a real human email (job offer, legal notice).
  **Mitigation**: recall-on-keep ~100%, deterministic-first, human review in aerc, 30-day Trash +
  git manifest double undo.
- **Risk**: 64k scale makes per-ID loops an 3-8h serial job with resumability/partial-failure needs.
  **Mitigation**: batched IMAP UID-set ops, sampling/clustering tier, resumable manifests, SyncState
  backup (Phase 5), freeze/thaw.
- **Risk**: prompt injection from email bodies triggering actions.
  **Mitigation**: break the action leg — mutations only from inert approved manifests; treat all
  mail content as data; no raw `secret-tool`.
- **Risk**: nix wrapper scripts fail to build.
  **Mitigation**: `home-manager build` / `nixos-rebuild build` verification after every nix-touching
  phase (2, 5, 8, 10).

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 0 | -- |
| 2 | 1, 2, 3, 5, 12 | 0 |
| 3 | 4, 6 | 2, 3 (P4); 1, 2, 3, 5 (P6) |
| 4 | 7 | 2, 4 |
| 5 | 8 | 6, 7 |
| 6 | 9 | 1, 5, 6, 7, 8 |
| 7 | 10 | 9 |
| 8 | 11 | 10 |

Phases within the same wave can execute in parallel (distinct file territory). All destructive
phases (6 single-message, 9 bulk) sit behind Phase 0 + OAuth (1) + safety infra (2, 3, 5) + the
Phase 6 dry-run verification.

### Phase 0: Prior-art audit and reconciliation decision [NOT STARTED]
- **Goal:** Audit the dormant `~/Mail/.claude` email-agent system and record a binding
  resume / retire / partition decision plus a harvested rules inventory. Blocking; non-destructive;
  NO new tooling until complete.
- **Tasks:**
  - [ ] `git -C ~/Mail log --oneline` and read `~/Mail/specs/state.json` (confirm last commit
    2026-02-19, task 27 `planned` but never implemented, `next_project_number` = 29).
  - [ ] Read `~/Mail/.claude/{commands/email.md, skills/skill-email/, agents/email-agent.md}` and the
    4 Python wrappers (`email_list.py`, `email_analyze.py`, `email_triage.py`, `email_execute.py`).
  - [ ] Read `~/Mail/.claude/context/project/email/email-preferences.md` and the task-2/task-14/
    task-28 summaries (Trash-first policy, batch-limit=50, checkbox approval UX, `pass`/Bridge fix).
  - [ ] Write a resume/retire/partition **decision** with rationale. Default lean (Teammate D):
    partition — `.dotfiles` owns the Gmail one-time purge + ongoing loop; `~/Mail` either retired or
    reserved for Logos phase 2. **ASSUMPTION #3 — confirm with user.**
  - [ ] Write a harvested-rules inventory (sender patterns, batch limit, approval-UX lessons) to
    `.claude/context/project/email/email-preferences.md` (new, nix-vs-.claude line: .claude-owned).
- **Timing:** ~2 hours
- **Depends on:** none
- **Done when:** a written decision (resume/retire/partition) + rules inventory exist; no tooling
  files created yet. Estimated output: ~150 lines (decision doc + harvested preferences).

### Phase 1: OAuth gate (task 46) [NOT STARTED]
- **Goal:** Verify current Gmail OAuth consent-screen mode and either resolve task 46 (publish app
  to Production) or declare it a hard blocking dependency of the destructive phases. This gate
  precedes any unattended/bulk run.
- **Tasks:**
  - [ ] Verify current OAuth status: is the consent screen still in Testing mode (7-day refresh-token
    expiry, `invalid_grant`)? Check `specs/046_.../reports/01_gmail-oauth2-token-expiry.md` and live
    token state / systemd logs for `refresh-gmail-oauth2`.
  - [ ] Decision branch: **(a) absorb** — publish the OAuth app to Production mode and re-authenticate,
    documenting the steps; or **(b) block** — mark task 46 a hard dependency and stop here until it is
    resolved out-of-band. Record which branch was taken.
  - [ ] Specify the harness fail-safe: wrappers must detect `invalid_grant` on any IMAP call, halt
    cleanly, and preserve the partial manifest (feeds Phase 2 wrapper error handling). **ASSUMPTION #1
    (delete=mix) — confirm before Phase 6/9.**
- **Timing:** ~2 hours
- **Depends on:** 0
- **Done when:** OAuth mode is verified and either fixed-to-Production or declared a blocker in
  writing; the `invalid_grant` fail-safe contract is specified. Estimated output: ~120 lines.

### Phase 2: nix-declared wrapper scripts (dry-run default) [NOT STARTED]
- **Goal:** Declare the five `writeShellScriptBin` wrappers, dry-run-by-default, each owning one verb,
  requiring `--execute` + `--confirm-manifest <sha256>` for mutation, with execute mode diffing
  executed IDs against the approved manifest.
- **Tasks:**
  - [ ] Add `email-census` (calls `notmuch address --output=sender --output=count
    --deduplicate=address`, folder/date buckets, `himalaya envelope list -o json` shape per
    Teammate A §7); read-only.
  - [ ] Add `email-classify` (deterministic rules: List-Unsubscribe / `precedence:bulk` /
    sender-domain / reply-history / VIP allowlist → provisional notmuch tags; emits a manifest);
    dry-run-only (tagging is reversible, but writes manifest, does not delete).
  - [ ] Add `email-archive-confirmed` and `email-delete-confirmed`: default dry-run; `--execute`
    requires `--confirm-manifest <sha256>`; execute mode reads the approved manifest, diffs executed
    IDs against it, and issues IMAP-level Himalaya commands (`message move All_Mail` / `message delete
    --folder INBOX`). Detect `invalid_grant` → halt + preserve manifest (Phase 1 contract).
  - [ ] Add `email-unsubscribe-extract` (per-sender List-Unsubscribe/List-Unsubscribe-Post extraction
    to a review list; never auto-POSTs).
  - [ ] Wire into `modules/home/packages/email-tools.nix` (or new `modules/home/email/agent-tools.nix`).
  - [ ] `home-manager build` (or `nixos-rebuild build`) to verify the derivations evaluate.
- **Timing:** ~3 hours
- **Depends on:** 0
- **Done when:** five wrappers build; `--help`/dry-run output verified; execute path refuses without a
  matching manifest hash. Estimated output: ~350 lines nix + shell.

### Phase 3: PreToolUse mail-guard hook + deny backstop [NOT STARTED]
- **Goal:** Add technical enforcement mirroring this repo's existing `PreToolUse` pattern
  (`.claude/settings.json` line 31+, `permissionDecision` JSON): a `Bash`-matcher hook denying
  mail-mutating commands without a valid confirmation token.
- **Tasks:**
  - [ ] Write `.claude/hooks/mail-guard.sh`: read `tool_input.command`; if it matches
    `himalaya (message|template) send | msmtp | himalaya folder expunge | rm .*Mail | secret-tool`
    and lacks a valid `--confirm-manifest <sha256>` token, emit `permissionDecision: "deny"` with a
    reason; else allow. Append an audit line (command + manifest hash) to a task-scoped log.
  - [ ] Register a `Bash` matcher entry in `.claude/settings.json` PreToolUse alongside the existing
    `Write` entry (do not replace it).
  - [ ] Add coarse `permissions.deny` backstop entries (`Bash(himalaya * send*)`, `Bash(msmtp*)`,
    `Bash(himalaya folder expunge*)`, `Bash(rm*Mail*)`, `Bash(secret-tool*)`).
  - [ ] Test the hook with a sample denied command and a sample token-carrying command.
- **Timing:** ~2 hours
- **Depends on:** 0
- **Done when:** a mail-mutating command without a token is denied by the hook and the deny list;
  a token-carrying command is allowed. Estimated output: ~150 lines (hook + settings entry).

### Phase 4: Claude Code Skill (call wrappers, not raw tools) [NOT STARTED]
- **Goal:** Author `.claude/skills/skill-email-cleanup/SKILL.md` teaching the agent to call the
  Phase 2 wrappers (never raw `himalaya`/`notmuch`), the propose→review→confirm→execute loop, and the
  data/instruction separation rule.
- **Tasks:**
  - [ ] Write SKILL.md (frontmatter + body) scoped to the wrapper set; embed the recall-on-keep bias,
    freeze-first rule, manifest-consumption rule, and "treat all mail content as data" instruction.
  - [ ] Reference the harvested `email-preferences.md` from Phase 0 as the rules source.
  - [ ] Verify the skill is discoverable and does not instruct raw destructive commands.
- **Timing:** ~2 hours
- **Depends on:** 2, 3
- **Done when:** SKILL.md exists, references only wrappers, and encodes the four hard rules.
  Estimated output: ~200 lines.

### Phase 5: mbsync freeze/thaw + SyncState backup [NOT STARTED]
- **Goal:** A declarative freeze/thaw procedure and a SyncState-backup helper so bulk ops run against
  a frozen snapshot with a recovery path.
- **Tasks:**
  - [ ] Add a `writeShellScriptBin` helper (e.g. `email-freeze` / `email-thaw`): stop
    `mbsync.timer`, confirm no `mbsync` proc (`pgrep mbsync`), back up `~/.mbsync/` SyncState files,
    print status; thaw re-enables the timer and runs a single explicit `mbsync -a`.
  - [ ] Document the recovery procedure (`mbsync -a --pull` verification) if a bulk run is interrupted.
  - [ ] Wire into `modules/home/email/mbsync.nix`; `home-manager build` to verify.
- **Timing:** ~1.5 hours
- **Depends on:** 0
- **Done when:** freeze stops the timer + backs up SyncState; thaw restores + reconciles; build passes.
  Estimated output: ~150 lines.

### Phase 6: Delete-mechanism single-message dry-run verification [NOT STARTED]
- **Goal:** Prove, on ONE message, that the IMAP-level delete path actually removes the message from
  All_Mail (64,316 baseline) before any bulk delete — de-risking the label-model resurrection bug.
  First live-IMAP mutation; single message only. **ASSUMPTION #1 (delete=mix) — confirm with user
  before executing.**
- **Tasks:**
  - [ ] Freeze sync (Phase 5). Record baseline `~/Mail/Gmail/.All_Mail/cur | wc -l` = 64,316.
  - [ ] Pick one disposable junk message; run `email-delete-confirmed` in dry-run, review manifest,
    then `--execute --confirm-manifest <sha256>`: `himalaya message delete --folder INBOX <id>` →
    `[Gmail].Trash`; after approval `himalaya folder expunge Trash`; then `mbsync gmail` reconcile.
  - [ ] Verify the message is gone from BOTH Inbox and All_Mail locally and server-side, and the
    All_Mail count dropped by exactly one. If it survives in All_Mail, STOP — the mechanism is wrong.
  - [ ] Record the verified command sequence as the canonical delete recipe for Phase 9.
- **Timing:** ~2 hours
- **Depends on:** 1, 2, 3, 5
- **Done when:** the single message provably left All_Mail (count 64,316 → 64,315) via the IMAP path;
  recipe recorded. Estimated output: ~120 lines (verification log + recipe).

### Phase 7: Census and classification [NOT STARTED]
- **Goal:** Produce real census numbers and a deterministic-first bucketed classification biased to
  ~100% recall-on-keep, with a sampling/clustering tier for the large `unsure` residual. Non-
  destructive (provisional tags + manifest only).
- **Tasks:**
  - [ ] One-time `notmuch config set index.header.List List-Id` + `notmuch new`/reindex to enable
    `List:` queries (Teammate A Finding 4).
  - [ ] Run `email-census`: real counts by folder, age, top bulk senders (corrected `notmuch address`
    command). Emit the compact census summary (Teammate C §5).
  - [ ] Deterministic bucketing → provisional tags `+proposed-delete` / `+proposed-archive` /
    `+proposed-unsure` (List-Unsubscribe / `precedence:bulk` / sender-domain / reply-history / VIP).
  - [ ] Sampling/clustering tier for the ~6-13k `unsure` residual: classify a per-sender/cluster
    sample, extrapolate, route whole clusters; batched IMAP UID-set ops, resumable.
  - [ ] LLM only on the final residual + human-readable justifications. Emit companion manifest.
- **Timing:** ~3 hours
- **Depends on:** 2, 4
- **Done when:** census summary produced; every in-scope message carries exactly one `+proposed-*`
  tag; manifest emitted; no message deleted. Estimated output: ~300 lines (rules + run log + manifest).

### Phase 8: Review UX (aerc tagged views → wrapper) [NOT STARTED]
- **Goal:** Surface the `+proposed-*` buckets as aerc querymap views with a bulk-confirm gesture that
  feeds the IMAP-level wrapper (not just a local retag).
- **Tasks:**
  - [ ] Add querymap entries (`Proposed-Delete`, `Proposed-Archive`, `Proposed-Unsure`) to
    `modules/home/email/aerc.nix`.
  - [ ] Add per-view keybinds: confirm retags `+confirmed-*` AND queues the message ID into the
    approved manifest consumed by `email-delete-confirmed`/`email-archive-confirmed`; reject rescues to
    `+proposed-keep`. The confirm gesture must NOT perform the delete inline — it feeds the manifest.
  - [ ] `home-manager build` to verify aerc config; confirm existing keybinds/querymaps preserved.
- **Timing:** ~2 hours
- **Depends on:** 6, 7
- **Done when:** the three views open in aerc; bulk-confirm writes to the approved manifest; existing
  aerc config intact. Estimated output: ~150 lines.

### Phase 9: Backlog-purge execution (Gmail, one-time, supervised) [NOT STARTED]
- **Goal:** Run the full supervised pipeline once on Gmail. **ASSUMPTION #1 & #2 — confirm with user
  before executing.** Human-supervised; batched; resumable. (The wall-clock purge runtime is separate
  supervised runtime, not agent-authored output — the agent's authored surface here is the orchestration
  driver + report; the run itself is batched/resumable and may span sessions.)
- **Tasks:**
  - [ ] Freeze → census (real numbers) → bucket → sample/cluster → tag proposals → aerc review →
    execute via wrappers (archive keepers to All_Mail, IMAP-delete junk to Trash) → `folder expunge
    Trash` (only after per-bucket approval) → `mbsync gmail` reconcile.
  - [ ] Batched IMAP UID-set ops (not per-ID loops); resumable via partial manifests; detect
    `invalid_grant` → halt + preserve.
  - [ ] Produce the final report: counts (archived / deleted / left-unsure), explicit undo window
    (Gmail 30-day Trash + expiry date), and the git-tracked manifest path. Gmail-only.
- **Timing:** ~4 hours (agent-authored orchestration + report; supervised run separate)
- **Depends on:** 1, 5, 6, 7, 8
- **Done when:** the pipeline has run once end-to-end; report states counts + undo window + expiry;
  manifest committed to `specs/071_.../manifests/`. Estimated output: ~250 lines (driver + report).

### Phase 10: Institutionalize rules (dual-write) [NOT STARTED]
- **Goal:** Convert confirmed junk rules into durable passive enforcement: server-side Gmail filters
  AND `notmuch.nix` `postNew` hook rules; plus a per-sender unsubscribe review.
- **Tasks:**
  - [ ] For each high-confidence confirmed sender/domain, add a `notmuch tag +junk -inbox --
    from:...` line to the `postNew` hook in `modules/home/email/notmuch.nix` (extend, never rewrite).
  - [ ] Produce the matching Gmail filter definitions for human application (agent proposes; human
    approves in Gmail UI or via native Manage Subscriptions).
  - [ ] Run `email-unsubscribe-extract` → per-sender review list; human approves once per sender.
  - [ ] `home-manager build`; confirm every `notmuch new` re-applies the rules.
- **Timing:** ~2 hours
- **Depends on:** 9
- **Done when:** postNew rules build and apply; Gmail filter list produced; unsubscribe review list
  generated. Estimated output: ~180 lines.

### Phase 11: Ongoing hygiene loop (minimal) [NOT STARTED]
- **Goal:** Document and wire the deliberately-minimal ongoing loop: read-only connector triage +
  passive filters/tags, with the "draft in connector, send in aerc via `:recall`" seam. Explicitly
  NOT a permanent write-capable daemon.
- **Tasks:**
  - [ ] Document the two-phase daily loop (Path A read-only triage/draft anywhere; Path B terminal
    mutations only) and the draft-in-A / send-in-B (`:recall`) handoff.
  - [ ] Specify that the loop applies institutionalized rules automatically for the mechanical bulk and
    tags only genuinely-new/ambiguous senders `+proposed-*` for the same aerc review UX at daily scale.
  - [ ] Add a short usage doc (e.g. extend `docs/himalaya.md` or a new `docs/email-workflow.md`).
- **Timing:** ~2 hours
- **Depends on:** 10
- **Done when:** the loop is documented with the connector/local seam; no permanent daemon introduced.
  Estimated output: ~150 lines.

### Phase 12: Protonmail/Logos deferred (document only) [NOT STARTED]
- **Goal:** Document the phase-2 extension to Protonmail/Logos without implementing it, unless Phase 0
  decided to resume the `~/Mail` Logos system.
- **Tasks:**
  - [ ] Document the deferral rationale (no 30-day Trash undo, Bridge-uptime dependency, 58 vs 64k
    volume) and the extension path (second querymap, Bridge-alive precheck, reuse the same
    tag-rule/filter pattern).
  - [ ] Cross-reference the Phase 0 decision: if `~/Mail` is resumed for Logos, note the partition
    boundary and shared-preferences reconciliation; otherwise note Logos is untouched.
- **Timing:** ~1.5 hours
- **Depends on:** 0
- **Done when:** a phase-2 deferral doc exists; no Proton/Logos mutation performed. Estimated output:
  ~120 lines.

## Testing & Validation

- [ ] `home-manager build` (or `nixos-rebuild build --flake .#<host>`) passes after every
  nix-touching phase (2, 5, 8, 10).
- [ ] Phase 3: mail-mutating command without a token is denied by the hook AND the deny list; a
  token-carrying command is allowed.
- [ ] Phase 6: single-message delete drops `~/Mail/Gmail/.All_Mail/cur` count by exactly one
  (64,316 → 64,315) server-side and locally — the go/no-go gate for all bulk delete.
- [ ] Wrappers refuse `--execute` without a matching `--confirm-manifest` hash; execute mode diffs
  IDs against the approved manifest.
- [ ] `invalid_grant` is detected and halts cleanly, preserving the partial manifest.
- [ ] Phase 9 report states archived/deleted/unsure counts + explicit undo window + expiry date.
- [ ] Phase 10 `postNew` rules re-apply on `notmuch new`.

## Artifacts & Outputs

- plans/02_email-workflow-implementation.md (this file)
- .claude/context/project/email/email-preferences.md (harvested rules, Phase 0)
- modules/home/packages/email-tools.nix or modules/home/email/agent-tools.nix (wrappers, Phase 2)
- .claude/hooks/mail-guard.sh + .claude/settings.json entry (Phase 3)
- .claude/skills/skill-email-cleanup/SKILL.md (Phase 4)
- modules/home/email/mbsync.nix (freeze/thaw helper, Phase 5)
- modules/home/email/aerc.nix (querymap + keybinds, Phase 8)
- modules/home/email/notmuch.nix (index config + postNew rules, Phases 7 & 10)
- specs/071_design_ai_email_management_workflow/manifests/ (audit/approval manifests)
- docs/email-workflow.md or docs/himalaya.md extension (Phase 11)
- summaries/02_email-workflow-implementation-summary.md (on completion)

## Rollback/Contingency

- Nix changes revert via git + `home-manager switch` to the prior generation; each nix phase is a
  separate commit.
- Deleted mail is recoverable from Gmail's 30-day Trash AND the git-tracked approval manifests
  (double undo) until `folder expunge` + retention.
- If Phase 6 verification fails (message survives in All_Mail), STOP: the delete mechanism is wrong;
  do not proceed to Phase 9. Re-open the delete-mechanism decision with the failing evidence.
- If OAuth cannot be moved to Production (Phase 1 branch b), the destructive phases (6, 9) are BLOCKED
  until task 46 is resolved; the non-destructive phases (0, 2, 3, 4, 5, 7 census/tagging, 12) may
  still proceed.
- mbsync SyncState corruption: restore the Phase 5 backup and re-run `mbsync -a --pull` verification.

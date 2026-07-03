# Implementation Plan: Email Workflow Infrastructure & Prerequisites

- **Task**: 72 - Email workflow infrastructure prereqs (.dotfiles mechanism; child of task 71)
- **Status**: [COMPLETED]
- **Effort**: 18 hours
- **Dependencies**: Task 46 (Gmail OAuth2) — blocking ONLY for the destructive purge (~/Mail #29) and for server-side delete verification via `mbsync gmail`; NOT for this infra build (himalaya/aerc use working app passwords)
- **Research Inputs**: reports/02_team-research.md (primary), reports/01_infrastructure-prereqs-seed.md (seed; delete-invariant framing corrected by the team report)
- **Artifacts**: plans/02_email-infra-wrappers.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: general

## Overview

Build the `.dotfiles`-owned MECHANISM of the 3-repo split of task 71: five nix-declared,
dry-run-by-default wrapper binaries (`modules/home/email/agent-tools.nix`), a PreToolUse
mail-guard hook that allowlists only those binaries, mbsync freeze/thaw helpers, aerc review
querymaps whose confirm gestures route through the wrappers, and notmuch `postNew` junk-rule
scaffolding. This task covers v3 reference-plan phases 0, 1, 2, 5, 9, and 11-local; it does NOT
run the purge (~/Mail #29) and does NOT author the `email/` extension (nvim #803) — it produces
the two handoffs those tasks consume. Verification-first: the team report's blocking gaps (empty
notmuch index, untested two-hop delete path, census invocation) are resolved in Phase 1 before
any wrapper is written.

### Research Integration

- `reports/02_team-research.md` (round-2 team synthesis) — PRIMARY. All 4 resolved conflicts are
  encoded: (1) corrected delete invariant — Himalaya is `backend.type = "maildir"`, so safety
  comes from the two-step move-to-Trash-then-expunge sequence plus `mbsync gmail` server
  push-back, NOT a transport-layer "IMAP vs local" distinction; (2) the empty notmuch index is a
  blocking verify-first gap; (3) the `invalid_grant` fail-safe re-targets the `mbsync gmail`
  step, not the himalaya wrappers; (4) aerc native `d`/`D`/`a`/`A` bypass is decided explicitly
  in Phase 9. Verified plan bugs fixed: Phase 8 thaw uses group-scoped `mbsync gmail` (never
  `mbsync -a`); manifests key on the Message-ID header (never Himalaya's per-folder envelope id).
  Contract hardening baked in now: reserved `--account gmail` flag, per-ID execution-status
  companion state, ≥0.90 auto-delete confidence recommendation.
- `reports/01_infrastructure-prereqs-seed.md` — scope table (§1), shared invariants (§2, with
  invariant 2's framing corrected per above), and the handoff contract (§4).
- Planning-time live verification (this plan): `permissions.deny` has ZERO mail entries (hook
  phase ADDS them); `.claude/settings.json` PreToolUse currently matches only `Write` (the
  `Bash` matcher is new); there is NO mbsync systemd timer — mbsync runs via notmuch
  `preNew = "mbsync -a"`, aerc's `$` keybind (`:exec mbsync -a && notmuch new`), and manual
  invocation; `SyncState *` puts per-folder `.mbsyncstate` files inside `~/Mail/Gmail/`, not
  `~/.mbsync/`. The failing `preNew` (`mbsync -a` hits gmail XOAUTH2 `invalid_grant`) is the
  likely cause of the empty index — Phase 1 uses `notmuch new --no-hooks`.

### Prior Plan Reference

No prior plan exists for task 72. The task-71 v3 reference plan
(`specs/071_design_ai_email_management_workflow/plans/04_email-workflow-implementation.md`) was
used for structure, effort calibration, postmortem constraints, and the preserved-assets list —
with the team report's corrections applied (thaw scope bug, manifest key, OAuth call-site,
`permissions.deny` entries are additions not preservation). Its phases were not copied verbatim.

### Roadmap Alignment

`specs/ROADMAP.md` exists but currently contains no items ("No items yet"); no roadmap
alignment entries apply. This plan does not modify ROADMAP.md.

## Goals & Non-Goals

**Goals**:
- Five nix-declared wrapper binaries in a NEW `modules/home/email/agent-tools.nix`
  (`email-census`, `email-classify`, `email-archive-confirmed`, `email-delete-confirmed`,
  `email-unsubscribe-extract`), dry-run by default, mutation gated by
  `--execute --confirm-manifest <sha256>`, execute mode diffing executed IDs against the
  approved manifest (never re-deriving).
- A FROZEN wrapper contract (binary names, verbs, flags, JSONL manifest schema keyed on
  Message-ID, reserved `--account gmail`, per-ID execution-status companion state) written as a
  handoff before nvim #803 authors against it.
- PreToolUse `mail-guard.sh` hook allowlisting ONLY the 5 wrapper binaries; raw
  `himalaya message delete|move|send`, `himalaya folder expunge`, `msmtp`, `rm *Mail*`,
  `secret-tool` denied; NEW `permissions.deny` mail entries added (none exist today).
- mbsync freeze/thaw helpers with SyncState backup and group-scoped `mbsync gmail` thaw.
- aerc `Proposed-Delete/Archive/Unsure` querymaps with confirm keybinds that `:exec` the
  wrappers, plus an explicit recorded decision on the pre-existing `d`/`D`/`a`/`A` binds.
- notmuch `postNew` per-sender junk tag-rule scaffolding (minimal diff to the existing string).
- Prior-art harvest (data only) from `~/Mail/.claude` + retirement of its harness; two handoff
  documents (to nvim #803 and ~/Mail #29).

**Non-Goals**:
- Running the Gmail backlog purge or any bulk mutation (that is ~/Mail #29).
- Authoring the `email/` Claude Code extension, its skills/agents/manifest (that is nvim #803).
- Building a generic `confirmed-mutation-wrapper` framework (memory breadcrumb only).
- Resolving task 46 itself (OAuth is researched and gated, not necessarily fixed here).
- Protonmail/Logos support (Gmail-first; `--account` flag reserved but gmail-only).
- Populating real junk rules or Gmail server-side filters (scaffolding only; rules land via #29).

## Risks & Mitigations

- **Risk**: notmuch index stays empty because `preNew` (`mbsync -a`) fails on gmail XOAUTH2,
  aborting `notmuch new` — census/classify design built on a fiction.
  **Mitigation**: Phase 1 runs `notmuch new --no-hooks` and confirms the count against the
  Maildir before any wrapper work; blocking gate for Phases 5-6.
- **Risk**: Delete silently no-ops (Gmail label model; message survives in All Mail).
  **Mitigation**: Phase 1 tests the full two-hop path on ONE disposable message; if the
  `mbsync gmail` reconcile is blocked by `invalid_grant`, server-side verification is explicitly
  recorded as BLOCKED on task 46 in the #29 handoff — never assumed.
- **Risk**: Manifest keyed on Himalaya envelope ids becomes unusable the moment
  `email-delete-confirmed` moves messages (per-folder ids change on move); 3 repos then consume
  a broken contract.
  **Mitigation**: contract keys on the Message-ID header (Phase 4); envelope ids are resolved at
  execution time, never persisted as keys.
- **Risk**: Thaw or preNew runs `mbsync -a` and touches the deferred Logos/Bridge account
  mid-operation.
  **Mitigation**: freeze/thaw uses group-scoped `mbsync gmail` (verified plan bug fixed);
  freeze procedure documents `notmuch new --no-hooks` and the aerc `$` keybind hazard.
- **Risk**: A convenience path (or aerc itself) mutates mail outside the guardrail.
  **Mitigation**: allowlist hook + new `permissions.deny` entries (layer 1) + git-tracked nix
  wrapper source (layer 2); Phase 9 confirm keybinds `:exec` wrappers only; the human-operated
  `d`/`D`/`a`/`A` scope is decided and documented explicitly, not left silent.
- **Risk**: `--execute` re-run after an `invalid_grant` halt double-executes or corrupts the
  approved manifest hash.
  **Mitigation**: per-ID execution-status companion state file (pending|executed|failed) keeps
  the approved manifest bytes immutable and makes execute idempotent per Message-ID.
- **Risk**: "Publish OAuth app to Production" turns out to require a weeks-long restricted-scope
  security assessment, silently blocking #29's schedule.
  **Mitigation**: Phase 3 researches Google's actual requirements/timeline for
  `https://mail.google.com/` before any recommendation; the block, if declared, is written into
  the #29 handoff.
- **Risk**: nix build breakage from the new module.
  **Mitigation**: `home-manager build` / `nixos-rebuild build` after every nix-touching phase
  (5, 6, 8, 9, 10); each phase is a separate commit for cheap revert.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4, 8, 10 | 1, 2, 3 (P4); 1, 3 (P8); 1 (P10) |
| 3 | 5, 7 | 4 |
| 4 | 6 | 4, 5 |
| 5 | 9 | 4, 6, 7 |
| 6 | 11 | 2-10 |

Phases within the same wave can run in parallel (distinct file territory: P1 = live-system
verification, P2 = `~/Mail` + handoffs, P3 = OAuth research; P8 = `mbsync.nix`, P10 =
`notmuch.nix`, while P5/P6 own `agent-tools.nix` and P7 owns `.claude/`).

### Phase 1: Verification baseline (blocking gaps) [COMPLETED]

**Goal**: Resolve the team report's currently-false/unverified premises against the live system
before any wrapper is designed around them.

**Tasks**:
- [ ] Record the systemd unit inventory: confirm there is NO mbsync timer/service (planning-time
  check found only `gmail-oauth2-refresh.{timer,service}` — timer active, service failed
  `invalid_grant` — and `protonmail-bridge.service`); record mbsync's actual trigger paths
  (notmuch `preNew = "mbsync -a"`, aerc `$` keybind, manual) as input to Phase 8.
- [ ] Rebuild the notmuch index with `notmuch new --no-hooks` (bypasses the failing `preNew`);
  confirm `notmuch count '*'` ≈ 64,316 (matches
  `find ~/Mail -path '*/cur/*' -o -path '*/new/*' -type f | wc -l`) and
  `notmuch count tag:inbox` > 0. **Blocking for Phases 5-6.**
- [ ] Confirm the census invocation:
  `notmuch address --output=sender --output=count --deduplicate=address -- '*'`
  (bare form errors; the query term is required). Record exact working form for Phase 5.
- [ ] Locate the real SyncState files: `SyncState *` means per-folder `.mbsyncstate*` files
  inside `~/Mail/Gmail/` (NOT `~/.mbsync/`); enumerate with
  `find ~/Mail/Gmail -name '.mbsyncstate*'` and record the backup set for Phase 8.
- [ ] Empirically test the two-hop delete path on ONE disposable message:
  `himalaya message delete --folder INBOX <id>` (confirm it lands in `~/Mail/Gmail/.Trash`),
  `himalaya folder expunge Trash` (confirm local removal), then `mbsync gmail`. If the reconcile
  fails with `invalid_grant` (expected while task 46 is open), record the local half as verified
  and mark server-side All-Mail-removal verification BLOCKED on task 46 (feeds Phase 3 and the
  #29 handoff). If it succeeds, confirm the message left `[Gmail]/All Mail` server-side.

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `specs/072_email_workflow_infrastructure_prereqs/handoffs/verification-baseline.md` - new; recorded counts, working invocations, delete-path result

**Verification**:
- Index count recorded and ≈ Maildir file count; census command exits 0; delete-path result
  (full, or partial + blocked-on-46) written down with the exact command sequence used.

---

### Phase 2: Prior-art harvest + retire (~/Mail/.claude) [COMPLETED]

**Goal**: Harvest data-only assets from the dormant `~/Mail/.claude` system into the nvim #803
handoff, record the not-harvestable gap note, and retire the harness (v3 Phase 0 verdicts).

**Tasks**:
- [ ] HARVEST (data only) into
  `specs/072_email_workflow_infrastructure_prereqs/handoffs/email-preferences.md`: the
  `email-preferences.md` rule taxonomy + JSON schema; `MAX_BATCH_SIZE=50`
  (`email_execute.py:26`); `PLAN_EXPIRY_DAYS=7` (reused for manifest staleness); the
  confidence-threshold table with the recommendation tightened to **≥0.90 auto-delete**
  (everything below → `unsure`; the prior art's 0.70 caused churn); the 13 hand-added custom
  domain-delete rules; sender/domain keyword lists marked **keyword-fallback tier only**.
- [ ] Write the gap note in the same handoff: List-Unsubscribe, `precedence: bulk`,
  reply-history, and VIP-allowlist classification are **new work, not harvestable** (confirmed
  absent from prior art) — record as "gap, not omission" for #803.
- [ ] RETIRE the harness in the `~/Mail` repo (its own git): remove
  `~/Mail/.claude/commands/email.md`, `skills/skill-email/`, `agents/email-agent.md`, and all 5
  Python scripts (`email_list.py` 236, `email_analyze.py` 819, `email_triage.py` 745,
  `email_filter.py` 348, `email_execute.py` 417 lines); commit in `~/Mail` with a message
  pointing at this task and the handoff path. PRESERVE `~/Mail` the repo (maildir + specs
  history) untouched otherwise.
- [ ] Record DISCARD verdicts in the handoff: the checkbox-approval UX (`~/Mail` tasks
  014/022/023; superseded by aerc tagged-view + git manifest) and the retired command's
  `model: opus` pin (tiered policy applies).
- [ ] Note (Critic F6): the #72 → #803 coupling is documentation-only (nvim #803 declares no
  machine dependency); say so explicitly in the handoff header rather than implying enforcement.

**Timing**: 2 hours

**Depends on**: none

**Files to modify**:
- `specs/072_email_workflow_infrastructure_prereqs/handoffs/email-preferences.md` - new; harvested data + gap note + verdicts
- `~/Mail/.claude/` (separate repo) - harness removal commit

**Verification**:
- Handoff file contains all harvest-table items + the gap note; `~/Mail` commit removes exactly
  the RETIRE inventory; `email-preferences.md` content survives in the handoff.

---

### Phase 3: OAuth gate — research + fail-safe spec (re-targeted to mbsync) [COMPLETED]

**Goal**: Verify OAuth state, research Google's Production-verification requirements for the
restricted `mail.google.com` scope BEFORE recommending "publish to Production", and specify the
`invalid_grant` fail-safe against the `mbsync gmail` step (NOT the himalaya wrappers).

**Tasks**:
- [ ] Verify live state: `gmail-oauth2-refresh.service` failed (`invalid_grant`), consent screen
  in Testing mode per task 46 report; confirm `himalaya`/`aerc` use the working
  `gmail-app-password` keyring entry (so wrapper dry-runs and this whole build are NOT gated).
- [ ] Research (WebSearch) Google's actual requirements and timeline for publishing an OAuth app
  to Production with the **restricted** scope set (`https://mail.google.com/` + the
  contacts/calendar/carddav scopes listed in `docs/himalaya.md:198`): restricted-scope
  verification, possible CASA security assessment, expected duration. Do NOT recommend "publish
  to Production" without this.
- [ ] Record the decision branch: (a) publish to Production (documented steps + realistic
  timeline), or (b) declare task 46 a hard blocker for the ~/Mail #29 purge and for server-side
  delete verification. Either way this infra build proceeds.
- [ ] Specify the `invalid_grant` fail-safe CONTRACT (consumed by Phases 4/6/8): detection lives
  on the **`mbsync gmail`** reconcile step (the only XOAUTH2 consumer); on detection: halt
  cleanly, preserve the approved manifest and the execution-status companion file, print resume
  instructions. Himalaya wrapper calls do NOT check for `invalid_grant` (app-password path).

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `specs/072_email_workflow_infrastructure_prereqs/handoffs/oauth-gate.md` - new; decision record + fail-safe spec (later folded into the #29 handoff)

**Verification**:
- Decision branch recorded with cited Google documentation; fail-safe spec names `mbsync gmail`
  as the sole detection point; task-46 blocking scope stated (purge yes, build no).

---

### Phase 4: Freeze the wrapper contract (the #803/#29 handoff key) [COMPLETED]

**Goal**: Write and freeze the wrapper CONTRACT document that nvim #803 authors its extension
against and ~/Mail #29 runs against — hardened now, before three repos consume it.

**Tasks**:
- [ ] Write `specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md`:
  the 5-binary table (`email-census`, `email-classify`, `email-archive-confirmed`,
  `email-delete-confirmed`, `email-unsubscribe-extract`) with verbs and safety class
  (read-only / local-tags-only / mutation).
- [ ] Global flag contract: dry-run by default; mutation requires
  `--execute --confirm-manifest <sha256>` (sha256 over raw manifest bytes, recomputed and
  refused on mismatch); **`--account gmail`** reserved on all 5 signatures (default and sole
  accepted value; any other value errors); positive `--execute` (never `--no-dry-run`).
- [ ] Manifest schema (JSONL, one object per line) **keyed on the Message-ID header**:
  `message_id, sender, subject, date, proposed_action (delete|archive|unsure|keep), reason,
  confidence`. Himalaya envelope ids are per-folder and change on move — they may appear as
  auxiliary debug fields but are NEVER keys and never persisted across steps; execute mode
  resolves current envelope id from Message-ID at run time.
- [ ] Companion execution-state file (`<manifest>.state.jsonl`): per-Message-ID
  `status (pending|executed|failed), timestamp, error` — approved manifest bytes stay immutable
  (hash stays valid) and `--execute` is safely re-runnable after an `invalid_grant` halt.
- [ ] Constants and policies: `MAX_BATCH_SIZE=50`; manifest staleness `PLAN_EXPIRY_DAYS=7`;
  confidence ≥0.90 for auto-delete proposals (below → `unsure`); execute mode **diffs executed
  IDs against the approved manifest, never re-derives**.
- [ ] Approval provenance: the aerc review gesture writes a NEW approved manifest of
  `+confirmed-*` Message-IDs; mutation wrappers consume ONLY approved manifests (never
  `email-classify` raw output). Manifest storage: git-tracked
  `specs/072_email_workflow_infrastructure_prereqs/manifests/` (override via
  `EMAIL_MANIFEST_DIR`).
- [ ] Document the corrected delete invariant (two-step move-to-Trash-then-expunge +
  `mbsync gmail` push-back; Himalaya backend is maildir — safety is the sequence, not the
  transport) and the **two-layer enforcement model** (PreToolUse hook gates the agent's
  top-level Bash calls; the git-tracked, nix-built wrapper source is the second layer).
- [ ] Fold in the Phase 3 `invalid_grant` fail-safe contract; note the correct read verb is
  `himalaya envelope list -o json` (`message list` does not exist in v1.2.0).

**Timing**: 1.5 hours

**Depends on**: 1, 2, 3

**Files to modify**:
- `specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md` - new; the frozen contract

**Verification**:
- Contract covers all five binaries, both hardening seams (`--account`, execution-state), the
  Message-ID key rule, staleness/batch/confidence constants, approval provenance, and the
  two-layer model — reviewed against the team report's Recommendations section line by line.

---

### Phase 5: agent-tools.nix — module scaffold + read-only wrappers [COMPLETED]

**Goal**: Create the NEW `modules/home/email/agent-tools.nix` with the shared `let`-bound
preamble string and the three non-mutating wrappers, and wire it into home-manager.

**Tasks**:
- [x] Create `modules/home/email/agent-tools.nix` with a Nix `let`-bound **preamble STRING
  interpolated** into each `writeShellScriptBin` (NOT a `source`d external lib) — each produced
  binary stays self-contained, which the mail-guard hook's allowlist-by-binary relies on.
  Preamble: arg parsing, `--account gmail` validation (reject anything else), manifest-dir
  resolution (`EMAIL_MANIFEST_DIR` default per contract), common logging. *(completed:
  `mkPreamble`/`mkMutationPreamble` nix functions, interpolated per binary)*
- [x] `email-census` (read-only): sender census via the Phase-1-verified
  `notmuch address --output=sender --output=count --deduplicate=address -- '*'`, folder/date
  bucket counts, `himalaya envelope list -o json` sampling (never `message list`). *(completed;
  live-verified: INBOX 2950, All_Mail 64785, sender census + date buckets + envelope sample all
  exit 0)*
- [x] `email-classify` (local tags only): deterministic rule scaffolding → provisional
  `+proposed-{delete,archive,unsure}` notmuch tags; emits a candidate JSONL manifest keyed on
  Message-ID with `confidence`; enforces `MAX_BATCH_SIZE=50`; also provides the
  `--append-approved` mode (writes a Message-ID line into the approved manifest — the
  allowlisted target for the Phase 9 aerc confirm gesture). Never mutates maildir/IMAP state.
  *(completed: tier-1 harvested custom rules + tier-2 keyword-fallback + >=0.90 delete
  confidence downgrade; live-verified on `folder:Gmail/.Trash --limit 5`, valid JSONL, tags
  applied and cleaned up)*
- [x] `email-unsubscribe-extract` (read-only): per-sender `List-Unsubscribe` header extraction
  to a review list; NEVER fetches or POSTs the URLs (reference `planetaryescape/list-unsubscribe`
  / RFC 8058 in a comment; do not hand-roll one-click semantics here). *(completed; live-verified
  against 8 real List-Unsubscribe/List-Unsubscribe-Post headers including RFC-2822 header
  folding)*
- [x] Import the module from the home-manager email module set (alongside
  `mbsync/notmuch/aerc/protonmail.nix`). *(completed: added to `home.nix` imports list)*
- [x] `home-manager build` (or `nixos-rebuild build`) passes; each binary's `--help` and dry-run
  output verified against the contract. *(completed: `home-manager build --flake .#benjamin`
  green; `--account logos` rejected)*

**Timing**: 2 hours

**Depends on**: 4

**Files to modify**:
- `modules/home/email/agent-tools.nix` - new; preamble + 3 read-only wrappers
- home-manager module imports (e.g., `modules/home/default.nix` or equivalent import list) - add agent-tools.nix

**Verification**:
- Build passes; `email-census`/`email-unsubscribe-extract` produce output on the live index;
  `email-classify` dry-run emits a valid JSONL manifest keyed on Message-ID; `--account logos`
  is rejected.

---

### Phase 6: agent-tools.nix — mutation wrappers + execution-state machinery [COMPLETED]

**Goal**: Add `email-archive-confirmed` and `email-delete-confirmed` with the full mutation
preamble: manifest hash verification, staleness/batch checks, Message-ID → envelope-id
resolution, execution-state companion file, and the mbsync-side `invalid_grant` fail-safe.

**Tasks**:
- [x] `mutationPreamble` (interpolated string extending the base preamble): dry-run default with
  a loud banner; `--execute` requires `--confirm-manifest <sha256>`; recompute sha256 over the
  raw approved-manifest bytes and refuse on mismatch; refuse manifests older than
  `PLAN_EXPIRY_DAYS=7`; enforce `MAX_BATCH_SIZE=50` per run; initialize/update the
  `<manifest>.state.jsonl` companion (skip `executed` IDs — idempotent re-run; mark `failed`
  with error text). *(completed: `mkMutationPreamble`; all four refusal paths live-verified —
  no `--confirm-manifest`, wrong hash, 10-day-stale manifest, 51-ID over-batch)*
- [x] Execute mode consumes ONLY the approved manifest and **diffs executed IDs against it**
  (never re-derives a target list); per Message-ID, resolve the CURRENT envelope id in the
  relevant folder at run time (notmuch `id:` lookup → file path → folder, then
  `himalaya envelope list -f <folder>` match), since envelope ids change on move. *(completed:
  `resolve_envelope_id`/`resolve_folder_from_path`; live-verified end-to-end against the Phase-1
  disposable test message — correctly resolved envelope 1014 in folder All_Mail via a
  subject-narrowed `envelope list` query verified against `message read -p -H Message-Id`,
  which is preview-mode and never marks Seen)*
- [x] `email-archive-confirmed`: for each approved `archive` ID, move to the all-mail folder
  (`himalaya message move` to `[Gmail].All Mail` alias) — dry-run prints the plan. *(completed:
  `himalaya message move All_Mail <id> -f <folder>`; dry-run "no approved IDs" path
  live-verified)*
- [x] `email-delete-confirmed`: for each approved `delete` ID, `himalaya message delete`
  (soft-move to `[Gmail].Trash`); the Trash expunge is a SEPARATE explicit invocation
  (`--expunge-trash`, also requiring `--execute --confirm-manifest`) so move and expunge are
  independently human-gated; after mutation, print the required `mbsync gmail` reconcile step
  with the `invalid_grant` fail-safe (detect in mbsync output → halt, preserve manifest + state
  file, print resume instructions — per Phase 3 contract). *(completed: hop 1/hop 2 use
  independent companion state files (`.state.jsonl` / `.expunge-state.jsonl`) so each
  `--execute --confirm-manifest` invocation is idempotent per hop; `run_mbsync_reconcile`
  matches both `invalid_grant` and `[AUTHENTICATIONFAILED]`; dry-run plans for both hops
  live-verified, including hop-2 correctly gating on hop-1's state)*
- [x] `home-manager build` passes; refusal paths exercised (no `--execute`; wrong hash; stale
  manifest; over-batch). *(completed: all live-verified above; skip-already-executed also
  verified by seeding state.jsonl and confirming no himalaya call was made)*

**Timing**: 2 hours

**Depends on**: 4, 5

**Files to modify**:
- `modules/home/email/agent-tools.nix` - add mutationPreamble + 2 mutation wrappers

**Verification**:
- Both wrappers refuse to mutate without `--execute` + matching `--confirm-manifest`; hash
  mismatch and >7-day staleness rejected; dry-run prints per-ID plan; state file marks
  executed/failed; re-run skips `executed` IDs.

---

### Phase 7: PreToolUse mail-guard hook + permissions.deny entries [COMPLETED]

**Goal**: Add the agent-side enforcement layer in this repo: a `Bash`-matcher PreToolUse hook
allowlisting ONLY the 5 wrapper binaries and denying raw mail mutations, plus NEW
`permissions.deny` backstop entries (there are currently ZERO mail entries — this adds, it does
not preserve).

**Tasks**:
- [x] Write `.claude/hooks/mail-guard.sh` (follow the stdin-JSON parsing pattern of
  `validate-meta-write.sh`): read `tool_input.command`; ALLOW if it invokes one of
  `email-census|email-classify|email-archive-confirmed|email-delete-confirmed|email-unsubscribe-extract`;
  DENY (`permissionDecision: "deny"` + reason) on `himalaya message (delete|move|send)`,
  `himalaya folder expunge`, `himalaya template send`, `msmtp`, `rm` targeting `*Mail*`, and
  `secret-tool`; non-mail commands pass through (`{}` / allow). Keep the allowlist and deny
  patterns as **clean isolated data arrays** at the top of the script (liftable
  safety-envelope pattern — Teammate D), and append an audit line (command + manifest hash if
  present) to a task-scoped log. *(completed: `ALLOWED_BINARIES`/`DENY_PATTERNS` arrays;
  audit log at `.claude/tmp/mail-guard-audit.log`, tab-separated timestamp/decision/hash/command)*
- [x] Register the `Bash` PreToolUse matcher in `.claude/settings.json` alongside the existing
  `Write` matcher (do not replace it). *(completed: Write matcher preserved as first entry,
  new Bash entry appended)*
- [x] ADD `permissions.deny` entries: `Bash(himalaya message delete*)`,
  `Bash(himalaya message move*)`, `Bash(himalaya * send*)`, `Bash(himalaya folder expunge*)`,
  `Bash(msmtp*)`, `Bash(secret-tool*)`, `Bash(rm *Mail*)`. *(completed: all 7 appended after
  the pre-existing 4 non-mail entries)*
- [x] Document the **two-layer enforcement model** in the hook header and the #803 handoff: the
  hook gates only the agent's own top-level Bash calls (not wrapper subprocesses); the
  git-tracked nix wrapper source is layer 2. Note that nvim #803 packages the same
  allowlist/deny DATA for consuming repos — keep the data block copy-liftable. *(completed in
  hook header comment; #803 handoff finalized in Phase 11)*
- [x] Test by piping synthetic PreToolUse JSON: raw `himalaya message delete ...` → deny;
  `himalaya message move ...` → deny; `himalaya folder expunge ...` → deny; `msmtp ...` → deny;
  `secret-tool lookup ...` → deny; `email-delete-confirmed --execute ...` → allow;
  an unrelated `git status` → pass-through. *(completed: all 7 cases + `himalaya message send`
  and `rm -rf ~/Mail/...` live-verified with correct permissionDecision; `jq . .claude/settings.json`
  parses)*

**Timing**: 1.5 hours

**Depends on**: 4

**Files to modify**:
- `.claude/hooks/mail-guard.sh` - new; allowlist/deny hook with isolated data block
- `.claude/settings.json` - add PreToolUse Bash matcher + permissions.deny mail entries

**Verification**:
- All deny/allow/pass-through stdin tests produce the expected `permissionDecision`; settings
  JSON still parses (`jq . .claude/settings.json`); existing Write matcher untouched.

---

### Phase 8: mbsync freeze/thaw + SyncState backup (group-scoped) [COMPLETED]

**Goal**: Declarative freeze/thaw helpers with the verified corrections: there is no mbsync
timer to stop; thaw reconciles with group-scoped `mbsync gmail`, never `mbsync -a`.

**Tasks**:
- [x] Add `email-freeze` / `email-thaw` as `writeShellScriptBin` helpers in
  `modules/home/email/mbsync.nix` (operator helpers, NOT part of the 5-binary agent contract;
  separate file territory from agent-tools.nix so this phase can run parallel to 5/6).
  *(completed)*
- [x] `email-freeze`: confirm no running sync (`pgrep -x mbsync`); note there is NO
  `mbsync.timer` (Phase 1 inventory) — instead print/enforce the trigger-path guards: during
  freeze, `notmuch new` must be run with `--no-hooks` (the `preNew` hook is `mbsync -a`) and the
  aerc `$` keybind (`mbsync -a && notmuch new`) must not be used; back up all
  `~/Mail/Gmail/**/.mbsyncstate*` files (Phase 1 enumerated set) to a timestamped tarball under
  `~/Mail/.syncstate-backups/`. *(completed; live-verified: correctly refuses when a
  process named `mbsync` is running, backup tarball diffed byte-identical against the 8
  live-enumerated `.mbsyncstate*` files)*
- [x] `email-thaw`: verify/restore path documented; reconcile with a single **`mbsync gmail`**
  (group-scoped — NEVER `mbsync -a`, which would touch the deferred Logos/Bridge account);
  apply the Phase 3 `invalid_grant` fail-safe (halt + preserve + instructions). *(completed;
  grep of the built binary confirms zero `mbsync -a` occurrences)*
- [x] Document the interrupted-run recovery procedure (restore SyncState backup, re-run
  `mbsync gmail`, then `notmuch new --no-hooks`) in the script `--help` and the #29 handoff.
  *(completed in script; #29 handoff finalized in Phase 11)*
- [x] `home-manager build` passes. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1, 3

**Files to modify**:
- `modules/home/email/mbsync.nix` - add freeze/thaw writeShellScriptBin helpers

**Verification**:
- Build passes; `email-freeze` detects a running mbsync (test with a sleep-wrapped fake);
  backup tarball contains every enumerated `.mbsyncstate*` file; thaw script contains no
  `mbsync -a` anywhere (grep the built binary).

---

### Phase 9: aerc review querymap + wrapper-routed confirm keybinds [COMPLETED]

**Goal**: Surface the `+proposed-*` buckets as aerc querymap views whose confirm gestures
`:exec` the wrapper binaries (never aerc's native `:delete-message`/`:archive`), and settle the
pre-existing native-keybind question explicitly.

**Tasks**:
- [x] Add querymap entries to the `querymap-gmail` block in `modules/home/email/aerc.nix`:
  `Proposed-Delete=tag:proposed-delete AND tag:gmail`, `Proposed-Archive=...`,
  `Proposed-Unsure=...` (preserve all existing entries). *(completed; live-verified in the
  built querymap-gmail file: all 8 pre-existing entries + 3 new ones present)*
- [x] Add per-view confirm/reject keybinds (folder-scoped `messages:folder=Proposed-*`
  sections): confirm retags `+confirmed-{delete,archive}` `-proposed-*` AND `:exec`s
  `email-classify --append-approved <...>` to queue the Message-ID into the approved manifest;
  reject rescues to `+proposed-keep`. The gesture MUST NOT perform the mutation inline and MUST
  NOT use native `:delete-message`/`:archive` (they run inside aerc's Go worker and bypass the
  hook + manifest flow entirely — CONFLICT 4). *(completed: uses `{{.MessageId}}` templating
  per aerc-templates(7), matching the documented `:term b4 am {{.MessageId}}` pattern; grep of
  the built binds.conf's 3 new sections confirms zero `:delete-message`/`:archive`)*
- [x] **DECIDE the pre-existing `d`/`D`/`a`/`A` scope explicitly** (silence is the gap).
  Recommended default: KEEP them as human-only paths and DOCUMENT that human-operated aerc
  deletes remain outside the agent guardrail by design (the PreToolUse hook can only gate agent
  Bash calls); harden `D` (bare `:delete`) and `A` (bulk archive) with a `:prompt` confirm.
  Record the decision + rationale in the #29 handoff. If the user instead wants them routed
  through wrappers, rebind to `:exec` equivalents — but record the trade-off (loses aerc-native
  UX). *(completed: DECIDED — kept human-only, recorded inline in aerc.nix; carried to the #29
  handoff in Phase 11; D and A now :prompt-confirm)*
- [x] Note and decide the `$` keybind (`:exec mbsync -a && notmuch new`): another `mbsync -a`
  blast-radius instance; recommend rebinding to `mbsync gmail && notmuch new --no-hooks` or
  documenting it as forbidden during freeze. Record the decision. *(completed: DECIDED —
  rebound to `mbsync gmail && notmuch new --no-hooks`, live-verified in the built binds.conf)*
- [x] Keybind-collision check: new bindings are aerc-internal; confirm nothing added here (or in
  the handoffs) shadows the nvim Himalaya plugin's `<leader>me/mS/mf`. *(completed: trivially
  clear — aerc's binds.conf and Neovim's `<leader>` keymaps are disjoint namespaces in separate
  applications; this task does not touch Neovim config)*
- [x] `home-manager build` passes; existing querymaps/binds preserved. *(completed: build
  green; built binds.conf has 10 `[...]` sections — 7 pre-existing + 3 new Proposed-* folder
  sections; all pre-existing keys preserved)*

**Timing**: 2 hours

**Depends on**: 4, 6, 7

**Files to modify**:
- `modules/home/email/aerc.nix` - querymap entries + folder-scoped confirm/reject keybinds (+ decided changes to d/D/a/A/$)

**Verification**:
- Three `Proposed-*` views open in aerc against the live index; confirm keybind text `:exec`s a
  wrapper (grep the generated config — zero native `:delete-message`/`:archive` in the new
  binds); `d/D/a/A` and `$` decisions recorded in writing; build passes.

---

### Phase 10: notmuch postNew junk-rule scaffolding [COMPLETED]

**Goal**: Append the per-sender junk tag-rule scaffolding to the EXISTING `postNew` string in
`notmuch.nix` (minimal diff, single ownership), with `afew` recorded as considered-and-rejected.

**Tasks**:
- [x] Append a clearly-delimited managed block to the existing `postNew` string in
  `modules/home/email/notmuch.nix` (extend, never rewrite):
  `# --- per-sender junk rules (managed: task 72 scaffold; populated via ~/Mail #29) ---`
  with one commented example rule
  (`# notmuch tag +junk -inbox -- from:sender@example.test`) and a pointer to the wrapper
  contract. No live rules land in this task. *(completed; git diff confirms append-only)*
- [x] Record `afew` as considered-and-rejected (second config surface; tagging stays in
  `notmuch.nix` `postNew`) — comment in the file + note in the #803 handoff. *(completed inline;
  #803 handoff finalized in Phase 11)*
- [x] `home-manager build` passes; run `notmuch new --no-hooks` then manually exercise the
  postNew content once to confirm the block is syntactically sound. *(completed with a
  deliberate deviation: build green and `bash -n` on the built post-new script confirms clean
  syntax; the FULL hook was NOT executed live because the live index currently has 67,466
  messages carrying `tag:new` (Phase 1's documented backfill artifact) and 0 carrying
  `tag:inbox` — running the unmodified pre-existing `notmuch tag +inbox +unread -- tag:new`
  line would bulk-retag the entire mailbox, which is an explicitly out-of-scope live bulk
  mutation for this task. The appended block itself is 100% comments (zero executable lines),
  so its syntactic soundness is additionally trivial by inspection.)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `modules/home/email/notmuch.nix` - append managed scaffold block to postNew

**Verification**:
- Diff to `notmuch.nix` touches only the `postNew` string (minimal-diff check); build passes;
  the hook body executes without error on the live index.

---

### Phase 11: Handoff assembly, docs, and memory breadcrumb [COMPLETED]

**Goal**: Assemble the two final handoffs (nvim #803, ~/Mail #29) from the as-built reality,
update repo docs, and leave the memory-candidate breadcrumb.

**Tasks**:
- [x] Finalize the **nvim #803 handoff** (`handoffs/email-preferences.md` +
  `handoffs/wrapper-contract.md`, updated to as-built): harvested data, gap note, the FROZEN
  contract (binary names, verbs, safety flags, Message-ID-keyed manifest schema, reserved
  `--account`, execution-state field), the two-layer enforcement model, the liftable
  allowlist/deny data block, and a `$PATH` precondition check requirement (extension must fail
  actionably when the wrapper binaries aren't built — Teammate D). *(completed:
  wrapper-contract.md §10 "AS-BUILT ADDENDUM" added, appending rather than rewriting the
  frozen §1-9; email-preferences.md unchanged from Phase 2, already complete)*
- [x] Write the **~/Mail #29 handoff**
  (`specs/072_email_workflow_infrastructure_prereqs/handoffs/mail-29-runbook.md`): the built
  binaries on `$PATH`, OAuth status (stable, or the declared task-46 block from Phase 3 —
  including whether server-side delete verification completed or remains blocked), the
  freeze/thaw + SyncState-recovery procedure, the aerc review flow (querymaps + confirm
  gestures + the recorded `d/D/a/A`/`$` decisions), the manifest directory + approval
  provenance, and the verified (or partially verified) delete recipe from Phase 1.
  *(completed: new file, all 7 sections present)*
- [x] State in BOTH handoffs that cross-repo ordering is documentation-only (no machine-enforced
  dependency; Critic F6). *(completed: wrapper-contract.md §10 preamble and
  mail-29-runbook.md's header both state it explicitly; email-preferences.md already had it
  from Phase 2)*
- [x] Update `docs/himalaya.md` (or add a short `docs/email-workflow.md`) describing the wrapper
  mechanism, dry-run/confirm flow, and the mail-guard hook; fix any `himalaya message list`
  references to `envelope list`. *(completed: new `docs/email-workflow.md` covers the
  mechanism/flow/hook; `docs/himalaya.md`'s two `message list` references fixed to
  `envelope list`; the one remaining repo-wide match is in
  `specs/archive/045_.../plans/01_aerc-notmuch-setup.md`, an archived historical artifact
  intentionally left untouched)*
- [x] Leave the memory-candidate breadcrumb for a future generic `confirmed-mutation-wrapper`
  pattern (dry-run default + sha256-confirmed manifest + allowlist hook + execution-state
  replay) — breadcrumb only; do NOT build the framework. *(completed: recorded in
  mail-29-runbook.md §7 and emitted as a memory_candidate in this agent's metadata; no
  framework built)*
- [x] Run the full Testing & Validation checklist; commit per-phase work per git-workflow rules.
  *(completed — see checklist below)*

**Timing**: 1.5 hours

**Depends on**: 2, 3, 4, 5, 6, 7, 8, 9, 10

**Files to modify**:
- `specs/072_email_workflow_infrastructure_prereqs/handoffs/mail-29-runbook.md` - new
- `specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md` - update to as-built
- `docs/himalaya.md` (or new `docs/email-workflow.md`) - wrapper mechanism docs

**Verification**:
- Both handoffs complete against the seed §4 contract table; docs updated; breadcrumb recorded;
  full checklist below passes.

## Testing & Validation

- [x] `home-manager build` / `nixos-rebuild build` succeeds with `agent-tools.nix` wired in, and
  again after each nix-touching phase (5, 6, 8, 9, 10). *(verified after every nix-touching
  phase in this dispatch; final `home-manager build --flake .#benjamin` green)*
- [x] notmuch index count matches the Maildir after `notmuch new --no-hooks` (≈ 64,316); the
  verified census invocation exits 0. *(index count 67,466 as of this dispatch — grew from
  Phase 1's baseline as new mail arrived; still consistent with the Maildir; census invocation
  exits 0, live-verified)*
- [x] Two-hop delete path tested on ONE disposable message; server-side removal from
  `[Gmail]/All Mail` confirmed, OR explicitly recorded as BLOCKED on task 46 in the #29 handoff.
  *(inherited from Phase 1, not re-run here per the explicit no-live-mutation constraint on
  this dispatch: local move-to-Trash hop VERIFIED; INBOX-label removal propagated server-side
  on app-password; the final \Deleted-flag+expunge hop was deliberately deferred to an
  interactive/human confirmation, per verification-baseline.md §6/§6a — recorded, not faked)*
- [x] Each mutation wrapper refuses to mutate without `--execute` + a matching
  `--confirm-manifest <sha256>`; hash mismatch rejected; manifests older than 7 days rejected;
  `MAX_BATCH_SIZE=50` enforced; `--account` accepts only `gmail`. *(all five live-verified in
  Phase 6 against a synthetic manifest built from the Phase 1 disposable test message)*
- [x] Execute mode diffs executed IDs against the approved manifest (never re-derives); the
  execution-state companion file makes re-runs skip `executed` IDs (idempotent after a halt).
  *(live-verified: seeded state.jsonl with status=executed, confirmed the wrapper printed SKIP
  and made no himalaya call)*
- [x] `mail-guard.sh` fed raw `himalaya message delete ...` on stdin returns
  `permissionDecision: deny`; same for `message move`, `folder expunge`, `msmtp`,
  `secret-tool`; fed `email-delete-confirmed ...` returns allow; unrelated commands pass
  through; `permissions.deny` gained the seven mail entries. *(all live-verified in Phase 7,
  plus `himalaya message send` and `rm *Mail*`)*
- [x] aerc: `Proposed-Delete/Archive/Unsure` views open; confirm keybinds `:exec` wrappers only
  (zero native `:delete-message`/`:archive` in new binds); `d/D/a/A` and `$` decisions recorded;
  no shadowing of `<leader>me/mS/mf`. *(built binds.conf inspected directly in Phase 9; three
  new folder-scoped sections present with zero native mutation commands; d/D/a/A/$ verified in
  the built base [messages] section)*
- [x] Thaw and freeze scripts contain `mbsync gmail` and no `mbsync -a`; SyncState backup covers
  every enumerated `.mbsyncstate*` file. *(live-verified: grep of the built thaw binary shows
  zero `mbsync -a` occurrences; the freeze backup tarball diffed byte-identical against the 8
  live-enumerated files)*
- [x] `notmuch.nix` diff is minimal (managed block appended to postNew only). *(git diff
  confirms append-only)*
- [x] Both handoff documents exist and state the documentation-only cross-repo ordering; memory
  breadcrumb emitted. *(wrapper-contract.md + mail-29-runbook.md both present and state it;
  breadcrumb recorded in mail-29-runbook.md §7 and as a memory_candidate)*

## Artifacts & Outputs

Nix-owned (this repo):
- `modules/home/email/agent-tools.nix` — NEW: preamble + 5 wrapper binaries (Phases 5-6)
- `modules/home/email/mbsync.nix` — freeze/thaw helpers added (Phase 8)
- `modules/home/email/aerc.nix` — Proposed-* querymaps + wrapper-routed keybinds (Phase 9)
- `modules/home/email/notmuch.nix` — postNew managed scaffold block (Phase 10)

Agent-system (this repo):
- `.claude/hooks/mail-guard.sh` — NEW allowlist/deny hook (Phase 7)
- `.claude/settings.json` — PreToolUse Bash matcher + NEW permissions.deny mail entries (Phase 7)

Handoffs (the two deliverables this task PRODUCES):
- **To nvim #803**: `specs/072_email_workflow_infrastructure_prereqs/handoffs/email-preferences.md`
  (harvested data + gap note, Phase 2) and `.../handoffs/wrapper-contract.md` (the FROZEN
  contract: binary names, verbs, safety flags, Message-ID-keyed JSONL manifest schema, reserved
  `--account gmail`, execution-status field, two-layer enforcement, liftable allowlist data;
  Phases 4 + 11)
- **To ~/Mail #29**: `.../handoffs/mail-29-runbook.md` (built binaries on `$PATH`, stable OAuth
  or declared task-46 block, freeze/thaw + recovery procedure, aerc review flow + recorded
  keybind decisions, manifest/approval provenance, verified delete recipe; Phase 11)

Task-scoped:
- `specs/072_email_workflow_infrastructure_prereqs/handoffs/verification-baseline.md` (Phase 1)
- `specs/072_email_workflow_infrastructure_prereqs/handoffs/oauth-gate.md` (Phase 3)
- `specs/072_email_workflow_infrastructure_prereqs/manifests/` (git-tracked manifest directory)
- `docs/himalaya.md` update or `docs/email-workflow.md` (Phase 11)
- `~/Mail` repo: harness-retirement commit (Phase 2)
- `plans/02_email-infra-wrappers.md` (this file); `summaries/02_*-summary.md` on completion

## Rollback/Contingency

- Nix changes revert via git + `home-manager switch` to the prior generation; each nix phase is
  a separate commit (Phases 5, 6, 8, 9, 10 individually revertible).
- Hook removal = delete the `Bash` PreToolUse matcher entry + `.claude/hooks/mail-guard.sh` +
  the added `permissions.deny` lines (all in one Phase 7 commit; revert restores today's
  zero-mail-entry state).
- The `~/Mail` harness retirement is a single commit in `~/Mail`'s own git — revertible there;
  the harvested data additionally survives in this repo's handoff file.
- If Phase 1's index rebuild fails (count mismatch) or the local delete path misbehaves, STOP:
  do not proceed to Phases 5-6; re-open the mechanism with the failing evidence.
- If the `mbsync gmail` reconcile is blocked by `invalid_grant` (task 46), everything in this
  task still completes EXCEPT server-side delete verification — record the block in the #29
  handoff and mark that verification item as a #29 precondition; do not fake it locally.
- No bulk mutation exists in this task; the only live-mail operation is the Phase 1
  single-disposable-message test, recoverable from Gmail's 30-day Trash.

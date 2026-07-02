# Research Report: Task #71 — AI-Assisted Email Management Workflow

**Task**: 71 — Design AI-assisted email management workflow
**Date**: 2026-07-02
**Mode**: Team Research (4 teammates: A-Tools, B-Security, C-UX, D-Critic/Integration)
**Session**: sess_1783019173_bf51f6
**Builds on**: seed report `01_ai-email-workflow.md`
**Teammate findings**: `02_teammate-{a,b,c,d}-findings.md`

---

## Summary

The team validated the seed report's core architecture (two access paths: read-only Anthropic
Gmail connector for triage/draft, local Himalaya/notmuch/mbsync stack for all destructive work)
and then materially sharpened it with **live, on-machine verification**. Three discoveries
change the plan:

1. **A dormant prior-art email-agent system already exists** in `~/Mail` — a *separate git repo*
   with its own `.claude/` install, 28 completed tasks (Feb 2026), Python/Himalaya wrappers, a
   preference-rules file, batch-limiting, and a checkbox plan-approval UX. It was built for the
   **Protonmail/Logos** account and abandoned mid-cleanup. Task 71 must **reconcile** (resume /
   retire / partition) with it before building anything — otherwise we ship a *second*
   uncoordinated agent with write access to the same mailbox.
2. **The seed's "tag it, then Expunge Both" delete mechanism is a correctness bug for Gmail.**
   Gmail exposes one message via multiple IMAP labels/channels (`gmail-inbox` → 2,301 local msgs;
   `gmail-all` → **64,316** local msgs). Removing/expunging the INBOX-channel file only strips the
   Inbox label — the message survives in All Mail, locally and server-side. **True delete requires
   an IMAP-level command against the live account.** Teammate A confirms the fix is already
   built into Himalaya: `himalaya message delete` moves to Trash (soft), and only `folder expunge`
   truly deletes. So the mechanism is "Himalaya IMAP-level delete/move, then reconcile mbsync" —
   **not** local Maildir/notmuch-tag manipulation.
3. **The backlog is real and large**: 64,316 messages in All_Mail, 2,301 in Inbox, 58 in Logos.
   This is past the seed's assumed "10k–50k" and forces **batched IMAP ops + sampling/clustering**
   rather than naive per-ID adjudication.

**Recommended harness** (converged across A/B/D): **nix-declared wrapper scripts + a Claude Code
Skill, enforced by a `PreToolUse` hook + confirmation token**, operating on the local stack.
Reject a write-capable Gmail MCP server (re-implements auth, second OAuth client, network-bound at
64k scale, can't cover Protonmail, ships first-class bulk-delete). Reject relying on the
connector for destructive work (confirmed still read/draft-only, [claude-code#51040]).

**Recommended split of effort** (Teammate D): build the heavy guardrailed harness as a
**one-time-use, closely-supervised tool for the 64k backlog purge**; keep the **ongoing hygiene
loop deliberately minimal** — institutionalized Gmail filters + notmuch `postNew` rules doing the
work passively, with read-only-connector triage for "what's new that doesn't match a rule."

---

## Key Findings by Dimension

### Tools (Teammate A) — command mechanics, live-verified on this machine

- **Himalaya v1.2.0 already implements Gmail-safe delete**: `himalaya message delete <id>` moves
  to the configured trash alias (`[Gmail].Trash`); *"only the expunge folder command truly
  deletes."* No hand-rolled trash dance needed. → `himalaya message delete --folder INBOX <ids>`
  then (only post-approval) `himalaya folder expunge Trash`, then `mbsync gmail`.
- **Census command correction**: `notmuch search --output=sender` does **not** exist in notmuch
  0.40 (live error). Correct sender census: `notmuch address --output=sender --output=count
  --deduplicate=address <query> | sort -rn`.
- **List-Id search needs one-time setup**: notmuch 0.40 has no `header:` prefix; run
  `notmuch config set index.header.List List-Id` + `notmuch reindex '*'` to make `List:<id>`
  queryable; otherwise parse `notmuch show --format=json` per-message (slower).
- **`himalaya envelope list -o json` is agent-parseable** (live-captured shape: `id`, `flags`,
  `subject`, `from.addr`, `date`, `has_attachment`) — consume with `jq`. Verify shape live; it
  drifts across versions/blogs.
- **Draft workflow** works for *both* accounts (unlike the connector): `himalaya template reply`
  → human edits `.mml` → `himalaya template save -f Drafts` (syncs to `[Gmail]/Drafts`) or
  `template send`.
- **Recommendation: Option (b)** nix wrappers (`email-census`, `email-classify`, `email-archive`,
  `email-delete-confirmed`, `email-unsubscribe-extract` as `writeShellScriptBin`) + a scoped
  Claude Code Skill, with dry-run/manifest-consumption as a *technical* control in the wrapper.

### Security (Teammate B) — technical enforcement

- **`PreToolUse` hooks are the real enforcement**, not `permissions.deny` alone (which has
  documented bypass gaps, [claude-code#18846]). A Bash-matcher hook sees the resolved command
  string and can `permissionDecision: "deny"`. **This repo already uses this exact pattern** in
  `.claude/settings.json` — no new infrastructure needed.
- **Confirmation token, not prose approval**: require the executed command to carry a token/
  manifest-hash the hook checks (`--confirm-manifest <sha256>`), converting "agent claims it was
  approved" into "the command is structurally incapable of running without the token." Wrapper
  should diff executed IDs against the approved manifest, not just check for a token.
- **Lethal trifecta applies unconditionally** (private mailbox + attacker-controlled bodies +
  SMTP/exfil path). Only reliable fix: **break the action leg** — no tool call may execute as a
  direct causal continuation of content read from an email body; every mutation restarts from a
  human-approved, inert manifest file.
- **Freeze sync during bulk ops** (`systemctl --user stop mbsync.timer` + confirm no `mbsync`
  proc); operate on the snapshot; reconcile deliberately afterward.
- **Dry-run-by-default** with an explicit `--execute` (not `--no-dry-run`) flag; **deny
  `secret-tool` in the skill's tool context** (Himalaya/mbsync already reach the keyring
  internally; the agent never needs raw `secret-tool`). Keyring blast radius is why the read-only
  connector is the safer daily default.
- **Git-tracked approval manifests** = a second, durable undo/audit trail beyond Gmail's 30-day
  Trash window.

### UX (Teammate C) — human-in-the-loop

- **Primary review UX: provisional notmuch tags + aerc saved-search views.** Agent tags
  `+proposed-delete` / `+proposed-archive` / `+proposed-unsure`; add querymap entries so each is a
  normal aerc list; human bulk-confirms with existing visual-select keybinds (`v`/`V`/`x`). A
  generated **manifest is the companion audit artifact** (satisfies B's requirement); batched chat
  prompts are worst for volume (wrong cognitive mode) — reserve for the genuinely-ambiguous few.
  *(See conflict resolution — the confirm keybind must trigger the IMAP-level delete, not just a
  local retag.)*
- **Gmail-first**: Gmail's native 30-day Trash = a free, documented undo window; Protonmail-via-
  Bridge has no equivalent and adds a Bridge-uptime dependency. Defer Logos to phase 2.
- **Daily loop seam**: draft in Path A (connector, read-only), **send in Path B** (aerc `:recall`
  on the synced Drafts folder) — the connector's "cannot send" becomes the natural handoff, not a
  gap.
- **Institutionalize dual-write**: confirmed junk rules → server-side Gmail filters (durable even
  if the agent never runs again) **and** this repo's `notmuch.nix` `postNew` hook (local, version-
  controlled — a one-file extension of the pattern already there). Unsubscribe UX = one decision
  **per sender**, not per message; prefer Gmail's native Manage Subscriptions where UI-only.
- **Every purge report must state the undo window + expiry date explicitly** — the highest-leverage
  trust detail (reframes "the AI deleted 3,000 emails" as "moved to a recoverable folder for a
  month").

### Critic / Integration (Teammate D) — gaps & cross-cutting risks

- **Prior-art `~/Mail/.claude` system** (Finding 1 above) — the single most important discovery;
  it already solved preferences, batch-limiting (max 50), and a plan-approval UX, for Logos.
- **Delete correctness bug** (Finding 2 above) — reconciled with A's Himalaya finding below.
- **Scale** 64k+ (Finding 3 above) → needs batched IMAP + sampling/clustering tiers; is the point
  where a *narrowly-scoped, one-time* managed-cleaner assist for the old All_Mail corpus deserves
  a second look (separate from the security axis — the seed conflates scale and security).
- **Classifier must bias recall-on-keep ≈ 100%**, not aggregate accuracy: deleting one real email
  (job offer, legal notice, infrequent-sender receipt) is far worse than keeping 100 junk. Prefer
  deterministic signals (List-Unsubscribe / `precedence: bulk` / sender-domain / reply-history /
  VIP list); reserve LLM judgment for the residual `unsure` bucket + human-readable justifications.
- **Task 46 (Gmail OAuth2 token expiry) is a live blocking risk**: root cause = OAuth consent
  screen still in **Testing** mode → hard **7-day refresh-token expiry** (`invalid_grant`).
  Unresolved (`researched` only). An unattended purge could break mid-run. Make it an explicit
  dependency/pre-check; harness must detect `invalid_grant` and fail safe.
- **Connector is confirmed read/draft-only** as of July 2026 ([claude-code#51040], filed
  2026-04-20, still open) — corroborates the Path A/Path B split.

---

## Synthesis

### Conflicts Resolved

1. **Delete mechanism (A + D vs seed + C).** The seed and Teammate C described execution as "tag
   `+confirmed-delete`, let mbsync `Expunge Both` finish." Teammate D proved this is a Gmail-
   specific no-op/footgun (strips a label, leaves the message in All Mail). Teammate A independently
   showed the correct primitive already exists. **Resolution: "delete" = an IMAP-level Himalaya
   command against the `gmail` account** (`himalaya message delete --folder INBOX <ids>` → soft-move
   to `[Gmail].Trash`; `himalaya folder expunge Trash` only after approval), **followed by** a
   deliberate `mbsync gmail` reconciliation — never a local Maildir-file/notmuch-tag operation
   alone. Teammate C's aerc `+confirmed-delete` keybind is kept **only as a review/marking gesture**;
   the actual deletion is performed by the wrapper script issuing the Himalaya IMAP command against
   the confirmed-tag set, not by the keybind rewriting local tags. (Planner: verify with a single-
   message dry-run before finalizing.)

2. **Account scope vs prior art (C vs D).** C recommends Gmail-first; D notes the *existing* tested
   harness is for Logos — the account C defers. **Resolution: Gmail-first stands** — the 64k backlog
   and the 30-day Trash undo are both on Gmail, and that is where the user's "largest task" lives.
   But **Phase 0 reconciliation of `~/Mail/.claude` is mandatory** and its Logos-specific lessons
   (preference rules, batch limits, the `pass`/Bridge fix from its task 28, the checkbox approval UX)
   feed the new design regardless of which account runs first.

3. **Harness form-factor.** A (nix wrappers + Skill), B (hook enforcement), D (split investment) are
   complementary, not conflicting. **Resolution**: nix-declared wrapper scripts (dry-run default,
   manifest-consuming, one-verb-each) + a scoped Claude Code Skill + a `PreToolUse` mail-guard hook +
   confirmation token; built as a heavier one-time backlog tool and a minimal ongoing loop.

4. **LLM vs deterministic classification.** Unanimous once stated: deterministic rules for the bulk
   80–90%, LLM only for the residual `unsure` bucket and for justifications, biased to recall-on-keep.

### Gaps Identified (carry into planning / need user input)

- **"Delete" semantics are ambiguous** (D's Q4): does the user mean (a) free Gmail storage / remove
  from All Mail permanently, or (b) just get it out of the Inbox (archive)? These have different
  mechanisms and risk profiles. **This needs an explicit user answer** and is upstream of nearly
  everything.
- **`~/Mail` reconciliation decision** (resume / retire / partition) — the de-facto open question #0.
- **Audit-trail repo location**: `.dotfiles/specs/071_.../` vs `~/Mail/specs/` (two unconnected git
  histories).
- **Task 46 OAuth fix**: block on it, or absorb it (publish OAuth app to Production) as part of 71.
- **mbsync `SyncState` corruption / resumability** for a multi-hour 64k purge (backup `~/.mbsync/`
  state, `mbsync --pull` verification, partial-progress manifests).
- **Primary gmail channels lack `Remove` directive** (default `None`) — review whether whole-folder
  removal should propagate.

### Recommendations (converged)

**Architecture**
1. Keep the two-path split: **read-only connector = daily triage/summarize/draft** (lowest blast
   radius, works anywhere); **local stack = all mutations** (send/archive/delete).
2. **Harness = nix wrappers + Claude Code Skill + `PreToolUse` hook + confirmation token.** Reject
   write-capable Gmail MCP servers and any connector-based destructive path.

**Backlog purge (the largest task) — Gmail-first, one-time supervised tool**
3. Pipeline: **freeze sync → census (real numbers) → deterministic bucket (recall-on-keep bias) →
   sampling/clustering for the large `unsure` residual → tag `+proposed-*` → human reviews in aerc
   tagged views (+ companion manifest) → execute via batched IMAP-level Himalaya delete/move →
   `folder expunge Trash` (approved) → `mbsync gmail` reconcile → report with explicit undo window.**
4. **Delete = Himalaya IMAP-level**, never local-tag/expunge (conflict resolution #1). Batch IMAP
   ops (UID sets), not per-ID loops, at 64k scale. Design for resumability/partial failure.
5. Bias classifier to **~100% recall on keep**; deterministic first, LLM only on residual.

**Ongoing hygiene — deliberately minimal**
6. Dual-write institutionalized rules to **Gmail filters + `notmuch.nix` postNew**; unsubscribe per
   sender; let filters do the passive work; use the connector for "what's new that doesn't match a
   rule."

**Enforcement & safety**
7. `PreToolUse` mail-guard hook denying `himalaya * send` / `msmtp` / `folder expunge` / `rm *Mail*`
   / `secret-tool*` unless a valid confirmation token / manifest-hash is present; dry-run default;
   freeze sync; git-tracked manifests; treat all mail content as data, never instructions.

**Sequencing / dependencies**
8. **Phase 0: reconcile `~/Mail/.claude` prior art.** **Resolve/absorb task 46 (OAuth expiry)** before
   any unattended run. **Ask the user the "delete = storage vs inbox" question** and the
   "one unified tool vs two" question.

---

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Tools / command mechanics (live-verified binaries) | completed | High (mechanics), Medium (form-factor judgment) |
| B | Security / guardrail enforcement | completed | Medium-High |
| C | UX / human-in-the-loop workflow | completed | High (review UX, Gmail-first) |
| D | Critic / integration / horizons | completed | High (prior-art, scale, mbsync, task 46), Medium (exact resurrection repro) |

**Note on environment**: notmuch's Xapian index was unpopulated during A's session (0 indexed),
so A's per-bucket *counts* are illustrative; D counted the Maildir directly (`ls .../cur | wc -l`)
for the real 64k/2.3k/58 figures. Run `notmuch new` before relying on notmuch-based census.

## Resolved Open Questions (from the seed's seven)

1. **Harness form-factor** → nix wrappers + Claude Code Skill + PreToolUse hook (not an MCP server).
2. **Approval UX** → provisional notmuch tags reviewed in aerc, companion git-tracked manifest.
3. **Account scope** → Gmail-first; Logos phase 2 (but reconcile the dormant Logos prior-art first).
4. **Backlog census** → **64,316 All_Mail / 2,301 Inbox / 58 Logos** (real, counted).
5. **Guardrail enforcement** → PreToolUse hook + confirmation token + dry-run default + manifest diff.
6. **Classifier quality** → deterministic-first, recall-on-keep ≈ 100%, LLM on residual only.
7. **Injection hardening** → break the action leg; mutations only from inert human-approved manifests.

## New Questions Raised (for `/plan` and user)

- **[USER] Does "delete" mean free-storage/remove-from-All-Mail, or just archive-out-of-Inbox?**
- **[USER] One unified tool, or a heavy one-time purge tool + a minimal ongoing loop?**
- Reconcile `~/Mail/.claude`: resume, retire, or partition?
- Make task 46 (OAuth Production-mode fix) a blocking dependency of 71's implementation?
- Audit-manifest location: `.dotfiles/specs/` vs `~/Mail/specs/`?
- mbsync state backup/verification + resumability for a multi-hour 64k purge.

---

## References

Consolidated from teammate findings (see `02_teammate-{a,b,c,d}-findings.md` for full lists):

- [openclaw/openclaw — skills/himalaya/SKILL.md (the "Himalaya skill", community)](https://github.com/openclaw/openclaw/blob/main/skills/himalaya/SKILL.md)
- [Claude Himalaya Skill guide — MCP.Directory](https://mcp.directory/blog/claude-himalaya-skill-guide)
- [Himalaya CLI (pimalaya/himalaya)](https://github.com/pimalaya/himalaya) · [himalaya(1)](https://man.archlinux.org/man/himalaya.1.en)
- [notmuch-address(1)](https://notmuchmail.org/manpages/notmuch-address-1/) · [notmuch-search-terms(7)](https://notmuchmail.org/manpages/notmuch-search-terms-7/)
- [mbsync(1) — isync](https://isync.sourceforge.io/mbsync.html) · [mbsync/Gmail deletion — isync list](https://sourceforge.net/p/isync/mailman/message/36386997/)
- [Sync mail deletion with notmuch + mbsync for Gmail — notmuch list (All-Mail footgun)](https://notmuchmail.org/pipermail/notmuch/2016/023112.html) · [Removing messages with notmuch — Tomeček](https://blog.tomecek.net/post/removing-messages-with-notmuch/)
- [Claude Code Hooks reference](https://code.claude.com/docs/en/hooks) · [permissions.deny enforcement gap #18846](https://github.com/anthropics/claude-code/issues/18846)
- [The lethal trifecta for AI agents — Simon Willison](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/) · [OWASP LLM Prompt Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html)
- [Gmail/Drive/Calendar connectors lack write ops #51040](https://github.com/anthropics/claude-code/issues/51040) · [Use Google Workspace connectors — Claude Help](https://support.claude.com/en/articles/10166901-use-google-workspace-connectors)
- [RFC 8058: One-Click Unsubscribe](https://www.rfc-editor.org/rfc/rfc8058.html) · [List-Unsubscribe 2026 guide — Prospeo](https://prospeo.io/s/list-unsubscribe-header)
- [Recover deleted Gmail after 30 days — Inbox Zero](https://www.getinboxzero.com/blog/post/how-to-recover-deleted-gmail-emails-after-30-days) · [AI human approval gate (Inbox Deletion Incident) — CloudRadix](https://cloudradix.com/blog/ai-employee-human-approval-gate/)
- Local ground truth: `~/Mail/.claude/` (dormant prior-art system), `~/Mail/specs/state.json`, `modules/home/email/{mbsync,notmuch,aerc}.nix`, `docs/himalaya.md`, `specs/046_investigate_fix_gmail_oauth2_token_expiry/`

---

*Team research synthesis for task 71. Supersedes the seed report's open questions with resolved
answers + a sharper, verified design; carries forward two USER decisions and a Phase-0
reconciliation into `/plan`.*

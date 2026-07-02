# Research Report: Task #71 — Teammate C (UX / Workflow)

**Task**: 71 — Design AI-assisted email management workflow
**Teammate**: C (human-in-the-loop UX / workflow ergonomics)
**Started**: 2026-07-02
**Completed**: 2026-07-02
**Dependencies**: Seed report `01_ai-email-workflow.md`; coordinates with Teammate A (tool
mechanics) and Teammate B (security enforcement) — this report does not re-specify command
syntax or guardrail implementation, only the human-facing interaction design.
**Sources/Inputs**: Codebase (`modules/home/email/aerc.nix`, `modules/home/email/notmuch.nix`),
seed report, WebSearch (2026 sources)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- **Primary approval UX for bulk deletion review**: tag-and-review in aerc (option a), not a
  manifest file or chat prompts. Have the agent apply provisional notmuch tags
  (`+proposed-delete`, `+proposed-archive`, `+proposed-keep`) and add three new querymap
  entries so the human reviews each bucket as a normal aerc list, bulk-selecting with
  visual mode (`V`/`x`) and confirming with one keybind per bucket. A generated **manifest
  file is the fallback**, reserved for offline/async review or when the user wants an
  auditable paper trail before an irreversible run.
- **Scope decision**: start Gmail-only. Gmail's native Trash is a 30-day soft-delete safety
  net that turns "delete" into a reversible operation for free; Protonmail-via-Bridge has no
  equivalent low-friction undo and depends on Bridge being up, so it should be phase 2.
- **Institutionalize, don't repeat**: every rule that survives the backlog triage becomes
  both a server-side Gmail filter (stops the mail from re-accumulating even if the agent
  never runs again) and a notmuch `postNew` tag rule (this repo's `notmuch.nix` already does
  exactly this pattern for folder/account tagging — extending it is a one-file diff).
- **Confidence**: High on the review-UX recommendation and Gmail-first sequencing (grounded
  in this repo's actual config + Gmail's documented retention policy); Medium on some 2026
  competitor-UX specifics for the same reason.

---

## Context & Scope

This report focuses exclusively on **interaction design**: what the human sees, clicks, and
approves at each stage of (1) the one-time backlog purge and (2) the ongoing daily triage
loop. It does not cover: shell command syntax for himalaya/notmuch (Teammate A), or
technical guardrail enforcement / prompt-injection defenses (Teammate B). Where those
dimensions intersect with UX (e.g., "the delete keybind must require confirmation"), this
report states the UX requirement and defers the mechanism to Teammate B.

---

## Findings

### 1. Approval UX for reviewing hundreds of proposed deletions

**Option (a) — provisional tag + aerc saved-search review view**

The agent runs its classifier and, instead of deleting anything, tags messages:
`notmuch tag +proposed-delete -- <query>`, `+proposed-archive`, `+proposed-keep-unsure`. The
human then reviews via **new querymap entries** analogous to the existing `Unread`/`Flagged`
entries in `~/.config/aerc/querymap-gmail`:

```
Proposed-Delete=tag:proposed-delete
Proposed-Archive=tag:proposed-archive
Proposed-Unsure=tag:proposed-unsure
```

This turns "review 500 proposed deletions" into "open the `Proposed-Delete` virtual folder in
aerc, use vim-style navigation you already know (`j`/`k`/`J`/`K`), and either trust the whole
bucket or spot-check." aerc already supports **visual/multi-select** (`v`/`V` toggle,
`x`/`X`/`<Space>` in this repo's config) followed by a bulk `modify-labels` or `:archive`
command applied to every selected/marked message at once — this is a first-class aerc
capability, not a workaround. A dedicated keybind such as:

```
messages:folder=Proposed-Delete {
  A = ":modify-labels -proposed-delete +confirmed-delete<Enter>"
  R = ":modify-labels -proposed-delete +proposed-keep<Enter>"  # reject/rescue one
}
```

lets the human bulk-confirm an entire screenful (or the whole bucket via `:select 0`,
`V`, `:select -1`, confirm) with one keystroke, while still being able to arrow down and
rescue individual false positives before confirming. Execution (the actual trash-move) is a
**separate, later step** gated on `tag:confirmed-delete`, never on the proposal tag itself —
this is the same "propose, then separately execute" split Teammate B will want for the
guardrail layer.

**Option (b) — generated manifest file (CSV/markdown table)**

The agent writes `specs/071_.../review/proposed-actions.csv` with columns
`id,sender,subject,date,proposed_action,reason`. The human edits the `proposed_action`
column (or deletes rows to reject) in a text editor/spreadsheet, and a script re-reads only
the rows still marked for action and executes them by notmuch id.

Trade-offs versus (a):
- **Pro**: works fully offline from aerc; git-diffable audit trail of exactly what was
  approved; trivially resumable if interrupted; good for a first-time trust-building run
  where the user wants to `grep`/sort/spot-check in bulk with familiar text tools (e.g.
  `awk -F, '$5=="delete"' | wc -l` to sanity-check bucket sizes before committing).
  Excellent as a **pre-approval sanity check layer on top of (a)** — see Recommended
  Approach below.
- **Con**: reviewing hundreds of rows in a flat CSV/table has no thread context, no
  preview pane, no keyboard-native "open and read the borderline one" — it's optimized for
  auditing a decision already made by the classifier, not for making the decision. It is
  strictly worse than aerc for the "eyeball 500 short lived messages fast" task because
  aerc gives subject+sender+date+flags in one line *and* one keypress to preview the body.

**Option (c) — batched interactive Claude Code prompts (approve N at a time)**

Worst option for hundreds-to-thousands of items: each batch consumes a conversational
turn, cannot be reviewed at the human's own pace (skim fast, slow down on ambiguous ones),
produces no durable artifact to resume from if the session is interrupted, and — critically
for decision fatigue — trades a **fast recognition task** (glancing at a sender/subject
line, which the human brain is very good at) for a **slow deliberation task** (reading a
chat message and typing a response), which is the wrong cognitive mode for bulk triage.
2026 UX literature on decision fatigue is consistent on this: batch/bulk operations that
let users work in a fast "recognize and gesture" mode outperform sequential one-at-a-time
prompts, and separating a fast "collect into a pile" pass from a slower "organize the pile"
pass reduces fatigue further ([Batch Operations in UX — Hforge](https://www.hforge.org/batch-operations-in-ux-why-doing-things-in-bulk-quietly-saves-hours/);
[UX Database — Decision Fatigue](https://www.uxdatabase.io/newsletter-issue/101-decision-fatigue)).
Reserve interactive prompts for genuinely ambiguous individual cases the agent flags, not
for bulk review.

**Recommendation: (a) primary, (b) fallback/companion, (c) only for edge cases.**

Concretely: agent tags proposals → agent *also* emits a manifest as a companion audit log
(cheap to generate, useful for a paper trail and for Teammate B's audit requirements) →
human does the actual approve/reject pass in aerc's tagged views using bulk visual-select →
for the handful of genuinely ambiguous messages the agent couldn't classify confidently, it
asks a batched interactive question ("these 8 senders don't match any rule — keep or junk?")
rather than forcing a manifest edit for 8 rows.

### 2. Daily/ongoing loop: where the connector fits vs the local stack

Per the seed report's Path A/Path B split, the daily loop should be explicitly two-phase in
the user's mental model, matching capability boundaries exactly:

**Morning triage (Path A — Anthropic Gmail connector, read-only)**
1. User: "What's important in my inbox today?" — connector searches/summarizes, zero risk.
2. User: "Draft a reply to X" — connector creates an **unsent Gmail draft**. Nothing is sent.
3. This phase needs no local terminal session at all — it can happen from any Claude
   client, which matters because it is the *lowest-friction, most-likely-to-actually-happen-
   daily* part of the loop. Habit formation favors the path with the least setup cost.

**Cleanup pass (Path B — local stack, mutation-capable)**
1. User opens a terminal, runs the agent-driven cleanup (skill/slash command backed by
   Himalaya + notmuch).
2. Agent applies the now-institutionalized rules (Section 4) automatically for the
   mechanically-classifiable 80%, and tags only the genuinely new/ambiguous senders as
   `+proposed-*` for review, using the same tagged-view UX as the backlog purge but at
   daily scale (tens, not hundreds, of items — so this is fast).
3. Human reviews in aerc, bulk-confirms, agent executes (trash-then-expunge for Gmail).
4. The Gmail drafts created in the morning session are visible in aerc's `Drafts` folder too
   (`:recall` binding already exists in this repo's config) — so the human can finish/send
   replies drafted by the read-only connector using the local stack's send capability. This
   is an important seam: **draft in Path A, send in Path B** — the connector's own
   limitation (`cannot send`) is turned into the natural handoff point rather than a gap.

This two-phase design means the user never has to remember "which tool can do what" — the
rule is simply *reading/summarizing/drafting happens anywhere, anytime; anything that
changes the mailbox happens in the terminal session with the local agent*.

### 3. Scope decision: Gmail-first vs both accounts

**Recommendation: Gmail-only for the backlog purge and for the initial ongoing-loop rollout;
add Protonmail/Logos in a second pass once the workflow is proven.**

Reasoning:
- **Reversibility asymmetry**: Gmail's Trash is a native 30-day soft-delete — "delete" is
  recoverable by design for a month with a one-click "Move to Inbox" from Trash
  ([Gmail retention](https://www.getinboxzero.com/blog/post/how-to-recover-deleted-gmail-emails-after-30-days)).
  This is a huge, free undo window that de-risks an AI-driven bulk-delete pass. Protonmail's
  delete/expunge semantics via Bridge do not offer the same well-documented, low-friction
  recoverability in this local IMAP-bridge setup, and any mistake compounds with the
  Bridge-availability dependency below.
- **Operational dependency**: Protonmail mail only flows through `127.0.0.1:1143/1025` while
  Bridge is running. A backlog job that silently no-ops or partially completes because
  Bridge wasn't up is a worse failure mode than "we simply didn't touch that account yet."
  Gmail's OAuth2/keyring path (already auto-refreshing via systemd timer per the seed report)
  has no equivalent "is the local proxy alive" precondition.
- **Volume concentration**: in nearly all dual-account setups, one account (typically the
  long-lived Gmail address) carries the vast majority of historical backlog and subscription
  noise; the newer/secondary account (Logos/Protonmail) is lower-volume and lower-risk to
  defer. (Confirm with the `notmuch count` census called for in the seed report's open
  question 4 — this is an assumption pending that data, not a hard fact.)
- **Sequencing benefit**: running the whole pipeline (freeze → census → bucket → approve →
  execute → institutionalize) once on Gmail validates the classifier's false-positive rate
  and the review UX's throughput on a smaller, better-understood risk surface before
  extending the same pipeline to a second account with different deletion semantics.

**Recommended sequencing**: (1) Gmail backlog purge end-to-end, including institutionalized
filters; (2) run the ongoing daily loop on Gmail alone for a week or two to validate; (3)
only then extend the same tag-rule/filter pattern to Logos/Protonmail, at which point the
classifier and review UX are already trusted and the marginal work is mostly "add a second
querymap and confirm Bridge is running before each run."

### 4. Institutionalizing heuristics so the inbox stays clean

Two independent, complementary mechanisms — one server-side, one local — should both be
updated from whatever rules "win" during the backlog triage (i.e., rules the human approved
with high confidence and no overrides):

**(a) Standing Gmail filters (server-side, works even if the agent never runs again)**

Once a sender/domain is confirmed junk during triage, convert it into a native Gmail filter
(`from:sender OR from:domain` → skip inbox + apply label + optionally auto-delete/archive).
This is the same manual action the 2026 sources describe for stopping a high-volume sender
without clicking every email
([Gmail filter creation via the sliders icon](https://www.getinboxzero.com/blog/post/gmail-filters-not-working-troubleshooting-guide)),
just driven by the agent proposing the filter definition for human approval rather than the
human hand-crafting it. Filters act **before mail even reaches the local Maildir**, so this
is the only mechanism that prevents regrowth if the local agent harness is ever offline.

**(b) notmuch `postNew` tag rules (local, this repo's existing pattern)**

`modules/home/email/notmuch.nix` already has exactly the right hook for this:

```nix
hooks.postNew = ''
  notmuch tag +inbox +unread -- tag:new
  notmuch tag -new -- tag:new
  notmuch tag +sent -inbox -- folder:Gmail/.Sent OR folder:Logos/.Sent
  notmuch tag +trash -inbox -- folder:Gmail/.Trash OR folder:Logos/.Trash
  notmuch tag +spam -inbox -- folder:Gmail/.Spam
  notmuch tag +gmail -- folder:/Gmail/
  notmuch tag +logos -- folder:/Logos/
'';
```

Extending this with additional lines per confirmed-junk sender
(`notmuch tag +junk -inbox -- from:newsletter@example.com`) is a **one-file, declarative,
version-controlled** way to institutionalize the classifier's output — every future
`notmuch new` (which already runs via `preNew = "mbsync -a"` on every sync) re-applies the
accumulated rule set automatically, with zero agent invocation required. This nix file
becomes the durable "rules memory" the seed report's Section 6 open question asked about;
it is superior to an ad hoc rules file because it is applied by notmuch itself, not by the
agent, so it works even when Claude Code isn't running.

**Bulk unsubscribe UX**: Gmail's native **Manage Subscriptions** feature (shipped July 2025)
already surfaces a list of senders and one-click unsubscribe, and RFC 8058
`List-Unsubscribe`/`List-Unsubscribe-Post` headers let Gmail unsubscribe via a background
POST with no redirect/dark-pattern risk
([List-Unsubscribe header 2026 guide](https://prospeo.io/s/list-unsubscribe-header);
[Gmail bulk-sender enforcement](https://blog.incogni.com/how-to-unsubscribe-from-emails-on-gmail-in-bulk/)).
The recommended UX: during triage, the agent groups the `junk` bucket by sender, extracts
`List-Unsubscribe` headers, and produces a **single review list of senders to unsubscribe**
(not one decision per email) — the human approves the list once, and the agent either (i)
points the human at Gmail's native Manage Subscriptions UI for one-click execution, or (ii)
where a machine-actionable `List-Unsubscribe-Post` header exists, proposes the POST action
for the same approve-then-execute pattern used for deletes. This collapses "unsubscribe from
50 newsletters" into one review decision per sender rather than per message — directly
addressing decision fatigue at the volume this system needs to handle.

### 5. Backlog-purge session UX end-to-end

Recommended session shape, matching the seed report's pipeline (Section 5) but specified as
a UX flow with concrete artifacts at each step:

1. **Freeze**: agent announces it is stopping mbsync timers; single confirmation ("proceed
   with full-backlog census? this pauses background sync until the session ends").
2. **Census summary shown to user** — not a wall of message IDs, a compact table:
   ```
   Total messages in scope: 4,812
   By proposed bucket:
     junk (bulk senders / list-ids / promotions): 3,102  (64%)
     keep (VIP / replied threads / receipts):        980  (20%)
     unsure (needs review):                          730  (15%)
   Top 10 junk senders by volume: [sender: count, ...]
   Oldest message: 2019-03-11   Newest: 2026-06-30
   ```
   This single screen is the human's "is this plausible?" gate before any per-message work
   begins — critical for trust calibration on a first run.
3. **Bucket preview**: for each bucket, a short *sample*, not the full list (e.g. 10 random
   `junk` examples, 10 random `unsure` examples) shown inline, so the human can sanity-check
   the classifier before committing to a full review pass.
4. **Approve**: the tagged-aerc-view flow from Section 1 — human works through
   `Proposed-Delete`, `Proposed-Archive`, `Proposed-Unsure` at their own pace, bulk-confirming
   with visual-select, rescuing individual false positives.
5. **Execute**: only after explicit confirmation per bucket, agent performs the batched
   move-to-Trash / archive / re-tag operations and re-enables sync with `Expunge Both`.
6. **Report** — the session should end with a summary in the same compact style as the
   census, now showing outcomes and the safety net explicitly:
   ```
   Executed:
     Archived:  980 messages -> All_Mail
     Deleted:  3,050 messages -> Trash (recoverable until ~2026-08-01, 30-day Gmail retention)
     Left unsure: 52 messages tagged +needs-review (not touched)
   Institutionalized: 14 sender rules added to Gmail filters + notmuch postNew hook
   Unsubscribe candidates queued for review: 23 senders
   ```
   Explicitly stating the **undo window and its expiry date** in the final report is the
   single highest-leverage trust-building UX detail: it converts "the AI deleted 3,000 of my
   emails" (alarming, echoes the Feb-2026 "Inbox Deletion Incident" documented publicly —
   [CloudRadix](https://cloudradix.com/blog/ai-employee-human-approval-gate/)) into "the AI
   moved 3,000 emails to a recoverable trash folder for the next month," which is a
   fundamentally different (and honest) risk framing.

### 6. 2026 patterns worth borrowing from AI email assistants

Without adopting the SaaS tools (data-residency conflicts with this user's self-hosted,
keyring-secured posture, per the seed report), several UX patterns generalize well to a
notmuch/aerc-driven design:

- **Bundling/grouping over per-message decisions** (Shortwave, Superhuman): both group mail
  into categories (e.g. "Marketing," "Social") and let the user act on the *bundle* in one
  click rather than per email
  ([Shortwave vs Superhuman](https://zapier.com/blog/shortwave-vs-superhuman/)). This maps
  directly onto tagging by sender/list-id bucket and letting aerc's visual-select act on the
  whole tagged view at once — the same mechanism recommended in Section 1.
- **Overlay, not full replacement** (SaneBox): SaneBox works *with* the existing provider
  rather than requiring a new client
  ([SaneBox review 2026](https://thesoftwarescout.com/sanebox-review-2026/)). This validates
  the architecture already in place here — Himalaya/notmuch/aerc as an overlay on Gmail/
  Protonmail rather than a wholesale migration — and argues for keeping the institutionalized
  rules server-side (Gmail filters) wherever possible so the "overlay" isn't a single point
  of failure.
- **Native provider affordances first** (Gmail Manage Subscriptions, Gemini in Workspace):
  when the provider ships a first-party bulk action (unsubscribe list, one-click bundle
  archive), prefer pointing the human at it over reimplementing equivalent logic locally —
  it inherits the provider's compliance/rate-limit handling for free.
- **Explicit approval gate as a named UX moment, not implicit** (the Feb-2026 incident
  write-ups, e.g. CloudRadix): the strongest 2026 consensus finding is that the failure mode
  isn't "the AI made a bad classification," it's "there was no checkpoint between decision
  and irreversible action." The recommended design in this report (propose-tag → separate
  confirm-tag → separate execute step) directly implements that checkpoint as three distinct,
  observable states rather than a single boolean "approved" flag — auditable at each stage.

---

## Decisions

- Use notmuch provisional tags + new aerc querymap entries as the primary bulk-review
  mechanism; a generated manifest is a companion audit artifact, not the primary review
  surface.
- Scope both the backlog purge and the initial ongoing-loop rollout to Gmail only;
  Protonmail/Logos is an explicit phase 2 after the pattern is validated.
- Institutionalization is dual-write: Gmail filters (server-side durability) AND
  `notmuch.nix` `postNew` hook rules (local durability, version-controlled) — not either/or.
- Unsubscribe UX groups by sender, review is one decision per sender not per message.
- Every purge-session report must state the undo window explicitly (Gmail Trash's 30-day
  retention) as part of the summary, not as a footnote.

## Risks & Mitigations

- **Risk**: tagged-view review still requires the human to actually open aerc regularly;
  if the backlog is large enough, even bucket-level review could feel like a chore.
  **Mitigation**: the census/preview step (Section 5, steps 2-3) lets the human calibrate
  trust and, after the first successful run, selectively skip full review of the `junk`
  bucket for future incremental runs once false-positive rate is empirically low — but this
  is a policy decision for Teammate B / the planner, not asserted here as a shortcut.
- **Risk**: Gmail Manage Subscriptions and List-Unsubscribe automation may not be scriptable
  headlessly (some flows are UI-only in Gmail's web client). **Mitigation**: treat "point the
  human at native Manage Subscriptions" as an acceptable manual step in the loop rather than
  something the agent must automate end-to-end; only automate the `List-Unsubscribe-Post`
  header POST path where it's genuinely programmatic.
- **Risk**: extending `notmuch.nix`'s `postNew` hook with many per-sender rules could grow
  unbounded and slow down `notmuch new`. **Mitigation**: this is a scale/performance question
  for Teammate A's tool-mechanics research; flagged here only as a UX-adjacent risk to the
  "institutionalize" recommendation.

## Context Extension Recommendations

- **Topic**: aerc bulk-review querymap pattern for AI-agent-proposed actions.
- **Gap**: `.claude/context/` has no documented pattern for "agent tags provisionally, human
  reviews via querymap, agent executes on confirm-tag" — this is a reusable pattern beyond
  email (could apply to any notmuch-like or tag-driven bulk-approval workflow).
- **Recommendation**: if task 71 proceeds to implementation, consider adding a
  `.claude/context/patterns/tag-propose-confirm-execute.md` describing the three-state tag
  lifecycle (`proposed-*` → `confirmed-*` → executed/cleared) as a general human-in-the-loop
  bulk-approval pattern, since it generalizes beyond this one task.

## Appendix

### Search queries used
- notmuch bulk email review tag workflow aerc saved search 2026
- AI email triage manifest CSV approve before delete human in the loop 2026
- Shortwave Superhuman SaneBox bulk unsubscribe triage review UX 2026
- decision fatigue batch review UX reviewing hundreds of items swipe bulk approve pattern
- Gmail filters List-Unsubscribe header bulk unsubscribe automation 2026
- aerc modify-labels bulk select visual mode multiple messages confirm prompt
- "inbox zero" backlog purge session report undo window trash retention 30 days Gmail

### Codebase references
- `/home/benjamin/.dotfiles/modules/home/email/aerc.nix` — querymap pattern (`Unread`,
  `Flagged`), existing single-message confirm-prompt pattern (`d` keybind), visual-select
  keybinds (`x`/`X`/`<Space>`), `A` bulk-archive-selected keybind.
- `/home/benjamin/.dotfiles/modules/home/email/notmuch.nix` — `postNew` hook, existing
  folder/account auto-tagging pattern to extend for junk-sender rules.

## References

- [Notmuch configuration for Hey.com-style workflows (GitHub Gist)](https://gist.github.com/vedang/26a94c459c46e45bc3a9ec935457c80f)
- [aerc-notmuch(5) — Arch manual pages](https://man.archlinux.org/man/aerc-notmuch.5.en)
- [aerc(1) — Arch manual pages, visual-mode select](https://man.archlinux.org/man/aerc.1.en)
- [Why Your AI Employee Needs a Human Approval Gate (The Inbox Deletion Incident) — CloudRadix](https://cloudradix.com/blog/ai-employee-human-approval-gate/)
- [How to Build a Gmail AI Agent with Human Approval — Bit Flows](https://bit-flows.com/blog/gmail-ai-agent-with-human-approval/)
- [Batch Operations in UX: How Bulk Actions Save Time Without Raising Anxiety — Hforge](https://www.hforge.org/batch-operations-in-ux-why-doing-things-in-bulk-quietly-saves-hours/)
- [UX Database Newsletter #101 — Decision Fatigue](https://www.uxdatabase.io/newsletter-issue/101-decision-fatigue)
- [Shortwave vs. Superhuman: Which is better? [2026] — Zapier](https://zapier.com/blog/shortwave-vs-superhuman/)
- [SaneBox Review 2026: Is It Actually Worth the Subscription? — The Software Scout](https://thesoftwarescout.com/sanebox-review-2026/)
- [List-Unsubscribe Header: 2026 Setup & Compliance Guide — Prospeo](https://prospeo.io/s/list-unsubscribe-header)
- [How to unsubscribe from emails on Gmail in bulk [2026] — Incogni](https://blog.incogni.com/how-to-unsubscribe-from-emails-on-gmail-in-bulk/)
- [How to Recover Deleted Gmail Emails After 30 Days? — Inbox Zero](https://www.getinboxzero.com/blog/post/how-to-recover-deleted-gmail-emails-after-30-days)
- [Gmail Filters Not Working? How to Fix Them (2026) — Inbox Zero](https://www.getinboxzero.com/blog/post/gmail-filters-not-working-troubleshooting-guide)

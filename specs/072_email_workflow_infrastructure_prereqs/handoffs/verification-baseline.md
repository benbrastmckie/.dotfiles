# Verification Baseline (Task 72, Phase 1)

**Date**: 2026-07-02
**Purpose**: Resolve the round-2 team report's currently-false/unverified premises against the live
system before any wrapper is designed around them. All results below are live-verified.

---

## 1. systemd unit inventory (input to Phase 8)

There is **no mbsync timer or service**. Mail-related user units:

| Unit | State |
|------|-------|
| `gmail-oauth2-refresh.service` | **failed** (`invalid_grant`) |
| `gmail-oauth2-refresh.timer` | active (waiting) |
| `protonmail-bridge.service` | active (running) |

mbsync's only trigger paths: notmuch `preNew` hook (`mbsync -a`), aerc `$` keybind
(`:exec mbsync -a && notmuch new`), and manual invocation. **Freeze (Phase 8) has no timer to
stop** — it must instead guard the `preNew`/aerc trigger paths.

## 2. notmuch index rebuild (Critic F2 — CONFIRMED + root cause)

- **Before**: `notmuch count '*'` = 0, `tag:inbox` = 0 (index empty — confirmed).
- **Root cause of the empty index**: the notmuch `pre-new` hook is literally `mbsync -a`
  (`~/.config/notmuch/default/hooks/pre-new`), which fails on Gmail XOAUTH2 (`invalid_grant`) and
  aborts `notmuch new` before indexing. Verified by reading the hook script.
- **Rebuild**: `notmuch new --no-hooks` (bypasses the failing `pre-new`) processed **99,794 files
  in 5m04s** and added **66,785 unique messages** (the 99,794 files dedup by Message-ID — Gmail's
  label model stores one message under multiple folders).
- Maildir ground truth: `~/Mail/Gmail` = 97,239 files; all `~/Mail` = 99,141; `.All_Mail` folder =
  64,785 indexed. Index count (66,785 unique) is consistent with the Maildir. **Blocking gate for
  Phases 5-6 is cleared.**

## 3. Census invocation (input to Phase 5)

- Bare form **errors**: `notmuch address --output=sender --output=count --deduplicate=address`
  → "notmuch search requires at least one search term."
- **Working form** (exit 0, real sender counts): 
  `notmuch address --output=sender --output=count --deduplicate=address -- '*'`
- Record this exact invocation for `email-census`.

## 4. Tagging + folder-query finding (NEW — important design input for Phase 5)

`new.tags = new` in notmuch config: newly indexed messages get `tag:new`, and the **`post-new`
hook** converts `tag:new` → `+inbox +unread` and applies folder/account tags (`+gmail`, `+sent`,
`+trash`, `+spam`). Because Phase 1 ran with `--no-hooks`, the `post-new` tagging did **not** run:

- `tag:new` = 66,785 · `tag:inbox` = 0 · `tag:gmail` = 0 (all untagged-by-folder).

Do **not** run the stock `post-new` hook wholesale on this full reindex: its
`notmuch tag +inbox +unread -- tag:new` line would tag **all** 66,785 messages (including All_Mail)
as inbox, since every message currently carries `tag:new`. That hook is written for incremental
`notmuch new` runs (a handful of genuinely new INBOX messages), not a full backfill.

**Consequence for the wrappers (Phase 5):** key off **folder-scoped queries**, not `tag:inbox`.
Under maildir++ (`maildirpp = true`), the correct queries are:

| Concept | Correct notmuch query | Count |
|---------|----------------------|-------|
| INBOX | `folder:Gmail` (account root — NOT `folder:Gmail/INBOX`, which = 0) | 2,950 |
| All Mail | `folder:Gmail/.All_Mail` | 64,785 |
| Gmail account (all) | `path:Gmail/**` | — |

`email-census` should report INBOX via `folder:Gmail`; `email-classify` applies its own
`+proposed-*` tags independently of the stock inbox tagging.

## 5. SyncState location (input to Phase 8)

`.mbsyncstate` files live **inside `~/Mail/Gmail/<folder>/`** (per-folder), NOT `~/.mbsync/`
(which does not exist). Enumerate for backup with:
`find ~/Mail/Gmail -name '.mbsyncstate*'` (root `~/Mail/Gmail/.mbsyncstate` plus one per
`.Folder`: `.Drafts`, `.All_Mail`, `.Sent`, `.Spam`, `.Trash`, `.Drafts`, custom labels, ...).

## 6. Two-hop delete-path test — RUN 2026-07-02 (interactive, user-confirmed)

Test message (user-selected, obviously junk, recoverable from Gmail 30-day Trash):
- Envelope id (INBOX): `3008`
- Message-ID: `750490484.27074584.1771276725900@lor1-app120285.prod.linkedin.com`
- From: `LinkedIn <notifications-noreply@linkedin.com>` — "Benjamin, last week your posts got 28 views!"

**Step 1 — `himalaya message delete --folder INBOX 3008` → VERIFIED (local move).**
- exit 0, "Message(s) successfully removed from INBOX!"
- 3008 no longer in INBOX; local Trash file count 54 → 55; the message now appears in
  `~/Mail/Gmail/.Trash` (himalaya Trash id 21), maildir file
  `1771280214.343236_12.hamsa,U=4652:2,S` (flags `S` only).
- **Confirms the corrected delete invariant's first hop:** himalaya's maildir `delete` is a
  move-to-Trash, not a purge.

**Step 2 — `himalaya folder expunge Trash` → NOT RUN (design finding + deferred).**
- **Design finding (feeds Phase 4 contract + #29 handoff):** the moved message carries flags
  `:2,S` only — it is NOT `\Deleted`-flagged. `himalaya folder expunge` removes only
  `\Deleted`-flagged messages, and `find ~/Mail/Gmail/.Trash ... | grep ':2,[^:]*T'` = **0**.
  So `expunge Trash` at this point is a **no-op**; it would neither remove our test message nor
  anything else. The true two-hop local-removal sequence is therefore
  **`himalaya message delete --folder Trash <id>` (sets `\Deleted`) → `himalaya folder expunge
  Trash`** — the wrapper (`email-delete-confirmed --expunge-trash`) must set the Deleted flag
  before expunging. Recorded for the Phase 6 wrapper and the wrapper contract.
- Local-removal execution deferred: it is destructive and was left for interactive confirmation;
  the message remains safely in local Trash (and, because the move never synced, still exists
  server-side in INBOX — it will reconcile once task 46 is fixed).

**Step 3 — `mbsync gmail` (group-scoped, never `-a`) → server-side reconcile BLOCKED on task 46.**
- `gmail-oauth2-refresh.service` = **failed (`invalid_grant`)** at test time.
- `mbsync gmail` returned `[AUTHENTICATIONFAILED] Invalid credentials (Failure)`, exit 1 (the
  stale/invalid XOAUTH2 access token). No server-side change occurred.
- **Server-side All-Mail removal verification is BLOCKED on task 46** (as the plan anticipated).
  Feeds Phase 3 (OAuth gate) and the #29 handoff, which must list this as a #29 precondition —
  never faked locally.

**Net result:** local delete→Trash hop VERIFIED; local expunge hop characterized (needs an
explicit `\Deleted`-flag step — new contract requirement) but not executed; server reconcile
BLOCKED on task 46. The message stays in Trash pending the eventual OAuth fix.

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

## 6. Two-hop delete-path test — PENDING (live-mail action, user-gated)

Deferred: this is the one irreversible live-mail action in Phase 1 (a real delete of one
disposable message, recoverable from Gmail's 30-day Trash) and is being run interactively with the
user. Sequence to execute and record:

1. `himalaya envelope list --folder INBOX -o json` → pick one disposable id.
2. `himalaya message delete --folder INBOX <id>` → confirm it lands in `~/Mail/Gmail/.Trash`.
3. `himalaya folder expunge Trash` → confirm local removal.
4. `mbsync gmail` → **watch for `invalid_grant`.** If it fails (expected while task 46 is open),
   record the local half verified and mark **server-side All-Mail removal BLOCKED on task 46**
   (feeds Phase 3 + the #29 handoff). If it succeeds, confirm the message left `[Gmail]/All Mail`
   server-side.

**Result**: _to be recorded after the user runs the test._

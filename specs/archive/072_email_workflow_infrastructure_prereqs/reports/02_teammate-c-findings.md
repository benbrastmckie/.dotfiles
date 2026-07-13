# Teammate C Findings: Critic Review — Email Workflow Infrastructure Research (Round 2)

**Task**: 72 (.dotfiles) — email workflow infrastructure/prerequisites
**Role**: THE CRITIC — gaps, blind spots, unvalidated assumptions in research quality/completeness
**Date**: 2026-07-02
**Reviewed**: `reports/01_infrastructure-prereqs-seed.md`, `specs/071_.../plans/04_email-workflow-implementation.md` (v3), live `modules/home/email/*.nix`, live system state (himalaya, notmuch, systemd)

## Key Findings

### FINDING 1 (CRITICAL — mechanism claim likely mischaracterized): "IMAP-level Himalaya ONLY" is not what the live config does

Shared Invariant #2 states delete is "IMAP-level Himalaya ONLY" and explicitly contrasts this with
"local Maildir-file `rm` or notmuch-tag+Expunge" as the unsafe alternative. **This framing is not
supported by the live configuration.** Both `config/himalaya-config.toml` accounts declare
`backend.type = "maildir"` (not `imap`) for message operations — confirmed by reading the file
directly (lines 6, 23 and the fuller copy in `docs/himalaya.md` lines 180, 224). Himalaya's
`message delete` / `folder expunge` therefore operate on the **local Maildir**, exactly like the
"unsafe" path the invariant warns against — they do not talk to Gmail's IMAP API directly. The
actual Gmail-side propagation happens only on the subsequent `mbsync gmail` call, which relies on
the channels' `Expunge Both` setting (confirmed present, no `Remove` line, on `gmail-inbox`,
`gmail-trash`, `gmail-all`, etc. in `modules/home/email/mbsync.nix`).

This means the "safe" wrapper path and the "unsafe" notmuch-tag path are **the same underlying
propagation mechanism** (local Maildir flag/move + mbsync `Expunge Both`), and the seed report never
examines *why* Himalaya's flag/move semantics would be more reliable than a raw notmuch tag change
with `maildir.synchronizeFlags = true` (which is enabled — `notmuch.nix:43`). The real distinguishing
factor, if there is one, is almost certainly correctness of the two-step **sequence**
(move-to-Trash, then expunge-Trash-only-after-approval) rather than a transport-layer ("IMAP vs
local") distinction — but the seed asserts the transport-layer framing as settled fact when it
is not. This is exactly the kind of claim the "already gives Gmail-safe primitives (live-verified)"
language in §3/Phase 2 should not have asserted without testing the full two-hop path end-to-end.

**Compounding risk**: because propagation is two-hop (Himalaya-local-op, then a *separate*
`mbsync gmail` call), and mbsync's Gmail channel uses OAuth2/XOAUTH2 (see Finding 3), a local
Himalaya delete can succeed while the Gmail-side propagation silently fails or queues — producing a
false-positive "deleted" state if Phase 7's verification only checks local Maildir file counts
rather than live IMAP/server state on both ends. The plan's Phase 7 task list does say "verify... 
locally and server-side," which is correct, but the seed report's confidence framing undersells how
load-bearing and untested this two-hop assumption actually is.

### FINDING 2 (CRITICAL — unverified premise): the live notmuch index is empty, not "64,316 local msgs"

The seed report (§1, §3, handoff contract) treats notmuch census commands as ready-to-wrap primitives
and cites "64,316 local msgs" as a verified figure. I confirmed the **Maildir file count** is indeed
64,316 (`find ~/Mail/Gmail/.All_Mail/cur -type f | wc -l`). But the **notmuch Xapian index itself is
effectively empty**:
```
$ notmuch count tag:inbox
0
$ notmuch search '*'
(no output)
$ notmuch address --output=sender --output=count --deduplicate=address '*'
(no output)
$ du -sh ~/Mail/.notmuch
28K   /home/benjamin/Mail/.notmuch
```
A 28K Xapian database cannot represent a 64k-message corpus. This means `notmuch new` has not been
run (or has failed) against the current Maildir on this machine, and **every claim that depends on
querying notmuch — census, List-Id tagging, `postNew` junk rules, aerc's own `notmuch://~/Mail`
backend — is currently querying an empty index.** This is not a hypothetical: aerc's account source
is `notmuch://~/Mail` (`aerc.nix:194,204`), so aerc would currently show zero messages in every
view. The seed report's §3 Phase 2 claims these commands were "live-verified"; if that verification
happened, it was not against the current index state, or the index has since gone stale/been wiped.
Either way this is a load-bearing, currently-false assumption that should be verified (`notmuch new`
re-run, confirm count matches Maildir) before Phase 2/8 wrapper work proceeds.

### FINDING 3 (scope mismatch in the OAuth contract): `invalid_grant` detection is specified against the wrong auth path

Task 46's own report (which the seed cites) states plainly: **mbsync uses OAuth2/XOAUTH2** (broken,
currently `invalid_grant`), while **himalaya and aerc use app passwords** (`gmail-app-password`
keyring entry, confirmed working, not subject to the 7-day Testing-mode expiry). I confirmed this is
still the live state:
```
$ systemctl --user status gmail-oauth2-refresh.service
Active: failed (Result: exit-code)
"error": "invalid_grant", "error_description": "Bad Request"
```
The seed's Postmortem-style requirement — "harness must detect `invalid_grant` on any IMAP call, halt
cleanly, preserve the partial manifest" (§3 Phase 1, plan Phase 1 task 3) — is written as if the
Himalaya wrapper commands themselves are the thing that will throw `invalid_grant`. Given Finding 1
(Himalaya operates on the local Maildir via app-password-authenticated SMTP send / maildir backend,
not XOAUTH2 IMAP), **the wrapper binaries calling `himalaya message delete`/`folder expunge` likely
will NOT surface `invalid_grant` at all** — only the separate `mbsync gmail` reconcile step will,
since that's the only component currently using XOAUTH2. The fail-safe contract needs to specify
*which invocation* (`mbsync`, not `himalaya`) is expected to fail, and what "preserve the partial
manifest" means when the failure occurs in a step the wrapper doesn't directly control. This is
under-specified in a way that will force churn during Phase 2 implementation once the real error
surface is discovered.

### FINDING 4 (assertion vs. verification, itemized)

Per the assignment's explicit ask, here is what I could actually confirm live vs. what remains an
unverified assertion in the seed report:

| Claim | Verified? | Evidence |
|---|---|---|
| `himalaya message delete --folder INBOX <id>` moves to Trash (non-Trash folder) | **Confirmed** (CLI help text) | `himalaya message delete --help`: "if the given folder points to the trash folder, it adds the deleted flag... otherwise it moves it to the trash folder" |
| `himalaya folder expunge <folder>` truly deletes flagged messages | **Confirmed** (CLI help), but **mechanism is local-Maildir, not IMAP** (Finding 1) | `himalaya folder expunge --help`; `backend.type = "maildir"` in config |
| `envelope list -o json` fields `id, flags, subject, from.addr, date, has_attachment` | **Confirmed present, but incomplete** — actual output also includes a `to` object | Live command run against local INBOX |
| `notmuch address --output=sender --output=count` (as literally written in the seed) | **False as written** — errors with "notmuch search requires at least one search term"; needs a query arg (e.g. `'*'` or `tag:inbox`) appended | Live command run, exit code non-zero on bare form |
| List-Id needs `notmuch config set index.header.List List-Id` + reindex | **Confirmed not yet configured** | `notmuch config get index.header.List` returns empty; not present in `notmuch.nix` |
| "64,316 local msgs" | **Confirmed for Maildir file count; the notmuch index representing them is empty** (Finding 2) | See Finding 2 |
| mbsync "Expunge Both but no Remove" on primary Gmail channels | **Confirmed, with an unstated exception**: `gmail-folders` (the catch-all custom-folder channel) DOES set `Remove Both` — the seed's blanket claim should note this is not uniform across all channels | `mbsync.nix:83-84` |
| Gmail delete = mix of archive-keepers + true-delete-junk | **Not verified — explicitly flagged as a USER assumption in both documents** | Seed §5, plan "User-Decision Assumptions" |

### FINDING 5 (safety-envelope hole not raised anywhere): aerc's own native delete keybinds bypass the entire wrapper/hook design

`modules/home/email/aerc.nix` already defines, today, in the `messages` and `view` binding tables:
```
d = ":prompt 'Delete message?' 'delete-message'<Enter>";
D = ":delete<Enter>";
a = ":archive flat<Enter>";
A = ":unmark -a<Enter>:mark -a<Enter>:archive flat<Enter>";
```
These are native aerc TUI actions, invoked interactively by a human inside the aerc process — they
never go through Claude Code's Bash tool, so the PreToolUse allowlist hook (Phase 3) **cannot and
will not** intercept them. That is fine for AI-agent safety (the hook's actual job), but it means the
"delete = IMAP-level Himalaya ONLY" invariant, if it is meant as a *system-wide* mutation policy
(not just an AI-agent policy), has an existing, pre-dated hole: a human can already press `D` in aerc
today and trigger a notmuch/Maildir-backed delete-and-sync path that (per Finding 1) is mechanistically
indistinguishable from the "unsafe" path the design is built to avoid. Neither the seed report nor the
v3 plan's Phase 9 (which *adds new* querymap views/keybinds) proposes removing, rebinding, or
warning about the pre-existing `d`/`D`/`a`/`A` bindings. This is a genuine completeness gap in the
research, not an implementation-risk footnote: the "two access paths" invariant (§2.1) never accounts
for this third, already-live, human-operated path through aerc's native message-store commands.

### FINDING 6 (cross-repo dependency not machine-enforced)

nvim task 803's description prose says "DEPENDS ON .dotfiles task 72" but its `dependencies` JSON
field is `[]` (confirmed via `~/.config/nvim/specs/state.json`). Since `dependencies` is a per-repo
field and there is no cross-repo state schema, this is arguably unavoidable given current tooling —
but the seed report should say so explicitly rather than implying the "handoff contract" is the
dependency-tracking mechanism. As written, nothing prevents someone from running `/implement` on nvim
803 before dotfiles 72 has produced the wrapper contract; the coordination is purely
documentation-based (three near-identical seed reports). Given round-3-of-task-71's own postmortem
about the extension forking/orphaning risk, this same "purely documented, not enforced" pattern for
the #72→#803 dependency deserves the same scrutiny.

### FINDING 7 (sequencing gap: OAuth Production-mode timeline unresearched)

Task 46's own report flags, in its own risk table, "Production mode requires verification: Medium
likelihood, delays fix." Google's OAuth verification for sensitive/restricted scopes (and
`https://mail.google.com/` is Google's own example of a **restricted** scope requiring a security
assessment for apps requesting it, per Google's published policy) can take **weeks**, not the ~2 hours
Phase 1 budgets. Neither the seed report nor the v3 plan researches what "publish to Production"
actually requires for this specific scope set (which also includes contacts/calendar/carddav per
`docs/himalaya.md:198`). This is a research gap, not just an implementation risk: recommending
"publish to Production (recommended)" without investigating Google's verification requirements for
this exact scope combination leaves open the possibility that Phase 1's "hard blocker" branch is the
only realistic outcome, which has cascading effects on whether #29's purge can start on the assumed
timeline.

### FINDING 8 (handoff contract under-specification)

The manifest schema in §4 lists fields (`id, sender, subject, date, proposed_action, reason`) but
does not specify: encoding/format of `id` (Maildir message-id? Himalaya envelope id, which is
**per-folder and not globally stable** per Himalaya's own docs — an id in INBOX is not the same id
after the message moves to Trash); the manifest file format (JSON? CSV?) or location convention
beyond "git-tracked"; or how `--confirm-manifest <sha256>` binds to a specific manifest file path
(is the hash alone sufficient to locate the file, or is a path also required?). Given Himalaya
envelope ids are folder-scoped and change on move (confirmed by the `--folder` flag being required on
every id-based subcommand), a manifest generated against INBOX ids will not be directly reusable
against the same messages once `email-delete-confirmed` has moved them to Trash — the wrapper
contract needs to specify whether it re-queries by a stable key (Message-ID header) or accepts that
IDs are single-use per manifest. This is exactly the kind of ambiguity that will force a plan
revision once Phase 2 implementation starts, and it is the "key handoff" nvim #803 is meant to author
against.

## Recommended Approach

Before this task proceeds to planning, verify/ask:

1. **Re-run `notmuch new` and confirm the index actually reflects the 64,316-message Maildir**
   (Finding 2) — this blocks any believable census/classification design, and blocks confirming
   whether aerc even currently shows real mail.
2. **Empirically test the full two-hop delete path** (Himalaya local move+expunge, then a live
   `mbsync gmail` reconcile) on one disposable message, and verify server-side removal from All_Mail
   — not just local file-count deltas — before asserting "IMAP-level Himalaya" is a safe/verified
   mechanism (Finding 1). This is what Phase 7 already plans to do; the seed report should stop
   presenting the mechanism as settled ahead of that test.
3. **Clarify which component (`himalaya` vs `mbsync`) is expected to raise `invalid_grant`**, and
   rewrite the fail-safe contract against the correct call site (Finding 3) — this affects the
   `email-delete-confirmed`/`email-archive-confirmed` wrapper design directly (does the wrapper need
   invalid_grant handling at all, or does `email-freeze`/`email-thaw`'s `mbsync` call need it?).
4. **Research Google's actual verification requirements/timeline** for publishing this specific OAuth
   client (scopes: `mail.google.com`, contacts, calendar, carddav) to Production before committing to
   Phase 1's ~2-hour estimate or recommending Production-publish as "the" fix (Finding 7).
5. **Decide explicitly whether the pre-existing aerc `d`/`D`/`a`/`A` keybinds are in-scope for this
   task** — either rebind/disable them so all delete/archive actions route through the wrapper+manifest
   flow, or explicitly document that human-operated aerc deletes remain outside the guardrail system
   by design (Finding 5). Silence on this is itself a gap.
6. **Fix the manifest ID-stability question** (Finding 8) before nvim #803 authors the
   `email-implementation-agent`'s tool-usage contract against it — a Message-ID-keyed manifest is
   probably correct but is not what's currently specified.
7. Confirm the exact `notmuch address ...` invocation with a required query term (Finding 4) so the
   wrapper's `email-census` implementation isn't drafted against a command that errors as literally
   documented.
8. The two USER-decision assumptions (delete=mix, scope=split) are correctly scoped as blocking only
   for #29's destructive phases, not for #72's infrastructure build — I did not find evidence that
   this task's own deliverables (wrapper scaffolding, hook, freeze/thaw, aerc querymap, notmuch
   scaffolding) require those decisions to be made first. That framing in the seed is sound.

## Evidence/Examples

All findings above are backed by direct command output or direct file reads performed during this
review (himalaya v1.2.0 CLI help and live JSON output; `notmuch count`/`search`/`address` against the
live `~/Mail` database; `systemctl --user status gmail-oauth2-refresh.{service,timer}`; direct reads
of `modules/home/email/{mbsync,notmuch,aerc}.nix`, `config/himalaya-config.toml`, `docs/himalaya.md`,
`specs/046_.../reports/01_gmail-oauth2-token-expiry.md`, and both repos' `state.json`). No web search
was needed or used — this review is entirely live-system and local-document verification, consistent
with the task's Tier 2 (docs/code) grounding.

## Confidence Level

- **High confidence**: Findings 2, 3, 4, 6, 7 (directly reproduced via commands or direct quotation of
  existing artifacts; not open to interpretation).
- **Medium-high confidence**: Finding 1 (the `backend.type = "maildir"` fact is certain; the inference
  that this undermines the "IMAP-level" safety framing is a reasoned analysis, not itself a live test —
  Phase 7's planned single-message dry run is the correct way to settle it definitively).
- **Medium confidence**: Finding 5 (the keybind bypass is factually present in config; whether it
  should be considered "in scope" for this task's safety envelope is a design judgment call, not a
  verifiable fact).
- **Medium confidence**: Finding 8 (Himalaya's per-folder envelope-id behavior is documented CLI
  behavior; whether it actually breaks the manifest workflow as designed depends on implementation
  choices not yet made).

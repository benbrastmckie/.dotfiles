# Research Report: Task #79

**Task**: 79 - Extend the five email agent wrapper binaries in `agent-tools.nix` to support the
Logos (Protonmail Bridge) account, generalizing the Gmail-only task-72 contract into real
per-account branching.
**Started**: 2026-07-04T13:00:00-07:00
**Completed**: 2026-07-04T13:15:00-07:00
**Effort**: Medium (single-file nix/bash edit, ~150-250 changed lines across 5 `writeShellScriptBin`
blocks + shared preambles; no new backend infra required)
**Dependencies**: task 72 (frozen wrapper contract + Logos backend scaffolding — already merged)
**Sources/Inputs**: `modules/home/email/agent-tools.nix` (full read), `mbsync.nix:110-197`,
`notmuch.nix:1-40`, `aerc.nix:225-260`, live `notmuch`/`himalaya` probes against this machine's real
`~/Mail` database, `specs/state.json` task-79 description, companion handoff report
`reports/01_nvim-extension-handoff.md` (read to confirm out-of-scope boundary), git diff of the
uncommitted `CUSTOM_KEEP_SENDERS` hand-edit.
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `agent-tools.nix` (721 lines) has exactly **8 Gmail-hardcoded sites** that must become
  per-account: the `--account` gate, two default-`QUERY` assignments, the census folder-count
  block, the maildir rel-path strip, the `mbsync gmail` reconcile step (5 references), the
  himalaya calls (all missing an explicit `-a`/account flag today, relying on the implicit
  himalaya default account = `gmail`), and the archive/delete move targets (`All_Mail`
  hardcoded).
- The Logos maildir is **folder-based, not label-based**: exactly four real IMAP folders exist
  locally under maildir++ dot-prefixed dirs — `.Sent` (12 msgs), `.Archive` (54), `.Drafts` (10),
  `.Trash` (1764) — plus the bare maildir root itself as the implicit INBOX (62 msgs, matching
  mbsync's `Inbox ~/Mail/Logos/` setting). **There is no `.All_Mail` and no `.Spam` for Logos** —
  confirmed via `notmuch count` and `himalaya folder list -a logos` (only `Sent`/`Archive`/
  `Drafts`/`Trash` rows; no All_Mail/Spam row). Non-dot `INBOX`/`Sent`/`Drafts`/`Trash`/`Archive`
  subdirectories also physically exist under `~/Mail/Logos/` but are **empty stray directories**
  (`folder:Logos/INBOX` etc. all count 0) — they must not be queried or used as move targets.
- **Operational caveat unrelated to task 79 but relevant to design choice**: the notmuch
  `postNew` account/folder tags (`+gmail`, `+logos`, `+sent`, `+trash`, `+spam`,
  `tag:inbox`) declared in `notmuch.nix:26-31` have **never actually been applied** to any
  message in the live database — `notmuch count 'tag:logos'`, `'tag:gmail'`, `'tag:inbox'`,
  `'tag:sent'`, `'tag:trash'` all return `0`, even though `folder:/Logos/` (regex) returns 1902 and
  `folder:/Gmail/` returns 65582. This confirms the task description's instinct is correct: the
  wrapper's account-scoping must key off **`folder:` queries**, never `tag:gmail`/`tag:logos` —
  a tag-based design would silently return zero results today.
- himalaya's Maildir backend treats both accounts identically at the plumbing level (`himalaya
  account list` shows **both** `gmail` and `logos` as `Maildir, SMTP` — Gmail is *also* accessed
  via local Maildir, not IMAP-direct, in this setup). This means the delete/archive *mechanism*
  (himalaya `message move` / `message delete` / `folder expunge`, two-hop delete) is
  account-agnostic and needs **zero logic changes** — only the folder-name arguments and the
  `-a <account>` flag differ per account.
- Recommended design: a single per-account **resolver block** near the top of the shared
  preamble (`mkPreamble`) that sets shell variables (`ACCOUNT_FOLDER`, `ACCOUNT_MAILDIR_REL`,
  `ACCOUNT_MBSYNC_GROUP`, `ACCOUNT_ARCHIVE_FOLDER`) via a `case "$ACCOUNT" in gmail|logos|*)`
  statement, plus a `HIMALAYA_ACCT_FLAG=(-a "$ACCOUNT")` array spliced into every himalaya
  invocation. `gmail` stays first in the case and its resolved values are byte-identical to
  today's hardcoded literals, so a bare invocation with no `--account` flag is unchanged.

## Context & Scope

This report covers **only** the `.dotfiles` nix/bash work in `modules/home/email/agent-tools.nix`
per task 79's scope. The companion nvim `email/` extension UX work (account selector in
`commands/email.md`, `BASE_QUERY` account-awareness in `skill-email-cleanup`, `mbsync` channel
default in `skill-email-sync`) is **out of scope** — that work is documented in
`specs/079_email_wrappers_multi_account/reports/01_nvim-extension-handoff.md` and is explicitly
sequenced to depend on this task landing + `home-manager switch` first. Nothing in this report
re-scopes or duplicates that companion report's content.

## Findings

### 1. Every Gmail-hardcoded site in `agent-tools.nix` (line-numbered, exact current text)

| # | Location | Current text | Used by |
|---|----------|--------------|---------|
| 1 | `agent-tools.nix:37` | `ACCOUNT="gmail"` | `mkPreamble` (all 5 binaries) |
| 2 | `agent-tools.nix:48` | `--account <gmail>       Reserved; only "gmail" is accepted (default: gmail)` | help text |
| 3 | `agent-tools.nix:70-74` | `if [ "$ACCOUNT" != "gmail" ]; then` … `log "ERROR: --account only accepts 'gmail'..."` … `exit 1` | the hard reject gate |
| 4 | `agent-tools.nix:175` | `local rel="''${filepath#*/Mail/Gmail/}"` (inside `resolve_folder_from_path`, used by both mutation binaries via `mkMutationPreamble`) | envelope-id resolution |
| 5 | `agent-tools.nix:255,259,268,271,277` | `mbsync gmail` (comment + literal invocation `out=$(mbsync gmail 2>&1)` + log lines) inside `run_mbsync_reconcile` | both mutation binaries, post-execute reconcile |
| 6 | `agent-tools.nix:295,298-303` | `echo "=== email-census (account: gmail) ==="` then 6 `notmuch count 'folder:Gmail...'` lines (bare, `.All_Mail`, `.Sent`, `.Trash`, `.Spam`, `.Drafts`) | `email-census` |
| 7 | `agent-tools.nix:313` | `n=$(notmuch count "folder:Gmail and date:$y-01-01..$y-12-31" ...)` | `email-census` date-bucket loop |
| 8 | `agent-tools.nix:319` | `himalaya envelope list -f INBOX -o json -s 10 2>/dev/null` (no `-a` flag — relies on himalaya's implicit default account) | `email-census` sample |
| 9 | `agent-tools.nix:334,344` | help text `[QUERY] ... (default: "folder:Gmail" = INBOX)` + `QUERY="folder:Gmail"` | `email-classify` |
| 10 | `agent-tools.nix:204,207,212` | `himalaya envelope list -f "$folder" -o json -s 5000 ...` / `himalaya message read "$eid" -f "$folder" -p -H Message-Id` (no `-a`) | `resolve_envelope_id` (both mutation binaries) |
| 11 | `agent-tools.nix:495,504` | help text `[QUERY] ... (default: "folder:Gmail" = INBOX)` + `QUERY="folder:Gmail"` | `email-unsubscribe-extract` |
| 12 | `agent-tools.nix:549,582,585,586` | comment `move approved 'archive' IDs to All_Mail`, log lines `-> All_Mail`, and `himalaya message move All_Mail "$RESOLVED_ENVELOPE_ID" -f "$RESOLVED_FOLDER"` (no `-a`) | `email-archive-confirmed` |
| 13 | `agent-tools.nix:669,701,712` | `himalaya message delete "$RESOLVED_ENVELOPE_ID" -f "$RESOLVED_FOLDER"` (hop 1), `himalaya message delete "$RESOLVED_ENVELOPE_ID" -f Trash` (hop 2), `himalaya folder expunge Trash` (no `-a` on any) | `email-delete-confirmed` |

**Important nuance on #8/#10/#13**: none of the current himalaya invocations pass an explicit
`-a`/`--account` flag anywhere in the file. They all rely on himalaya's own config-level default
account, which `himalaya account list` shows is `gmail` (`DEFAULT` column = `yes`). This means the
Logos branch **must** add `-a "$ACCOUNT"` (or equivalent) to every himalaya call site, while the
Gmail branch can either keep omitting it (relying on the default) or also pass `-a gmail`
explicitly for symmetry — passing it explicitly for both is safer against a future default-account
change in `~/.config/himalaya/config.toml` and is recommended so both branches are equally
explicit, not just Logos.

### 2. Confirmed Logos local folder tokens (live probes on this machine)

```
$ notmuch count 'folder:Logos'          # bare root = INBOX per mbsync `Inbox ~/Mail/Logos/`
62
$ notmuch count 'folder:Logos/.Sent'
12
$ notmuch count 'folder:Logos/.Archive'
54
$ notmuch count 'folder:Logos/.Trash'
1764
$ notmuch count 'folder:Logos/.Drafts'
10
$ notmuch count 'folder:Logos/INBOX'    # stray empty subdir — do NOT use
0
$ notmuch count 'folder:Logos/Sent'     # stray non-dot subdir — do NOT use
0
$ notmuch count 'folder:Logos/Trash'    # stray non-dot subdir — do NOT use
0
$ notmuch count 'folder:Logos/Drafts'   # stray non-dot subdir — do NOT use
0
$ notmuch count 'folder:Logos/Archive'  # stray non-dot subdir — do NOT use
0
```

`himalaya folder list -a logos` corroborates exactly four named folders (`Sent`, `Archive`,
`Drafts`, `Trash`; no `INBOX` row is listed because root is always the implicit default folder for
a Maildir backend — same as Gmail, whose `himalaya folder list -a gmail` also omits an `INBOX` row
but lists `Spam`, `All_Mail`, `EuroTrip`, `Sent`, `Letters`, `Drafts`, `CrazyTown`, `Trash`).

**Conclusion**: the Logos census/query folder set is **`INBOX` (bare `folder:Logos`), `Sent`,
`Archive`, `Drafts`, `Trash`** — five entries, mirroring Gmail's census block structurally but
completely replacing `All_Mail`/`Spam` (neither exists for Logos) with `Archive` (which Gmail's
census block doesn't currently show at all, since Gmail archive = `All_Mail` under the label
model).

**Tag-based scoping is currently non-viable** (see Executive Summary) — `tag:logos`, `tag:gmail`,
`tag:inbox` are all `0` in the live database because the `notmuch.nix:26-31` `postNew` hook rules
that would populate them have apparently never executed (no `~/Mail/.notmuch/hooks/` directory
even exists, and `folder:/Logos/`/`folder:/Gmail/` regex-folder counts are non-zero, confirming the
raw mail is indexed — only the *tag* application step is inert). This is **not** task 79's bug to
fix (it's a `notmuch.nix` hook wiring issue, out of scope), but it is the reason the wrapper design
must resolve account scope via `folder:` queries exclusively, never via `tag:<account>`.

### 3. Recommended per-account branching design

Add a single resolver near the top of `mkPreamble` (after the `--account`/`--manifest-dir` flag
parse loop, replacing the current hard-reject block at lines 70-74):

```bash
case "$ACCOUNT" in
  gmail)
    ACCOUNT_FOLDER="Gmail"
    ACCOUNT_MAILDIR_MARKER="/Mail/Gmail/"
    ACCOUNT_MBSYNC_GROUP="gmail"
    ACCOUNT_ARCHIVE_FOLDER="All_Mail"
    ;;
  logos)
    ACCOUNT_FOLDER="Logos"
    ACCOUNT_MAILDIR_MARKER="/Mail/Logos/"
    ACCOUNT_MBSYNC_GROUP="logos"
    ACCOUNT_ARCHIVE_FOLDER="Archive"
    ;;
  *)
    log "ERROR: --account only accepts 'gmail' or 'logos' (got: '$ACCOUNT')"
    log "Unknown accounts are rejected; see wrapper-contract.md for the supported set."
    exit 1
    ;;
esac
HIMALAYA_ACCT=(-a "$ACCOUNT")
```

Then thread these through every site from the table in Finding 1:

- **Default `QUERY`** (sites #9, #11 — `email-classify`, `email-unsubscribe-extract`): change
  `QUERY="folder:Gmail"` to `QUERY="folder:$ACCOUNT_FOLDER"`. Must be set *after* the resolver
  runs (mutation/classify preambles already run after `mkPreamble`, so ordering is fine).
- **`resolve_folder_from_path`** (site #4, line 175): change the hardcoded marker to
  `"''${filepath#*$ACCOUNT_MAILDIR_MARKER}"`. The rest of the function (the
  `cur|new|tmp -> INBOX`, `.*` strip, fallback) is already account-agnostic and needs no change —
  it was written generically even though only Gmail exercised it before.
- **`run_mbsync_reconcile`** (site #5): parameterize the literal `gmail` to
  `"$ACCOUNT_MBSYNC_GROUP"` in the `mbsync $ACCOUNT_MBSYNC_GROUP` invocation and update the log
  strings to interpolate the group name instead of hardcoding "gmail" in the English text (keep
  the **never `mbsync -a`** comment verbatim — it remains true and important for both accounts).
- **Census block** (sites #6, #7, #8): replace the fixed 6-line block with a per-account table.
  Simplest correct approach — a bash associative concept via a small case-driven list, e.g.:
  ```bash
  echo "=== email-census (account: $ACCOUNT) ==="
  printf "%-10s %s\n" "INBOX" "$(notmuch count "folder:$ACCOUNT_FOLDER")"
  case "$ACCOUNT" in
    gmail)
      printf "%-10s %s\n" "All_Mail" "$(notmuch count 'folder:Gmail/.All_Mail')"
      printf "%-10s %s\n" "Sent"     "$(notmuch count 'folder:Gmail/.Sent')"
      printf "%-10s %s\n" "Trash"    "$(notmuch count 'folder:Gmail/.Trash')"
      printf "%-10s %s\n" "Spam"     "$(notmuch count 'folder:Gmail/.Spam')"
      printf "%-10s %s\n" "Drafts"   "$(notmuch count 'folder:Gmail/.Drafts')"
      ;;
    logos)
      printf "%-10s %s\n" "Sent"     "$(notmuch count 'folder:Logos/.Sent')"
      printf "%-10s %s\n" "Archive"  "$(notmuch count 'folder:Logos/.Archive')"
      printf "%-10s %s\n" "Trash"    "$(notmuch count 'folder:Logos/.Trash')"
      printf "%-10s %s\n" "Drafts"   "$(notmuch count 'folder:Logos/.Drafts')"
      ;;
  esac
  ```
  This preserves the Gmail branch byte-for-byte (same 6 lines, same literal queries) while giving
  Logos its real, verified folder set instead of inventing `.All_Mail`/`.Spam` queries that would
  silently return `0` forever. The date-bucket loop (site #7) only needs
  `folder:$ACCOUNT_FOLDER and date:...` substituted for `folder:Gmail and date:...` — no other
  change, it's already generic per-year.
- **himalaya calls** (sites #8, #10, #12, #13): splice `"''${HIMALAYA_ACCT[@]}"` into each
  invocation, e.g. `himalaya envelope list "''${HIMALAYA_ACCT[@]}" -f "$folder" -o json -s 5000
  ...`. Recommend doing this for **both** branches (not just Logos) so `-a gmail` is explicit and
  the code path is symmetric — this is a behavior-preserving change since himalaya's default
  account is already `gmail`.
- **Archive move target** (site #12): replace the hardcoded `All_Mail` literal (comment, two log
  lines, and the `himalaya message move All_Mail ...` call) with `$ACCOUNT_ARCHIVE_FOLDER`. For
  `gmail` this resolves to `All_Mail` (unchanged behavior); for `logos` it resolves to `Archive`
  (a real Proton folder, confirmed to exist via `himalaya folder list -a logos`).
- **Delete two-hop** (site #13): no folder-name change needed beyond the existing
  `$RESOLVED_FOLDER` (hop 1, already generic) and the literal `Trash` (hop 2 + expunge) — `Trash`
  is a real, identically-named folder for both accounts (confirmed via both `himalaya folder
  list` outputs), so this site needs **only** the `HIMALAYA_ACCT` flag added, no folder-name
  parameterization.
- **Help text** (sites #2, #9, #11): update `--account <gmail>` to `--account <gmail|logos>` and
  the default-query comments to name both folder tokens generically (e.g. `default:
  "folder:<Account>"`) or just say "the account's INBOX".

This design keeps `gmail` as the **first** `case` branch with values textually identical to
today's literals, satisfying the "bare invocations byte-for-byte unchanged" requirement — the
Gmail resolved variables are the same strings the code currently hardcodes, so every
Gmail-scoped notmuch query, log line, and himalaya call produces character-identical output to the
pre-task-79 binary.

### 4. Proton archive/delete semantics vs Gmail — recipe design

Gmail's IMAP-delete-via-label model means a Gmail "archive" or "delete" through this wrapper is
really a **label move**: `himalaya message move All_Mail ...` moves the message into the
`All_Mail` label-folder (which, under Gmail's model, every message is already a member of by
default — hence the task-72 "correctness concern" that a *delete* alone, without confirming the
message actually lands in `All_Mail`/`Trash`, could leave stale label state). Proton, by contrast,
is genuinely folder-based over the Bridge — `Archive` and `Trash` are real, distinct maildir
folders with no overlapping "everything" folder. Concretely:

- **Logos archive** = `himalaya message move Archive "$eid" -f "$folder" ''${HIMALAYA_ACCT[@]}"`
  — a real, unambiguous move into the `Archive` folder (54 messages already live there from prior
  manual use), mechanically identical to the Gmail `move All_Mail` call, just a different target
  folder name resolved via `$ACCOUNT_ARCHIVE_FOLDER`.
- **Logos delete** = the same two-hop dance already implemented for Gmail: hop 1
  `himalaya message delete "$eid" -f "$folder" ''${HIMALAYA_ACCT[@]}"` (moves to `Trash`, 1764
  messages already there), hop 2 (`--expunge-trash`) flags `\Deleted` in `Trash` then
  `himalaya folder expunge Trash ''${HIMALAYA_ACCT[@]}"`. No new code branch needed — the two-hop
  *mechanism* is account-agnostic (it operates purely on himalaya Maildir move/delete/expunge
  primitives), it just needs the `HIMALAYA_ACCT` flag threaded through, same as every other
  himalaya call site.
- **Still wrapper-only, still no raw `rm`**: nothing in this design introduces or requires a
  filesystem-level delete; both archive and delete stay expressed purely as `himalaya message
  move`/`message delete`/`folder expunge` invocations, matching the CLAUDE.md safety invariant
  ("Delete is IMAP/maildir-level Himalaya only, never a raw filesystem `rm` against Maildir").

### 5. Preserving task-72 safety invariants

All of the frozen invariants live in `mkPreamble`/`mkMutationPreamble` and are **untouched** by
this design — the per-account resolver is additive, inserted after the existing flag-parse loop
and before `mkdir -p "$MANIFEST_DIR"` (line 76):

- `MAX_BATCH_SIZE=50` (line 34) and `PLAN_EXPIRY_DAYS=7` (line 35) — unchanged, account-agnostic
  constants; no reason to make these per-account.
- Dry-run-by-default + `--execute --confirm-manifest <sha256>` gate (lines 90-146) — entirely
  above/independent of the account resolver; no change needed.
- `MANIFEST_DIR`/`MANIFEST_FILE`/`STATE_FILE` resolution (lines 38, 108-111) — task 79's scope
  note doesn't ask for per-account manifest directories, and the description doesn't request it;
  recommend leaving `MANIFEST_DIR` shared (both accounts' approved/candidate manifests coexist in
  the same `specs/072_.../manifests/` dir, distinguished by the `account` field the classify
  binary should stamp into each manifest row — see Decision below). This avoids scope creep into
  a manifest-schema change; if a later task wants per-account manifest isolation, that's a
  separate, explicit decision.
- **`never mbsync -a`** invariant (contract §7, `mbsync.nix:13` comment) — preserved: the
  resolver only ever supplies `$ACCOUNT_MBSYNC_GROUP` (either literal `gmail` or `logos`) to a
  group-scoped `mbsync $GROUP` call; no code path constructs `mbsync -a`.
- **`CUSTOM_KEEP_SENDERS` hand-edit** (agent-tools.nix:401-404, confirmed via `git diff`):
  the working tree already has an uncommitted edit adding three Proton addresses
  (`noae@protonmail.com`, `rob.mckie1235@proton.me`, `andy.stace@protonmail.com`) to the
  keep-list. This is inside `email-classify`'s Tier-1 rule tables, which are account-agnostic by
  design (the classifier runs against whatever `QUERY` scope it's given, regardless of account) —
  **no reconciliation conflict**: the hand-edit is a content addition orthogonal to the
  branching work in this task and should simply be kept as-is (it must not be reverted or
  clobbered by the implementer's edits to the surrounding function).

### 6. Contract revision documentation

Task-72's `wrapper-contract.md` (referenced throughout the file's header comments, e.g. lines
1-3, 22, 32, 83) froze `--account gmail` as a reserved-but-single-valued flag with explicit
language ("Protonmail/Logos are out of scope; the flag is reserved for future multi-account
support" — line 72, verbatim in the current reject message). Task 79 is exactly the anticipated
follow-on that lifts this reservation. The plan produced from this report should:

- Update the in-file header comment block (lines 1-16) to note that `--account` now accepts a
  real second value (`logos`), superseding the "Logos/Bridge is deferred" framing that appears
  there and in the `run_mbsync_reconcile` comment (line 256: "that would also touch the deferred
  Logos/Bridge account" — this phrase becomes stale and should be reworded to reflect that Logos
  is no longer deferred, just still isolated from Gmail by the group-scoped `mbsync` call).
  Also line 12-14 attributes the maildir++ folder-name mapping fact "verified against the live
  system" only for the Gmail probe; the implementer's own new Logos probes (this report's
  Finding 2) should be cited there too once landed.
- Note explicitly (e.g. in the task's implementation summary, or a short addendum to
  `wrapper-contract.md` if the plan chooses to touch it) that the `--account` dimension is now a
  real enum `{gmail, logos}` rather than a single frozen literal, and that adding a third account
  in the future means extending exactly the one `case` statement introduced by this design plus
  the account's backend prerequisites (mbsync IMAPAccount + Group, notmuch tag rule, maildir dirs,
  himalaya account, aerc account) — i.e., document the "foundation for future multi-account"
  framing from the task title concretely as "extend one case statement," not "rewrite the
  wrappers again."

### 7. Verification approach

1. **Build**: `home-manager build --flake .#benjamin` (confirmed correct flake output name via
   `flake.nix:80,193` and prior task-72 plan/summary artifacts, which used this exact command at
   every nix-touching phase).
2. **Gmail regression (byte-for-byte)**: `email-census` with no `--account` flag; diff its output
   against a pre-change capture (or simply confirm the six census lines, the himalaya sample, and
   the date-bucket loop are unchanged) — the case-branch design in Finding 3 guarantees this by
   construction (gmail branch = today's literals), but an actual before/after `diff` of
   `email-census` stdout is the cheap concrsurrent confirmation.
3. **Logos dry-run smoke test**: `email-census --account logos` should print the five-row Logos
   folder set (INBOX/Sent/Archive/Drafts/Trash — no All_Mail/Spam rows) with the live counts this
   report captured (62/12/54/10/1764, modulo any mail arriving between now and implementation).
   `email-classify --account logos --limit 5` (dry-run local-tags-only; safe to actually run since
   it never touches IMAP/maildir) should classify against `folder:Logos` instead of `folder:Gmail`.
   For the mutation binaries, a dry-run (no `--execute`) plan against a hand-built tiny approved
   manifest with `logos`-account message IDs is the safe verification path — never `--execute`
   against production Logos mail during verification.
4. **Unknown-account rejection**: `email-census --account work` (or any third value) must still
   exit 1 with an actionable error, exercising the `case ... *)` fallthrough branch.
5. **`nix flake check`** (or at minimum `home-manager build`, which already evaluates the whole
   module) catches any bash-in-nix interpolation/quoting mistakes in the new `case` block and
   `HIMALAYA_ACCT` array splices before they'd surface at runtime.

## Decisions

- Use **`folder:`-scoped** account resolution exclusively (never `tag:gmail`/`tag:logos`) —
  justified by the live finding that the tag-based scheme is currently inert (Finding 2).
- Keep **`gmail` as the first, default-preserving branch** of a `case "$ACCOUNT" in gmail|logos|*)`
  statement, replacing the current binary if/reject at lines 70-74, rather than introducing a
  lookup table/associative array (bash 3-compatible `writeShellScriptBin` scripts in this repo
  don't currently use associative arrays elsewhere, and a `case` statement is the more idiomatic,
  more readable fit for exactly two-then-N accounts).
- Keep the census folder set **per-account, hand-listed** (Finding 3) rather than trying to derive
  it dynamically from `himalaya folder list` — the Gmail set already hardcodes exactly which
  folders matter (`All_Mail`, not e.g. `Letters`/`EuroTrip`/`CrazyTown` which also exist), so
  Logos should get the same hand-curated treatment (`Archive`, not attempt to auto-discover).
- **Do not** introduce per-account manifest directories/files in this task — out of scope per the
  task description; manifests stay shared, differentiated by an `account` field the plan should
  add to the JSON schema `email-classify` emits (both candidate and approved-append paths) so a
  human/aerc reviewer and the mutation binaries can tell which account a given manifest row
  belongs to. (If the plan decides this schema change is itself out of scope, the fallback is:
  mutation binaries must be invoked with the SAME `--account` value that was used to classify a
  given manifest's rows, since `resolve_envelope_id`'s folder resolution now depends on
  `$ACCOUNT_MAILDIR_MARKER` — invoking `email-archive-confirmed --account gmail` against a
  manifest built from a Logos classify run would resolve folders incorrectly.)
- Add `-a "$ACCOUNT"` (via a `HIMALAYA_ACCT` array) to **every** himalaya call for **both**
  accounts, not just Logos — see Finding 1 nuance under sites #8/#10/#12/#13.

## Risks & Mitigations

- **Risk**: a manifest built under `--account logos` gets fed to a mutation binary invoked with
  the default (`gmail`) — since neither the manifest file format nor the mutation binaries
  currently record/require the account. **Mitigation**: see the manifest `account`-field decision
  above; at minimum, the plan should have the implementer add a defensive check (compare a
  manifest-embedded `account` field, if the schema change is adopted, against the invoked
  `$ACCOUNT`, refusing execution on mismatch) — or, if the schema change is deferred, document the
  operator responsibility loudly in `--help` text and the task's implementation summary.
- **Risk**: Proton/Bridge availability — `mbsync logos` requires the `protonmail-bridge` service
  (enabled per `protonmail.nix`) to be running locally on `127.0.0.1:1143`; a Logos dry-run
  (census, classify) never touches mbsync/Bridge (notmuch-only), but `--execute` mutation +
  reconcile will fail loudly (non-auth-failure path, since Bridge-down is a connection refusal,
  not an `invalid_grant`/`AUTHENTICATIONFAILED` string) if Bridge isn't up. The existing
  `is_mbsync_auth_failure` matcher won't catch this failure mode — that's fine, it already falls
  through to the generic "exited non-zero for a reason OTHER than an auth failure" branch (line
  271), which surfaces the raw output either way; no code change needed, just don't expect the
  auth-specific guidance for a Bridge-down scenario.
- **Risk**: the stray non-dot `INBOX`/`Sent`/`Drafts`/`Trash`/`Archive` directories under
  `~/Mail/Logos/` (all empty, confirmed Finding 2) could tempt a future edit to reference them
  literally (e.g. copy-pasting a Gmail-style bare `Sent` folder name). **Mitigation**: this report
  explicitly documents that only the dot-prefixed maildir++ folders are real/live; the plan should
  carry this table forward verbatim so the implementer doesn't have to re-derive it.
- **Risk**: `notmuch count` result drift between this research pass and implementation (mail
  continues arriving). **Mitigation**: the *shape* of the finding (which folders exist, dot vs
  non-dot, All_Mail/Spam absent) is structural and stable; only the specific counts (62/12/54/
  10/1764) are point-in-time and are cited only as illustrative confirmation, not as values to
  hardcode anywhere in the implementation.

## Appendix

### Search/verification commands used

```
notmuch --version                                     # 0.40
notmuch count 'folder:Logos'                          # 62 (root = INBOX)
notmuch count 'folder:Logos/.Sent'                     # 12
notmuch count 'folder:Logos/.Archive'                  # 54
notmuch count 'folder:Logos/.Trash'                    # 1764
notmuch count 'folder:Logos/.Drafts'                   # 10
notmuch count 'folder:Logos/INBOX'                     # 0 (stray empty dir)
notmuch count 'folder:Logos/Sent|Trash|Drafts|Archive' # 0 each (stray empty dirs)
notmuch count 'tag:gmail' / 'tag:logos' / 'tag:inbox'  # 0 / 0 / 0 (postNew hook inert)
notmuch count 'folder:/Logos/' / 'folder:/Gmail/'      # 1902 / 65582 (regex folder, raw indexed)
himalaya account list                                  # gmail (default) + logos, both Maildir+SMTP
himalaya folder list -a logos                          # Sent, Archive, Drafts, Trash (no All_Mail/Spam)
himalaya folder list -a gmail                          # Spam, All_Mail, EuroTrip, Sent, Letters, Drafts, CrazyTown, Trash
find ~/Mail/Logos -maxdepth 2                          # confirmed dot vs non-dot dir split
git diff -- modules/home/email/agent-tools.nix         # confirmed CUSTOM_KEEP_SENDERS hand-edit at 401-404
```

### References

- `modules/home/email/agent-tools.nix` (full file, 721 lines) — primary edit target.
- `modules/home/email/mbsync.nix:110-197` — Logos `IMAPAccount`/`Group logos` backend (already
  merged, task-72 scaffolding).
- `modules/home/email/notmuch.nix:1-40` — account/folder tag rules (confirmed currently inert).
- `modules/home/email/aerc.nix:225-260` — `[logos]` account + `querymap-logos` (already merged).
- `specs/079_email_wrappers_multi_account/reports/01_nvim-extension-handoff.md` — companion,
  out-of-scope UX layer, confirmed not re-scoped by this report.
- `specs/072_email_workflow_infrastructure_prereqs/plans/02_email-infra-wrappers.md` — prior
  wrapper-contract plan, source of the `home-manager build --flake .#benjamin` verification
  convention and the frozen safety invariants this report preserves.

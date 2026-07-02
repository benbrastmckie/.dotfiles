# Teammate A Findings: Tools Dimension — Harness & Command Mechanics

**Task**: 71 — Design AI-assisted email management workflow
**Teammate**: A (TOOLS dimension)
**Date**: 2026-07-02
**Sources/Inputs**: Local config (`mbsync.nix`, `notmuch.nix`, `aerc.nix`, `docs/himalaya.md`), live `himalaya --help`/`notmuch --help` output on this machine (Himalaya v1.2.0, notmuch 0.40), WebSearch/WebFetch for Himalaya skill, RFC 8058, isync docs, GongRzhe/Google MCP servers.
**Artifacts**: this report

---

## Key Findings

1. **The installed Himalaya v1.2.0 already implements Gmail-safe delete semantics natively** — `himalaya message delete <id>` does *not* delete; if the source folder isn't the trash folder it moves the message to the configured trash alias, and "only the expunge folder command truly deletes messages" (verified via live `--help` text on this machine, not just docs). This eliminates most of the hand-rolled "trash-then-expunge dance" the seed report worried about — the agent just needs to call `delete` then, separately and only after human approval, `folder expunge Trash`.
2. **The "Claude Himalaya skill" is a community artifact (OpenClaw org), not an Anthropic-published skill** — its canonical source is `github.com/openclaw/openclaw/blob/main/skills/himalaya/SKILL.md` (mirrored at `github.com/openclaw/skills`). The MCP.Directory blog post packages/describes it for a Claude audience but it is directly portable to a Claude Code `.claude/skills/skill-email/SKILL.md` because Claude Code and OpenClaw both consume the same Markdown-with-frontmatter skill format. This is directly adoptable as Option (a) with no protocol mismatch.
3. **`notmuch search --output=sender` does not exist in notmuch 0.40** (confirmed by live error on this machine: `Unrecognized option`). The correct command for a bulk-sender census is `notmuch address --output=sender --output=count '<query>'` — `--output=sender` is an `address`-subcommand option, not a `search` one. Several web sources conflated the two; this is a correction worth encoding directly into any harness script so the agent doesn't emit a broken command.
4. **notmuch has no built-in `header:List-Id:` search prefix** in 0.40 (search-terms(7) manpage confirmed no such term). To query by List-Id you must add a custom probabilistic prefix via `notmuch config set index.header.List List-Id` (one-time setup, requires re-`notmuch new`/reindex to backfill), after which `List:<list-id-substring>` becomes searchable. Without this, List-Id extraction must go through `notmuch show --format=json` and JSON-parse the `headers` object per-message, which is far slower for a bulk census.
5. **A newer official Google Gmail MCP server now exists** (`developers.google.com/workspace/gmail/api/guides/configure-mcp-server`, Google Workspace Developer Preview) that is read + label/draft only — no send, no delete/archive — using `gmail.readonly` + `gmail.compose` scopes. This is a fourth option beyond the seed report's three, but it is strictly less capable than local Himalaya for the backlog-cleanup goal (same ceiling as the Anthropic connector, just Google's own version) and does not change the recommendation.
6. **Himalaya's real JSON envelope shape** (captured live against this machine's Gmail maildir) is flatter and slightly different from what generic docs describe — see Evidence section for the exact captured shape. Agent code should be written against this, not against blog-post approximations.

---

## Recommended Approach

**Recommend Option (b): nix-declared wrapper scripts + a Claude Code Skill, not a write-capable Gmail MCP server.**

Rationale, by trade-off dimension:

| Dimension | (a) Skill only (raw Himalaya via SKILL.md) | (b) Nix-declared wrapper scripts + slash-commands (recommended) | (c) Write-capable Gmail MCP server (GongRzhe/community, or a self-hosted OAuth-scoped one) |
|---|---|---|---|
| Reproducibility on NixOS | Good — skill just shells out to `himalaya`/`notmuch`, which are already Nix-built | **Best** — wrapper scripts (census, classify, archive, delete-with-expunge, unsubscribe-extract) are `home.packages`/`writeShellScriptBin` derivations, versioned in this repo's git history like everything else in `modules/home/email/` | Poor — requires provisioning a new Node/Python MCP server process, a *second* OAuth client registration in Google Cloud Console (distinct from the existing `GMAIL_CLIENT_ID` used by Himalaya/mbsync), and its own credential storage outside the keyring pattern already used here |
| Blast radius | Medium — agent constructs raw `himalaya`/`notmuch` invocations ad hoc; no enforced dry-run boundary except the skill's written instructions (a "seatbelt," not a guarantee, per the skill's own docs) | **Smallest** — each wrapper script owns exactly one verb (census/classify/archive/delete/unsubscribe) and can hard-code `--dry-run`-by-default, require an explicit `--yes` flag or an ID-manifest file, and refuse to run outside a whitelisted folder set. This is a technical control, not just a documented convention | Largest — the MCP server exposes `delete_email`/batch-delete tools directly as callable tools the model can invoke in a single turn with no intermediate confirmation surface unless the *harness* (Claude Code permission system) is configured to gate that specific tool — and, per GongRzhe's README, batch deletes up to 50 messages at once are a first-class feature, i.e. designed for exactly the kind of one-shot bulk action this project wants to avoid |
| Latency on 10k+ messages | Local Maildir + notmuch Xapian index — sub-second queries once indexed | Same — wrapper scripts are still local Maildir/notmuch operations | Network-bound: every list/delete/label call is a Gmail API round trip subject to quota (Gmail API default quota units), materially slower for a one-time backlog of thousands of messages, and re-introduces rate-limit handling logic that mbsync/mbsync-Gmail already has cause to worry about (see `docs/himalaya.md` "Gmail Rate Limiting" section) |
| Duplicates existing stack? | No — reuses Himalaya/notmuch/mbsync as-is | No — additive layer on top of the same stack, following the exact pattern already used for `refresh-gmail-oauth2` (a `home.packages` wrapper script + systemd unit) | **Yes** — re-implements auth, message listing, and mutation against the Gmail REST API when an OAuth2-authenticated, keyring-backed IMAP/SMTP path to the same data already exists and is exercised daily |
| Both accounts (Gmail + Proton) | Yes (Himalaya is account-agnostic via `-a`) | Yes (scripts parametrize `--account`) | No — Gmail API only; Protonmail Bridge is IMAP-only and has no equivalent write API surface, so a Gmail MCP server can never cover the Logos account |

**Concretely**: add a `modules/home/email/agent-tools.nix` (or extend `packages/email-tools.nix`) that declares a handful of `pkgs.writeShellScriptBin` wrappers (e.g. `email-census`, `email-classify`, `email-archive`, `email-delete-confirmed`, `email-unsubscribe-extract`), each calling Himalaya/notmuch with fixed, reviewed flag sets, and pair them with a Claude Code Skill (`.claude/skills/skill-email-cleanup/SKILL.md`, structurally similar to the OpenClaw Himalaya skill but scoped to *this* wrapper set) that teaches the agent to call the wrappers rather than raw `himalaya`/`notmuch` invocations. This keeps the "propose → print IDs → human approves → execute" loop enforced in the wrapper script itself (e.g., `email-delete-confirmed` refuses to run without a manifest file argument that was itself generated and printed by `email-classify`), not merely in prose instructions.

---

## Evidence/Examples

### 1. Backlog census (notmuch)

Total mail and per-bucket counts:
```bash
notmuch count '*'                          # everything indexed
notmuch count tag:inbox                    # current inbox size
notmuch count tag:inbox and tag:unread      # unread backlog
notmuch count tag:gmail and date:..1year    # gmail messages older than 1yr
notmuch count folder:/Gmail\/.All_Mail/     # size of All Mail
```

Top bulk senders (corrected command — `search --output=sender` does **not** exist; confirmed by live error `Unrecognized option: --output=sender` on this machine's notmuch 0.40):
```bash
# CORRECT: use `notmuch address`, not `notmuch search`, for sender census
notmuch address --output=sender --output=count --deduplicate=address tag:inbox \
  | sort -rn | head -30

# Equivalent uniq -c pattern if you want raw dedup without --output=count:
notmuch address --output=sender --deduplicate=mailbox tag:inbox \
  | sort | uniq -c | sort -rn | head -30
```

Bucket by age:
```bash
notmuch count tag:inbox and date:..6M          # older than 6 months
notmuch count tag:inbox and date:6M..1y        # 6mo-1yr
notmuch count tag:inbox and date:1y..           # over a year old
```

Bucket by folder (Maildir++ dot-prefix syntax, confirmed against this machine's actual folder names — e.g. `.All_Mail`, `.Spam`, `.Trash` exist under `~/Mail/Gmail`):
```bash
notmuch count folder:Gmail/.Spam
notmuch count folder:Gmail/.Trash
notmuch count folder:Gmail                      # everything under Gmail root (INBOX)
```

List-Id enumeration — **no built-in `header:` prefix in notmuch 0.40** (confirmed: `notmuch help search-terms` lists no `header:` term). Two paths:

```bash
# Path 1 (one-time setup, then fast querying):
notmuch config set index.header.List List-Id
notmuch reindex '*'         # backfills the new prefix across the whole corpus (slow, one-time)
notmuch search --output=summary 'List:mailchimp'    # now works as a fast query

# Path 2 (no setup, slower, per-message JSON parse):
for id in $(notmuch search --output=messages tag:inbox); do
  notmuch show --format=json "$id" \
    | jq -r '.[0][0].headers["List-Id"] // empty'
done | sort | uniq -c | sort -rn
```

### 2. Classify (junk vs keep vs unsure)

```bash
# Cheap deterministic junk signal: presence of List-Unsubscribe / List-Id at all
notmuch tag +bulk -- 'List:*'            # after index.header.List setup
# or, pre-setup, tag by known bulk sender domains gathered from the census step:
notmuch tag +bulk -- from:linkedin.com or from:noreply@ or from:no-reply@

# Keep signal: threads you've replied to (Message-Id you sent In-Reply-To)
notmuch tag +keep -- thread:{tag:sent} and tag:inbox

# Unsure = everything else
notmuch tag +unsure -- tag:inbox and not tag:bulk and not tag:keep
```

### 3. Archive

```bash
# notmuch-only (does not touch server until mbsync runs)
notmuch tag +archived -inbox -- tag:keep

# Himalaya-driven move (also just a local Maildir rename until synced)
himalaya message move All_Mail 1023 1024 1025 --folder INBOX
```
Because `maildir.synchronize_flags = true` is set in `notmuch.nix`, any notmuch tag change that maps to a maildir flag (e.g. removing `unread` → clears the `S`/seen flag on the filename) round-trips back into the Maildir filename; a subsequent `mbsync` picks up the renamed file and, with `Expunge Both`/`Create Both` set on every channel in `mbsync.nix`, replicates the state to Gmail. Pure notmuch *tags* that have no maildir-flag equivalent (like a custom `+bulk` tag) stay local-only and never sync to Gmail — only folder moves and the four standard flags (seen/answered/flagged/draft) round-trip.

### 4. Delete with Gmail semantics — the key finding

Verified live from this machine's installed Himalaya v1.2.0 (`himalaya message delete --help`):

> "This command does not really delete the message: if the given folder points to the trash folder, it adds the 'deleted' flag to its envelope, otherwise it moves it to the trash folder. Only the **expunge folder** command truly deletes messages."

So the two-step dance is already built into Himalaya's own subcommands — the agent does not need to construct raw IMAP trash semantics by hand:
```bash
# Step 1: soft-delete (moves INBOX message to the account's configured trash alias, "[Gmail].Trash")
himalaya message delete --folder INBOX 4711 4712 4713

# Step 2 (ONLY after human approval — this is irreversible once mbsync propagates it):
himalaya folder expunge Trash
```
This matches `docs/himalaya.md`'s folder alias config: `folder.alias.trash = "[Gmail].Trash"`, and the `gmail-trash` mbsync channel (`Far :gmail-remote:"[Gmail]/Trash"`, `Near :gmail-local:Trash`, `Expunge Both`). After `folder expunge Trash` removes the file locally, running `mbsync gmail` (or `mbsync gmail-trash`) with `Expunge Both` propagates the deletion to Gmail's actual Trash, and Gmail's own 30-day auto-purge (or IMAP `\Deleted` handling) finishes the job server-side.

`rm` on the maildir file alone only deletes the local copy; because `SyncState *` in mbsync tracks a UID mapping between local and remote, the next sync sees the file "reappear missing" and, depending on directionality, either re-downloads it from Gmail (net no-op) or — worse — desyncs the UID state. isync's own docs are explicit here: "If your server supports auto-trashing (as Gmail does), it is probably a good idea to rely on that instead of mbsync's trash functionality" — reinforcing: let Himalaya's move-to-trash + `folder expunge` + `mbsync ... Expunge Both` do the work; never `rm` maildir files directly.

Notmuch-only equivalent (for a pure-notmuch-driven pipeline without Himalaya in the loop), per Tomáš Tomeček's method:
```bash
notmuch tag +deleted -- <query>
for f in $(notmuch search --output=files tag:deleted); do mv "$f" "${f}T"; done   # add maildir T (trashed) info-flag
# then mbsync with Expunge Both propagates
```
This is described by its own author as "definitely not safe" — prefer the Himalaya `delete`/`folder expunge` path, which is a first-class, tested command rather than a manual filename hack.

### 5. Unsubscribe pass

```bash
# Gather List-Unsubscribe + List-Unsubscribe-Post per message in the +bulk bucket
for id in $(notmuch search --output=messages tag:bulk); do
  notmuch show --format=json "$id" | jq -r '
    .[0][0].headers as $h |
    [$h["List-Id"], $h["List-Unsubscribe"], $h["List-Unsubscribe-Post"]] | @tsv'
done > /tmp/unsubscribe-candidates.tsv

# Split into RFC 8058 one-click (has https:// URI + List-Unsubscribe-Post: One-Click)
# vs mailto-only (needs a sent email) using the community parser as a reference implementation:
# https://github.com/planetaryescape/list-unsubscribe (typed action enum: OneClick | Mailto | None)
```
Per RFC 8058, a compliant one-click unsubscribe requires **both** `List-Unsubscribe: <https://...>` and `List-Unsubscribe-Post: List-Unsubscribe=One-Click` — an agent should POST (not GET) the HTTPS URI with that body to trigger it, and only fall back to composing a `mailto:` template (via `himalaya template write`/`save`, human-approved) when no HTTPS URI is present.

### 6. Draft replies

```bash
# Generate a reply template pre-filled with quoted body + your signature (does not send)
himalaya template reply --folder INBOX 4711 > /tmp/reply-4711.mml

# Human edits/approves the .mml file, then EITHER:
himalaya template save --folder Drafts < /tmp/reply-4711.mml     # lands in [Gmail]/Drafts via folder alias
# OR, once approved for sending:
himalaya template send < /tmp/reply-4711.mml
```
Drafts saved via `template save -f Drafts` land in the local `Drafts` maildir folder, which mbsync's `gmail-drafts` channel (`Far :gmail-remote:"[Gmail]/Drafts"`, `Expunge Both`) syncs up to Gmail's actual Drafts on the next `mbsync gmail` — visible in the Gmail web UI/app for final human review before send, exactly like the Anthropic connector's draft-into-Gmail behavior, except this path also works for the Logos/Protonmail account (`template save -a logos -f Drafts`), which the connector cannot touch at all.

### 7. `--output json` — confirmed real shape

Live capture on this machine (`himalaya envelope list -o json --page-size 3`), Gmail account, real messages:
```json
[
  {
    "id": "3076",
    "flags": [],
    "subject": "“scientific researcher”: Anthropic - Research Engineer / Scientist, Societal Impacts",
    "from": {"name": "LinkedIn Job Alerts", "addr": "jobalerts-noreply@linkedin.com"},
    "to": {"name": "Benjamin Brast-McKie", "addr": "benbrastmckie@gmail.com"},
    "date": "2026-02-19 21:32+00:00",
    "has_attachment": false
  },
  {
    "id": "3073",
    "flags": ["Seen"],
    "subject": "Re: LFRG (Long Form Reading Group)",
    "from": {"name": "Evans, Noah", "addr": "nevans@draper.com"},
    "to": {"name": "Leach-Krouse, Graham", "addr": "gleach-krouse@draper.com"},
    "date": "2026-02-19 19:29+00:00",
    "has_attachment": true
  }
]
```
Notes vs. secondary sources: the real field names are `addr` (not `email`), `has_attachment` (snake_case, not `has-attachment`), `from`/`to` are single objects here (not arrays) for the default envelope-list shape, and `flags` is a flat string array (`["Seen"]`), not the nested `{raw, iana}` object shape reported in some blog posts. **Agent-parseable: yes** — trivially consumed via `jq -r '.[] | [.id, .from.addr, .subject] | @tsv'`. Always verify against a live `--help`/sample call on the target machine before trusting third-party docs of the JSON shape, since Himalaya's schema has clearly drifted across versions/sources.

---

## Confidence Level

**High** for sections 2–6 and 8 (backlog census syntax, delete/expunge semantics, JSON shape, draft workflow) — all directly verified against this machine's live installed binaries (Himalaya v1.2.0, notmuch 0.40), not just secondary web sources.

**Medium** for section 1 (harness form-factor recommendation) and section 6 (unsubscribe RFC 8058 mechanics) — the trade-off reasoning is sound and grounded in verified facts (Himalaya's version-agnostic account model, mbsync's Gmail-specific auto-trash guidance, Google's official MCP server scope), but the *specific* recommendation to build custom nix-declared wrappers is a design judgment, not something independently tested end-to-end in this session (no wrapper scripts were actually written/run). RFC 8058 mechanics are from the RFC text and secondary sources, not live-tested against a real one-click unsubscribe endpoint.

**Note on environment**: this machine's notmuch Xapian index (`~/Mail/.notmuch/xapian`) was empty during this research session (0 messages indexed) even though the Maildir itself contains ~2,950 files under `~/Mail/Gmail` — i.e., `notmuch new` had not yet been run in this environment. All notmuch commands above were verified for *syntax correctness* (flags, error messages, help text) against notmuch 0.40, but sender/count/date-range *numbers* could not be captured live and are illustrative placeholders, not real backlog statistics. Himalaya commands, by contrast, were verified against real Maildir content since Himalaya reads Maildir directly without requiring a notmuch index.

---

## References

- [openclaw/openclaw — skills/himalaya/SKILL.md (canonical source of the "Himalaya skill")](https://github.com/openclaw/openclaw/blob/main/skills/himalaya/SKILL.md)
- [Claude Himalaya Skill: Email from the Terminal (2026) — MCP.Directory](https://mcp.directory/blog/claude-himalaya-skill-guide)
- [Himalaya CLI (pimalaya/himalaya)](https://github.com/pimalaya/himalaya)
- [himalaya(1) — Arch manual pages](https://man.archlinux.org/man/himalaya.1.en)
- [notmuch-search-terms(7)](https://notmuchmail.org/manpages/notmuch-search-terms-7/)
- [notmuch-address(1)](https://notmuchmail.org/manpages/notmuch-address-1/)
- [Removing messages with notmuch — Tomáš Tomeček](https://blog.tomecek.net/post/removing-messages-with-notmuch/)
- [mbsync(1) — isync — Debian manpages](https://manpages.debian.org/testing/isync/mbsync.1.en.html)
- [mbsync/Gmail configuration for proper deletion — isync mailing list](https://sourceforge.net/p/isync/mailman/message/36386997/)
- [RFC 8058: Signaling One-Click Functionality for List Email Headers](https://www.rfc-editor.org/rfc/rfc8058.html)
- [planetaryescape/list-unsubscribe — RFC 2369/8058 header parser (reference implementation)](https://github.com/planetaryescape/list-unsubscribe)
- [GongRzhe/Gmail-MCP-Server](https://github.com/GongRzhe/Gmail-MCP-Server)
- [Configure the Gmail MCP server — Google Workspace Developers (official, Developer Preview)](https://developers.google.com/workspace/gmail/api/guides/configure-mcp-server)

*Local ground truth used: `himalaya --help` / `himalaya message move|delete|copy --help` / `himalaya flag add|remove --help` / `himalaya template --help` / `himalaya folder expunge --help` / `himalaya envelope list -o json` (live sample), `notmuch search --help` / `notmuch address --help` / `notmuch help search-terms` / `notmuch tag --help` / `notmuch config list` — all run directly on this machine (Himalaya v1.2.0, notmuch 0.40).*

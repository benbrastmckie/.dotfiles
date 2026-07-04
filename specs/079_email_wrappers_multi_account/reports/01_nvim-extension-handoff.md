# Handoff: nvim `email/` Extension Changes for Multi-Account (Logos) Support

**For**: an agent working in `~/.config/nvim/.claude/extensions/email/` (the canonical
authoring home of the email extension).
**Companion to**: `.dotfiles` task 79 (extends the five `agent-tools.nix` wrapper binaries to
accept `--account logos`). This report covers ONLY the extension/UX layer that sits on top of
those wrappers.
**Date**: 2026-07-04

---

## 0. Hard sequencing constraint (read first)

These extension edits **depend on task 79 landing and being switched in**. The cleanup skill will
begin passing `--account logos` to the wrappers; until the nix-built wrappers actually accept that
flag (task 79 + `home-manager switch`), every Logos invocation errors at the preamble gate
(`agent-tools.nix:70-72`). Correct order:

1. `.dotfiles` task 79 merged → `home-manager switch` (wrappers now accept `--account logos`).
2. Then apply the extension edits below in `~/.config/nvim/.claude/extensions/email/`.
3. Sync the extension down to the consumer repo (`~/Mail/.claude/...`) via the loader — never
   edit the `~/Mail` copy directly (it is downstream and gets overwritten).

Do not interleave: shipping the extension flag before the wrapper flag produces a broken `/email
--logos`.

---

## 1. What the backend already gives you (no extension work needed for these)

The Logos backend is fully built (task-72 deferred scaffolding). The extension does **not** need
to create any of it — it only needs to *select* it:

- `mbsync` `Group logos` (Protonmail Bridge `127.0.0.1:1143`) — `mbsync.nix:121-197`.
- notmuch `+logos` tag + `folder:Logos/.Sent`/`.Trash` auto-tagging — `notmuch.nix:26-31`.
- `~/Mail/Logos/{INBOX,Sent,Drafts,Trash,Archive}` maildir — `misc.nix:19-24`.
- himalaya `logos` account (Maildir + SMTP) — `himalaya account list`.
- aerc `[logos]` + `querymap-logos` — `aerc.nix:237`.

After task 79, the five wrappers accept `--account logos` and resolve `folder:Logos`, the Logos
maildir, `mbsync logos`, and `himalaya -a logos` internally.

---

## 2. Files to change in the extension

### 2.1 `commands/email.md` — add the account dimension

Currently the command parses `--all`, `--archive`, `--sync [channel]` and a free-text focus hint;
account is implicit-Gmail everywhere.

**Add an account selector.** Two viable shapes — recommend the explicit `--account`:

- Preferred: `--account <gmail|logos>` (default `gmail`), plus a `--logos` shorthand for
  `--account logos`. Generalizes cleanly to future accounts.
- Minimal: just `--logos`.

Thread the resolved account into the skill delegation args alongside `mode`/`scope`/`focus_hint`,
e.g. `args: "account={gmail|logos}, mode=..., scope=..., focus_hint=..."`. The command's flag-
parse block (around lines 45-56) is where `--all`/`--archive` are stripped — strip `--account`/
`--logos` there too.

**`--archive` scope needs per-account meaning.** Today (line 47-48) `--archive` →
`folder:Gmail/.All_Mail`. Proton has **no All-Mail label model** — it is folder-based. For
`account=logos`, `--archive` should map to the real `folder:Logos/.Archive`, OR be rejected as
not-applicable for Logos. Decide and document; do not silently send `folder:Gmail/.All_Mail` for a
Logos run.

**Help/desc text** (lines 2, 9-12, 109-128) is Gmail-worded ("reconcile … to Gmail", "All Mail
(~64k messages)"). Conditionalize or generalize the account-specific copy.

### 2.2 `skills/skill-email-cleanup/SKILL.md` — parameterize BASE_QUERY + pass `--account`

This is the load-bearing extension edit. Two concrete changes:

1. **BASE_QUERY derivation (lines 60-63)** hardcodes Gmail:
   - `scope=inbox` → `BASE_QUERY="folder:Gmail"`
   - `scope=archive` → `BASE_QUERY="folder:Gmail/.All_Mail"`

   Make it account-aware:
   - `account=gmail, scope=inbox` → `folder:Gmail`
   - `account=logos, scope=inbox` → `folder:Logos` (aerc's INBOX view uses
     `tag:inbox AND tag:logos`; confirm which the wrappers expect — folder-scoped is simplest and
     matches Gmail's pattern)
   - `account=logos, scope=archive` → `folder:Logos/.Archive` (see §2.1 decision)

   **Verify the exact local folder tokens first** with
   `notmuch search --output=folders folder:Logos` before hardcoding — do not assume `.All_Mail`/
   `.Spam` exist for Logos (they don't in the synced set).

2. **Pass `--account <account>` to every wrapper invocation.** The census/classify/archive/delete
   calls (e.g. the `email-classify --limit 50 "<CURSOR_QUERY>"` at line 89, the census at line 84,
   the `--all` sweep at lines 155-197) must all carry `--account <account>` once task 79 adds it.
   Gmail stays the default so existing behavior is unchanged when the flag is omitted.

   Note: the durable `tag:proposed-*` cursor (lines 98-110) is account-agnostic but stays correct
   because `BASE_QUERY` is folder-scoped — Gmail and Logos passes never collide. No cursor change
   needed; just confirm the exclusion query is appended to the account-scoped BASE_QUERY.

### 2.3 `skills/skill-email-sync/SKILL.md` — account→channel default

The sync skill (lines 50-51) defaults the mbsync channel to `gmail`. For a Logos cleanup, `--sync`
must reconcile **`mbsync logos`** (the group exists — `mbsync.nix:190`). Options:

- Make the default channel follow the active account (`gmail`→`gmail`, `logos`→`logos`), still
  allowing explicit override.
- Preserve the **never `mbsync -a`** invariant (the whole point of the group split is account
  isolation — see `mbsync.nix:13`). `--sync logos` = `mbsync logos`, never `-a`.

The Gmail-specific copy (lines 23-25: "land in All Mail", "Trash … ~30 days in Gmail") should be
conditionalized — Proton Trash/Archive are real-move folders, not label operations.

### 2.4 `mail-guard.sh` — NO CHANGE REQUIRED

The hook allowlists by **binary name** (`ALLOWED_BINARIES`), and task 79 adds no new binaries — it
only adds a `--account` flag to the existing five. The `rm … Mail` deny pattern still covers the
Logos maildir. **Only** touch this file if task 79 renames/adds a wrapper binary (it should not).
State this explicitly in your PR so a reviewer doesn't "fix" a non-issue.

### 2.5 `manifest.json` (optional) — keyword auto-detection

`keyword_overrides.email.keywords` (currently includes `gmail`, `himalaya`, …) could gain
`logos`, `protonmail`, `proton` so account-flavored task descriptions route to the email type.
Low priority; not required for `/email --logos` to work.

### 2.6 `EXTENSION.md` — document multi-account

`EXTENSION.md` is the merge source for the `extension_email` section of `.claude/CLAUDE.md`. Add
the account dimension to the command table and the safety-invariants list (account isolation, the
never-`mbsync -a` rule, per-account `--archive` semantics). This propagates on the next sync.

---

## 3. Verification for the extension side

After task 79 is switched in and the extension edits are applied + synced to `~/Mail`:

1. `/email --logos` (default 50-step) runs a census + classify against `folder:Logos` and proposes
   against the Logos inbox — not Gmail.
2. Bare `/email` (no account flag) behaves **byte-for-byte** as before (Gmail).
3. `/email --logos --sync` reconciles `mbsync logos` only (confirm it never runs `mbsync -a`).
4. `mail-guard.sh` still allows the five wrappers and still denies raw `himalaya message move` /
   `rm … Mail` — unchanged.
5. Unknown account (`/email --account work`) surfaces the wrapper's actionable rejection, not a
   silent Gmail fallback.

---

## 4. One-paragraph summary to hand your other agent

> The Logos/Protonmail backend (mbsync group, notmuch tags, maildir, himalaya + aerc accounts,
> Bridge service) is already fully built. `.dotfiles` task 79 teaches the five wrapper binaries a
> real `--account logos`. Your job in `~/.config/nvim/.claude/extensions/email/` is the UX layer on
> top: add an `--account`/`--logos` selector to `commands/email.md`; make
> `skill-email-cleanup`'s `BASE_QUERY` account-aware (`folder:Gmail`↔`folder:Logos`, verify Logos
> folder tokens with `notmuch search --output=folders folder:Logos`) and pass `--account` to every
> wrapper call; make `skill-email-sync` default the mbsync channel to the active account
> (`mbsync logos`, never `-a`); give `--archive` a per-account meaning (Proton has no All-Mail);
> update Gmail-specific help copy; and document it in `EXTENSION.md`. `mail-guard.sh` needs **no
> change** (allowlist is by binary name; no new binaries). Sequence after task 79 lands + switches;
> never edit the `~/Mail` copy directly.

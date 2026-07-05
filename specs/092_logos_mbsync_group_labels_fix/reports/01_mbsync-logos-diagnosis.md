# Logos mbsync Group / Labels Fix — Live Diagnosis Seed

**Task**: 92 · **Type**: nix · **Status**: not_started
**Diagnosed**: 2026-07-04, live from the `~/Mail` repo during a `/email --logos --all` run.
**Source of truth**: `modules/home/email/mbsync.nix` (Logos section, lines 121–197).

> The runtime `~/.mbsyncrc` is a home-manager symlink into `/nix/store`
> (`readlink ~/.mbsyncrc` → `…-home-manager-files/.mbsyncrc`). **Never edit it directly** —
> the fix must land in the nix source above and be activated with `home-manager switch`.

## Symptom

After the email wrappers moved 20 Logos-INBOX messages to Trash, the wrapper's internal
`mbsync logos` reconcile exited non-zero:

```
IMAP command 'APPEND "Sent" (\Seen) {144}' returned an error:
    invalid rfc5322 message: Required header field 'Date' not found or empty
Maildir error: duplicate UID 3 in /home/benjamin/Mail/Logos//.Trash.
Maildir error: duplicate UID 1 in /home/benjamin/Mail/Logos//.Archive.
Maildir notice: no UIDVALIDITY in .Labels.CrazyTown, creating new.   (… ×8)
store 'logos-local', folder 'Labels/benbrastmckie@gmail.com':
    SubFolders style Maildir++ does not support dots in mailbox names
Channels: 7  Boxes: 14  Far: +0 *3 #0 -3   Near: +41797 *31 #0 -31
```

The **local** maildir moves succeeded regardless (Logos `.Trash` 1764 → 1784 = +20, verified on
the filesystem). Only the **server-side reconcile** is impacted.

## Root cause

`Group logos` (lines 190–197) chains **all 7** logos channels, including:

- `logos-labels` — `Patterns "Labels/*"` (lines 172–179)
- `logos-folders` — `Patterns "Folders/*"` (lines 181–188)

The Proton far side exposes a Gmail-import label literally named **`benbrastmckie@gmail.com`**.
Under `SubFolders Maildir++` (line 135), `.` is the folder-hierarchy separator, so a mailbox
**name** containing dots (`gmail.com`) cannot be represented → mbsync aborts the channel → the
whole group returns exit 1.

Secondary: the labels/folders channels pull the entire Gmail-import label tree
(`Near: +41797`), which is irrelevant to an INBOX→Trash cleanup reconcile and makes every
wrapper mutation's internal reconcile slow and noisy.

## Existing precedent in the same file

`Group gmail` (lines 114–119) **deliberately omits** `gmail-trash` and `gmail-spam` channels —
with an explanatory comment (lines 69, 87–90) — because those far-boxes are `[NONEXISTENT]` /
not IMAP-selectable and break the group. The Logos fix mirrors this pattern exactly.

## Proposed fix

1. **Slim `Group logos`** to core channels only — `logos-inbox`, `logos-sent`, `logos-drafts`,
   `logos-trash`, `logos-archive` — so the wrapper's `mbsync logos` reconcile can't choke on
   labels.
2. **Add `Group logos-full`** = the core channels **plus** `logos-labels` + `logos-folders`, for
   explicit on-demand full sync.
3. **Harden** `logos-labels` (and `logos-folders`) with a negative pattern so even
   `mbsync logos-full` skips dotted label names:
   `Patterns "Labels/*" "!Labels/*.*"` / `Patterns "Folders/*" "!Folders/*.*"`.

Sketch:

```nix
    Channel logos-labels
    Far :logos-remote:
    Near :logos-local:
    Patterns "Labels/*" "!Labels/*.*"   # skip dotted label names Maildir++ can't hold
    Create Both
    Expunge Both
    Remove Both
    SyncState *
    # (same "!Folders/*.*" guard on logos-folders)

    # Wrapper reconcile target — core folders only (mirrors Group gmail omitting trash/spam)
    Group logos
    Channel logos-inbox
    Channel logos-sent
    Channel logos-drafts
    Channel logos-trash
    Channel logos-archive

    # On-demand full sync incl. labels/folders — NOT in the agent reconcile path
    Group logos-full
    Channel logos-inbox
    Channel logos-sent
    Channel logos-drafts
    Channel logos-trash
    Channel logos-archive
    Channel logos-labels
    Channel logos-folders
```

## Secondary issues (non-blocking — note, don't necessarily fix here)

- **Duplicate UID in `.Trash` (CONFIRMED, blocks the Trash-folder sync).** Two files in
  `~/Mail/Logos/.Trash/cur/` both carry `U=3`:
  - `1770669071.1006834_3.hamsa,U=3:2,`
  - `1770669126.1007943_17.hamsa,U=3:2,S`

  `mbsync logos-trash` exits 1 on `duplicate UID 3 in .Trash`, so the trashed copies never
  reach the Proton **Trash** folder. It does NOT block the INBOX removal (see below). Fix is
  maildir UID surgery (rename one file's `U=` token, or reset the folder's `.uidvalidity` /
  sync-state) — do it deliberately, not ad-hoc. Also seen once: `duplicate UID 1 in .Archive`.
- One **malformed 144-byte message** in local `Sent` missing a `Date:` header that Proton
  rejects on APPEND. Separate concern; investigate which message and whether to drop/repair it.

## Follow-up finding (2026-07-04, post-cleanup sync attempt)

The **INBOX channel already reconciles correctly**: after the cleanup, `mbsync logos-inbox`
alone reports `Far: +0 / Near: +0`, exit 0 — i.e. the 20 INBOX→Trash removals DID propagate to
the Proton server INBOX (the wrapper's internal reconcile runs `logos-inbox` before it dies on
the labels channel). So the observed end-user impact of this bug is narrower than the exit-1
suggests: **removals reach the server; only (a) the automatic full-group `mbsync logos` exit
code and (b) the Trash-folder copy-up are broken.** The group-slimming fix addresses (a); the
duplicate-UID item above addresses (b).

## Verification

- `home-manager build --flake .#<host>` evaluates.
- After `home-manager switch`: `mbsync logos` exits 0 and propagates the pending Logos
  INBOX→Trash deletes to the Proton server; `mbsync logos-full` completes without the
  dotted-label fatal error.

## Cross-repo context

- Diagnosis performed in `~/Mail`; approved delete manifest + wrapper state files live at
  `~/Mail/specs/email-manifests/logos/`.
- Relates to `.dotfiles` email-workflow tasks **72** (frozen wrapper contract) and **79**
  (multi-account wrappers).

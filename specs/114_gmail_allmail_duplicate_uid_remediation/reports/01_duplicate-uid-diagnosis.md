# Gmail/.All_Mail duplicate-UID remediation — diagnosis report

**Task:** 114 — Safely remediate the duplicate-UID collision in `~/Mail/Gmail/.All_Mail`
that makes `mbsync gmail` exit non-zero.
**Status:** Research (seeded from live diagnosis during the aerc email work, 2026-07-14).
**Risk class:** HIGH — live 64k-message Gmail "All Mail" folder synced with `Expunge Both`.
A wrong move can permanently delete a real message from the Gmail server.

## Symptom

- aerc shows a recurring red banner: `gmail: () checkmail: error running command: exit status 1`
  every ~10 minutes.
- Source chain: aerc `[gmail] check-mail-cmd = mail-sync gmail --no-wait` (task 113) →
  `mail-sync` sets `OVERALL_STATUS=1` because `run_group gmail` returns 1 →
  `mbsync gmail` exits 1.
- This is **pre-existing corruption surfaced by task 113's check-mail wiring**, NOT introduced
  by tasks 110–113. The same failure also fails the `mail-sync-timer` systemd unit (task 113
  Part B) and blocks clean sync of `All_Mail`, which is the archive destination for task 112.

## Root cause (verified live 2026-07-14)

`mbsync gmail` aborts with:

```
Maildir error: duplicate UID 15 in /home/benjamin/Mail/Gmail//.All_Mail.
```

Two **different** messages in `~/Mail/Gmail/.All_Mail/cur/` both carry the maildir UID tag `,U=15`:

| File | Subject | Message-ID | mtime-ordinal |
|------|---------|------------|---------------|
| `1770746110.1372450_624.hamsa,U=15:2,` | `eNTERTAINMENT cENTER` | `<000001c6ee96$483cd850$4101a8c0@isda1>` | later (1770746110) |
| `1770674724.1073681_15.hamsa,U=15:2,` | `A message from our CEO Nick Slape` | `<0.0.F.6B.1D7857A52BBBC03.0@t01.communicatoremail.com>` | earlier (1770674724) |

mbsync (maildir++ backend) reads the IMAP UID from the `,U=<n>` filename suffix. Two files with
the same UID in one folder is an illegal state → hard error, whole `mbsync gmail` reconcile aborts.

### Which one is the stray?

`~/Mail/Gmail/.All_Mail/.mbsyncstate` contains exactly **one** mapping for near-UID 15:

```
FarUidValidity 1
NearUidValidity 1770746106
MaxPulledUid 493775
MaxPushedUid 67147
...
33 14 S
34 15 S      <-- far UID 34 <-> near (local) UID 15, flags: Seen
```

So mbsync's state believes there is a single legitimate local UID-15 message, mapped to far
(server) UID 34. One of the two files above is that message; the other erroneously acquired the
`,U=15` tag (most plausibly from the historical email dedup/migration tooling visible under
`~/Mail/specs/email-manifests/…`). **The state file does not store filenames**, so mapping
far-UID 34 → the correct file still needs to be established (see "Open questions").

## Constraints that make this dangerous

1. **`Expunge Both` on the `gmail-all` channel** (`modules/home/email/mbsync.nix`):
   ```
   Channel gmail-all
   Far  :gmail-remote:"[Gmail]/All Mail"
   Near :gmail-local:All_Mail
   Create Near
   Expunge Both
   ```
   If a previously-synced local file simply disappears, mbsync can propagate that as a deletion
   to the server → **permanent loss of a real Gmail message**. Therefore **do NOT `rm` or move
   either file out of the maildir**.

2. **`Create Near`** (not `Both`): local-only messages are never uploaded to the server. This is
   the property that makes the "de-UID one file" fix safe from server-side *duplication* — a file
   with no `,U=` tag is treated as new-local and will not be pushed up.

## Candidate remediation (to be validated, NOT yet applied)

**Preferred, least-destructive:** rename (never delete) the **stray** file to strip its `,U=15`
suffix, e.g.:

```
mv '…_624.hamsa,U=15:2,'  '…_624.hamsa:2,'     # illustrative — target the STRAY, confirmed first
```

Expected effect:
- Collision resolved (only one `,U=15` remains) → `mbsync gmail` exits clean.
- The de-UID'd file becomes a new local-only message. With `Create Near`, mbsync will **not**
  upload it → no server duplicate.
- No file removed → no `Expunge Both` propagation → no server deletion.
- Fully reversible (rename back) if anything looks wrong.

Residual consideration: if the de-UID'd message also still exists on the server under its own
(correct) UID, a future pull may re-download it as a second local copy — a harmless local
duplicate, self-correcting, never server damage.

**Rejected:** `rm` / move-out-of-maildir (Expunge-Both server-deletion risk); full
`.mbsyncstate`/`.uidvalidity` reset (re-pairs 64k messages, slow, and does NOT fix the on-disk
`,U=15` collision by itself since UIDs are read from filenames).

## Open questions for the remediation plan

1. **Confirm which file is the stray** before renaming. Options: (a) map far-UID 34 to a
   Message-ID via a read-only IMAP `FETCH 34 (BODY[HEADER.FIELDS (MESSAGE-ID)])` against
   `[Gmail]/All Mail` (needs care/creds); (b) check which Message-ID appears elsewhere in the
   maildir / notmuch with a consistent UID; (c) default to de-UIDing the later-mtime file
   (`…_624… eNTERTAINMENT cENTER`) as the likely-injected duplicate, but ONLY after corroboration.
2. Verify `notmuch` re-index behaviour after the rename (the file changes name; `notmuch new`
   should re-key it — confirm no dangling index entry).
3. Decide whether a durable guard belongs in `modules/home/email/mail-sync.nix` (e.g. detect the
   known duplicate-UID class and exit 0 with a warning so aerc's check-mail does not red-banner on
   a benign, already-tracked condition) — weigh against hiding real future failures.
4. Sweep for OTHER duplicate-UID collisions in All_Mail (and other folders) beyond UID 15, so the
   fix is complete rather than whack-a-mole.

## Verification (for the implement phase)

- After the rename: `mbsync gmail` exits 0; `mail-sync gmail` exits 0; aerc banner clears.
- Confirm in the Gmail web UI that both "eNTERTAINMENT cENTER" and "CEO Nick Slape" messages
  still exist in All Mail (nothing deleted server-side).
- `systemctl --user start mail-sync-timer.service` then `is-failed` returns non-failed.

## Provenance

All facts above are live-verified on 2026-07-14 against the running system (mbsync 0.21-era
maildir++ store at `~/Mail/Gmail/.All_Mail`, mbsync exit reproduced directly). No mail files were
modified during diagnosis.

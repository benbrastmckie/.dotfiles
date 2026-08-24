# Phase 2 — Stray identification (corroborated)

## Primary corroboration: read-only IMAP UID FETCH 34

`~/Mail/Gmail/.All_Mail/.mbsyncstate` maps near-UID 15 to far-UID 34 (`34 15 S`).

- `FarUidValidity` in `.mbsyncstate`: `1`
- Live IMAP `STATUS "[Gmail]/All Mail" (UIDVALIDITY)`: `1` — **matches**, so far-UID 34 is
  still trustworthy (no UIDVALIDITY rollover since the state file was written).
- Read-only `UID FETCH 34 (BODY.PEEK[HEADER.FIELDS (MESSAGE-ID SUBJECT)])` (SELECT opened
  `readonly=True`; `BODY.PEEK` used instead of `BODY` so no `\Seen` flag was set — pure read,
  zero mutation) returned:
  ```
  Subject: eNTERTAINMENT cENTER
  Message-ID: <000001c6ee96$483cd850$4101a8c0@isda1>
  ```

**Conclusion**: far-UID 34 (= near-UID 15 per state) is the **eNTERTAINMENT cENTER** message.

This is the OPPOSITE of the diagnosis report's speculative mtime-ordinal heuristic (which
guessed the later-mtime `eNTERTAINMENT cENTER` file was "the likely injected duplicate"). The
primary corroboration signal overrides the heuristic per the plan's own precedence rule
("only accept the heuristic when a second signal agrees" — here the primary signal disagrees
with the heuristic, so the heuristic is discarded).

## Secondary corroboration: notmuch + content comparison

`notmuch search --output=files id:"<message-id>"` for each Message-ID returned TWO files per
message — the colliding `,U=15` file AND a separate, independently-UID'd file elsewhere in
`.All_Mail/cur/`:

| Message-ID | Colliding file | Independent copy |
|---|---|---|
| `<000001c6ee96$483cd850$4101a8c0@isda1>` (eNTERTAINMENT cENTER) | `...1372450_624.hamsa,U=15:2,` | `...1523822_21746.hamsa,U=64479:2,` |
| `<0.0.F.6B.1D7857A52BBBC03.0@t01.communicatoremail.com>` (CEO Nick Slape) | `...1073681_15.hamsa,U=15:2,` | `...1523822_12554.hamsa,U=55287:2,` |

Both independent copies match Subject/From/Date/Message-ID and byte-size of their respective
`,U=15` sibling (content-identical duplicates). This confirms:
1. Neither message is at risk of being "lost" from the local maildir even in the worst case —
   both already have a second, non-colliding, properly-UID'd local copy.
2. The low sequence numbers in the colliding files' basenames (`_624`, `_15`) versus the high
   sequence numbers in the independent copies (`_21746`, `_12554`) are consistent with the
   report's hypothesis that the colliding pair originated from an earlier bulk
   dedup/migration batch, one of which erroneously retained a stale `,U=15` tag.

This is neutral/supporting secondary evidence — it does not itself identify the stray, but it
is fully consistent with (does not contradict) the primary IMAP signal, and confirms the
rename is low-risk regardless.

## Decision

- **LEGIT (keeps `,U=15`)**: `1770746110.1372450_624.hamsa,U=15:2,` (eNTERTAINMENT cENTER)
- **STRAY (to be renamed, strip `,U=15`)**: `1770674724.1073681_15.hamsa,U=15:2,` (CEO Nick Slape)

Identification is corroborated by (a) a live read-only IMAP UID FETCH of the exact far-UID
recorded in `.mbsyncstate`, with UIDVALIDITY cross-checked as unchanged, and (b) neutral
supporting evidence from notmuch/content comparison. No ambiguity — proceeding to Phase 3.

# aerc config — session work log & refactor handoff brief

**Task:** 115 — Consolidate and refactor the aerc email configuration.
**Purpose of this document:** a complete, self-contained hand-off so the refactor can be
orchestrated *after the working context is cleared*. It records everything changed in the
2026-07-13/14 aerc work session, the design decisions and why they were made, what is still
outstanding, and the invariants any refactor MUST preserve. **Read this first; do not re-derive.**

> Scope note: the goal of task 115 is a *maintainability/coherence* refactor of an already-working
> config — NOT a behavior change. Every behavior below is intended and verified; preserve it unless
> the plan makes an explicit, justified decision to change it.

---

## 1. What the config does (current architecture)

Mail stack (all Nix/home-manager managed, under `modules/home/email/` unless noted):

| File | Role |
|------|------|
| `aerc.nix` | aerc client config: `programs.aerc` (ui/viewer/compose/filters/openers/binds) + `home.file` for `accounts.conf` and two `querymap-*` files. **384 lines, the refactor's primary target.** |
| `mbsync.nix` | `.mbsyncrc` — IMAP↔maildir channels for gmail + logos. `gmail-all` is `Create Near` + **`Expunge Both`** (deletion-propagation risk — see §4). |
| `mail-sync.nix` | `mail-sync <gmail\|logos\|both> [--no-wait]` wrapper (task 109): single flock-serialized choke point for `mbsync` + `notmuch new --no-hooks`. Exits non-zero if any `mbsync <group>` exits non-zero. |
| `notmuch.nix` | notmuch config + `postNew` hook that tags `+inbox +unread` once at delivery (never removes `-inbox` on archive — this is why task 110 stopped using `tag:inbox` for the INBOX view). |
| `protonmail.nix`, `agent-tools/` | Proton bridge + the 5 wrapper binaries for `/email` triage (out of scope here). |
| `../services/mail-sync-timer.nix` | systemd user timer (task 113): runs `mail-sync both` every 15 min (`OnCalendar=*:0/15`, `Persistent=true`). Wired via `modules/home/default.nix`. |

Account model: two accounts (`[gmail]`, `[logos]`), both `source = notmuch://~/Mail`, both
`maildir-store = ~/Mail`. Folder views come from per-account `query-map` files (virtual folders:
INBOX, Sent, Drafts, Trash, All_Mail/Archive, Spam, Unread, Flagged, Proposed-*).

---

## 2. Session changelog (what changed and why)

### Batch tasks 110–113 (commit `fb734af`, orchestrated)

- **110 — INBOX querymap → real folder.** Changed `INBOX=tag:inbox AND folder:/Gmail/` →
  `INBOX=folder:Gmail` (and Logos). Root cause: `tag:inbox` is a permanent "was delivered" marker
  (notmuch.nix postNew never removes it) and `folder:/Gmail/` is a *regex* matching all subfolders
  incl. `.All_Mail`, so the INBOX tab showed ~12.5k msgs instead of the true ~85. Bare exact-match
  `folder:Gmail` = INBOX-only, and archived (moved-out) mail now disappears from the view.
  Unread/Flagged/Proposed-* deliberately kept account-wide (tag-driven triage views).
- **111 — compose line wrapping.** Verified drafted `[compose]` edits: `editor = "nvim -c 'setlocal
  textwidth=0 formatoptions-=t'"` (defeats nvim's mail ftplugin hard-wrap) + `format-flowed = true`
  (RFC3676, recipients reflow). Correct & complete against aerc 0.21.0.
- **112 — enable real archive.** Added `maildir-store = ~/Mail` + `multi-file-strategy = act-dir`
  to both accounts. Without maildir-store the notmuch worker returned `errUnsupported` (silent
  no-op); `act-dir` handles the 35/85 multi-file (label) messages. `:archive` now os.Rename's into
  `archive=` (All_Mail / Archive); `Expunge Both` propagates INBOX-label removal on next sync.
  **Live-mail verification (archive real msgs, mbsync, confirm in Gmail web) was deferred to a
  manual user checklist — an autonomous agent must not mutate live mail. Still user-pending.**
- **113 — archive-on-reply + periodic sync.** Research *pivoted* away from the originally-drafted
  Subject-sniffing `[hooks] mail-sent` block to aerc's **native `:send -a flat`** (reply.go OnClose
  archives the exact replied-to message by reference; immune to cursor drift; the hook was removed
  to avoid double-archiving). Added `mail-sync-timer` systemd unit + `[gmail] check-mail = 10m` /
  `check-mail-cmd = mail-sync gmail --no-wait` / `check-mail-timeout = 30s` (also fixes the `u`
  keybind). `[logos]` check-mail intentionally unwired.

### Follow-up fixes this session (separate commits)

- **`c671d59` — `folders-exclude = ~^Gmail,~^Logos` (both accounts).** Regression from 112: setting
  `maildir-store=~/Mail` made the notmuch worker enumerate the whole shared `~/Mail` maildir tree,
  stacking every physical Gmail/* and Logos/* folder into BOTH accounts' sidebars on top of the
  querymap virtuals. `folders-exclude` is display-only (does NOT affect `:archive`), regex-hides the
  physical tree, restores the clean per-account list. (User confirmed: "that worked.")
- **`747705d` — `[view]` `r = :reply -c` / `R = :reply -a -c`.** After archive-on-reply from an
  opened message *viewer*, aerc stranded the user in the now-stale viewer. aerc's native `-c` flag
  closes the viewer at reply-open time → tab history returns to the message list after send.
  Source-verified safe: `-c` is a no-op from the list (`mv==nil`), orthogonal to `-a` (no
  double-archive), abort reopens a peek-view. **Caveat: `-a -c` two-flag form is the safe syntax;
  bundled `-ac` was NOT verified against aerc's go-opt parser.**
- **`25b8691` — `[view]` `<Enter> = :next-part`.** Multipart (text/plain vs text/html) selection:
  aerc has no "Enter to select"; you cycle parts with `:next-part`/`:prev-part` (`j`/`k`). Enter was
  unbound so it fell through to the `less` pager. Aliased Enter to `:next-part` for discoverability
  (trade-off: Enter no longer scrolls the pager one line). text/html renders via the existing
  `w3m` `[filters]` entry.

### Task 114 spun off (commit `d6e6d14`) — see §4.

---

## 3. Current known-good behaviors (verified)

- `home-manager build --flake .#benjamin` succeeds after every change.
- INBOX tab shows the true inbox; archived mail leaves the view.
- Per-account sidebars show only querymap virtual folders (no physical-tree clutter, no
  cross-account bleed).
- Reply → send → archives the replied message → returns to the list (from both list and viewer).
- Enter/j/k cycle text/plain↔text/html in the viewer.
- Periodic sync runs via the 15-min systemd timer + while-open aerc check-mail; the
  "Mail sync + reindex complete" toast is the success notification.

---

## 4. Outstanding / deferred issues (do NOT lose these)

1. **Task 114 — Gmail/.All_Mail duplicate-UID (HIGH RISK, separate task).** Two different messages
   both carry `,U=15`, so `mbsync gmail` exits 1 → `mail-sync gmail` exits 1 → aerc check-mail
   *previously* red-bannered. `gmail-all` is **`Expunge Both`**: removing/moving a synced maildir
   file can PERMANENTLY DELETE a real Gmail message. Safe fix = RENAME (never delete) the stray to
   strip `,U=15`. Full grounded analysis: `specs/114_gmail_allmail_duplicate_uid_remediation/
   reports/01_duplicate-uid-diagnosis.md`. **This is its own task; 115 must not attempt the maildir
   remediation, but should be aware the check-mail error is symptomatic of it.**
2. **112/113 live-mail verification still user-pending.** The reply→archive→sync→confirm-in-Gmail
   end-to-end checks (in the 112 and 113 summaries) were never run against live mail by an agent.
3. **`check-mail-cmd` surfaces real sync failures as UI errors.** By design it reports mbsync's
   non-zero exit. Until 114 is fixed, gmail sync exits non-zero. The refactor should DECIDE (not
   silently mask) how check-mail should behave on a benign/known failure vs a real one.
4. **`-a -c` parser caveat** (§2) — confirm the multi-flag syntax, or find the canonical form.
5. **Config clutter.** `aerc.nix` carries **17** `Task NN` / "Regression fix" comment markers
   accreted across many tasks (34, 72, 105, 110, 112, 113 + follow-ups). Prime consolidation target.

---

## 5. Refactor goals for task 115 (candidate scope — research/plan should refine)

- **Consolidate the historical `Task NN` comment archaeology** into concise, forward-looking
  documentation. Keep the *rationale* (why INBOX is `folder:Gmail`, why folders-exclude, why native
  `:send -a` over the hook, why Unread/Flagged stay account-wide, the Expunge-Both danger) but drop
  the task-number narration. Goal: a reader who never saw tasks 34–114 understands the config.
- **Reconsider, holistically, decisions that were made incrementally under pressure:**
  - querymap + `folders-exclude` blacklist vs a `folders` whitelist (which is more robust/clear?).
  - text/plain-first vs text/html-first `alternatives` default (user finds html "a little better").
  - whether `<Enter>`-cycles-parts is worth losing Enter-to-scroll, or a different key is better.
  - whether `[logos]` should also get check-mail / how check-mail should treat known failures.
  - de-duplicate the two near-identical `querymap-gmail`/`querymap-logos` files if a generator helps.
- **Verify internal consistency** between `aerc.nix`, `mbsync.nix`, `mail-sync.nix`, `notmuch.nix`
  (folder names, archive targets, tag semantics) and document the contract in one place.
- **Do NOT change behavior** without an explicit, justified decision in the plan. This is a
  maintainability refactor, not a redesign.

---

## 6. Invariants that MUST be preserved

- **No live-mail mutation by an agent.** Archiving real mail, `mbsync`/`mail-sync` against live
  servers, and driving aerc's TUI are manual user steps. Agents apply config + `home-manager build`
  only; never `home-manager switch`, never send mail.
- **`Expunge Both` deletion risk** on `gmail-all` — never `rm`/move a maildir file out of All_Mail.
- **Wrapper-only mail mutation** for the `/email` triage stack (the 5 agent-tools binaries); the
  refactor touches aerc *config*, not that contract.
- **Folder-scoping is expressed via `folder:` tokens**, per the repo's email conventions
  (CLAUDE.md): bare `folder:Gmail` = INBOX-only exact match; `folder:/Gmail/` = whole-account regex.
- Keep `home-manager build --flake .#benjamin` green at every step.
- Don't reintroduce double-archiving (native `:send -a` + a hook) or the `tag:inbox` INBOX bug.

---

## 7. Verification approach for the refactor

- Build after every change (`home-manager build --flake .#benjamin`).
- Diff the *rendered* `~/.config/aerc/{aerc.conf,binds.conf,accounts.conf,querymap-*}` before/after
  the refactor and confirm they are **semantically identical** (a pure-refactor should produce
  byte-identical or provably-equivalent rendered config unless a decision explicitly changes it).
- Leave a manual user checklist for any behavior the agent cannot exercise (TUI, live mail).

---

## 8. Commit trail (this session)

```
d6e6d14 task 114: create gmail All_Mail duplicate-UID remediation task
25b8691 aerc: bind <Enter> to cycle message parts in viewer
747705d aerc: reply from viewer returns to message list (:reply -c)
c671d59 aerc: hide physical maildir tree from sidebar (folders-exclude)
fb734af orchestrate tasks 110-113: complete orchestration
d1a0407 task 110-113: create aerc email sync fix tasks
```

Unrelated dirty file left untouched throughout: `modules/system/packages.nix` (ocrmypdf/tesseract).

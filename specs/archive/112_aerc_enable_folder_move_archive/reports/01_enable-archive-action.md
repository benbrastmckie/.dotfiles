# Research Report: Task #112

**Task**: 112 - Enable a real, server-propagating archive action in aerc (`a`/`A` keys; reply hook is task 113)
**Started**: 2026-07-13T23:48:36Z
**Completed**: 2026-07-13
**Effort**: Small (two-line accounts.conf change per account) but with a HIGH-CONSEQUENCE live-mail-mutation verification step, plus one non-obvious source-level risk that must be tested
**Dependencies**: Task 110 (completed) — the aerc INBOX querymap now reflects true folder membership (`folder:Gmail`/`folder:Logos`), so an archived message correctly disappears from the INBOX tab once its file actually moves
**Sources/Inputs**: `modules/home/email/aerc.nix`, `modules/home/email/mbsync.nix`, `modules/home/email/agent-tools/archive-confirmed.nix`, locally installed aerc 0.21.0 man pages (`aerc-accounts(5)`, `aerc-notmuch(5)`), the exact nixpkgs `aerc.src` Go source tree fetched from the Nix store (`/nix/store/vzbr9yjgh71ha9qiq7b9ll410j4ldvk5-source`) — `config/accounts.go`, `worker/notmuch/worker.go`, `worker/notmuch/message.go`, `worker/lib/maildir.go`, `worker/types/mfs.go`, `commands/msg/archive.go`; upstream aerc GitHub master branch (for forward-compatibility contrast only)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The proposed `accounts.conf` fix (add `maildir-store = ~/Mail` and `multi-file-strategy = act-dir` to both `[gmail]` and `[logos]`) is **fully grounded and correct for the exact aerc build in use** (nixpkgs `aerc-0.21.0` — verified by reading the actual Go source the Nix store built, not just upstream docs). Both option names, `act-dir`'s validity, `~` expansion, and the "notmuch backend requires `maildir-store` for `:archive`/`:delete`" claim are all confirmed at the source-code level, not just from documentation.
- **New, non-obvious, source-grounded risk found and NOT in the task description**: aerc's notmuch worker resolves the "current folder" (`curDir`) used by `act-dir` from the **currently open tab's name**, and that name must be an exact key in the physical folder map built by walking the `maildir-store` root. The tab named `INBOX` (the querymap alias `INBOX=folder:Gmail` that task 110 introduced, and which `default = INBOX` opens automatically) is **not** such a key — the physical folder is named `Gmail`, not `INBOX`. If this is right, archiving a **multi-file** message while sitting on the `INBOX` tab will silently downgrade `act-dir` to `refuse` and produce `refusing to act on multiple files`, i.e. the exact 35/85 multi-file messages the task is most worried about may fail from the tab the user actually lives in day to day, while succeeding from a literal `Gmail`/`Logos` folder tab. This must be the first thing the live-verification step checks (see "Critical risk" below) — it does not block making the accounts.conf edit, but it changes what "verify by archiving one multi-file message" needs to test.
- `archive = All_Mail` (gmail) / `archive = Archive` (logos) are unchanged, confirmed present, and are exactly what `:archive flat` targets (`archiveDir := acct.AccountConfig().Archive` in `commands/msg/archive.go`).
- The underlying operation is a literal `os.Rename()` of the maildir file from the source folder's `cur/` into the archive folder's `cur/` — the same class of maildir-level mutation as the repo's already-proven `email-archive-confirmed` wrapper (`himalaya message move ... -f INBOX`), and it is exactly what `mbsync`'s `gmail-inbox` channel (`Expunge Both`) will detect and propagate to Gmail as an INBOX-label removal on the next sync.
- Recommendation on goal 5 (existing `:prompt` confirmations): no change strictly required. `A` (bulk archive of all marked) and `D`/`d` (delete) are already prompted; bare `a` (single-message archive) is unprompted in both `messages` and `view` contexts today. Archiving is a low-risk, reversible action (moving a file back to INBOX is trivial), so leaving `a` unprompted is a defensible, common mail-client convention — but this is now a genuine, real decision (previously it was moot because `a` was a no-op) and should be recorded explicitly rather than left implicit.

## Context & Scope

Task 112 is scoped to `modules/home/email/aerc.nix`'s `accounts.conf` `home.file` block only (`file_scope: ["modules/home/email/aerc.nix"]` per state.json). It depends on task 110 (already completed: INBOX querymap is folder-scoped, not tag-scoped). It explicitly excludes wiring archive-on-reply and periodic sync (task 113's `mail-sent` hook already calls `aerc :archive flat` conditionally on `Re:*` subjects — see aerc.nix lines 59-70 — but that hook is currently as inert as the `a`/`A` keys for the same underlying reason, and task 113 is where its correctness is re-verified once archive is live).

## Findings

### 1. Current `accounts.conf` definition (exact location and content)

`modules/home/email/aerc.nix`, `home.file.".config/aerc/accounts.conf".text` (lines 262-282):

```
[gmail]
source = notmuch://~/Mail
query-map = ~/.config/aerc/querymap-gmail
default = INBOX
from = Benjamin Brast-McKie <benbrastmckie@gmail.com>
copy-to = Sent
archive = All_Mail
outgoing = smtps://benbrastmckie@gmail.com@smtp.gmail.com:465
outgoing-cred-cmd = secret-tool lookup service gmail-app-password username benbrastmckie@gmail.com

[logos]
source = notmuch://~/Mail
query-map = ~/.config/aerc/querymap-logos
default = INBOX
from = Benjamin Brast-McKie <benjamin@logos-labs.ai>
copy-to = Sent
archive = Archive
outgoing = smtp://benjamin@logos-labs.ai@127.0.0.1:1025
outgoing-cred-cmd = secret-tool lookup service protonmail-bridge username benjamin@logos-labs.ai
```

- Both accounts already share `source = notmuch://~/Mail` — a single shared notmuch database root, with per-account scoping done entirely via `query-map`/`folder:` queries (task 34, task 110), not via separate notmuch databases or `maildir-account-path`.
- `archive =` is already set correctly for both accounts: `All_Mail` (gmail) and `Archive` (logos). Confirmed these are exactly the folder names produced by `mbsync.nix`'s `Near :gmail-local:All_Mail` and `Near :logos-local:Archive` directives, and match the `querymap-gmail`/`querymap-logos` entries (`All_Mail=folder:Gmail/.All_Mail`, `Archive=folder:Logos/.Archive`).
- Maildir root for both accounts is `~/Mail` (not `$MAILDIR` — that env var is not used anywhere in this repo's email modules; every reference is the literal `~/Mail` path, consistent with `mbsync.nix`'s `Inbox ~/Mail/Gmail/` / `Inbox ~/Mail/Logos/`).
- **Recommended edit**: add two lines to each account section, directly after `source =` (grouping the two notmuch-backend options together):

```
[gmail]
source = notmuch://~/Mail
maildir-store = ~/Mail
multi-file-strategy = act-dir
query-map = ~/.config/aerc/querymap-gmail
...

[logos]
source = notmuch://~/Mail
maildir-store = ~/Mail
multi-file-strategy = act-dir
query-map = ~/.config/aerc/querymap-logos
...
```

No other line needs to change. `maildir-account-path` should NOT be set for either account: both accounts already share the same `~/Mail` maildir-store root exactly as they already share the same notmuch `source` root, and per-account scoping is handled entirely by `query-map`/folder queries — setting `maildir-account-path` is documented as being "used to achieve traditional maildir one tab per account behavior," which is not this repo's model and is not needed for `:archive`/`:delete` to work.

### 2. `~` expansion — confirmed correct, by source code, not inference

The task explicitly flagged this as something to verify ("aerc may not expand `~` in accounts.conf"). Read directly from the nixpkgs-built aerc source (`worker/notmuch/worker.go`, `NewWorker`/`Configure`, around line 233):

```go
val, ok := msg.Config.Params["maildir-store"]
if ok {
    path := xdg.ExpandHome(val)
    w.maildirAccountPath = msg.Config.Params["maildir-account-path"]
    path = filepath.Join(path, w.maildirAccountPath)
    store, err := lib.NewMaildirStore(path, false)
    ...
}
```

`maildir-store`'s raw string value is passed through `xdg.ExpandHome()` before use — `~` IS expanded for this option. This is also consistent with existing precedent already deployed in this exact file: `general.default-save-path = "~/Downloads"` (aerc.nix line 11) already relies on the same tilde-expansion behavior and is a live, working setting in this config. `maildir-store = ~/Mail` is therefore the correct form (not an absolute `/home/benjamin/Mail` path, and not a `file://` URL — it is a bare filesystem path string, unlike `source`, which is a `notmuch://` URL).

Note the distinct rule for `source`: the man page (`aerc-notmuch(5)`) states the path portion following `notmuch://` must be prefixed with either `/` (absolute) or `~` (home-relative) — a URL-parsing rule specific to `source`, separately confirmed in source (`worker/notmuch/worker.go` calls `xdg.ExpandHome(u.Hostname() + u.Path)` on the parsed `notmuch://` URL). `maildir-store` is a plain path option (no URL scheme) with its own, separately-confirmed `xdg.ExpandHome()` call — both end up tilde-expanded, by two different code paths, but neither depends on the other.

### 3. Option names and validity for the installed aerc version — verified against actual build, not upstream master

Locally installed: `aerc 0.21.0 +notmuch-5.7.0` (`which aerc` → `/home/benjamin/.nix-profile/bin/aerc`; `aerc --version`). `nix eval nixpkgs#aerc.version` also resolves to `"0.21.0"`, and the exact source tree Nix fetches for this build (`/nix/store/vzbr9yjgh71ha9qiq7b9ll410j4ldvk5-source`) was read directly.

- `doc/aerc-notmuch.5.scd` in that exact source tree documents `maildir-store`, `maildir-account-path`, and `multi-file-strategy` fully and without any deprecation notice — matching the locally-installed man pages (`man 5 aerc-notmuch`, read via `zcat .../aerc-notmuch.5.gz`).
- `worker/types/mfs.go` defines the exact valid strategy strings as a Go map:

  ```go
  var StrToStrategy = map[string]MultiFileStrategy{
      "refuse":              Refuse,
      "act-all":             ActAll,
      "act-one":             ActOne,
      "act-one-delete-rest": ActOneDelRest,
      "act-dir":             ActDir,
      "act-dir-delete-rest": ActDirDelRest,
  }
  ```

  `act-dir` is confirmed as an exact, valid literal key. Alternatives: `refuse` (default), `act-all`, `act-one`, `act-one-delete-rest`, `act-dir-delete-rest`.
- **Important forward-compatibility note, not a current blocker**: upstream aerc's `master` branch (post-`0.20.1`, commit `9e77103` "notmuch: simplify source URL and use automatic discovery", 2024-10-12) has since **deprecated `maildir-store`** in favor of a new `enable-maildir` option (default `true`; maildir root now auto-discovered from the notmuch database) — `config/accounts.go` on master strips `maildir-store` from the params map and emits a `"accounts.conf: maildir-store is deprecated"` warning telling the user to remove it. This deprecation is **not** present in the nixpkgs `0.21.0` source actually installed here (confirmed by grepping the real `aerc.src`, which has no `enable-maildir` anywhere and documents `maildir-store` normally). No action needed now, but if/when nixpkgs bumps `aerc` past this point, `maildir-store`/`maildir-account-path` will need to be removed from `accounts.conf` (they'll become harmless-but-warned deprecated no-ops with the new default-`true` `enable-maildir` behavior superseding them) — worth a one-line comment in the accounts.conf edit for future maintainers, or a follow-up task when that bump happens.

### 4. Confirmed: notmuch backend requires `maildir-store` for `:archive`/`:delete`/`:move` — verified in source, explains the "silent no-op"

`worker/notmuch/worker.go`'s mutation handlers all gate on `w.store` (the `*lib.MaildirStore` initialized only if `maildir-store` is present in accounts.conf):

```go
func (w *worker) handleMoveMessages(msg *types.MoveMessages) error {
    if w.store == nil {
        return errUnsupported
    }
    ...
}
```

Identical `if w.store == nil { return errUnsupported }` guards exist in `handleDeleteMessages` and `handleCopyMessages` too. Without `maildir-store` set, `w.store` stays `nil` (it is only constructed inside the `if ok` branch when `Params["maildir-store"]` is present), so every `:archive`/`:delete`/`:move`/`:copy` request returns `errUnsupported` immediately — this is the exact mechanism behind the task's observed symptom ("`a = :archive flat` is a silent no-op — replied messages remain in Gmail/cur with tag:inbox, unmoved"). Adding `maildir-store` is necessary and sufficient to unblock this code path (though see the critical risk below for one more gate that applies specifically to multi-file messages).

### 5. Archive semantics confirmed at the file-operation level

`commands/msg/archive.go`, the `archive()` function backing `:archive flat`:

```go
archiveDir := acct.AccountConfig().Archive   // = "All_Mail" (gmail) / "Archive" (logos)
...
case ARCHIVE_FLAT:
    uidMap = make(map[string][]models.UID)
    uidMap[archiveDir] = commands.UidsFromMessageInfos(msgs)
...
for dir, uids := range uidMap {
    store.Move(uids, dir, true, mfs, ...)
}
```

This confirms `:archive flat` targets exactly the account's configured `archive =` value — `All_Mail` for gmail, `Archive` for logos — consistent with what's already in `accounts.conf` and unchanged by this task.

The actual file operation, in `worker/notmuch/message.go`, `Message.Move`:

```go
func (m *Message) Move(curDir, destDir maildir.Dir, mfs types.MultiFileStrategy) error {
    move, del, err := m.filenamesForStrategy(mfs, curDir)
    ...
    for _, filename := range move {
        name := lib.StripUIDFromMessageFilename(filepath.Base(filename))
        dest := filepath.Join(string(destDir), "cur", name)
        if err := os.Rename(filename, dest); err != nil {
            return err
        }
        if _, err = m.db.IndexFile(dest); err != nil {
            return err
        }
        if err := m.db.DeleteMessage(filename); err != nil {
            return err
        }
    }
    ...
}
```

This is a literal `os.Rename()` of the maildir file out of the source folder's `cur/` into the destination folder's `cur/`, followed by re-indexing the file at its new path and removing the old-path notmuch entry. This is the same class of maildir-level relocation as `email-archive-confirmed.nix`'s already-proven `himalaya message move "$ACCOUNT_ARCHIVE_FOLDER" "$id" -f "$RESOLVED_FOLDER"` (`modules/home/email/agent-tools/archive-confirmed.nix` line 51) — both ultimately relocate the physical file between Maildir++ folders; aerc does it directly via its own Go worker rather than shelling out to himalaya.

### 6. `mbsync` propagation — confirmed `gmail-inbox` is `Expunge Both`

`modules/home/email/mbsync.nix`, lines 36-41:

```
Channel gmail-inbox
Far :gmail-remote:INBOX
Near :gmail-local:
Create Both
Expunge Both
SyncState *
```

`Expunge Both` means mbsync propagates deletions/removals symmetrically: when a message's local file physically vanishes from the `Gmail/cur/` maildir folder (because aerc's `os.Rename` moved it into `Gmail/.All_Mail/cur/`), the next `mail-sync gmail` (which wraps `mbsync gmail`, itself running the `gmail-inbox` channel as part of `Group gmail`) will expunge that message from the Far side (`:gmail-remote:INBOX`) too — which for a Gmail IMAP mailbox means removing the `INBOX` label from that message on the server, i.e. true archiving, not deletion. Symmetrically, `Channel logos-inbox` (lines 137-142 of mbsync.nix) is also `Expunge Both`, and Logos's Protonmail-Bridge IMAP semantics for folder membership apply the same propagation.

### 7. CRITICAL RISK (new finding, not in the task description): `act-dir`'s `curDir` resolution depends on the OPEN TAB'S NAME, not just on `multi-file-strategy` being set

This is the single most important thing the live-verification step must specifically test, and it follows directly from reading the worker source rather than the man page.

**Mechanism** (`worker/notmuch/worker.go`):

- Every mutation handler resolves the "current folder" the same way:
  ```go
  folders, _ := w.store.FolderMap()
  curDir := folders[w.currentQueryName]
  ```
  (identical pattern in `handleMoveMessages`, `handleDeleteMessages`, `handleCopyMessages`.)
- `w.currentQueryName` is set in `handleOpenDirectory` to `msg.Directory` — the **name of the tab currently open**, i.e. whatever string the account's `default =`/tab-switch resolved to. For this repo, the default and normally-used tab is `INBOX` (`default = INBOX` in accounts.conf; `INBOX=folder:Gmail` in the querymap, per task 110).
- `w.store.FolderMap()` (`worker/lib/maildir.go`) is built by `filepath.Walk`-ing the `maildir-store` root and keying every directory that contains `new`/`tmp`/`cur` subdirectories **by its literal relative path from the root** — for this repo's layout that produces keys `Gmail`, `Gmail/.Sent`, `Gmail/.All_Mail`, `Gmail/.Drafts`, `Gmail/.Trash`, `Gmail/.Spam`, and the `Logos` equivalents. Critically, `NewMaildirStore(path, false)` is called with the Maildir++ flag hardcoded `false` (`worker/notmuch/worker.go` line ~239), so the `FolderMap()` special-case that would otherwise alias `"INBOX"` to the store root (`if s.maildirpp { folders["INBOX"] = ... }`, in `worker/lib/maildir.go`) **never applies**. There is no `"INBOX"` key in this map — only `"Gmail"`.
- Consequence: when the user is on the `INBOX` tab (the querymap alias, opened by default), `w.currentQueryName == "INBOX"`, but `folders["INBOX"]` does not exist, so `curDir` resolves to the empty string.
- `filterForStrategy` (`worker/notmuch/message.go`) explicitly downgrades the strategy when `curDir` is empty:
  ```go
  if curDir == "" &&
      (strategy == types.ActDir || strategy == types.ActDirDelRest) {
      strategy = types.Refuse
  }
  ```
  So archiving a **multi-file** message (one with a copy in both `Gmail/cur/` and `Gmail/.All_Mail/cur/`) while on the `INBOX` tab will silently become `refuse` and fail with `refusing to act on multiple files` — even though `multi-file-strategy = act-dir` is correctly set in accounts.conf. Single-file messages are unaffected (`filterForStrategy` returns early via `if len(filenames) < 2 { return filenames, []string{}, nil }` before the strategy switch even runs), so ~50/85 ordinary messages will archive fine from any tab.
- **This is fixable in the UI without any further accounts.conf change**: `handleListDirectories` posts **both** the raw physical folder names from `FolderMap()` (available as soon as `maildir-store` is set) **and** every querymap name as separate sidebar/tab entries:
  ```go
  for name := range folders {                 // "Gmail", "Gmail/.All_Mail", ...
      w.w.PostMessage(&types.Directory{... Dir: &models.Directory{Name: name}}, nil)
  }
  for _, name := range w.queryMapOrder {       // "INBOX", "Sent", "Unread", ...
      w.w.PostMessage(&types.Directory{... Dir: &models.Directory{Name: name, Role: models.QueryRole}}, nil)
  }
  ```
  So once `maildir-store` is added, a literal `Gmail` (and `Logos`) tab becomes navigable (e.g. via `:cf Gmail<Enter>`), distinct from the `INBOX` querymap alias. Opening that literal tab sets `w.currentQueryName = "Gmail"`, which **does** match a `FolderMap()` key, so `curDir` resolves correctly and `act-dir` behaves as documented — acting only on the file physically present in `Gmail/cur/`, leaving the pre-existing `Gmail/.All_Mail/cur/` copy untouched (`del = []string{}` for plain `act-dir`, confirmed in `filterForStrategy`).
- **What the implementer's live verification must therefore check** (this sharpens, not replaces, the task's own instruction to "archive ONE known multi-file message"):
  1. From the normal `INBOX` tab, archive a message known to have a second `All_Mail`/`Archive` copy. If this fails with `refusing to act on multiple files`, that confirms the `curDir`-empty theory above.
  2. If it does fail, retry the same message from the literal `Gmail` (or `Logos`) tab (`:cf Gmail<Enter>` then archive) and confirm it now succeeds.
  3. If (1) actually succeeds (i.e. this analysis is wrong, or aerc's tab-name resolution differs from what a static read of the source suggests), that is equally important to record — either way, this determines whether the `a`/`A` keybinds can stay bound in the `messages`/`view` contexts as-is, or whether they (or a dedicated Gmail/Logos-only binding) need to `:cf Gmail<Enter>`/`:cf Logos<Enter>` first for reliable multi-file handling. This refinement is implementation-level and out of scope for this research report, but the finding itself is squarely in scope ("verify the exact semantics").

### 8. Secondary consequence of `act-dir` on multi-file messages worth flagging for the live-verification step

For a message that already has a copy in **both** `Gmail/cur/` and `Gmail/.All_Mail/cur/` (the 35/85 case), archiving from the correct tab (`Gmail`, per point 7) with plain `act-dir` renames only the `Gmail/cur/` copy into `Gmail/.All_Mail/cur/` — it does **not** touch or delete the pre-existing `All_Mail` copy (`act-dir-delete-rest` would; plain `act-dir` does not, confirmed via `filterForStrategy`'s `del = []string{}` for the non-delete-rest case). The result is that `Gmail/.All_Mail/cur/` will end up holding **two physical files for the same message** (harmless for notmuch, which already dedupes by Message-ID) with the UID stripped from the newly-renamed file's name (`lib.StripUIDFromMessageFilename`, deliberate, per an inline aerc source comment, "to prevent sync issues"). Because `mbsync.nix`'s `gmail-all` channel is `Create Near` only (not `Both`) — i.e. it only pulls Far→Near, never pushes local-only files to the server — this newly-created local duplicate should not get pushed up to Gmail as a new/duplicate message on the next `mail-sync gmail`. This is a reasonable inference from the channel directions in mbsync.nix, but it has **not** been independently confirmed against mbsync's actual behavior for an untracked, UID-less local file appearing in a `Create Near`-only channel's folder, and is exactly the kind of subtlety the task's mandated live check (archive one multi-file message, then run `mail-sync gmail`, then inspect the Gmail web UI) is designed to catch. Flag this explicitly as something to watch for during that live check: confirm no duplicate message appears in Gmail's All Mail/web view after the sync, beyond the pre-existing one.

### 9. `a`/`A` confirmation prompts and Proposed-* gestures — review per goal 5

Current bindings (`modules/home/email/aerc.nix` lines 104-113, 200-206):

```
d = ":prompt 'Delete message?' 'delete-message'<Enter>"
D = ":prompt 'Hard delete (bypass the confirm-message prompt)?' 'delete'<Enter>"
a = ":archive flat<Enter>"
A = ":unmark -a<Enter>:mark -a<Enter>:prompt 'Archive ALL marked messages?' 'archive flat'<Enter>"
```

- `A` (bulk archive of every marked message) is already gated by an explicit `:prompt` confirmation — appropriate given the larger blast radius, and needs no change.
- `d`/`D` (delete) are already prompted.
- Bare `a` (single-message archive, in both `messages` and `view` contexts) has **no** confirmation today. This was harmless while `:archive` was a no-op; once `maildir-store` is set it becomes a real, immediately-executed, server-propagating mutation on the currently selected message. Recommendation: this is defensible to leave unprompted — archiving is low-risk and trivially reversible (moving the file back into the inbox folder undoes it), which is why most mail clients (including Gmail's own web UI) bind archive to a single unconfirmed keystroke while reserving confirmation dialogs for delete. No functional change is required for this task, but the decision should be recorded explicitly (e.g., a one-line comment next to the `a =` binding) rather than left as an accidental non-decision, since it was never a deliberate choice while archive was inert.
- The `messages:folder=Proposed-Archive` / `Proposed-Delete` / `Proposed-Unsure` view bindings (`modules/home/email/aerc.nix` lines 175-184) are unaffected by this change: they deliberately **never** call aerc's native `:archive`/`:delete-message` at all — they only `:modify-tags` and `:exec email-classify --append-approved`, explicitly to stay inside the wrapper-routed propose/review/confirm/execute flow and avoid aerc's Go worker doing the mutation directly (per the existing task-72-Phase-9 comment at lines 161-169). Enabling native archive/delete for the plain `a`/`A`/`d`/`D` keys does not change or need to change this separation; it only makes the *human-only* native path (used everywhere **except** those three curated views) actually functional instead of silently inert.

## Decisions

- **accounts.conf edit**: add `maildir-store = ~/Mail` and `multi-file-strategy = act-dir` to both `[gmail]` and `[logos]` sections in `modules/home/email/aerc.nix`, placed directly after each account's `source = notmuch://~/Mail` line. No other accounts.conf lines change. Do not set `maildir-account-path` (both accounts intentionally share one `maildir-store` root, mirroring how they already share one notmuch `source` root).
- **Live verification must explicitly test tab context for the multi-file case**: per finding 7, archive one ordinary (single-file) message and one known multi-file message from the `INBOX` tab; if the multi-file archive fails with `refusing to act on multiple files`, retry from the literal `Gmail` tab (`:cf Gmail<Enter>`) and record which tab context actually makes `act-dir` take effect. This determines whether any follow-up keybind adjustment (`:cf Gmail<Enter>` before `:archive flat`) is needed — that adjustment itself is out of scope for this task if the plain `INBOX`-tab archive of a multi-file message already works (i.e., if this report's source-level analysis turns out not to manifest in practice).
- **No change to `a`/`A`/`d`/`D` :prompt confirmations required.** Recommend documenting (a one-line comment) that `a` is deliberately left unprompted now that it is live, matching the reversible/low-risk archive convention, while `A`/`d`/`D` remain prompted for their higher blast radius or destructiveness.
- **No change needed to `Proposed-*` view bindings** — they never call native archive/delete and are unaffected by this task.

## Risks & Mitigations

- **Risk (the critical one, finding 7)**: multi-file messages may fail to archive from the `INBOX` tab despite `multi-file-strategy = act-dir` being configured correctly, because `curDir` resolution depends on the open tab's name literally matching a `FolderMap()` key, and `INBOX` (the querymap alias) does not. **Mitigation**: this is precisely what the task's own mandated live-verification step (archive one multi-file message, confirm via `mail-sync gmail` + Gmail web UI) will surface; this report gives the implementer the exact tab-switch retry (`:cf Gmail<Enter>`) to try if the first attempt fails with `refusing to act on multiple files`, rather than assuming a source-code or Nix build defect.
- **Risk**: a multi-file archive (once it works, from whichever tab) leaves two physical files for one message under `Gmail/.All_Mail/cur/` (harmless to notmuch, dedupes by Message-ID) and depends on `mbsync`'s `gmail-all` channel (`Create Near` only) not pushing the new local duplicate up to Gmail as a new/duplicate server-side message. **Mitigation**: the task's mandated live check already includes inspecting the Gmail web UI after `mail-sync gmail` — explicitly confirm no duplicate appears there, not just that the message left the inbox.
- **Risk**: forward nixpkgs bump risk — `maildir-store`/`maildir-account-path` are deprecated on aerc's upstream `master` (replaced by `enable-maildir`, default `true`, auto-discovered maildir root) as of commit `9e77103` (2024-10-12), though not yet present in the nixpkgs `0.21.0` build installed here. **Mitigation**: no action now; flag with an inline comment in the accounts.conf edit, and revisit if/when the nixpkgs `aerc` derivation is bumped past that point (accounts.conf would then need `maildir-store`/`maildir-account-path` removed per the emitted deprecation warning; `enable-maildir` defaults `true` so no replacement line would be needed).
- **Risk**: `a` (single-message archive) now performs a real, unprompted, immediately-executed mutation. **Mitigation**: judged acceptable given archive's low-risk/reversible nature and mail-client convention (see finding 9); if the user later wants extra safety, the same `:prompt` pattern already used for `D`/`A` can be applied to `a` with a one-line change.
- **No changes to any wrapper binary, `mail-guard.sh` allowlist, or the Proposed-\* review flow are needed or made by this task** — this is purely a native-aerc, human-only-path change (per the existing task-72-Phase-9 architecture decision already recorded in aerc.nix).

## Appendix

### Live-verification checklist for the implementer (per task's own instruction, sharpened by this report's findings)

1. `home-manager build --flake .#benjamin` (or equivalent) — must succeed; this is a pure accounts.conf text-content change with no Nix syntax risk beyond string-literal correctness.
2. Restart/reload aerc so the notmuch worker re-reads `accounts.conf` (the worker only parses `maildir-store` in its `Configure`/`NewWorker` path).
3. Identify one ordinary (single-file) inbox message and one known multi-file message (a copy also present under `Gmail/.All_Mail`), e.g. via `notmuch search --output=files <query>` counting files per Message-ID, or reusing whatever the task's own "35 of 85" probe used.
4. Archive the ordinary message from the `INBOX` tab with `a`. Confirm it disappears from `INBOX` and appears in the `All_Mail` querymap tab.
5. Archive the multi-file message from the `INBOX` tab with `a`. If it fails with `refusing to act on multiple files`, switch to the literal `Gmail` tab (`:cf Gmail<Enter>`) and retry.
6. Run `mail-sync gmail` (the `$` keybind or directly).
7. In the Gmail web UI, confirm both messages: (a) left the inbox (no `INBOX` label), (b) remain visible in All Mail (i.e. archived, not trashed), and (c) for the multi-file case specifically, that no duplicate copy was created server-side.
8. Repeat steps 3-7 for the `logos` account (`Archive` folder, Protonmail Bridge), noting task 108's recent CA-trust fix (commit `6c42117`) is a prerequisite for Logos connectivity generally.
9. Record the actual tab-context result (finding 7) in the implementation summary — this determines whether any follow-up `:cf`-prefixed keybind change belongs in this task or should be spun into a new task.

### Files/sources read

- `modules/home/email/aerc.nix` (full)
- `modules/home/email/mbsync.nix` (full)
- `modules/home/email/agent-tools/archive-confirmed.nix` (full)
- `specs/110_aerc_inbox_querymap_real_folder/reports/01_inbox-querymap-real-folder.md` (prior task's grounding, for the INBOX querymap dependency)
- `specs/state.json` (task 112 entry, `file_scope`, dependencies)
- Locally installed aerc man pages: `aerc-accounts(5)`, `aerc-notmuch(5)` (`aerc 0.21.0 +notmuch-5.7.0`)
- nixpkgs `aerc.src` (exact source tree fetched via `nix eval`/`nix-store -r`, matching the installed build): `config/accounts.go`, `worker/notmuch/worker.go`, `worker/notmuch/message.go`, `worker/lib/maildir.go`, `worker/types/mfs.go`, `commands/msg/archive.go`, `doc/aerc-notmuch.5.scd`
- Upstream aerc GitHub (`rjarry/aerc`, `master` branch and `CHANGELOG.md`) — for forward-compatibility contrast only (the `enable-maildir` deprecation, not applicable to the installed 0.21.0 build)

### Web sources consulted

- [aerc-notmuch(5) — Arch manual pages](https://man.archlinux.org/man/aerc-notmuch.5.en)
- [aerc-notmuch: notmuch configuration for aerc(1) — ManKier](https://www.mankier.com/5/aerc-notmuch)

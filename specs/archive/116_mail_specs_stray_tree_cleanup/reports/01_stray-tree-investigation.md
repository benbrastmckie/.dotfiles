# Research Report: Task #116

**Task**: 116 - Investigate and safely remediate a misplaced non-mail filesystem tree at ~/Mail/specs/
**Started**: 2026-07-14T00:00:00Z
**Completed**: 2026-07-14T00:00:00Z
**Effort**: medium
**Dependencies**: task 114 (Gmail All_Mail duplicate-UID remediation — related but distinct finding)
**Sources/Inputs**:
- Live filesystem inspection of `~/Mail/` and `~/.dotfiles/` (`ls -la`, `find`, `stat`, `du`)
- `~/Mail/.git` and `~/.dotfiles/.git` history (`git log`, `git ls-files`, `git status`)
- `~/Mail/.claude/tmp/mail-guard-audit.log` and `~/.dotfiles/.claude/tmp/mail-guard-audit.log` (PreToolUse Bash audit trails)
- `modules/home/email/notmuch.nix`, `modules/home/email/agent-tools/lib.nix` (repo source)
- Task 114 artifacts (`08_stray-dir-baseline.txt`, `08_stray-directory-finding-NOT-REMOVED.md`, `10_phase6-guard-decision.md`)
- `notmuch-config(1)` man page (`new.ignore` semantics)

**Artifacts**: this report

**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The task's core premise is only partly correct.** `~/Mail/specs/` (8.4MB, 219 files) is
  **not** a single stray tree accidentally dumped by one 2026-07-13/14 tool run. `~/Mail` is
  itself a **fully independent, long-lived git repository** (158 commits back to a `task 1`
  commit, its own `.claude/` agent-system deployment, its own task numbering) whose `specs/`
  directory is its legitimate, git-tracked task-management history going back to **February
  2026**. 218 of the 219 files are committed, clean (`git status` shows nothing dirty under
  `specs/`), and are the **only copy** of that repo's own task history — they must not be
  deleted or "relocated into `~/.dotfiles`" (there is nothing to relocate; they belong to a
  different project).
- **Exactly one artifact under `~/Mail/specs/` is genuinely stray**:
  `~/Mail/specs/072_email_workflow_infrastructure_prereqs/manifests/` — an **empty**, **untracked**
  two-directory stub (0 files, ~8KB of bare directory entries) with Birth time
  **2026-07-13 12:23:08**, created **5 minutes after** `~/Mail`'s own task 072 was archived
  (git commit `ba3f0ff`, 2026-07-13 12:18:00, "archive 7 tasks"). This is filesystem litter,
  not data — safe to remove with `rmdir` (empty-only).
- **Root cause identified with certainty**: `modules/home/email/agent-tools/lib.nix:35` hardcodes
  `manifestDirDefault = "specs/072_email_workflow_infrastructure_prereqs/manifests"` — a
  **repository-relative** (not absolute) path, baked into all five nix-built wrapper binaries
  (`email-census`, `email-classify`, `email-archive-confirmed`, `email-delete-confirmed`,
  `email-unsubscribe-extract`). Every wrapper does
  `MANIFEST_DIR="${EMAIL_MANIFEST_DIR:-${manifestDirDefault}}"` then `mkdir -p "$MANIFEST_DIR"`.
  Unless the caller explicitly sets `$EMAIL_MANIFEST_DIR` or passes `--manifest-dir`, invoking
  **any** of these binaries from a `cwd` other than `~/.dotfiles` recreates
  `<cwd>/specs/072_email_workflow_infrastructure_prereqs/manifests/`. The audit-log trail shows
  this literal relative path used from at least three different `cwd`s (`~/.dotfiles`, `~/Mail`,
  and — per task 114's independent finding — apparently once inside
  `~/Mail/Gmail/.All_Mail/cur/`), and it only "worked" invisibly for months because both
  `~/.dotfiles` and `~/Mail` coincidentally have their **own, unrelated** task 072 about
  "email workflow infrastructure prereqs." The bug surfaced visibly only once `~/Mail`'s task 072
  was archived and something re-invoked a wrapper (or ran the same manual `mkdir -p`-style
  snippet) from `cwd=~/Mail` afterward.
- **notmuch's `new.ignore`** (`modules/home/email/notmuch.nix`) currently lists only 4 filename
  patterns (`.mbsyncstate`, `.strstrings`, `.lock`, `dovecot*`). Since `database.path = ~/Mail`
  (the whole repo root, not a maildir-only subdirectory), **every** non-maildir top-level entry
  under `~/Mail` (`specs/`, `.claude/`, `.git/`, `docs/`, `email_plans/`, `email_reports/`,
  `.memory/`, `README.md`, `README_OLD.md`, `CLAUDE.md`, `Contacts/`, `.gitignore`,
  `.logos-backup-*/`, `.logos-presync-*/`, `.syncstate-backups/`) triggers "Ignoring non-mail
  file" log spam on every `notmuch new` — `specs/` is one of many, not a special case.
- The separate, already-resolved finding from task 114
  (`~/Mail/Gmail/.All_Mail/cur/specs,U=67297/072_email_workflow_infrastructure_prereqs/manifests/`,
  an empty directory *inside* the live Gmail maildir that briefly blocked `mbsync gmail`) is
  confirmed **already gone** from the filesystem as of this investigation
  (`find ~/Mail/Gmail -iname "specs*"` returns nothing). No further action needed there.

## Context & Scope

Task 114 (duplicate-UID remediation) surfaced a stray directory inside the live Gmail maildir
and, separately, noted that `~/Mail/specs/` itself looked suspicious. Task 116 was created to
determine precisely what `~/Mail/specs/` is, whether any of it is unique/valuable data, and how
to prevent recurrence. This investigation is read-only: nothing was deleted, moved, or mutated.

## Findings

### Provenance: `~/Mail` is an independent repo, not an accidental write target

```
~/Mail/.git exists, no remote configured (local-only repo)
git -C ~/Mail log --oneline | wc -l        -> 158 commits
git -C ~/Mail log --oneline | tail -5      -> 088dbc8 task 1: create implementation plan
                                               7d4feaa task 1: complete research
                                               4f269e0 task 1: create research himalaya email
                                                        system documentation
                                               0b2c291 added gitignore
                                               73543c3 added claude
```

`~/Mail/README.md` confirms this is documented, intentional infrastructure: "Maildir++ mail
storage for two email accounts... " with its own `.claude/` agent-system checkout
(`.claude/agents/`, `.claude/commands/`, `.claude/context/`), its own `docs/` directory, and its
own `specs/{TODO.md,state.json,ROADMAP.md}` — i.e., a **second, independent deployment of the
same Claude Code agent-system framework used by `~/.dotfiles`**, scoped specifically to
email-related task work (task numbers referenced in comments as "Mail repo task 35",
"~Mail task 34", distinct from `.dotfiles` task numbers like "852/853"). This is corroborated by
`modules/home/email/notmuch.nix`'s own comment: *"~Mail task 34 baseline; tracked separately as
.dotfiles task 852/853"* — the codebase already documents that `~/Mail` runs its own parallel
task-numbering scheme.

`git -C ~/Mail status --porcelain -- specs/` returns **empty** — the entire tracked `specs/` tree
is clean, nothing modified/staged. `git -C ~/Mail ls-files specs/ | wc -l` → **218** files,
matching the task description's "~219 files" almost exactly (the 219th being the untracked stray
directory described below, which contributes 0 files but 2 directory entries).

### The one genuine stray artifact

`~/Mail/specs/072_email_workflow_infrastructure_prereqs/manifests/`:

```
$ stat ~/Mail/specs/072_email_workflow_infrastructure_prereqs
  Birth: 2026-07-13 12:23:08.892769290 -0700
$ find ~/Mail/specs/072_email_workflow_infrastructure_prereqs -type f | wc -l
0
$ git -C ~/Mail ls-files specs/072_email_workflow_infrastructure_prereqs
(empty — untracked)
```

`~/Mail`'s own task 072 was archived 5 minutes earlier:

```
$ git -C ~/Mail log -1 --format='%ci' -- specs/archive/072_email_workflow_infrastructure_prereqs
2026-07-13 12:18:00 -0700   (commit ba3f0ff "todo: archive 7 tasks and track 1 orphaned directory")
```

The populated, git-tracked version of this directory now lives at
`~/Mail/specs/archive/072_email_workflow_infrastructure_prereqs/manifests/` (contains
`sweep-logos-inbox-20260705T000000.sh` and two `.jsonl`/`.log` artifacts, all git-tracked, all
committed as part of the archive move). The empty stub at the pre-archive path was recreated
minutes later by a process still resolving the manifest directory via the stale relative default
(see Root Cause below) with `cwd=~/Mail`.

This is a **git-detected non-event**: because the directory is empty, git doesn't even list it as
untracked in `git status` (git only tracks blobs/files, never empty directories), which is why it
was invisible until an explicit `find`/`ls -la` walk.

### Per-subtree uniqueness/duplication table

| Path | Size | Files | Git status (in `~/Mail` repo) | Duplicate of `.dotfiles/specs/`? | Verdict |
|---|---|---|---|---|---|
| `specs/TODO.md`, `state.json`, `ROADMAP.md`, `.meta-return.json` | ~14K | 4 | tracked, clean | No — distinct task numbers/content (`~/Mail`'s own task list, e.g. tasks 1-35, 72, 858...) | **Unique**, legitimate own-repo state. Keep. |
| `specs/archive/001.../035.../072.../` (33 archived task dirs) | 8.2M | ~200 | tracked, clean | No overlap in directory names except `072_email_workflow_infrastructure_prereqs` (coincidental — see below) | **Unique**, `~/Mail`'s own archived task history (Feb-Jul 2026). Keep. |
| `specs/027_email_cleanup_logos_20260219/` | 36K | 3 | tracked, clean | No — `.dotfiles/specs/` has no task 027 | **Unique**. Keep. |
| `specs/029_gmail_backlog_purge_and_ongoing_hygiene/` | 16K | 1 | tracked, clean | No — `.dotfiles/specs/` has no task 029 | **Unique**. Keep. |
| `specs/072_email_workflow_infrastructure_prereqs/manifests/` (top-level, non-archive) | 8.0K | **0** | **untracked**, invisible to `git status` (empty dirs) | N/A — empty | **Stray litter.** Safe `rmdir` (innermost-first, empty-only). No data at risk. |
| `specs/email-manifests/logos/*.jsonl` (7 files: candidate-manifest, sweep-accumulator ×2, sweep-dedup, approved-all-20260704 + its `.state.jsonl` chain) | 88K | 7 | tracked, clean | No — `.dotfiles` has **no `email-manifests/` directory anywhere** (`find /home/benjamin/.dotfiles -iname "email-manifests"` → empty) | **Unique.** Historical Logos classification working-data from `~/Mail`'s own tasks 27/29. Keep — treat as the ONLY copy per the task's own safety constraint (confirmed true, not just assumed). |
| `specs/meta/` | 4.0K | small | tracked, clean | N/A | `~/Mail`'s own `/meta` task-creation output. Keep. |
| `specs/tmp/` | 8.0K | — | **gitignored** (`.gitignore`: `specs/tmp/`) | N/A | Scratch, gitignore-covered, not a concern. |

**`072` name-collision explanation**: `~/Mail/specs/archive/072_email_workflow_infrastructure_prereqs/`
and `~/.dotfiles/specs/archive/072_email_workflow_infrastructure_prereqs/` are the **only**
overlapping directory names between the two repos' archives
(`comm -12` of sorted directory-name lists returns only `072_email_workflow_infrastructure_prereqs`
and the trivial `state.json`). This is a coincidence of two independent task counters both
reaching "72" for similarly-scoped "email workflow infrastructure prereqs" work around the same
period — not evidence of cross-repo copying. Both repos' `072` directories contain **different**
content specific to their own repo (`.dotfiles/specs/archive/072/` has
`handoffs/wrapper-contract.md`, `handoffs/mail-29-runbook.md`, `plans/`, `summaries/`, `reports/`;
`~/Mail/specs/archive/072/` has only a `manifests/` subdirectory with a sweep shell script and
progress logs).

**Conclusion**: of the ~219 files/entries under `~/Mail/specs/`, **218 are legitimate,
git-committed, unique data belonging to `~/Mail`'s own independent task-management repo** (some
dating to February 2026) and must not be touched. **Exactly 2 empty directory entries (0 files)**
are stray litter from a path-resolution bug, safe to remove.

### Root cause: `manifestDirDefault` hardcoded as a relative path

`modules/home/email/agent-tools/lib.nix`:

```nix
manifestDirDefault = "specs/072_email_workflow_infrastructure_prereqs/manifests";
...
MANIFEST_DIR="''${EMAIL_MANIFEST_DIR:-${manifestDirDefault}}"
...
mkdir -p "$MANIFEST_DIR"
```

This constant is interpolated into **all five** nix-built wrapper binaries (`email-census`,
`email-classify`, `email-archive-confirmed`, `email-delete-confirmed`,
`email-unsubscribe-extract` — the only binaries permitted to touch mail per the wrapper-only
safety invariant). The binaries' own `--help` text acknowledges the fragility: *"default:
$EMAIL_MANIFEST_DIR, else specs/072_.../manifests/ relative to the current working directory —
normally the .dotfiles repo root"* — "normally" is doing a lot of work here; nothing enforces it.

Evidence from the audit trail (`~/Mail/.claude/tmp/mail-guard-audit.log` and
`~/.dotfiles/.claude/tmp/mail-guard-audit.log`, PreToolUse Bash logs) shows the identical relative
idiom `MDIR=specs/072_email_workflow_infrastructure_prereqs/manifests` (or
`MANIFEST="specs/072_.../manifests/candidate-manifest.jsonl"`) invoked from at least three
different working directories over time:
- `cd /home/benjamin/.dotfiles` then `MDIR=...` (correct — resolves inside `.dotfiles`, matches
  `.dotfiles/specs/archive/072_.../manifests/README.md`, now archived).
- `cd /home/benjamin/Mail` then `MDIR=...` (resolves inside `~/Mail`'s **own, coincidentally
  same-numbered** task 072 — worked by accident for months, from 2026-07-04 through archival on
  2026-07-13).
- Task 114 independently found the maildir-internal instance
  (`~/Mail/Gmail/.All_Mail/cur/specs,U=67297/072_.../manifests/`, Birth 2026-07-13 13:46:47,
  confirmed empty, confirmed never mbsync-mapped), consistent with the same relative default
  resolving against a `cwd` that had drifted inside a live maildir `cur/` folder.

No systemd unit, cron job, or skill (`skill-email-cleanup`, `skill-email-implementation`) sets
`EMAIL_MANIFEST_DIR` or documents a required `cd ~/.dotfiles` precondition —
`grep -rn "EMAIL_MANIFEST_DIR\|cd ~/.dotfiles" .claude/skills/skill-email-*/SKILL.md` returns
nothing. The override mechanism exists but nothing forces its use.

### notmuch `new.ignore` — current gap

```nix
# modules/home/email/notmuch.nix
new = {
  tags = [ "new" ];
  ignore = [
    ".mbsyncstate"
    ".strstrings"
    ".lock"
    "dovecot*"
  ];
};
```

Live config confirms this is exactly what's deployed:
`notmuch config get new.ignore` → `.mbsyncstate` / `.strstrings` / `.lock` / `dovecot*`, and
`notmuch config get database.path` → `/home/benjamin/Mail` (the whole repo root).

Per `notmuch-config(1)`, `new.ignore` accepts two entry forms:
1. **Bare name** (file or directory, no path) — ignored "regardless of the location in the mail
   store directory hierarchy" (i.e., matched at any depth by basename).
2. **Anchored regex** delimited by `/.../ ` — matched against the path relative to
   `database.path`, with explicit `^`/`$` anchors required.

Since `~/Mail`'s top-level non-maildir entries are `specs/`, `.claude/`, `.git/`, `docs/`,
`email_plans/`, `email_reports/`, `.memory/`, `README.md`, `README_OLD.md`, `CLAUDE.md`,
`Contacts/`, `.gitignore`, `.logos-backup-20260706/`, `.logos-presync-20260712T132632Z/`,
`.syncstate-backups/` — none of these are in `new.ignore` today, so `notmuch new` walks and logs
"Ignoring non-mail file" for every one of them, not just `specs/`. `specs/` (219 entries) is
simply the largest single contributor to that noise, not a uniquely-caused special case.

## Decisions

- **Do not delete, move, or "relocate into the repo" anything under `~/Mail/specs/` except the
  two empty directory entries at `~/Mail/specs/072_email_workflow_infrastructure_prereqs/`.**
  Everything else is unique, git-tracked, legitimate data belonging to `~/Mail`'s own independent
  task-management repo and is out of scope for any "cleanup" beyond the notmuch-noise guard.
- The task description's framing ("stray copy... created ~2026-07-13/14... writing RELATIVE
  specs/... paths there instead of into the repo") should be corrected in any follow-up plan: the
  correct scope is (a) `rmdir` the 2-directory empty stub, (b) fix the `lib.nix` root cause so it
  cannot recreate stray manifest directories at an arbitrary `cwd` again, and (c) add a notmuch
  `new.ignore` guard — not a bulk relocation/deletion of `~/Mail/specs/`.

## Risks & Mitigations

- **Risk**: A future plan/implementer, taking the task description at face value, could attempt
  to bulk-delete or "reconcile" `~/Mail/specs/archive/` or `email-manifests/` believing them
  duplicates. **Mitigation**: this report's per-subtree table with concrete `git ls-files`/`git
  status`/`find` evidence should be treated as authoritative; any implementation plan must scope
  mutation to exactly the two empty directories identified above.
- **Risk**: Removing the empty stub via a generic `rm -rf` could be riskier than necessary.
  **Mitigation**: use `rmdir` (innermost directory first), which refuses non-empty directories as
  a built-in safety check — identical to the low-risk pattern task 114 already recommended for
  the (now-resolved) maildir-internal instance of this same bug.
- **Risk**: Changing `manifestDirDefault` to an absolute path anchored at
  `specs/072_email_workflow_infrastructure_prereqs/manifests` is only a partial fix, since task
  072 is itself now archived — any fresh `mkdir -p` against that absolute path would still
  recreate a now-meaningless directory outside the archive. **Mitigation** (see recommendation
  below): decouple the default manifest directory from any specific task-numbered `specs/`
  path entirely, since `specs/` task directories are subject to archival and (per
  `.claude/rules/state-management.md`'s vault operation) renumbering — neither of which a
  hardcoded task-072 path can track.
- **No server-deletion / mbsync risk** in any of this: nothing under `~/Mail/specs/` is inside a
  maildir folder, so `mbsync`'s Maildir scanner never walks it (confirmed by task 114's finding
  that the *only* maildir-internal instance of this bug was a physically separate directory
  under `Gmail/.All_Mail/cur/`, already removed).

## Guard Recommendations (for the implementation plan)

### (a) notmuch `new.ignore` — silence non-mail top-level noise

Add anchored, root-relative regex entries to `modules/home/email/notmuch.nix`'s
`programs.notmuch.new.ignore` list, one per non-maildir top-level entry under `~/Mail`:

```nix
ignore = [
  ".mbsyncstate"
  ".strstrings"
  ".lock"
  "dovecot*"
  "/^specs$/"
  "/^\\.claude$/"
  "/^\\.git$/"
  "/^docs$/"
  "/^email_plans$/"
  "/^email_reports$/"
  "/^\\.memory$/"
  "/^README\\.md$/"
  "/^README_OLD\\.md$/"
  "/^CLAUDE\\.md$/"
  "/^Contacts$/"
  "/^\\.gitignore$/"
  "/^\\.logos-backup.*$/"
  "/^\\.logos-presync.*$/"
  "/^\\.syncstate-backups$/"
];
```

Anchored (`^...$`, relative-to-`database.path`) regex form is preferred over bare basenames here
because it restricts matching to true top-level entries only, avoiding any (currently
theoretical) risk of a same-named entry appearing inside a real maildir folder. Verify post-change
with `home-manager build` (or `nix flake check`) then a live
`notmuch new --no-hooks --full-scan 2>&1 | grep -c "Ignoring non-mail file"` before/after
comparison — should drop to (near) zero.

### (b) Root-cause fix — decouple `manifestDirDefault` from a specific `specs/` task path

Two options, in increasing order of robustness:

1. **Minimal**: change `manifestDirDefault` in `modules/home/email/agent-tools/lib.nix:35` to an
   **absolute** path, e.g. `"$HOME/.dotfiles/specs/072_email_workflow_infrastructure_prereqs/manifests"`.
   This stops the "recreates wherever `cwd` happens to be" failure mode, but keeps a stale
   dependency on task 072's now-archived location and is fragile to task-072 renumbering
   (vault operation, `.claude/rules/state-management.md`).
2. **Recommended**: move the default off the `specs/` task lifecycle entirely, into a stable,
   XDG-appropriate absolute state directory decoupled from any task number, e.g.
   `"$HOME/.local/state/email-agent/manifests"` (or `${config.xdg.stateHome}/email-agent/manifests`
   if wired through Home Manager's `xdg.stateHome`). This directory is never subject to `/todo`
   archival or vault renumbering, so `mkdir -p "$MANIFEST_DIR"` can never again land somewhere
   unintended regardless of `cwd` or task-lifecycle state.

Either way, this is a one-line change (`manifestDirDefault` in `lib.nix`) but requires a
`home-manager build`/`nixos-rebuild` cycle to regenerate the five wrapper binaries, plus updating
the `--help` text (`lib.nix:72-73`) and `docs/email-workflow.md:26` (which documents the same
default) to match. As defense-in-depth, `skill-email-cleanup`/`skill-email-implementation`
SKILL.md could also be updated to always export `EMAIL_MANIFEST_DIR` explicitly (absolute path)
before invoking any wrapper binary, rather than relying on the compiled-in default at all — this
does not require a nix rebuild and can land independently/first.

### Stray-stub removal (safe, in scope)

```bash
rmdir ~/Mail/specs/072_email_workflow_infrastructure_prereqs/manifests
rmdir ~/Mail/specs/072_email_workflow_infrastructure_prereqs
```

`rmdir` refuses non-empty directories, so this is self-verifying: if either command fails, stop
and re-investigate rather than escalating to `rm -rf`.

## Context Extension Recommendations

- **Topic**: Multi-repo agent-system deployments (`~/.dotfiles`, `~/Mail`, and per the audit log
  also `~/.config/nvim`) each run independent `specs/` task-numbering with the same Claude Code
  agent-system framework. This is not currently documented anywhere in `.claude/context/` and
  caused the task-116 description itself to misread `~/Mail/specs/` as "stray" when it is a
  peer deployment. **Recommendation**: a short note in
  `.claude/context/repo/project-overview.md` (or a new `.claude/context/architecture/` entry)
  documenting that `~/Mail` and `~/.config/nvim` are recognized sibling repos with their own
  task-management history, so future investigations don't need to rediscover this from scratch.

## Appendix

### Key commands used

```bash
git -C ~/Mail log --oneline | wc -l
git -C ~/Mail log --oneline | tail -5
git -C ~/Mail ls-files specs/ | wc -l
git -C ~/Mail status --porcelain -- specs/
stat ~/Mail/specs/072_email_workflow_infrastructure_prereqs{,/manifests}
git -C ~/Mail log -1 --format='%ci' -- specs/archive/072_email_workflow_infrastructure_prereqs
comm -12 <(ls ~/Mail/specs/archive/ | sort) <(ls ~/.dotfiles/specs/archive/ | sort)
grep -n "manifestDirDefault\|EMAIL_MANIFEST_DIR\|mkdir -p" modules/home/email/agent-tools/lib.nix
notmuch config get new.ignore
notmuch config get database.path
man notmuch-config   # new.ignore semantics (bare-name vs anchored-regex forms)
find ~/Mail/Gmail -iname "specs*"   # confirms task 114's maildir stray already removed
```

### References

- `~/Mail/README.md`, `~/Mail/.git` history
- `modules/home/email/notmuch.nix`
- `modules/home/email/agent-tools/lib.nix` (lines 35, 61, 72-73, 127)
- `docs/email-workflow.md:26`
- `specs/114_gmail_allmail_duplicate_uid_remediation/artifacts/08_stray-dir-baseline.txt`
- `specs/114_gmail_allmail_duplicate_uid_remediation/artifacts/08_stray-directory-finding-NOT-REMOVED.md`
- `specs/114_gmail_allmail_duplicate_uid_remediation/artifacts/10_phase6-guard-decision.md`
- `~/Mail/.claude/tmp/mail-guard-audit.log`, `~/.dotfiles/.claude/tmp/mail-guard-audit.log`

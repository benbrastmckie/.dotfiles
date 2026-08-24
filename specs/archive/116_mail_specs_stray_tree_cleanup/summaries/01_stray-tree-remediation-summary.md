# Implementation Summary: Task #116

**Completed**: 2026-07-14
**Duration**: ~1 hour

## Overview

Remediated the single genuine stray artifact under `~/Mail/specs/` and fixed its root cause.
Removed the one empty, untracked stub directory at
`~/Mail/specs/072_email_workflow_infrastructure_prereqs/manifests/`; changed the five email
wrapper binaries' `manifestDirDefault` from a repo-relative `specs/072_...` path to a stable
absolute XDG-state path (`$HOME/.local/state/email-agent/manifests`) so no future wrapper can
recreate a stray tree relative to an arbitrary `cwd` or a to-be-archived task directory; and
added anchored `notmuch new.ignore` regex entries to silence "Ignoring non-mail file" spam for
non-maildir top-level entries under `~/Mail`. All git-tracked content under the sibling `~/Mail`
repo (including the archived, populated copy of the same manifests directory) was left
completely untouched, per the plan's explicit non-goals.

## What Changed

- `~/Mail/specs/072_email_workflow_infrastructure_prereqs/` (external, not in `~/.dotfiles`) —
  removed via innermost-first `rmdir` after empty + untracked pre-checks passed; no git commit
  in `~/Mail` since the directory was never tracked. The archived, git-tracked copy at
  `~/Mail/specs/archive/072_email_workflow_infrastructure_prereqs/manifests/` remains intact and
  untouched.
- `modules/home/email/agent-tools/lib.nix` — `manifestDirDefault` (line 35) changed from
  `"specs/072_email_workflow_infrastructure_prereqs/manifests"` to
  `"$HOME/.local/state/email-agent/manifests"`; help text (lines 72-74) updated to drop the
  stale "relative to the current working directory — normally the .dotfiles repo root" phrasing.
  Override precedence (`EMAIL_MANIFEST_DIR` env var, then `--manifest-dir`/`--manifest-dir=`
  flags) is unchanged — only the compiled-in default moved.
- `docs/email-workflow.md` (line 27) — documented default updated to match the new absolute
  path.
- `modules/home/email/notmuch.nix` — `programs.notmuch.new.ignore` list extended with 15
  anchored, root-relative `/^...$/` regex entries (`/^specs$/`, `/^\.claude$/`, `/^\.git$/`,
  `/^docs$/`, `/^email_plans$/`, `/^email_reports$/`, `/^\.memory$/`, `/^README\.md$/`,
  `/^README_OLD\.md$/`, `/^CLAUDE\.md$/`, `/^Contacts$/`, `/^\.gitignore$/`,
  `/^\.logos-backup.*$/`, `/^\.logos-presync.*$/`, `/^\.syncstate-backups$/`), keeping the
  original 4 bare-name entries (`.mbsyncstate`, `.strstrings`, `.lock`, `dovecot*`).

## Decisions

- Chose the absolute XDG-state path (`$HOME/.local/state/email-agent/manifests`) over an
  absolute path anchored at the archived task directory, per the plan's rationale: this
  directory is never subject to `/todo` archival or vault renumbering, fully decoupling the
  manifest store from any `specs/` task lifecycle.
- Verified override precedence via two read-only, wrapper-only, no-`--execute` invocations of
  `email-census --account gmail` (one with `EMAIL_MANIFEST_DIR` set, one with `--manifest-dir`
  passed) rather than a synthetic/mocked test, since this is the sanctioned live verification
  method the plan itself specifies ("Stay within wrapper-only, dry-run, read-only invocations").
  Both confirmed `mkdir -p` targeted the overridden path, not the compiled default; both temp
  dirs and the log file were removed immediately afterward.
- Verified the Phase 3 notmuch config change via direct inspection of the built
  `hm_notmuchdefaultconfig` Nix store output (extracted via `nix-store -q --outputs` on the
  matching `.drv`) rather than running `notmuch new --no-hooks --full-scan`, since the live check
  requires activation (`home-manager switch`), which is out of scope for a build-only implement
  run — the plan's own optional-check wording explicitly permits this deferral.

## Plan Deviations

- **Task 2 (optional)**: Deferred the optional note on whether `skill-email-cleanup` /
  `skill-email-implementation` should always export an explicit `EMAIL_MANIFEST_DIR` — the plan
  marks this optional and explicitly says "do not implement unless trivially in scope." Not
  implemented; flagged here per the plan's own instruction. No functional impact: the new
  absolute default already resolves correctly without this.
- **Task 3.4 (optional)**: Deferred the live `notmuch new --no-hooks --full-scan` before/after
  count check (requires activation, out of scope for this run). Verified instead via direct
  inspection of the built notmuch config's generated `[new] ignore=` line, confirming all 15 new
  entries are present alongside the original 4 — a static, equally conclusive substitute.

## Verification

- Build: Success — `home-manager build --flake .#benjamin` succeeded for both the Phase 2
  (5 wrapper binaries) and Phase 3 (notmuch config) changes; `nix flake check` passed cleanly
  (`all checks passed!`) both as a pre-change baseline and after all edits.
- Tests: N/A (declarative Nix config; verified via build + built-artifact inspection + sanctioned
  read-only wrapper invocations)
- Files verified: Yes — all 5 rebuilt wrapper binaries (`email-census`, `email-classify`,
  `email-unsubscribe-extract`, `email-archive-confirmed`, `email-delete-confirmed`) grep to the
  new absolute default; `email-census --help` shows the resolved absolute path; the built
  `hm_notmuchdefaultconfig` output contains all 15 new ignore entries; `grep -rn
  "072_email_workflow_infrastructure_prereqs/manifests" modules/home/email docs/` returns no
  stale live references (only historical/archived-task mentions remain, as expected).

## Notes

- No live-mail mutation, `mbsync`, `--execute`, or maildir-folder access occurred at any point.
  The only mail-adjacent interaction was two throwaway, read-only `email-census --account gmail`
  invocations used strictly to verify manifest-dir override precedence (notmuch index reads
  only, no IMAP fetch), with all artifacts cleaned up immediately.
- No git-tracked file under the sibling `~/Mail` repo was touched. Task 114 was not re-done and
  is unaffected.
- All three phases were logically independent (per the plan's dependency-wave analysis) and were
  executed sequentially as instructed for single-agent execution; each phase was committed
  separately (`task 116 phase 1/2/3: ...`).

# Implementation Plan: Task #116

- **Task**: 116 - Safely remediate the one genuine stray artifact under ~/Mail/specs/ and fix its root cause
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: None (task 114 is related history, not a blocker; its maildir-internal stray is already resolved)
- **Research Inputs**: specs/116_mail_specs_stray_tree_cleanup/reports/01_stray-tree-investigation.md
- **Artifacts**: plans/01_stray-tree-remediation.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: general

## Overview

The task's original premise ("relocate unique artifacts from ~/Mail/specs/ into the repo, remove
the rest") is **wrong and must be dropped**. Per the research report, `~/Mail` is an independent,
long-lived git repository (158 commits back to Feb 2026) running its own Claude Code agent-system
deployment with its own `specs/` task-numbering; **218 of the 219 files under `~/Mail/specs/` are
git-tracked, clean, and the only copy of that sibling repo's own task history**. They are out of
scope and must not be deleted, moved, or "reconciled". Exactly **one** genuine stray exists: an
empty (0 files), untracked, two-directory stub at
`~/Mail/specs/072_email_workflow_infrastructure_prereqs/manifests/`, produced by a path-resolution
bug. This plan (1) removes that single empty stub with `rmdir` (empty-only, self-verifying),
(2) fixes the root cause in `modules/home/email/agent-tools/lib.nix:35` where `manifestDirDefault`
is a repo-relative path baked into all five email wrapper binaries, decoupling the default from any
archivable/renumberable `specs/` task directory, and (3) closes the `notmuch new.ignore` gap so
`notmuch new` stops logging "Ignoring non-mail file" for every non-maildir top-level entry under
`~/Mail`. Definition of done: the empty stub is gone, the five wrapper binaries build and resolve
an absolute default manifest dir with override behavior unchanged, and the notmuch config builds
with the non-mail top-level entries silenced.

### Research Integration

Directly grounded in `reports/01_stray-tree-investigation.md`:
- The per-subtree uniqueness table (report "Per-subtree uniqueness/duplication table") proves what
  must NOT be touched: everything under `~/Mail/specs/` except the two empty directory entries.
- The exact root-cause line: `lib.nix:35` `manifestDirDefault = "specs/072_email_workflow_infrastructure_prereqs/manifests"`,
  interpolated at `lib.nix:61` (`MANIFEST_DIR="''${EMAIL_MANIFEST_DIR:-${manifestDirDefault}}"`),
  `mkdir -p`'d at `lib.nix:127`, and echoed in help text at `lib.nix:72-74`.
- The `notmuch new.ignore` recommendation (report section "(a) notmuch new.ignore") with anchored,
  root-relative regex forms, incorporated verbatim in Phase 3.
- The recommended absolute default (report section "(b)", option 2): move the default off the
  `specs/` task lifecycle entirely into an XDG-state path.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided for this dispatch; ROADMAP alignment not evaluated.

## Goals & Non-Goals

**Goals**:
- Remove the single empty, untracked stray stub at
  `~/Mail/specs/072_email_workflow_infrastructure_prereqs/manifests/` (and its now-empty parent),
  using `rmdir` (empty-only) with an explicit pre-check that both are still empty and untracked.
- Change `manifestDirDefault` in `modules/home/email/agent-tools/lib.nix` from a repo-relative
  path to a stable absolute XDG-state path decoupled from any task-numbered `specs/` directory, so
  no wrapper can recreate a stray manifest tree at an arbitrary `cwd` again.
- Keep the `--manifest-dir` flag and `EMAIL_MANIFEST_DIR` override precedence exactly as-is
  (override still wins over the new default).
- Rebuild the five wrapper binaries and verify they still build and resolve the new default.
- Update the two in-tree references to the old default (`lib.nix` help text and
  `docs/email-workflow.md:27`) so documentation matches the new behavior.
- Add anchored `new.ignore` regex entries in `modules/home/email/notmuch.nix` for the non-maildir
  top-level entries under `~/Mail`, silencing the "Ignoring non-mail file" spam.

**Non-Goals**:
- Re-doing task 114 (its maildir-internal `specs,U=67297/...` stray is already gone; confirmed by
  the report's `find ~/Mail/Gmail -iname "specs*"` returning nothing).
- Any live-mail mutation, classification, archive, delete, or `mbsync` run.
- Touching any actual maildir folder (`cur/`, `new/`, `tmp/`, `.All_Mail`, `.Archive`, etc.).
- Deleting, moving, "relocating into ~/.dotfiles", or otherwise altering ANY git-tracked file
  under `~/Mail` — including all of `~/Mail/specs/archive/`, `~/Mail/specs/email-manifests/`,
  and the 33 archived task directories. These are the sibling repo's own unique, committed history.
- Removing anything under `~/Mail/specs/072_email_workflow_infrastructure_prereqs/` if it turns
  out to be non-empty or tracked (the pre-check STOPS the phase in that case rather than escalating
  to `rm -rf`).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer takes the original task framing at face value and bulk-deletes/relocates `~/Mail/specs/` content | H | M | This plan and the report scope removal to exactly the two empty directory entries; the per-subtree uniqueness table is authoritative. Phase 1 mutates nothing else. |
| Stray stub is non-empty or tracked at execution time (state drifted since research) | M | L | Phase 1 pre-check asserts `find ... -type f | wc -l == 0` and `git -C ~/Mail status`/`ls-files` show it untracked BEFORE any `rmdir`; if not, STOP and re-investigate. `rmdir` itself refuses non-empty dirs as a second guard. |
| New absolute default changes behavior for callers that relied on cwd=~/.dotfiles + relative default | M | L | This is the intended fix. The old relative default already resolved to a now-archived (nonexistent) path inside `.dotfiles` (task 072 archived there too), so real workflows already pass `--manifest`/`--manifest-dir` or set `EMAIL_MANIFEST_DIR`. Phase 2 explicitly verifies override precedence is unchanged. |
| Nix double-quoted string escaping mishandles `$HOME` and bakes a literal or wrong path into binaries | M | M | `manifestDirDefault` at `lib.nix:35` is an ordinary double-quoted Nix string where `$HOME` stays literal and is interpolated into the `''...''` preamble, so bash expands it at runtime. Phase 2 verifies by inspecting the built binary and running `--help`/a dry invocation to confirm the resolved path is absolute under `$HOME/.local/state/...`. |
| `notmuch new.ignore` regex silences a real maildir path | L | L | Use anchored, root-relative regex (`/^name$/`) per the report, matching only true top-level entries relative to `database.path`, never basenames at arbitrary depth. Verify with a before/after `notmuch new` "Ignoring non-mail file" count. |
| Nix rebuild fails on unrelated pre-existing issue | M | L | Run `nix flake check` first to establish a baseline; scope build verification to `home-manager build --flake .#benjamin` (or the current NixOS host) and read errors before assuming they are caused by this change. |
| No server-deletion / mbsync risk | — | — | Nothing in scope is inside a maildir folder, so `mbsync`'s Maildir scanner never walks it (report Risks section confirms). |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |

All three phases are logically independent (distinct targets: a filesystem stub, `lib.nix` +
docs, and `notmuch.nix`) and may execute in parallel. Under single-agent sequential execution,
run them in order 1 -> 2 -> 3; Phases 2 and 3 both edit `.nix` files and can share a single
combined `home-manager build` / `nix flake check` verification if executed together.

---

### Phase 1: Remove the single empty stray stub [NOT STARTED]

**Goal**: Delete only the empty, untracked two-directory stub at
`~/Mail/specs/072_email_workflow_infrastructure_prereqs/manifests/` (and its now-empty parent),
with a pre-check that proves it is still empty and untracked. This is the ONLY filesystem removal
in the entire task.

**Tasks**:
- [ ] Pre-check emptiness: confirm `find ~/Mail/specs/072_email_workflow_infrastructure_prereqs -type f | wc -l` returns `0`. If non-zero, STOP and re-investigate (do NOT escalate to `rm`).
- [ ] Pre-check untracked: confirm `git -C ~/Mail ls-files specs/072_email_workflow_infrastructure_prereqs` returns empty (untracked) and `git -C ~/Mail status --porcelain -- specs/072_email_workflow_infrastructure_prereqs` shows nothing tracked/staged.
- [ ] Confirm the populated, git-tracked copy still exists at `~/Mail/specs/archive/072_email_workflow_infrastructure_prereqs/manifests/` (so nothing unique is at risk) — this is out of scope and must remain untouched.
- [ ] Remove innermost-first, empty-only: `rmdir ~/Mail/specs/072_email_workflow_infrastructure_prereqs/manifests` then `rmdir ~/Mail/specs/072_email_workflow_infrastructure_prereqs`. If either `rmdir` fails (non-empty), STOP and re-investigate — do not use `rm -rf`.
- [ ] Post-check: confirm `~/Mail/specs/072_email_workflow_infrastructure_prereqs` no longer exists and `git -C ~/Mail status` is otherwise unchanged.

**Timing**: ~15 minutes

**Depends on**: none

**Files to modify**:
- None in `~/.dotfiles`. Filesystem-only removal of two empty directory entries under `~/Mail`
  (a separate repo; no git commit is made in `~/Mail` for removing an untracked, empty directory —
  git never tracked it).

**Verification**:
- `find ~/Mail/specs/072_email_workflow_infrastructure_prereqs 2>&1` reports the path does not exist.
- `git -C ~/Mail status --porcelain` shows no new changes attributable to this phase (the stub was
  untracked, so its removal leaves the tree exactly as clean as before).
- `~/Mail/specs/archive/072_email_workflow_infrastructure_prereqs/manifests/` is still present and
  intact (spot-check it still lists its `sweep-*.sh` / `.jsonl` / `.log` files).

---

### Phase 2: Root-cause fix — absolute, task-decoupled default manifest dir [NOT STARTED]

**Goal**: Change `manifestDirDefault` in `modules/home/email/agent-tools/lib.nix` from the
repo-relative `specs/072_email_workflow_infrastructure_prereqs/manifests` to a stable absolute
XDG-state path, so `mkdir -p "$MANIFEST_DIR"` can never again create a stray tree relative to an
arbitrary `cwd`. Preserve `--manifest-dir` / `EMAIL_MANIFEST_DIR` override precedence. Rebuild and
verify the five wrapper binaries. Update the two in-tree references to the old default.

**Chosen new default** (report recommendation (b), option 2 — decouple from the `specs/` task
lifecycle entirely): `"$HOME/.local/state/email-agent/manifests"`.
- Rationale: this directory is never subject to `/todo` archival or vault renumbering, unlike any
  `specs/072_...` path (task 072 is already archived in both repos). An absolute path anchored at
  the still-existing-but-archived task dir (option 1) was rejected as only a partial fix.
- Nix note for the implementer: `lib.nix:35` is an ordinary double-quoted Nix string, so `$HOME`
  stays literal in the Nix value and is interpolated into the `''...''` preamble at `lib.nix:61`;
  bash then expands `$HOME` at binary runtime. `lib.nix` is a plain expression (no `config` arg),
  so `config.xdg.stateHome` is not available here — the literal `$HOME/.local/state/email-agent/manifests`
  is the correct form. Do not convert `lib.nix` into a Home Manager module for this.

**Tasks**:
- [ ] Baseline: run `nix flake check` to confirm the tree builds cleanly before editing (records a baseline so any post-change failure is attributable).
- [ ] Edit `modules/home/email/agent-tools/lib.nix:35`: set `manifestDirDefault = "$HOME/.local/state/email-agent/manifests";`.
- [ ] Update the help text at `lib.nix:72-74` so the `--manifest-dir` default description reads as the new absolute path (no longer "relative to the current working directory — normally the .dotfiles repo root").
- [ ] Update `docs/email-workflow.md:27` (the `(default $EMAIL_MANIFEST_DIR, else specs/072_email_workflow_infrastructure_prereqs/manifests/)` reference) to the new absolute default.
- [ ] Confirm override precedence is untouched: `lib.nix:61` still reads `MANIFEST_DIR="''${EMAIL_MANIFEST_DIR:-${manifestDirDefault}}"` and the `--manifest-dir` / `--manifest-dir=` arg branches (`lib.nix:86-87`) still override `MANIFEST_DIR` afterward.
- [ ] Rebuild the wrappers: `home-manager build --flake .#benjamin` (or `nix build .#homeConfigurations.benjamin.activationPackage`; if wrappers are delivered via the NixOS host config, `nixos-rebuild build --flake .#<current-host>`). Then `nix flake check`.
- [ ] Verify the built binaries resolve the new default: inspect one built wrapper (e.g. grep the store path for `email-census`) to confirm the interpolated default is `${EMAIL_MANIFEST_DIR:-$HOME/.local/state/email-agent/manifests}` and NOT the old relative `specs/072...` string; run `email-census --help` and confirm the help text shows the absolute default.
- [ ] Verify override still wins: with `EMAIL_MANIFEST_DIR=/tmp/mtest-116` set (or `--manifest-dir /tmp/mtest-116`), confirm a dry/read-only wrapper invocation uses that dir (its `mkdir -p` targets `/tmp/mtest-116`), not the compiled default. Clean up `/tmp/mtest-116` afterward. (Stay within wrapper-only, dry-run, read-only invocations — no `--execute`.)
- [ ] (Optional, defense-in-depth; no rebuild required, may land independently) Note in this plan's summary whether `skill-email-cleanup` / `skill-email-implementation` SKILL.md should be updated to always export an explicit absolute `EMAIL_MANIFEST_DIR` before invoking wrappers, rather than relying on the compiled default. Do not implement unless trivially in scope.

**Timing**: ~50 minutes (edit is one line + two doc/help updates; the rebuild + binary verification dominate)

**Depends on**: none

**Files to modify**:
- `modules/home/email/agent-tools/lib.nix` - line 35 (the default), lines 72-74 (help text).
- `docs/email-workflow.md` - line 27 (documented default).

**Verification**:
- `nix flake check` passes.
- `home-manager build` (or the host `nixos-rebuild build`) succeeds.
- A built wrapper's interpolated default is the absolute `$HOME/.local/state/email-agent/manifests`; the old `specs/072_...` relative string appears in no built binary.
- `EMAIL_MANIFEST_DIR` / `--manifest-dir` override still redirects `MANIFEST_DIR` (verified with a throwaway dir).
- `grep -rn "072_email_workflow_infrastructure_prereqs/manifests" modules/home/email docs/` returns no stale live references (archived-task mentions in comments/history are acceptable; the live default and its documented description are updated).

---

### Phase 3: notmuch new.ignore guard for non-mail top-level entries [NOT STARTED]

**Goal**: Add anchored, root-relative `new.ignore` regex entries to
`modules/home/email/notmuch.nix` so `notmuch new` stops logging "Ignoring non-mail file" for every
non-maildir top-level entry under `~/Mail` (`database.path = ~/Mail`, the whole repo root). `specs/`
is one of many such entries, not a special case.

**Tasks**:
- [ ] Edit the `programs.notmuch.new.ignore` list (`notmuch.nix:66-71`) to add anchored regex entries (one per non-maildir top-level entry), keeping the existing four bare-name entries: append `"/^specs$/"`, `"/^\\.claude$/"`, `"/^\\.git$/"`, `"/^docs$/"`, `"/^email_plans$/"`, `"/^email_reports$/"`, `"/^\\.memory$/"`, `"/^README\\.md$/"`, `"/^README_OLD\\.md$/"`, `"/^CLAUDE\\.md$/"`, `"/^Contacts$/"`, `"/^\\.gitignore$/"`, `"/^\\.logos-backup.*$/"`, `"/^\\.logos-presync.*$/"`, `"/^\\.syncstate-backups$/"` (per report section "(a)").
- [ ] Use the anchored `/^...$/` regex form (matched against the path relative to `database.path`), NOT bare basenames — this restricts matching to true top-level entries and avoids any theoretical match inside a real maildir folder.
- [ ] Follow `nix.md` formatting: each list item on its own line, 2-space indentation, quoted strings.
- [ ] Rebuild: `home-manager build --flake .#benjamin` (or the host `nixos-rebuild build`), then `nix flake check`. (If executed together with Phase 2, a single combined build covers both.)
- [ ] (Optional live check) After activation, run `notmuch new --no-hooks --full-scan 2>&1 | grep -c "Ignoring non-mail file"` and compare against a pre-change count; expect it to drop to (near) zero. This is a read-only index operation (the sanctioned `--no-hooks` reindex form) and does not mutate mail; skip if activation is out of scope for the implement run and note the deferral in the summary.

**Timing**: ~30 minutes

**Depends on**: none

**Files to modify**:
- `modules/home/email/notmuch.nix` - the `new.ignore` list (lines 66-71).

**Verification**:
- `nix flake check` passes and `home-manager build` (or host `nixos-rebuild build`) succeeds with the expanded `ignore` list.
- The generated notmuch config (post-activation) contains the new anchored entries: `notmuch config get new.ignore` lists them alongside the original four.
- (If the live check was run) the "Ignoring non-mail file" line count from `notmuch new --no-hooks` drops to near zero versus baseline.

---

## Testing & Validation

- [ ] `~/Mail/specs/072_email_workflow_infrastructure_prereqs` no longer exists; the archived tracked copy under `~/Mail/specs/archive/...` is intact; `git -C ~/Mail status` shows no unintended changes.
- [ ] No git-tracked file under `~/Mail` was deleted, moved, or modified.
- [ ] `nix flake check` passes after all edits.
- [ ] `home-manager build --flake .#benjamin` (or the current NixOS host's `nixos-rebuild build`) succeeds.
- [ ] Built email wrapper binaries resolve an absolute default manifest dir (`$HOME/.local/state/email-agent/manifests`) and honor `EMAIL_MANIFEST_DIR` / `--manifest-dir` overrides unchanged; no built binary contains the old relative `specs/072_...` default.
- [ ] `notmuch config get new.ignore` (post-activation) includes the anchored top-level entries; "Ignoring non-mail file" noise is silenced (if the live check was run).
- [ ] No live-mail mutation, `mbsync`, `--execute`, or maildir-folder access occurred during implementation.

## Artifacts & Outputs

- `specs/116_mail_specs_stray_tree_cleanup/plans/01_stray-tree-remediation.md` (this plan)
- `specs/116_mail_specs_stray_tree_cleanup/summaries/01_stray-tree-remediation-summary.md` (on implementation)
- Modified: `modules/home/email/agent-tools/lib.nix`, `modules/home/email/notmuch.nix`, `docs/email-workflow.md`
- Filesystem: removal of the empty stub `~/Mail/specs/072_email_workflow_infrastructure_prereqs/` (external to this repo; no committed diff)

## Rollback/Contingency

- **Phase 1**: The removal is of an empty, untracked directory only; there is nothing to restore
  and no data loss is possible. If a `rmdir` fails (non-empty), that is the built-in stop signal —
  re-investigate why content appeared rather than forcing removal. If the directory must be
  recreated for any reason, `mkdir -p ~/Mail/specs/072_email_workflow_infrastructure_prereqs/manifests`
  reproduces the empty stub exactly.
- **Phases 2 & 3**: All edits are in git-tracked `~/.dotfiles` files. Revert with a normal
  `git checkout -- modules/home/email/agent-tools/lib.nix modules/home/email/notmuch.nix docs/email-workflow.md`
  (only on a clean-enough tree per the No-Destructive-Git rule; otherwise `git diff`-guided manual
  revert), then rebuild. Because the changes are declarative Nix, reverting the source and
  rebuilding fully restores prior wrapper binaries and notmuch config.
- **General**: Each phase is independently revertible; a failure in one does not require unwinding
  the others (they touch disjoint targets).

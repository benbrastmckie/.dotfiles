# Research Report: Task #82

**Task**: 82 - Dead code removal (task 81 Tier 0, subtask blueprint #1)
**Started**: 2026-07-05T02:13:06Z
**Completed**: 2026-07-05T02:30:00Z
**Effort**: Small (single-pass verification + doc edits, no nix logic changes)
**Dependencies**: None (Tier 0, fully parallel with tasks 83/84/85)
**Sources/Inputs**: Live repo grep verification, `specs/081_.../reports/01_repo-organization-review.md`,
`specs/081_.../reports/02_team-research.md`, `specs/081_.../design/target-layout.md` §3/§4
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Every file/directory named in the task description was independently re-verified live against
  the current working tree via `grep`/`ls`/`git ls-files` — **all are confirmed dead or resolved
  exactly as described**. No new orphans or surprises found.
- `modules/opencode.nix` is confirmed both dead (only self-referential comments) and broken (its
  `default = ../../config/opencode.json` resolves two levels above `modules/`, i.e. outside the
  repo root — would fail to evaluate if the option were ever enabled).
- `packages/neovim.nix` vs `modules/home/core/neovim.nix` are confirmed distinct files; only the
  latter is imported (`home.nix:10`). No accidental overlap risk.
- `packages/test-mcphub.sh` has exactly 3 doc references, confirmed at the exact cited
  locations/line numbers. All three are prose using it as a template/pointer/testing-doc entry,
  not code — safe to edit in place without any downstream breakage.
- `config/rclone.conf` is confirmed untracked (`git ls-files` returns nothing) and already listed
  in `.gitignore:35` — the "verify" step is correctly dropped; there is genuinely nothing to do.
- **One coverage gap identified** (see Risks): `packages/README.md` also carries a 3-line
  `### neovim.nix` doc section (lines 257-259) documenting `packages/neovim.nix`, which is
  *not* one of the 3 cited `test-mcphub.sh` doc references and is not explicitly assigned to any
  subtask. It is low-risk (doc-only, no build impact) and deferred to subtask 91 per the design's
  explicit assignment of "package list" cleanup to Documentation Sync — but flagged here so it
  isn't lost.
- Recommended approach: proceed exactly as scoped in the task description; no scope changes
  needed to the deletion/edit set itself.

## Context & Scope

Task 82 is Tier 0, blueprint subtask #1 of task 81's 10-subtask reorganization queue: pure
dead-code removal with **no** structural changes, no dependencies, and a build-only inertness
verification bar (`nix flake check` + build all 3 real hosts + HM activation build; `git status`
must show only deletions + the 3 doc edits). This report's job was to re-confirm — via live grep
of the actual current repo, not by trusting the seed inventory verbatim — that every item in
scope is truly dead/orphaned, and to surface any risks before implementation.

Scope boundary (inherited from task 81 design doc §1.2): Nix-managed tree only. `.claude/`,
`.memory/`, `.opencode/`, `specs/` are out of scope and untouched by this task.

## Findings

### `home-modules/` — confirmed DEAD, safe to delete in full

- `home-modules/mcp-hub.nix` (869 bytes) + `home-modules/README.md` (464 bytes) are the only 2
  files in the directory.
- Repo-wide grep for `home-modules` (excluding the directory's own files and `specs/`) turns up
  exactly one live-tree hit: the commented-out `home.nix:6`:
  ```
  # ./home-modules/mcp-hub.nix  # Disabled - using lazy.nvim approach
  ```
  No other `.nix` file references it, and it does not appear in any `imports =` list.
- Two stale comment references confirmed at the exact cited lines:
  - `modules/home/core/shell.nix:8` — `# MCP_HUB_PATH is now managed by the MCP-Hub module`
  - `modules/home/packages/email-tools.nix:38-39` — `# Required for running mcp-hub JavaScript
    tools` / `# MCP-Hub is now managed by the home module`
- **Deletion set**: `home-modules/` (directory, both files), `home.nix:6` (comment line), the
  stale comment lines at the two locations above. All 4 edits are comment-only removals with zero
  evaluation impact.

### `modules/opencode.nix` — confirmed DEAD and BROKEN

- Grep for `opencode.nix` across all `.nix` files shows only a self-referential comment inside the
  file itself (`# imports = [ ./modules/opencode.nix ];`, a usage-example comment, not an actual
  import anywhere else) and an unrelated hit in `overlays/unstable-packages.nix:11`
  (`packages/opencode.nix` — a *different* file, the actual opencode package derivation, wired via
  `callPackage`; not affected by this deletion).
- Confirmed broken: the file's `dotfilesPath` option defaults to `../../config/opencode.json`.
  From `modules/opencode.nix`'s location at `modules/`, `../../` climbs two levels — one past the
  repo root — so this path resolves outside the repository entirely. If `programs.opencode.enable`
  were ever set `true` anywhere (it currently is not, confirmed via grep for
  `programs.opencode`), evaluation would fail on a nonexistent path.
- **Deletion set**: `modules/opencode.nix` (whole file, 1 file, no doc references to patch).

### `packages/neovim.nix` — confirmed DEAD, distinct from the live `modules/home/core/neovim.nix`

- `packages/neovim.nix` is a `wrapNeovimUnstable` derivation (852 bytes). Repo-wide grep for
  `neovim.nix` shows exactly one other hit: `home.nix:10 -> ./modules/home/core/neovim.nix` — a
  completely different file (a Home Manager module configuring the *live* Neovim setup, not a
  package derivation). No `callPackage ../packages/neovim.nix` exists in either overlay
  (`overlays/unstable-packages.nix`, `overlays/python-packages.nix`), confirming it is wired
  nowhere and wholly orphaned.
- **Deletion set**: `packages/neovim.nix` (whole file). See Risks below for one adjacent
  `packages/README.md` doc section this does *not* currently cover per the task's literal scope.

### `packages/test-mcphub.sh` — confirmed doc-referenced, NOT orphaned (Critic correction validated)

- Grep confirms exactly 3 references outside `specs/`, matching the task description precisely:
  - `docs/packages.md:244` — `Use \`packages/test-mcphub.sh\` as template for testing custom
    packages:` (under a "## Package Testing" heading)
  - `docs/applications.md:26` — `Use \`~/.dotfiles/packages/test-mcphub.sh\` to verify
    installation and troubleshoot issues.` (under "## MCP-Hub Integration")
  - `packages/README.md:260-277` — a `### test-mcphub.sh` subsection (one-line description at 260)
    plus a `### Testing` block (267-283) with a `bash ~/.dotfiles/packages/test-mcphub.sh` code
    fence and a bulleted "what it checks" list
- All three are prose/doc references only — none is a `.nix` import or `callPackage`, so patching
  them is a pure text edit with no evaluation risk. The straightforward edit is to remove each
  reference (the file no longer exists to point at); no replacement script exists to point to
  instead, and none is implied by any source document.
- **Deletion + edit set**: `packages/test-mcphub.sh` (delete) + edit the 3 exact locations above.

### `config/rclone.conf` — confirmed already resolved, "verify" step correctly dropped

- File exists on disk (541 bytes, `-rw-------` at `config/rclone.conf`) but `git ls-files
  config/rclone.conf` returns empty — **it is untracked**.
- `.gitignore:35` lists `config/rclone.conf` explicitly.
- No `.nix` file references it (only `config/README.md`'s general "config/ is deployed via 3
  mechanisms" prose, not a rclone-specific reference).
- Conclusion: there is nothing to delete (never tracked) and nothing to verify — the task
  description's instruction to drop this step entirely is correct. No action taken, none needed.

### Root files — confirmed orphaned, safe to delete

- `test-sasl.sh` (965 bytes, executable) and `test-update.md` (12,134 bytes) — grep confirms zero
  references outside `specs/` task-tracking artifacts (which are self-describing this task, not
  live consumers).
- Root `TODO.md` (720 bytes) — grep confirms zero live-tree references outside `specs/` artifacts;
  `specs/TODO.md` is the actual canonical/active task list per `.claude/rules/state-management.md`.
- **Deletion set**: all 3 files, whole-file deletes, no doc-reference patching needed for any of
  them.

### `wallpapers/` — confirmed 5-file cruft cluster, `riverside.jpg` untouched

- `ls wallpapers/` confirms exactly 6 files: `IMPLEMENTATION_COMPLETE.md`, `README.md`,
  `riverside.jpg` (1.1 MB, KEEP), `SAVE_IMAGE_HERE.txt`, `SETUP_INSTRUCTIONS.md`,
  `verify-setup.sh`.
- Grep for `wallpapers/<each-scaffolding-file>` shows the 5 files only reference **each other**
  (e.g. `wallpapers/README.md` references `IMPLEMENTATION_COMPLETE.md`, `SETUP_INSTRUCTIONS.md`,
  `verify-setup.sh`) — a self-contained cluster with zero external consumers.
- Grep for `wallpapers/` across all `.nix` files confirms only `riverside.jpg` is referenced
  (`modules/system/desktop.nix:23,24,28,33`; `modules/home/desktop/gnome.nix:45,46,52`) — the
  live asset is untouched by this deletion.
- **Deletion set**: the 5 named files only; `riverside.jpg` explicitly excluded and confirmed live.

## Decisions

- Proceed with the exact deletion/edit set as specified in the task description — live-repo
  verification found no discrepancies requiring a scope change.
- Do not act on the `packages/README.md` `### neovim.nix` stale-doc-section gap (see Risks) within
  this subtask's literal scope; leave it for the planner/implementer to fold in opportunistically
  (the file is already open for the `test-mcphub.sh` edit) or defer to subtask 91 (documentation
  sync), whichever the implementation phase judges lower-risk. Recommendation: since
  `packages/README.md` is already being edited in this same subtask for `test-mcphub.sh`, folding
  in the 3-line `neovim.nix` section removal at the same time is the more efficient choice and
  carries identical (zero) evaluation risk — but this is advisory, not mandatory, since it exceeds
  the task's literally-stated scope.
- Do not touch root `README.md` (lines 75-76, 91: Module Map + directory-organization bullet
  linking to `home-modules/README.md`) or `docs/configuration.md:20` (stale "Stub scaffold"
  line) — both reference the soon-to-be-deleted `home-modules/`, but neither is in this task's
  scope; both are explicitly deferred to subtask 91 (Documentation Sync, task 91), which owns
  root README Module Map corrections per the task 81 design doc §3 row 10.

## Risks & Mitigations

- **Risk**: After this subtask lands, root `README.md` will contain a dead link
  (`[README](home-modules/README.md)`) and two stale Module Map lines referencing a now-deleted
  directory, until subtask 91 (documentation sync, task 91) lands.
  **Mitigation**: None needed for *this* subtask — it's explicitly out of scope and doesn't affect
  build/evaluation (README.md is not consumed by Nix). Confirmed subtask 91's design-doc scope
  ("root README Module Map... drop `neovim.nix`...") already covers this class of fix; no new
  subtask needed. Flagging here only so the gap isn't rediscovered as a surprise later.
- **Risk**: `packages/README.md`'s `### neovim.nix` section (lines 257-259) becomes a dangling doc
  reference to a deleted file, and is not one of the 3 cited `test-mcphub.sh` references in this
  task's explicit scope.
  **Mitigation**: Low severity (doc-only, no build/eval impact). Recommend the implementer fold
  this 3-line removal into the same `packages/README.md` edit pass while the file is already open
  for the `test-mcphub.sh` doc patch, as a zero-risk opportunistic cleanup — but this is advisory;
  the task's literal scope does not require it, and deferring to subtask 91 is also acceptable.
- **Risk**: Staging discipline — `flake.nix`'s `root = self` means `nix flake check` /
  `nixos-rebuild build` only see git-tracked content (per design doc §4.1). Deleting files with
  `rm`/`git rm` without an explicit `git add <paths>` (or equivalent staging of the deletion)
  before running the verification harness could produce a false-positive green result against the
  stale tracked layout.
  **Mitigation**: Already codified as the mandatory cross-cutting protocol inherited by this
  subtask — stage each deletion/edit with `git add <specific paths>` (never `git add -A`)
  immediately before running `nix flake check` / `nixos-rebuild build` / `nix build`. No new
  mitigation needed; just confirming the protocol applies identically to `git rm` deletions
  (`git add` on a deleted path stages the removal) as it does to new/modified files.
- **Risk**: None found regarding accidental collision between `packages/neovim.nix` (to delete)
  and `modules/home/core/neovim.nix` (live) — explicitly re-verified as distinct files via grep;
  the task description's own caution flag on this point is correct and no further action is
  needed beyond care during the actual `rm`/`git rm` command (delete only the `packages/` path).

## Appendix

### Search queries used

```bash
grep -rn "home-modules" --include="*.nix" --include="*.md" --include="*.sh" .
grep -rn "mcp-hub\|mcp_hub\|MCP-Hub\|MCP_HUB" --include="*.nix" --include="*.md" --include="*.sh" .
grep -rn "modules/opencode\|opencode\.nix" --include="*.nix" .
grep -rn "packages/neovim\|neovim\.nix" --include="*.nix" .
grep -n "callPackage" overlays/*.nix
grep -rln "test-sasl" . --include="*.md" --include="*.nix" --include="*.sh"
grep -rln "test-update" . --include="*.md" --include="*.nix" --include="*.sh"
grep -rln "\bTODO\.md\b" . --include="*.md" --include="*.nix" --include="*.sh"
grep -rn "wallpapers/" --include="*.nix" .
grep -rn "test-mcphub" . --include="*.md" --include="*.nix" --include="*.sh"
git ls-files config/rclone.conf   # confirms untracked
grep -n "rclone" .gitignore
```

### References

- `specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md`
  (seed inventory: "home-modules/ — DEAD", "packages/ — mostly LIVE; two orphans", "Root files",
  "wallpapers/" sections)
- `specs/081_reorganize_nixos_dotfiles_repository_design/reports/02_team-research.md` (Recommended
  Subtask Decomposition, row 1; Critic correction on `test-mcphub.sh`)
- `specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md` §3 (Subtask
  Blueprint row 1), §4 (Migration Safety & Verification — git-add-before-verify protocol)
- Live repo state as of 2026-07-05 (this session's `grep`/`ls`/`git ls-files` verification, not
  re-quoted from the seed reports)

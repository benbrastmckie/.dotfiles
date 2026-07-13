# Research Report: Task #92 — Cross-Repo Linkage to nvim Mail Sync (task 851)

**Task**: 92 - logos_mbsync_group_labels_fix
**Type**: report
**Started**: 2026-07-11T14:51:57Z
**Completed**: 2026-07-11T14:51:57Z
**Session**: sess_1783806717_bc03e4
**Dependencies**: None
**Builds on**: `reports/02_task-still-needed.md` (do not repeat — this report adds only the
new cross-repo dimension that 02 could not see, being scoped to `mbsync.nix` + its git history)
**Sources/Inputs**:
- `reports/01_mbsync-logos-diagnosis.md`, `reports/02_task-still-needed.md` (this task)
- `~/.config/nvim` commits `bcb662549`, `a1c64151b` (this session's mail-stack changes)
- `~/.config/nvim/specs/851_himalaya_mail_sync_and_keymap_fixes/reports/01_himalaya-mail-sync-keymaps.md`
- `modules/home/email/mbsync.nix` (current `Group logos`, lines 207-213)

**Artifacts**: this report
**Standards**: report-format.md; repo CLAUDE.md documentation policy (no emojis, ASCII markers)

---

## Executive Summary

`reports/02_task-still-needed.md` already established the technical status of task 92:
the blocking crash is **fixed** (commit `a8f65ad`, removing `logos-labels` from `Group logos`,
landed incidentally via nvim task 826), while proposal parts 2 (`Group logos-full`) and 3
(negative dotted-name patterns) remain **unimplemented**. That classification (**PARTIAL**)
stands and is not re-litigated here.

This report adds one thing 02 could not know: a **new consumer of `Group logos`** landed in the
`~/.config/nvim` repo during this session (task 851). Interactive Neovim mail keymaps now invoke
`mbsync -a` (which runs `Group logos`) and `mbsync logos-inbox` far more routinely than before —
which (a) raises the practical value of task 92's residual hardening and (b) makes task 92's
verification identical to nvim task 851's remaining open item. The two should be verified together.

## New finding: nvim now drives `Group logos` on interactive keymaps

This session's nvim changes (committed `bcb662549`, `a1c64151b`) wired mail sync to keymaps:

| nvim keymap | Command / action | mbsync invocation | Touches `Group logos`? |
|-------------|------------------|-------------------|------------------------|
| `<leader>ms` | HimalayaSyncAllInbox | `mbsync gmail-inbox`, then `mbsync logos-inbox` (sequential) | No (single channel) |
| `<leader>me` | open aerc + background sync | `mbsync -a && notmuch new` | **Yes** (`-a` runs Group logos) |
| `<leader>mN` | explicit full sync | `mbsync -a && notmuch new` | **Yes** |

Implications for task 92:

1. **The crash fix is load-bearing for the new nvim UX.** `<leader>me` runs `mbsync -a` on
   *every aerc open*. Because a8f65ad already removed `logos-labels` from `Group logos`, this is
   safe today — but it means the group's health is now exercised frequently and interactively,
   not just by the occasional wrapper reconcile. Any regression that re-introduced a dotted-name
   member to `Group logos` would now surface as a visible error on a common keystroke.
2. **Part-3 hardening matters more than 02 implied.** 02 framed the missing `"!Labels/*.*"` /
   `"!Folders/*.*"` guards mainly around the manual `mbsync logos-labels` "inspection" path.
   With `mbsync -a` now on a hot keymap, the latent risk that Proton later introduces a dotted
   **Folder** name (`logos-folders` IS still in `Group logos`) would break `<leader>me` for the
   user directly. The negative pattern on `logos-folders` is the single highest-value residual item.
3. **`Group logos-full` (part 2) remains low priority** — it is an operator convenience; no nvim
   keymap depends on it.

## Verification is shared with nvim task 851

nvim task 851's one remaining open item is: "live end-to-end verification that `<leader>ms`
reconciles `logos-inbox` (and `<leader>me`'s `mbsync -a`) against the Proton Bridge server
without error." That is exactly task 92's own verification criterion (`mbsync logos` exits 0 and
propagates INBOX->Trash deletes). A single live check closes the open item in BOTH repos:

```
mbsync logos-inbox   # exercises the <leader>ms logos leg
mbsync logos         # exercises Group logos (the wrapper reconcile + subset of mbsync -a)
mbsync -a            # exercises the <leader>me / <leader>mN path end to end
```

Expected per 02: all exit 0 now that `logos-labels` is out of the group (non-fatal
duplicate-UID warnings and the one dateless Sent message noted in report 01 may still appear but
do not fail the reconcile).

## Recommendation (reconciled)

No change to 02's core recommendation. Concretely:

- **Keep task 92 open, narrowed** to the two residual items, prioritized by the new nvim usage:
  1. Add `"!Folders/*.*"` to `logos-folders` and `"!Labels/*.*"` to `logos-labels` (part 3) —
     now the highest-value item because `logos-folders` is in the `mbsync -a` path a hot nvim
     keymap runs.
  2. Add `Group logos-full` (part 2) — optional operator convenience.
  Research is complete (reports 01, 02, 03); route directly to `/plan`.
- **Verify once, credit both repos**: run the three `mbsync` commands above; a clean result
  closes task 92's verification and nvim task 851's remaining item simultaneously.
- The COMPLETED-vs-ABANDONED-vs-narrow-open disposition remains a scope/priority call for the
  user, exactly as 02 stated; this report only re-weights the residual items given the new
  interactive `mbsync -a` consumers.

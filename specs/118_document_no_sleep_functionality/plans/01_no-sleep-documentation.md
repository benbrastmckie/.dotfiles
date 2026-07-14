# Implementation Plan: Task #118

- **Task**: 118 - document_no_sleep_functionality
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: None (documents already-implemented task 117 functionality; no config changes)
- **Research Inputs**: specs/118_document_no_sleep_functionality/reports/01_no-sleep-functionality.md
- **Artifacts**: plans/01_no-sleep-documentation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Consolidate the "no-sleep for AI agents" functionality (already implemented in task 117) into a
single user-facing documentation page. The functionality spans four independent, layered
mechanisms (Claude Code session inhibitors, GNOME/logind idle+lid settings, niri swayidle, and a
root battery-suspend backstop) that are currently documented only partially across
`docs/gnome-settings.md` and `docs/niri.md`, with no single coherent page and no coverage of the
Claude Code hook mechanism itself. This plan creates `docs/no-sleep-agents.md`, trims/redirects
the existing pages to avoid duplication, wires up the repo's standard cross-reference conventions
(README index entry + `# See docs/X.md.` nix trailers), and folds in a live-state verification
step for two time-sensitive facts. Definition of done: a reader can understand the whole system
end-to-end from one page, existing pages point to it rather than duplicating it, and no
unverified claim is propagated.

### Research Integration

The research report (`reports/01_no-sleep-functionality.md`) is the sole primary input and supplies
all mechanism detail, exact config values/file locations, the composed-scenario table (§2), the
current activation-status table (§3), the existing-docs gap analysis (§4), and the documentation
targets (§5). Two report-flagged items drive a dedicated verification phase: (a) the live logind
`HandleLidSwitch` gap (committed `"lock"` but live `"suspend"` at research time — needs re-check at
write time), and (b) the unverified Neovim `<leader>rz` inhibitor claim in `docs/gnome-settings.md`
(no matching keymap/`systemd-inhibit` call found in the repo tree). The report's hard constraint —
no `specs/117_...` citations in `docs/` output (per `.claude/rules/no-task-references-in-deliverables.md`)
— is honored: all mechanism explanations are written in the page's own words.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found; no roadmap_flag set. No roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Create one consolidated `docs/no-sleep-agents.md` covering all four mechanisms, the
  composed-scenario table, exact config values/file locations, an activation-verification
  checklist (as commands, not hardcoded status), and a short "why not X" rejected-alternatives
  section.
- Trim `docs/gnome-settings.md` and `docs/niri.md` to summary-plus-cross-reference, eliminating
  duplication/drift with the new page.
- Wire the new page into repo conventions: `docs/README.md` index entry and
  `# See docs/no-sleep-agents.md.` trailers in `modules/system/power.nix` and
  `modules/home/desktop/gnome.nix`.
- Verify the two time-sensitive/unconfirmed facts at write time and reflect the true state
  (re-run the `busctl` lid check; verify-or-drop the `<leader>rz` claim).

**Non-Goals**:
- No configuration changes to any `.nix`/`.kdl`/`settings.json` file (this is a docs task; task
  117 already implemented the functionality). The only nix edits are one-line `# See ...` comment
  trailers.
- No citations of `specs/117_...` or any task number from `docs/` content.
- No decision to remediate the live logind activation gap here (fixing it is a system action, not
  documentation) — the page documents how to verify and fix it, but running `systemctl restart
  systemd-logind` is out of scope.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Doc goes stale on the activation-status claim | M | H | Write the verification *command* (`busctl`), not a hardcoded status, into the page (Phase 2), mirroring the repo's verify-against-source convention |
| Duplication/drift between the new page and gnome-settings.md/niri.md | M | M | Explicitly perform the trim-and-cross-reference in Phase 3 rather than only adding the new page |
| Propagating the unverified `<leader>rz` claim into the new page | L | M | Verify (grep) or drop the claim in Phase 1 before it can reach the new page; do not carry it forward uncritically |
| Accidental config change while editing nix files for trailers | M | L | Restrict nix edits to comment-only `# See docs/...` trailers; verify with `nix flake check` or targeted `git diff` that only comments changed |
| Task-number reference leaking into docs/ | L | M | Write all mechanism prose in the page's own words; grep the new/edited docs for `specs/117` / `task 117` before completion |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Verify time-sensitive and unconfirmed facts [COMPLETED]

- **Goal:** Establish the true current state of the two report-flagged facts so the new page
  reflects reality at write time rather than the research snapshot.
- **Tasks:**
  - [x] Re-run the live lid check: `busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch` and record whether it is now `"lock"` (activated) or still `"suspend"` (activation gap persists). **Result: still `s "suspend"` — activation gap persists, unchanged from research snapshot.**
  - [x] Confirm the battery backstop and gsettings are still live: `systemctl is-active battery-suspend-backstop.timer`, `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type` / `sleep-inactive-battery-type` / `sleep-inactive-battery-timeout`. **Result: timer `active`; `sleep-inactive-ac-type` = `'nothing'`; `sleep-inactive-battery-type` = `'suspend'`; `sleep-inactive-battery-timeout` = `3600`. All match committed config.**
  - [x] Verify-or-drop the `<leader>rz` inhibitor claim: grep the repo (and any nvim config source it points to) for `rz`, `systemd-inhibit`, and `inhibit` in `.lua` files; determine whether the keymap/inhibitor exists. If unconfirmed, decide to drop the claim rather than propagate it. **Result: `grep -rn "rz" --include="*.lua"`, `grep -rln "systemd-inhibit" --include="*.lua"`, and `grep -rln "inhibit" --include="*.lua"` all returned zero matches repo-wide. Decision: DROP the claim — omit from the new page and remove/replace the existing Note in `docs/gnome-settings.md`.**
  - [x] Record all findings (as a short note for Phase 2/3 to consume) including the exact command outputs. **Recorded above.**
- **Timing:** ~20 minutes
- **Depends on:** none

### Phase 2: Author the consolidated docs/no-sleep-agents.md page [COMPLETED]

- **Goal:** Produce the single end-to-end page covering all four mechanisms in the reader's
  own words, with the composed-scenario table, verification checklist, and rejected-alternatives
  section.
- **Tasks:**
  - [x] Write the four-mechanism breakdown in reader-encounter order: (1) Claude Code `SessionStart`/`SessionEnd` inhibitor hooks in `config/claude/settings.json` (the `systemd-inhibit --what=sleep:idle ... --mode=block`, the `tail --pid=$PPID` tether rationale, pid-file reaping, session-scoped-not-activity-scoped) — this is the currently-undocumented piece; (2) GNOME/logind settings (`modules/system/power.nix` logind lid `lock`, the `lock`-vs-`ignore` mutter rationale, `modules/home/desktop/gnome.nix` `sleep-inactive-*` dconf keys, `LidSwitchIgnoreInhibited` note); (3) niri swayidle equivalent (`config/config.kdl`, native lid handling, zero idle auto-suspend); (4) root `battery-suspend-backstop` timer/service in `modules/system/power.nix` (`BAT*` glob, `<=10%` + discharging, `systemctl suspend -i` inhibitor bypass, threshold rationale, escape hatches).
  - [x] Include the composed-scenario table (AC vs battery, session open vs not, lid closed, external monitor, `<=10%` backstop) from report §2.
  - [x] Add an "Activation & verification" section written as the `busctl`/`systemctl`/`gsettings` *commands* to run (not a hardcoded status), and reflect the Phase 1 finding on whether the logind lid setting is currently live (including the `sudo systemctl restart systemd-logind` / reboot fix if the gap persists).
  - [x] Add a short "Why not just X" section covering the rejected alternatives (plain `ignore` instead of `lock`; UPower's 2% HybridSleep; hibernate/suspend-then-hibernate on this hardware) in the writer's own words.
  - [x] Only include the `<leader>rz` reference if Phase 1 confirmed it; otherwise omit it entirely. *(Phase 1 could not confirm the claim — omitted entirely from the new page.)*
  - [x] Ensure zero `specs/117` / `task 117` / task-number references anywhere in the page.
  - [x] Choose the page's README category placement note (System/Hardware vs Applications & Desktop) for Phase 4 to apply. *(Decision: place under "Applications & Desktop", adjacent to gnome-settings.md/niri.md, since it primarily addresses desktop-session power behavior that both those pages already partially cover; a one-line description will note the system/hardware content it also touches.)*
- **Timing:** ~60 minutes
- **Depends on:** 1

### Phase 3: Trim and cross-reference existing pages [COMPLETED]

- **Goal:** Remove the cross-cutting narrative from `docs/gnome-settings.md` and `docs/niri.md`,
  leaving only their file-scoped content plus a pointer to the new page, so the two pages no longer
  duplicate/drift from it.
- **Tasks:**
  - [x] `docs/gnome-settings.md`: trim the "Power Management" + "Lid-Close Behavior" sections to a short summary of the GNOME-dconf-scoped facts (idle-delay, the raw `sleep-inactive-*` keys) plus a "See docs/no-sleep-agents.md" cross-reference; move the cross-cutting rationale (AC/battery difference, backstop rationale, lid `lock`-vs-`ignore`) out to the new page.
  - [x] Apply the Phase 1 `<leader>rz` decision to the existing gnome-settings.md Note (correct it if verified, remove it if not). *(Removed — the unverified Note was dropped along with the rest of the trimmed section.)*
  - [x] `docs/niri.md`: trim the swayidle paragraph and the "no idle auto-suspend" bullet to a brief statement plus a "See docs/no-sleep-agents.md" cross-reference.
  - [x] Re-grep both edited pages for `specs/117` / task-number leakage. *(Zero matches in both files.)*
- **Timing:** ~30 minutes
- **Depends on:** 2

### Phase 4: Wire index entry and nix cross-reference trailers [NOT STARTED]

- **Goal:** Register the new page per the repo's documented "adding new docs/ files" convention.
- **Tasks:**
  - [ ] Add `docs/no-sleep-agents.md` to `docs/README.md` under the category chosen in Phase 2 (with a one-line description).
  - [ ] Add a comment-only `# See docs/no-sleep-agents.md.` trailer near the relevant blocks in `modules/system/power.nix` (logind lid settings banner and `battery-suspend-backstop` service/timer banner).
  - [ ] Add a comment-only `# See docs/no-sleep-agents.md.` trailer near the `sleep-inactive-*` dconf keys in `modules/home/desktop/gnome.nix`.
  - [ ] Optionally add a one-line mention/link in root `README.md` only if judged sufficiently user-facing (writer's call per report §5.6; default is to skip, matching task 117's guidance).
  - [ ] Verify the nix edits are comment-only (targeted `git diff` shows only added `#` lines) and, if convenient, that the flake still evaluates.
- **Timing:** ~20 minutes
- **Depends on:** 2

## Testing & Validation

- [ ] `docs/no-sleep-agents.md` exists and covers all four mechanisms, the composed-scenario table, a command-based verification section, and a rejected-alternatives section.
- [ ] The activation section uses verification *commands*, not a hardcoded pass/fail status, and reflects the Phase 1 live finding.
- [ ] `grep -rn "specs/117\|task 117\|task-117" docs/no-sleep-agents.md docs/gnome-settings.md docs/niri.md` returns no matches.
- [ ] `docs/gnome-settings.md` and `docs/niri.md` no longer duplicate the cross-cutting narrative and each contain a `See docs/no-sleep-agents.md` reference.
- [ ] `docs/README.md` lists the new page under an appropriate category.
- [ ] `modules/system/power.nix` and `modules/home/desktop/gnome.nix` contain `# See docs/no-sleep-agents.md.` trailers, and `git diff` confirms only comment lines changed in those files.
- [ ] The `<leader>rz` claim is either verified-and-kept or dropped everywhere (new page + gnome-settings.md), never left as an unverified assertion.
- [ ] (Optional) `nix flake check` still passes after the comment-only nix edits.

## Artifacts & Outputs

- `docs/no-sleep-agents.md` (new consolidated page)
- `docs/gnome-settings.md` (trimmed + cross-referenced)
- `docs/niri.md` (trimmed + cross-referenced)
- `docs/README.md` (index entry added)
- `modules/system/power.nix` (comment trailer only)
- `modules/home/desktop/gnome.nix` (comment trailer only)
- `specs/118_document_no_sleep_functionality/summaries/01_no-sleep-documentation-summary.md` (implementation summary)

## Rollback/Contingency

All changes are additive docs plus comment-only nix edits. To revert: delete
`docs/no-sleep-agents.md`, and `git checkout` the modified `docs/*.md` and the two `.nix` files
(a clean working tree makes this a one-command revert; no build state is affected since the nix
edits are comments only). If the live logind activation gap is found unresolved in Phase 1,
document the verification+fix commands in the page rather than attempting remediation, and note
the gap prominently.

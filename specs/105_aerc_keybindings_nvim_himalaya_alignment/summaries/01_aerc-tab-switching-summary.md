# Implementation Summary: Task #105

**Completed**: 2026-07-09
**Duration**: ~15 minutes

## Overview

Added `<Tab>` = `:next-tab<Enter>` and `<S-Tab>` = `:prev-tab<Enter>` bindings to
the aerc `[messages]` and `[view]` `extraBinds` contexts in
`modules/home/email/aerc.nix`, aligning aerc's account-tab switching with the
Neovim `<Tab>`/`<S-Tab>` buffer-nav reflex. The existing `<C-n>`/`<C-p>` global
binds were left untouched as guaranteed fallback aliases. The change is purely
additive (4 new lines + 2 comment blocks); no existing bind was modified.

## What Changed

- `modules/home/email/aerc.nix` — Added `"<Tab>" = ":next-tab<Enter>";` and
  `"<S-Tab>" = ":prev-tab<Enter>";` to the `messages` attribute set (grouped
  after `J`/`K` folder navigation) and to the `view` attribute set (grouped
  after `J`/`K` message navigation), each with a short comment referencing task
  105 and the Neovim `<Tab>`/`<S-Tab>` reflex.

## Decisions

- Followed the plan's Non-Goals exactly: no `<Tab>`/`<S-Tab>` added to
  `[global]`, `[compose]`, `compose::editor`, or `terminal` contexts, to avoid
  stealing `<Tab>` from compose text fields.
- `<C-n>`/`<C-p>` (global) kept verbatim as fallback aliases, per plan.

## Plan Deviations

- **Phase 2 / `home-manager switch`** deferred: per the orchestrator's explicit
  instruction, this agent ran `home-manager build` only and did not run
  `home-manager switch` (a deployment step reserved for the user to confirm).
- **Phase 2 manual in-aerc checks** (interactive `<Tab>`/`<S-Tab>` tab-switch
  confirmation in the message list/view, compose-buffer non-interference check,
  and the WezTerm backtab `CSI Z` distinguishability check) deferred to the
  user as a follow-up, since they require an interactive terminal session
  after `switch` is run. As a substitute, the safety-critical and new-bind
  content was statically verified against the actual built `binds.conf`
  derivation output (see Verification below), which is a stronger check than
  a source-diff read alone.

## Verification

- `git diff modules/home/email/aerc.nix`: purely additive (6 `+` lines added
  per context, 0 `-` lines); confirmed no existing bind (including
  `d`/`D`/`a`/`A`, the three `Proposed-*` folder blocks, and `$` sync) was
  touched.
- `home-manager build --flake .#benjamin`: **Success** (exit 0). Built
  `hm_homebenjamin.configaercbinds.conf.drv`, `home-manager-files.drv`,
  `home-manager-generation.drv`.
- Inspected the actual built `binds.conf` output via
  `nix path-info <drv>^out` + read:
  - `[messages]` and `[view]` sections each contain
    `<S-Tab> = :prev-tab<Enter>` and `<Tab> = :next-tab<Enter>`.
  - Safety-critical lines present byte-for-byte unchanged:
    - `[messages]`: `d = :prompt 'Delete message?' 'delete-message'<Enter>`,
      `D = :prompt 'Hard delete (bypass the confirm-message prompt)?' 'delete'<Enter>`,
      `a = :archive flat<Enter>`,
      `A = :unmark -a<Enter>:mark -a<Enter>:prompt 'Archive ALL marked messages?' 'archive flat'<Enter>`.
    - `$ = :exec mbsync gmail && notmuch new --no-hooks<Enter>` (scoped form,
      never `mbsync -a`).
    - `[messages:folder=Proposed-Delete]`, `[messages:folder=Proposed-Archive]`,
      `[messages:folder=Proposed-Unsure]`: all three retain their
      `:modify-tags ... <Enter>:exec email-classify --append-approved
      {{.MessageId}}<Enter>` wrapper-routed gestures and `k` = keep rescues.
  - `[global]` unlabeled top section retains `<C-n> = :next-tab<Enter>` and
    `<C-p> = :prev-tab<Enter>` unchanged; no `<Tab>` added there.
  - `[compose]`, `[compose::editor]`, `[terminal]` sections retain only
    `<C-n>`/`<C-p>` — no `<Tab>`/`<S-Tab>` added, confirming compose text
    fields are unaffected.

## Notes

- `home-manager switch` and the interactive `<Tab>`/`<S-Tab>` / backtab
  distinguishability manual checks are a required user follow-up before the
  Definition of Done in the plan is fully satisfied. The build-level
  verification above gives high confidence the generated `binds.conf` will be
  correct once `switch` is run, since the built derivation output (not just
  the source diff) was inspected directly.
- Rollback: if any issue is found, `git checkout modules/home/email/aerc.nix`
  (before commit) or `git revert` (after commit), then re-run
  `home-manager switch`.

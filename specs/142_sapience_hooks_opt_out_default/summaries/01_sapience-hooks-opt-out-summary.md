# Implementation Summary: Sapience Hooks Opt-Out Default

**Completed**: 2026-11-18
**Duration**: ~1 hour

## Overview

`modules/home/services/sapience.nix`'s `sapienceBootstrap` wrote `~/.sapience/config.json`'s
`"hooks"` key through two jq expressions that both forced it to `true` via jq's `//` operator,
which treats an explicit `false` the same as absent — silently reverting a deliberate opt-out on
every re-bootstrap. Both sites now default `"hooks"` to `false` while preserving an explicit
value of either polarity, a new repo-tracked detector reports any vendor-written injection hook
in `~/.claude/settings.json` before the enforced-key merge can hide it, `docs/sapience.md` and
the module's header comment document the resulting three-layer design, and a real
`home-manager switch` followed by a forced `sapience_upkeep.py --update` confirmed no hook
reappeared.

## What Changed

- `modules/home/services/sapience.nix` — the re-bootstrap merge site's `.hooks` clause now reads
  `(if .hooks == null then false else .hooks end)` instead of `(.hooks // true)`; the first-run
  mint literal now writes `hooks: false`; a comment explains why `auto_approve` keeps `//` while
  `hooks` cannot; a new `sapienceHooksGuard` `home.activation` entry, declared
  `entryBefore [ "claudeSettings" ]`, runs the new detector non-fatally; the header comment
  block gains a two-line pointer to the opt-out and the guard.
- `scripts/check-sapience-hooks.sh` — new detector script. Flattens
  `hooks.SessionStart`/`SessionEnd`/`Stop` command strings from a settings file (default
  `~/.claude/settings.json`, overridable by a first positional argument) and reports any entry
  containing `.sapience/mcp.py` together with `--briefing-text`, `--receipt`, or
  `--effect-line`. Exits `1` on a finding (naming each offender and the remedy), `0` otherwise,
  including on a missing file, invalid JSON, or an absent `hooks` key. `--quiet-ok` suppresses
  the "no finding" line for the activation call site.
- `docs/sapience.md` — new subsection, "The three layers that keep machine-wide hooks out of
  settings.json", naming the opt-out, the `claudeSettings` backstop, and `sapienceHooksGuard`,
  the scope boundary of `"hooks": false` (it does not affect the per-repository hooks the
  sapience extension merges), and the standalone detector invocation.

## Decisions

- Default, not force: an explicit `"hooks"` value of either polarity survives every
  re-bootstrap; only an absent key is defaulted to `false`.
- The detector is ordered `entryBefore [ "claudeSettings" ]`, not after it — `claudeSettings`
  resets `hooks` as an enforced key on every switch, so a guard running after it would always
  read an already-cleaned file and could never fire.
- The activation call is loud but non-fatal; the hard-failing exit lives only in the standalone
  script, so a detection cannot itself block the same switch's `claudeSettings` from stripping
  the injection.
- One script, two call sites (`scripts/check-sapience-hooks.sh`), rather than an inline
  activation heredoc, so `nix flake check`'s `shellcheck` covers the logic.

## Plan Deviations

- Phase 4's rebuild step ran only `home-manager switch --flake .#benjamin` rather than the full
  `sudo nixos-rebuild switch` + `home-manager switch` pair `scripts/update.sh` wraps: `sudo` is
  categorically denied inside this agent harness, and the user-level generation is the one that
  owns `~/.nix-profile` and actually executes `home.activation`, which is what this phase needed
  to exercise. The NixOS-integrated generation stays out of sync pending a human-run
  `sudo nixos-rebuild switch`.
- Phase 4's "run the full gate set" verification step discharged against a scoped tier
  (`nix flake check` plus `verify-deploy.sh --skip-unchanged --only-gate 4`) rather than an
  independent full `verify-deploy.sh` sweep, per this dispatch's own Batch Gate Deferral
  directive (this task was one of several `implement`-phase dispatches in one `/orchestrate`
  batch invocation). The complete gate set still runs once for the whole batch at the end of
  that invocation.

## Verification

- `nix flake check`: Success (statix, deadnix --fail, nixfmt --check, shellcheck, home-eval),
  re-run clean after every phase that touched a tracked file.
- jq fixture exercise of the merge expression: `{"hooks": false}` -> `false`,
  `{}` -> `false`, `{"hooks": true}` -> `true`; mint literal -> `false`.
- `scripts/check-sapience-hooks.sh`: exit `1` with all three synthetic entries named on a
  fixture carrying the vendor's injection signature; exit `0` on the real live
  `~/.claude/settings.json`, a missing file, invalid JSON, and a file with no `hooks` key.
- Activation DAG: `nix build .#homeConfigurations.benjamin.activationPackage` succeeded, and the
  built `activate` script shows `sapienceHooksGuard` activating before `claudeSettings`.
- Real `home-manager switch --flake .#benjamin`: succeeded; the resulting generation's store
  path matched the one inspected for DAG ordering; `~/.claude/settings.json`'s mtime moved
  during the switch, confirming `claudeSettings` ran; `sapienceHooksGuard` reported nothing
  (clean).
- `python3 ~/.sapience/sapience_upkeep.py --update`: output read "Claude Code: left alone (you
  switched the Sapience hooks off in config.json)" — the opt-out branch, not the wiring branch.
- Post-update `~/.claude/settings.json`: no `.sapience/mcp.py` entry with any of the three flags;
  `scripts/check-sapience-hooks.sh` standalone agreed (exit `0`).
- GOAL item (2) re-attested empirically: this repository's own `.claude/settings.local.json`
  (it loads the sapience extension) still carries all three per-repository
  `mcp.py --briefing-text`/`--receipt`/`--effect-line` entries, unaffected by `"hooks": false`.
- `bash .claude/scripts/verify-deploy.sh --skip-unchanged --only-gate 4`: PASS (task-reference
  lint) at Phase 3 and Phase 4.
- No task-number reference or version-history phrasing found in `docs/sapience.md` or
  `modules/home/services/sapience.nix`.

## Notes

Both live files (`~/.claude/settings.json`, `~/.sapience/config.json`) were backed up to
timestamped `.bak-20261118-110409` copies before the rebuild, per the Phase 4 contingency plan.
No rollback was needed. The companion extension-side verifier/doc task
(`sapience_activation_surface_scoping_gaps`, nvim repository) is unaffected by this work; nothing
under `.claude/**` or the sapience extension source store was touched.

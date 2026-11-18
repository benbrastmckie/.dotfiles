# Implementation Summary: Task #139

**Completed**: 2026-11-18
**Duration**: ~4 hours (4 phases)

## Overview

Added a new `programs.sapience.sessionClassifier` boolean option that exports the vendor's
`NO_CLASSIFY=1` switch, wired into both hand-maintained module trees — this repository's
`modules/home/services/sapience.nix` (default `false`, flipping the vendor default on this
machine's measured near-zero classifier hit rate) and the standalone, externally-consumed
`packages/sapience-flake` (default `true`, matching the vendor default). The option disables the
work/personal classifier's one model call per not-yet-extracted session, which the research
confirmed is the dominant per-pass cost on the metered `anthropic` backend. The change is applied
to the live machine generation via `home-manager switch`, and `docs/sapience.md` records the
measured cost shape as settled fact.

## What Changed

- `modules/home/services/sapience.nix` — new `sessionClassifier` option (default `false`); four
  `NO_CLASSIFY=1` export sites (`sapienceCli`, `sf1Cli`, `sapienceBootstrap`, the
  `sapience-sync.service` script); classifier-aware progress ticker (`classify_on` literal gating
  the total-call estimate and the `phase="classifying"` label); updated ESTIMATE comment.
- `packages/sapience-flake/lib/wrappers.nix` — new `sessionClassifier` argument; three
  `NO_CLASSIFY=1` export sites; the same ticker treatment, kept textually parallel to the
  home-manager tree.
- `packages/sapience-flake/modules/sapience.nix` — new option (default `true`); added to the
  `inherit (cfg)` list feeding `wrappers`; export line in the sync unit script.
- `packages/sapience-flake/flake.nix` — `sessionClassifier = true;` in the `mkWrappers`
  vendor-default argument set.
- `packages/sapience-flake/checks/default.nix` — `sessionClassifier = true;` in the checks'
  `mkWrappers` default argument set.
- `packages/sapience-flake/README.md` — new `sessionClassifier` row in the `## Defaults` table.
- `docs/sapience.md` — `### Cost shape` rewritten with the measurement (29 min wall clock / 3.5s
  CPU / 71 sources / 1208 objects; classifier accounting for roughly the first 20 minutes); the
  `### Performance and failure modes` backlog bullet corrected to drop the "until it drains"
  framing; new `sessionClassifier` rows in both option tables; new
  `### The work/personal classifier is off` design-decision section; one clarifying sentence each
  added to `## Where your data goes` and `### Watching a run`.

## Decisions

- **Lever chosen: `NO_CLASSIFY=1` via a new module option**, not verdict caching (rejected —
  would require patching the vendor's self-updating `~/.sapience/extract_local.py`) and not
  "accept and document" alone (insufficient once the backlog was confirmed not to drain).
- **Option named `sessionClassifier`**, mirroring the `memoryFiles`/`NO_MEMFILES` naming pattern
  and avoiding the ambiguous polarity of `classifyPersonal`.
- **Both module trees changed, with different defaults** — this repository's module flips the
  classifier off (measured near-zero hit rate here), while `packages/sapience-flake` keeps the
  vendor default on, since it is a published artifact whose default must not be set from this
  machine's corpus.

## Plan Deviations

- Phase 1's first draft of the ticker's ESTIMATE comment used the literal string
  `NO_CLASSIFY=1`, which collided with the built-artifact verification's own
  `grep -c 'NO_CLASSIFY=1'` == 1 check against `sapience-bootstrap`. Rephrased to "NO_CLASSIFY
  exported" to drop the collision; confirmed by rebuild.
- Phase 4's `bash .claude/scripts/verify-deploy.sh /home/benjamin/.dotfiles` (complete gate set)
  was deferred to the batch stage per this dispatch's own Batch Gate Deferral directive — this
  implementation ran as one of several `implement`-phase dispatches inside a single multi-task
  `/orchestrate` batch invocation. Discharged instead via the scoped narrowing invocation
  `bash .claude/scripts/verify-touched.sh` (no args), which returned 74 passed / 12 failed / 86
  total — one *better* than the plan's recorded 13-suite baseline:
  `test-lint-state-writer-boundary.sh` now passes cleanly (confirmed directly: 27 passed, 0
  failed), an unrelated fix that landed between plan time and this dispatch. No suite newly
  failed. The complete, unscoped gate set still runs exactly once for the whole batch at the end
  of the `/orchestrate` invocation.

## Verification

- `nix flake check` (repo root): Success.
- `nix flake check -L ./packages/sapience-flake`: Success, including `help-output` (no golden-file
  drift) and `hm-module`.
- `bash packages/sapience-flake/tests/install-test.sh`: Success.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 4`: Success (task-reference lint;
  run per-phase for Phases 1 and 3).
- `bash .claude/scripts/verify-touched.sh` (scoped discharge of the complete gate set): 74
  passed / 12 failed / 86 total — one suite better than the recorded baseline (see Plan
  Deviations above).
- Built-artifact evidence: `nix build .#homeConfigurations.benjamin.activationPackage` then
  `grep -c 'NO_CLASSIFY=1'` returns exactly 1 for `sapience`, `sf1`, `sapience-bootstrap`, and the
  `sapience-sync` script.
- `nix build ./packages/sapience-flake#sapience` then `grep -c 'NO_CLASSIFY'` returns 0 (vendor
  default keeps the classifier on, as designed).
- Applied: `home-manager switch --flake .#benjamin` succeeded. Post-switch,
  `grep -c 'NO_CLASSIFY=1' "$(command -v sapience)"` returns 1, and the `sapience-sync.service`
  unit's `ExecStart` script (resolved by store path) carries the same export.
- Post-change `sapience coverage` reading (2026-11-18): "would ingest now: 136" — unchanged from
  the pre-switch reading the same day, now recorded in `docs/sapience.md`'s `### Cost shape`.

## Notes

The classify-eligible backlog held flat at 136 across two independent `sapience coverage`
inspections on 2026-11-18 (pre- and post-switch), reinforcing the research's two-pair
before/after measurement that the backlog does not self-drain. The next task touching this area
now has a dated post-change datum rather than only a pre-change one.

# Implementation Plan: Task #139

- **Task**: 139 - Reduce or accept the Sapience extraction classifier cost now that extraction is metered
- **Status**: [IMPLEMENTING]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: specs/139_reduce_sapience_classifier_cost/reports/01_reduce-classifier-cost.md
- **Artifacts**: plans/01_reduce-classifier-cost.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

The vendor's work/personal classifier makes one model call per not-yet-extracted session on
every extraction run, and that backlog does not drain, so on the metered `anthropic` backend it
is a permanent per-run cost that dominates wall clock. This plan implements the lever the
research recommended — a new `programs.sapience` boolean that exports the already-supported
vendor switch `NO_CLASSIFY=1`, defaulting against the vendor default on this machine, exactly
mirroring the existing `memoryFiles`/`NO_MEMFILES` option — in both trees that carry this
module, then records the measured cost shape in `docs/sapience.md`. Done means: the option
exists and is wired at every invocation site in both trees, `nix flake check` is green for both
flakes, the built artifacts are shown to carry the export, and `docs/sapience.md` states the
measurement as settled fact rather than as an open question.

### Research Integration

Findings carried into this plan from `reports/01_reduce-classifier-cost.md`:

- `extract_local.py:168` reads `CLASSIFY = os.environ.get('NO_CLASSIFY', '') != '1'`, consulted
  only by `is_personal()` (:1625-1636), which returns `False` immediately when `CLASSIFY` is
  falsy — so the switch removes the classify API call outright rather than merely ignoring its
  verdict.
- Redaction (`extract_local.py:2264`) runs unconditionally on every chunk regardless of
  `CLASSIFY`, so this change does not weaken redaction. The privacy cost is narrow and named:
  ordinary personal prose in a ticked folder is no longer filtered out before the provider call.
- Verdict caching (the second lever in the task description) is **rejected**: it would require
  patching `~/.sapience/extract_local.py`, which `sapience update`'s daily `auto_update()` can
  silently overwrite within a day, with no probe anywhere in this repo's inspection recipes for
  "is my patch still present."
- The classifier's measured hit rate on this corpus is one `(skipped a personal session)` event
  across the entire three-pass measured series.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no ROADMAP consultation was performed.

## Goals & Non-Goals

**Goals**:

- Add one boolean `programs.sapience` option that, when false, exports `NO_CLASSIFY=1` at every
  client invocation site, in `modules/home/services/sapience.nix`.
- Default it to the cost-reducing value on this machine (classifier off), with the measured
  rationale in the option description, mirroring `memoryFiles`'s own
  "defaults against the vendor default" framing.
- Mirror the option into `packages/sapience-flake` at the vendor default (classifier on), since
  that tree is a published, externally-consumed artifact whose default must not be set from this
  machine's corpus.
- Keep the progress ticker's phase labels and call-count estimate honest when the classifier is
  off, in both trees.
- Record the measured per-pass cost shape in `docs/sapience.md`'s `### Cost shape` section, and
  correct the now-falsified "until it drains" claim wherever it appears.

**Non-Goals**:

- Patching any file under `~/.sapience/` (the vendor payload). Rejected with reasons above.
- Running a new paid extraction pass to re-measure wall clock or to obtain a $/token figure. No
  $/token figure is obtainable from this client's output; that was confirmed three times in the
  prior measurement series and is not re-litigated here.
- Changing `MAX_CHUNKS`, `sourceDirs`, the folder selection, or the review gate.
- Changing `packages/sapience-flake`'s shipped default behavior for other consumers.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Personal prose in a ticked folder now reaches `api.anthropic.com` unfiltered | M | M | Redaction still runs unconditionally; the folder picker remains the real control; the option reverts in one line; Phase 3 states the trade-off in `docs/sapience.md` rather than leaving it implicit |
| The option's default is set from this machine's corpus and silently exported to other consumers | M | L | The two trees get **different** defaults by design (Phase 1 false, Phase 2 true), exactly as `memoryFiles` already does; Phase 2's option description says so |
| A `wrappers.nix` argument added without updating both of its other callers fails evaluation | M | M | Phase 2 is declared `atomic-batch` over its full file set for this reason; `nix flake check -L ./packages/sapience-flake` is its gate |
| The repo's full shell battery is already red (13 suites) for reasons unrelated to this task | M | H (already true) | Baseline measured and recorded at plan time (see Decisions); Phase 4 compares a delta, and this task touches no `.sh` file so the expected delta is zero |
| The ticker change is unobservable at the configured backend (`anthropic` emits no local journal signal) | L | H | Verification is by reading the generated script text, not by running the ticker; stated as such in Phase 1 and 2 criteria |
| A live `home-manager switch` disturbs the running session or fails for an unrelated cause (sops secret, concurrent writer) | L | L | The activation-package build in Phase 1 already proves the content independently; Phase 4 records a failed switch as a Reasoned Exclusion and leaves the code change in place for the next `scripts/update.sh` |
| Figures carried from the task description were never re-measured | L | M | Phase 3's Scope Hypothesis marks them `CARRIED-UNVERIFIED` with their source named, and re-derives the one figure that is free to re-derive (`sapience coverage`) |

## Decisions

1. **Lever: `NO_CLASSIFY=1` via a new module option.** Of the three levers in the task
   description, verdict caching is rejected (vendor-payload patch, silently undone by the daily
   auto-update) and "accept and document" is insufficient on its own now that the backlog is
   confirmed not to drain. Documenting the cost is still required and is Phase 3, regardless.
2. **Option name: `sessionClassifier`.** The research left the name open (`classifyPersonal` "or
   an equivalently named boolean option"). `sessionClassifier` is chosen because its polarity
   cannot be misread — `sessionClassifier = false` means there is no session classifier, whereas
   `classifyPersonal` reads ambiguously as "classify as personal" — and because it is a noun
   phrase like every neighbouring option (`memoryFiles`, `sourceDirs`, `backgroundSync`).
3. **Both trees change, with different defaults.** `packages/sapience-flake` is included rather
   than deferred, because its own `memoryFiles` precedent is already wired in both trees and the
   two are hand-maintained parallel copies that drift silently otherwise. Its default is the
   vendor default (`true`), and this repo's module flips it (`false`) with the measured
   rationale, exactly the split `memoryFiles` already uses
   (`modules/home/services/sapience.nix:746` default `false`;
   `packages/sapience-flake/modules/sapience.nix:179` default `true`).
4. **The known-red shell-battery baseline is recorded, not chased.** Measured in the plan
   dispatch: `bash .claude/scripts/verify-touched.sh modules/home/services/sapience.nix
   docs/sapience.md` returns `__FULL_SWEEP__` for both paths (no mapped suite) and therefore runs
   the full 86-suite battery, which reports `73 passed, 13 failed (0 expected, 13 NEW)`. The 13
   are: `test-common-lib.sh`, `test-deploy-baseline-lib.sh`,
   `test-gate-out-derived-staleness.sh`, `test-gate-out-self-attribution.sh`,
   `test-generate-task-order.sh`, `test-lint-hook-registration-paths.sh`,
   `test-lint-state-writer-boundary.sh`, `test-manifest-scripts-sync.sh`,
   `test-orchestrate-conclusion-aggregate.sh`, `test-reconcile-demote-stranded.sh`,
   `test-reconcile-handoff-status.sh`, `test-resume-scan-nonconformance.sh`,
   `test-sweep-invalidated-claims.sh` (all under `.claude/scripts/tests/`). This task touches no
   `.sh` file, so every one of them is pre-existing by construction; Phase 4 treats only a
   departure from this list as a regression.
5. **Correction targets confirmed present at authoring time.** The task description attributes
   the whole-backlog-reclassify note to `docs/sapience.md`'s `## Known gaps` section; it is not
   there. The real carriers, both confirmed by grep at plan time, are `### Cost shape`
   (`docs/sapience.md:465-471`) and the `**The classifier re-runs across the whole backlog.**`
   bullet under `### Performance and failure modes` (`docs/sapience.md:511-515`). Phase 3 names
   those two, and says what to do if either has moved by the time the phase runs.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Wire `sessionClassifier` into the home-manager module [COMPLETED]

**Goal**: `programs.sapience.sessionClassifier` exists in
`modules/home/services/sapience.nix`, defaults to `false`, exports `NO_CLASSIFY=1` at every
client invocation site, and leaves the progress ticker's labels and estimate correct when the
classifier is off.

**Tasks**:

- [x] Add the option beside `memoryFiles` (currently `modules/home/services/sapience.nix:746-765`):
      `lib.types.bool`, `default = false`, with a description that states (a) when false,
      `NO_CLASSIFY=1` is exported for every client invocation; (b) that it defaults against the
      vendor default here, because the filter fired exactly once across the whole measured
      extraction series on this machine's four captured folders (`nvim`, `dotfiles`, `app`,
      `abood`) while costing roughly two-thirds of every run; (c) that redaction runs
      unconditionally either way, so this is not a redaction setting; and (d) that adding a
      captured folder with a materially different content profile is the trigger to revisit the
      default.
- [x] Add `${lib.optionalString (!cfg.sessionClassifier) "export NO_CLASSIFY=1"}` immediately
      after each existing `NO_MEMFILES` line, at all four sites: `sapienceCli` (:88), `sf1Cli`
      (:177 — a documented no-op, since `sf1.py` never calls `is_personal()`, kept for parity
      exactly as `NO_MEMFILES` is there), `sapienceBootstrap`'s extraction call (:362), and the
      `sapience-sync.service` `ExecStart` script (:1229).
- [x] Make the ticker classifier-aware. Interpolate one eval-time literal (e.g.
      `classify_on=${if cfg.sessionClassifier then "1" else "0"}`) into the `ticker()` body and
      use it twice: drop the per-source term from the `total=$((srcs + budget))` estimate
      (:~432) when the classifier is off, and suppress the `phase="classifying"` branch
      (:454-456) so chunk calls are never mislabelled as classification.
- [x] Update the ticker's own ESTIMATE comment block (:385-397) so its "one model call per
      session to classify it work-vs-personal" sentence states the `sessionClassifier` condition
      rather than asserting it unconditionally. *(altered: the first draft of this comment
      reused the literal string "NO_CLASSIFY=1", which collided with the Verification section's
      `grep -c 'NO_CLASSIFY=1'` count-of-1 check against `sapience-bootstrap` — rephrased to
      "NO_CLASSIFY exported" to drop the collision; confirmed by rebuilding and re-grepping, now
      exactly 1 per target)*
- [x] Run `nix fmt` (or `nix develop --command nixfmt`) on the changed file before verifying, so
      the `nixfmt` check cannot fail on formatting alone.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: the four `NO_MEMFILES` export sites are `modules/home/services/sapience.nix`
lines 88, 177, 362 and 1229 — re-derived in the plan dispatch by
`grep -n 'NO_MEMFILES' modules/home/services/sapience.nix`, not carried from the research
report. Confirm with that same grep before editing; if the line numbers have moved, the grep's
output is authoritative and the count (4) is the claim to check.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this path (measured
in the plan dispatch via `bash .claude/scripts/verify-touched.sh modules/home/services/sapience.nix`,
which fell back to the full battery), so per plan-format.md sub-case (c) the covering checks are
`nix flake check` — whose `home-eval` output evaluates the standalone home generation end to end,
which is exactly this edit's blast radius — plus
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 4 /home/benjamin/.dotfiles` for the
one agent-system gate that is live in a deploy-consumer tree.

**Files to modify**:
- `modules/home/services/sapience.nix` - new `sessionClassifier` option; four `NO_CLASSIFY=1` export sites; ticker estimate and phase-label made classifier-aware; ticker ESTIMATE comment updated

**Verification**:
- `nix flake check` is green (this runs `statix`, `deadnix`, `nixfmt --check`, `shellcheck` and
  the `home-eval` evaluation of `homeConfigurations.benjamin.activationPackage`).
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 4 /home/benjamin/.dotfiles`
  passes.
- Built-artifact evidence, which is the decisive check and does not require a switch:
  `out=$(nix build --no-link --print-out-paths .#homeConfigurations.benjamin.activationPackage)`,
  then `grep -c 'NO_CLASSIFY=1'` returns exactly 1 for each of `$out/home-path/bin/sapience`,
  `$out/home-path/bin/sf1`, `$out/home-path/bin/sapience-bootstrap`, and for the
  `sapience-sync` script store path referenced by
  `$out/home-files/.config/systemd/user/sapience-sync.service`.
- The ticker change is confirmed by reading the generated `sapience-bootstrap` script text, not
  by running it: the ticker's journal signal is the local Ollama access log, and at
  `backend = "anthropic"` no call transits this machine, so the ticker is inert here by design.

---

### Phase 2: Mirror the option into `packages/sapience-flake` at the vendor default [NOT STARTED]

**Goal**: the standalone flake carries the same option with `default = true` (vendor default),
wired through its shared wrapper library and its own sync unit, with both of `wrappers.nix`'s
other callers updated so the flake still evaluates.

**Tasks**:

- [ ] `lib/wrappers.nix`: add `sessionClassifier` to the argument set (beside `memoryFiles`,
      :21) and emit `${lib.optionalString (!sessionClassifier) "export NO_CLASSIFY=1"}` after
      each existing `NO_MEMFILES` line at :160, :262 and :427.
- [ ] `lib/wrappers.nix`: apply the same ticker treatment as Phase 1 (estimate term and
      `phase="classifying"` branch at :525), keeping the two trees' ticker bodies textually
      parallel.
- [ ] `modules/sapience.nix`: add the option beside `memoryFiles` (:179-193) with
      `default = true` and a description that states it matches the vendor default, says what
      setting it false buys (removes one model call per not-yet-extracted session per run) and
      costs (no work/personal filtering; redaction unaffected), and does **not** import this
      machine's measured hit rate as a general claim.
- [ ] `modules/sapience.nix`: add `sessionClassifier` to the `inherit (cfg)` list that feeds
      `wrappers` (:42), and add the export line to the `sapience-sync` `ExecStart` script beside
      the existing `NO_MEMFILES` line (:434).
- [ ] `flake.nix`: add `sessionClassifier = true;` to the `mkWrappers` vendor-default argument
      set (:85 area), keeping its comment's "matching ./modules/sapience.nix's own option
      defaults exactly" claim true.
- [ ] `checks/default.nix`: add `sessionClassifier = true;` to the `mkWrappers` default argument
      set (:40 area) so every check builds from the same defaults a consumer installs.
- [ ] `README.md`: add a `sessionClassifier` row to the `## Defaults` table (beside
      `memoryFiles`, :243).
- [ ] Do **not** edit any help-text line. The four `checks/golden/help-*.txt` files are derived
      from that text and are compared by the `help-output` check inside this phase's own gate; if
      a help line changes for any reason, regenerate those golden files in this same phase
      rather than deferring.
- [ ] Run `nix fmt` over the changed `.nix` files before verifying.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Scope Hypothesis**: this phase's declared file set is exactly the five files above plus the
README — re-derived in the plan dispatch by
`grep -rn 'NO_MEMFILES\|memoryFiles' packages/sapience-flake/`, which reports
`modules/sapience.nix:42,179,185,434`, `lib/wrappers.nix:21,160,262,427`,
`checks/default.nix:40`, `README.md:243`, plus `flake.nix:85` found by reading `mkWrappers`.
`atomic-batch` is declared because adding an argument to `wrappers.nix` without updating both of
its other callers in the same commit fails evaluation outright — the intermediate per-file states
are expected red. No help-text line is edited, so no `checks/golden/help-*.txt` file moves;
confirm that with the `help-output` check inside this phase's gate.

**Tier Justification**: `nix flake check -L ./packages/sapience-flake` runs this tree's own
`hm-module`, `help-output`, `shellcheck`, `token-functions`, `wsl-probe` and `register-mcp`
checks against generated wrappers built from these exact defaults, which is the complete set of
checks that observe this edit's blast radius inside that flake.

**Files to modify**:
- `packages/sapience-flake/lib/wrappers.nix` - new `sessionClassifier` argument; three `NO_CLASSIFY=1` export sites; ticker estimate and phase-label made classifier-aware
- `packages/sapience-flake/modules/sapience.nix` - new option with `default = true`; added to the `inherit (cfg)` wrapper argument list; export line in the sync unit script
- `packages/sapience-flake/flake.nix` - `sessionClassifier = true;` in the `mkWrappers` vendor-default argument set
- `packages/sapience-flake/checks/default.nix` - `sessionClassifier = true;` in the checks' `mkWrappers` default argument set
- `packages/sapience-flake/README.md` - new row in the `## Defaults` table

**Verification**:
- `nix flake check -L ./packages/sapience-flake` is green, including the `help-output` check
  (which is what proves no golden file drifted).
- `nix flake check` at the repo root is still green: its `statix`, `deadnix` and `nixfmt` checks
  read every `.nix` file in the repo, this subtree included.
- `nix build --no-link --print-out-paths ./packages/sapience-flake#sapience` followed by
  `grep -c 'NO_CLASSIFY' <result>/bin/sapience` returns 0 — the standalone output set defaults
  the classifier **on**, so the absence of the export is the correct result and is what
  distinguishes this tree's default from Phase 1's.
- `grep -n 'sessionClassifier' packages/sapience-flake/lib/wrappers.nix packages/sapience-flake/modules/sapience.nix packages/sapience-flake/flake.nix packages/sapience-flake/checks/default.nix`
  shows the argument threaded through all four files.

---

### Phase 3: Record the measured cost shape in `docs/sapience.md` [NOT STARTED]

**Goal**: `docs/sapience.md` states the classifier's measured per-pass cost as settled fact,
documents the new option and its default, and no longer claims the backlog drains.

**Tasks**:

- [ ] Re-run `sapience coverage` (free: it makes no model call and no provider request — it only
      stats files on disk and consults the already-cached `source_skip` rules) and use its own
      fresh `would ingest now` reading as the backlog figure this section cites, with the date.
- [ ] Rewrite `### Cost shape` (`docs/sapience.md:465-471`) to state: the classifier is the
      dominant per-pass cost (roughly the first 20 minutes of a measured 29-minute,
      network-bound pass that extracted 71 sources and staged 1208 knowledge objects against
      3.5s of CPU); the classify-eligible backlog holds steady in the low hundreds rather than
      draining (two clean before/after pairs held exactly flat, and the fresh reading above
      confirms it again); no $/token or per-pass dollar figure is obtainable from this client's
      own output, confirmed across `sapience stats`, `sapience coverage` and the systemd journal,
      so wall clock is the only cost signal; and `programs.sapience.sessionClassifier = false` is
      the default here, with `= true` named as the one-line way back.
- [ ] Correct the `**The classifier re-runs across the whole backlog.**` bullet under
      `### Performance and failure modes` (`docs/sapience.md:511-515`): drop the "while a backlog
      exists" / "until it drains" framing, which the measurement falsifies, and point at the new
      option instead of at the bare `NO_CLASSIFY=1` env var.
- [ ] Add a `programs.sapience.sessionClassifier` row to the `## How this machine is configured`
      table (:22-32) and to the `## Module options` table (:767-780), the latter linking to the
      new design-decision section below in the same style as the `memoryFiles` row.
- [ ] Add a `### The work/personal classifier is off` design-decision section, modelled on
      `### Memory-file ingestion is off` (:567-581) and placed after
      `### The source store goes in by name` ends and before `### One bootstrap at a time, and
      never during a switch` (:637): what the filter does, what it measurably caught here (one
      skip in the whole recorded series), what it cost (the dominant share of every run,
      permanently, because the backlog does not drain), that redaction is unaffected, and what
      would make this default wrong (a captured folder with a different content profile).
- [ ] Add one sentence to `## Where your data goes` (:363-401) stating that no work/personal
      filter is applied under this configuration and that redaction is therefore the whole
      guarantee — the section currently never mentions the filter in either direction.
- [ ] Add one sentence to `### Watching a run`'s "The phase word explains the rate" paragraph
      (:316-321) noting that with the classifier off there is no classify phase, so the ticker
      goes straight to `extracting` — consistent with the Phase 1 ticker change.
- [ ] Re-read the rendered section anchors used by any link added here, so no new
      `[above](#...)` link points at a heading that does not exist.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: two classes of figure land in this phase. (a) CARRIED-UNVERIFIED, source
named: 29 min wall clock / 3.5s CPU / 71 sources / 1208 objects / "roughly the first 20 minutes",
all from this task's own description, which took them from
`specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/01_coverage-pass-ledger.md`
Pass 1; re-deriving them would require a new paid extraction pass, which is a Non-Goal, so they
are written as the measured series' figures with that attribution rather than as fresh ones.
(b) Re-derived in this phase: the backlog count, from the phase's own `sapience coverage` run
(the research report read 136 on 2026-11-18, itself materially unchanged from 134 five days
earlier — cite the phase's own fresh number, not either of those).

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for `docs/sapience.md`
(measured in the plan dispatch), and it is a deploy-consumer-tree, non-`specs/**` markdown file,
so per plan-format.md sub-case (c) the covering check is
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 4 /home/benjamin/.dotfiles`
alongside the `prose` row's own diff read-through.

**Files to modify**:
- `docs/sapience.md` - `### Cost shape` rewritten with the measurement; `### Performance and failure modes` backlog bullet corrected; new `sessionClassifier` rows in the two option tables; new `### The work/personal classifier is off` design-decision section; one sentence each in `## Where your data goes` and `### Watching a run`

**Verification**:
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 4 /home/benjamin/.dotfiles`
  passes (this is the task-reference lint; `docs/**` is not exempt from it).
- Diff read-through confirming every changed hunk is prose, and that no claim in the new text
  contradicts the measurement it cites.
- `grep -n 'until it drains\|while a backlog exists' docs/sapience.md` returns no hit that still
  asserts the backlog self-drains.
- `grep -n 'sessionClassifier' docs/sapience.md` shows the option in both tables and in the new
  design-decision section.
- Every `#`-anchor link added or touched resolves to a heading present in the file.

---

### Phase 4: Full gate, applied configuration, and cost record [NOT STARTED]

**Goal**: the complete gate set is green against the recorded baseline, the change is applied to
the live generation, and the per-pass cost measurement is on record.

**Tasks**:

- [ ] `nix flake check` at the repo root (no `--skip` of any kind).
- [ ] `nix flake check -L ./packages/sapience-flake`.
- [ ] `bash packages/sapience-flake/tests/install-test.sh` — the stubbed-vendor home-manager
      activation that CI runs for that subtree.
- [ ] `bash .claude/scripts/verify-deploy.sh /home/benjamin/.dotfiles` — the complete gate set
      for this repository, every gate, no `--skip-slow` and no `--only-gate`. Compare gate 8's
      failing-suite list against the 13 names recorded in Decisions item 4: an identical list is
      the expected result and is not a regression, because this task touches no `.sh` file. A
      departure from that list is a regression and blocks this phase.
- [ ] Apply the change: `home-manager switch --flake .#benjamin` (the standalone path this
      machine's profile actually uses; `scripts/update.sh` is the equivalent fuller route). If it
      fails for a cause unrelated to this change — a sops secret, a concurrent writer, a vendor
      payload state — record it as a Reasoned Exclusion under this phase, leave the code change
      in place, and note that the next `scripts/update.sh` applies it. The built-artifact
      evidence from Phase 1 stands independently of the switch.
- [ ] Confirm the applied result: `grep -c 'NO_CLASSIFY=1' "$(command -v sapience)"` returns 1,
      and `systemctl --user cat sapience-sync.service` shows the export in its `ExecStart`
      script.
- [ ] Re-run `sapience coverage` once after the switch and record the reading, so the next task
      touching this area has a dated post-change datum rather than only a pre-change one.
- [ ] Confirm the three `issues.jsonl` entries for this task carry the run's own issues and wins,
      per the dispatch's Issue Log contract.

**Timing**: 45 minutes

**Depends on**: 2, 3

**Verification Tier**: full

**Scope Hypothesis**: the gate-8 failing-suite baseline is the 13 suites enumerated in Decisions
item 4, measured in the plan dispatch on 2026-11-18 via
`bash .claude/scripts/verify-touched.sh modules/home/services/sapience.nix docs/sapience.md`
(`73 passed, 13 failed (0 expected, 13 NEW), 0 skipped, 86 total`). Confirm by comparing this
phase's own gate-8 output against that list; a suite that newly fails, or a listed suite that now
passes, are both findings worth recording rather than silently absorbing.

**Files to modify**:
- `specs/139_reduce_sapience_classifier_cost/summaries/01_reduce-classifier-cost-summary.md` - completion summary recording the applied change, the gate results against the recorded baseline, and the post-change `sapience coverage` reading

**Verification**:
- The complete gate set: `bash .claude/scripts/verify-deploy.sh /home/benjamin/.dotfiles` run
  with no narrowing flag, its gate-8 failing list matching the recorded 13-suite baseline
  exactly; plus `nix flake check`, `nix flake check -L ./packages/sapience-flake`, and
  `bash packages/sapience-flake/tests/install-test.sh`, all green.
- `grep -c 'NO_CLASSIFY=1' "$(command -v sapience)"` returns 1 after the switch.
- `systemctl --user cat sapience-sync.service` shows `export NO_CLASSIFY=1` in its script.
- `docs/sapience.md`'s `### Cost shape` section carries a dated measurement and no open question.

## Testing & Validation

- [ ] `nix flake check` green at the repo root (statix, deadnix, nixfmt, shellcheck, home-eval).
- [ ] `nix flake check -L ./packages/sapience-flake` green, `help-output` check included.
- [ ] `bash packages/sapience-flake/tests/install-test.sh` green.
- [ ] `bash .claude/scripts/verify-deploy.sh /home/benjamin/.dotfiles` complete gate set, gate-8
      failures matching the recorded 13-suite baseline and no other failure.
- [ ] Exactly one `NO_CLASSIFY=1` export in each of the four dotfiles-generated artifacts
      (`sapience`, `sf1`, `sapience-bootstrap`, the `sapience-sync` script).
- [ ] Zero `NO_CLASSIFY` exports in the standalone flake's default `packages.<system>.sapience`
      output (its default keeps the classifier on).
- [ ] `docs/sapience.md` carries the measurement, both option-table rows, and the new
      design-decision section, with no surviving "until it drains" claim.

## Artifacts & Outputs

- `modules/home/services/sapience.nix` — `programs.sapience.sessionClassifier` (default
  `false`), four export sites, classifier-aware ticker.
- `packages/sapience-flake/{lib/wrappers.nix,modules/sapience.nix,flake.nix,checks/default.nix,README.md}`
  — the same option at the vendor default (`true`).
- `docs/sapience.md` — `### Cost shape` measurement record, corrected backlog bullet, two option
  table rows, new `### The work/personal classifier is off` section, two clarifying sentences.
- `specs/139_reduce_sapience_classifier_cost/summaries/01_reduce-classifier-cost-summary.md` —
  completion summary.

## Rollback/Contingency

Every change here is additive text in tracked files, so reverting is `git revert` of the phase
commits — no snapshot-then-rollback recipe is needed, and no step in this plan discards
uncommitted work.

Behaviourally, the live effect reverts in one line: set `programs.sapience.sessionClassifier =
true;` in `home.nix` and run `home-manager switch --flake .#benjamin`, which restores the vendor
classifier exactly as it behaves today. If the applied generation itself is the problem,
`home-manager generations` lists the prior generation and its `activate` script restores it.

If a phase's gate goes red for a cause this plan did not anticipate, fix forward on the source
rather than reaching for a destructive git operation — see `context/contracts/recovery.md` for
the recovery ladder, whose rollback rung is the only sanctioned path to a working-tree revert and
carries its own snapshot invocation shape.

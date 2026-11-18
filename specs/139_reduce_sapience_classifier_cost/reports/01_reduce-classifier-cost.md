# Research Report: Reduce or Accept the Sapience Extraction Classifier Cost

**Task**: Reduce or accept the Sapience extraction classifier cost now that extraction is metered
**Started**: 2026-11-18T23:13:53Z
**Completed**: 2026-11-18T23:45:00Z
**Effort**: ~30 minutes (code reading, live `sapience coverage` probe, prior-task ledger analysis; no extraction pass run)
**Dependencies**: None blocking this report; builds directly on `evaluate_sapience_coverage_and_tune_extraction_scope`'s closed measurement series
**Sources/Inputs**:
- `docs/sapience.md` (`## Cost shape`, `## Performance and failure modes`, `## Known gaps` sections)
- `~/.sapience/extract_local.py` (vendor payload, live on this machine): `is_personal()` (:1625-1636), the classify-then-chunk loop (:2173-2334), `--coverage` (:979-1046)
- `~/.sapience/upload.py`: `source_skip()` / `SRC_CACHE` verdict-cache implementation (:77-119)
- `modules/home/services/sapience.nix` (this repo's live home-manager module): `sapienceCli`, `sapienceBootstrap`, `sapience-sync.service` wrapper bodies; `memoryFiles`/`NO_MEMFILES` option (:746-759, wired at :88, :177, :362, :1229)
- `packages/sapience-flake/{modules/sapience.nix,lib/wrappers.nix}` (standalone, independently-maintained reusable package export)
- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/01_coverage-pass-ledger.md` and `.../records/03_extraction-scope-decision.md` (closed measurement series this task was deferred from)
- Live probe: `sapience coverage` run in this session (read-only, no model call; see Findings)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The classifier is the dominant recurring cost: on the one fully-instrumented pass
  (CARRIED-UNVERIFIED, task description), it consumed roughly 20 of a 29-minute wall-clock run
  before chunk extraction began at all, even though the backlog it reclassifies is small in
  absolute count (134-136 sessions).
- That backlog is **not self-draining**. `evaluate_sapience_coverage_and_tune_extraction_scope`'s
  closed series found `would ingest now` held exactly flat (118 -> 118, then 134 -> 134) across
  both of its clean before/after passes, and a fresh `sapience coverage` run in this session reads
  136 today -- confirming the classify tax recurs every run indefinitely, not just while a
  one-time backlog drains.
- Across the entire measured corpus (3 real extraction passes, 71+ sources classified), the
  work/personal classifier fired exactly **once** (`(skipped a personal session)`, Pass 1). On
  this machine's actual captured folders (dotfiles/nvim/app/abood -- dev and research work), the
  filter's measured hit rate is near zero.
- `NO_CLASSIFY=1` is already a supported vendor environment variable
  (`extract_local.py:168`), unwired in this module today, and the module already has an exact
  precedent for wiring exactly this shape of toggle: `programs.sapience.memoryFiles` /
  `NO_MEMFILES=1`, exported at the same three invocation sites a classify toggle would need.
- Caching classifier verdicts the way `source_skip()` caches `source_rules.json` entries would
  require patching vendor code inside `~/.sapience/extract_local.py` -- code this module's own
  header comment designates "deliberately mutable state" that `sapience update`'s daily
  auto-update (`sapience_upkeep.py`) can silently overwrite, undoing a hand-patch within a day
  with no warning. This is assessed as the wrong lever (see Decisions).
- Recommendation: wire `NO_CLASSIFY=1` as a new, default-on cost-reduction toggle (new option,
  default value flips the vendor default given this machine's measured near-zero hit rate), and
  update `docs/sapience.md`'s `## Cost shape` section with the measurements this report and the
  prior task's series already established, rather than re-measuring a $/token figure that is
  confirmed unobtainable from the client's own output.

## Context & Scope

Task scope, verbatim from the description: weigh three levers for the Sapience extraction
classifier's recurring cost on the now-metered `anthropic` backend -- `NO_CLASSIFY=1`, caching
classifier verdicts across runs the way `source_skip` verdicts are cached, or accepting the cost
and documenting it -- and implement whichever is right, recording the per-pass cost measurement
in `docs/sapience.md`'s `## Cost shape` section.

This is a **research-only dispatch**; the task's own "implement" instruction is scoped to a later
plan/implement phase. This report is the recommendation and evidence that phase consumes, not the
code change itself.

In scope: evidence already in hand (this machine's own git history, the vendor payload's actual
code, and `evaluate_sapience_coverage_and_tune_extraction_scope`'s closed measurement series) plus
one fresh, free, read-only probe (`sapience coverage`, which performs no model call -- see
Findings). Explicitly out of scope: running a new paid extraction pass to re-measure wall clock
(the prior task's three-pass series already measured this, and a fourth near-spaced pass would be
exactly the destroyed-rather-than-delayed datum that series' own method warned against); auto
behind-the-scenes code changes.

## Findings

### The classifier is the dominant recurring cost, and the backlog it reclassifies is not shrinking

The task description states (CARRIED-UNVERIFIED, task description, not re-measured in this
session): a measured pass took 29 minutes wall clock against 3.5s CPU (entirely network-bound) to
extract 71 sources and stage 1208 knowledge objects, with the classifier phase accounting for
roughly the first 20 minutes before chunk extraction began. This matches
`docs/sapience.md`'s existing `## Performance and failure modes` section, which already documents
the same two-phase shape (classify at `max_tokens=6`, tenths of a second each per the ticker's own
in-code comment at `modules/home/services/sapience.nix:451`; chunk extraction at `max_tokens=8000`,
seconds each) and the first 71-source pass exactly matches Pass 1 of
`evaluate_sapience_coverage_and_tune_extraction_scope`'s ledger (`records/01_coverage-pass-ledger.md`,
Pass 1 block: 29min 4.283s wall clock, 50 chunks, 1208 objects staged, 71 sources).

Critically, `evaluate_sapience_coverage_and_tune_extraction_scope`'s closed series re-derived
(not carried) that the classify-eligible backlog does not drain with use:
`would ingest now` held **exactly flat** across both of its clean before/after pairs (Pass 2:
118 -> 118; Pass 3: 134 -> 134 -- `evaluate_sapience_coverage_and_tune_extraction_scope`'s record
03, Cost Dimension / Drain Question sections). This session re-derived a fresh reading directly:

```
$ sapience coverage
  would ingest now:          136
  skipped (headless/agent):    45
  skipped (subagent / harness-started transcripts): 1402
  skipped (folder not chosen): 216
```

136 today, essentially unchanged from the prior task's last reading of 134 five days earlier.
Because `extract_local.py`'s sync loop classifies every file not yet marked `done` (`_session_done`,
:2152-2156) before any chunk work happens, and marks a file done only once its extraction delta is
fully consumed (gated by the 50-chunk `MAX_CHUNKS` cap, which does not scale with backlog size),
the classifier re-runs across the full ~136-session backlog on every pass, indefinitely, not just
while a one-time backlog drains. This is a **persistent, not transient**, per-pass cost -- a
stronger case for a code-level reduction than this task's own description already implies.

**`sapience coverage` performs no model call and no network request to the extraction provider**
(confirmed by reading `coverage()`, `extract_local.py:979-1046`: it only stats files on disk,
consults the already-cached `source_skip()` path-pattern rule, and a `_interactive()` turn-count
check -- never `is_personal()`). The 136 reading above cost nothing and is safe to re-run anytime.

### The classifier's measured hit rate on this corpus is near zero

Across the three real extraction passes the prior task recorded (Pass 1: 71 sources; Pass 2 and
Pass 3: additional sources at the same ~50-chunk cap), the journal shows exactly **one**
`(skipped a personal session)` line in the entire series (Pass 1, 11:58:16 --
`evaluate_sapience_coverage_and_tune_extraction_scope`'s record 01, Pass 1 block,
"`extract error:` lines" subsection). No other occurrence appears anywhere else in that ledger.
The four captured folders are `nvim`, `dotfiles`, `app` (this machine's own agent-system source
store, a Philosophy papers project, and a side project), and `abood` -- development, writing, and
research work, not a general personal-chat surface. On the measured evidence, the filter this
task is weighing the cost of removing has essentially nothing to show for its cost on this
specific corpus.

### `NO_CLASSIFY=1` is a supported, unwired vendor switch with an exact precedent already in the module

`extract_local.py:168` reads `CLASSIFY = os.environ.get('NO_CLASSIFY', '') != '1'`, consulted only
by `is_personal()` (:1625-1636), which returns `False` immediately when `CLASSIFY` is falsy --
skipping the classify call entirely rather than merely ignoring its verdict. Setting
`NO_CLASSIFY=1` therefore removes the classify API call outright (not just its filtering effect),
which is what collapses the ~20-minute classify phase.

This module already wires an **identically-shaped** vendor environment-variable toggle:
`programs.sapience.memoryFiles` (`modules/home/services/sapience.nix:746-759`), which when `false`
exports `NO_MEMFILES=1` at exactly three invocation sites -- the `sapienceCli` wrapper (:88), the
`sf1Cli` wrapper (:177, where it is a no-op but kept for parity), and `sapienceBootstrap`'s own
extraction call (:362) -- plus a fourth site in the `sapience-sync.service` unit's `ExecStart`
script (:1229). A `NO_CLASSIFY` toggle is the same shape of change: a new boolean
`programs.sapience.*` option, `lib.optionalString (!cfg.<option>) "export NO_CLASSIFY=1"` at the
same four sites (`sf1.py` never calls `is_personal()`, so that site is a documented no-op exactly
as `NO_MEMFILES` already is there).

Redaction is unaffected either way: `is_personal()` only gates *whether a session's text is sent
to the classifier model*; `extract_local.py:2264`'s redaction pass (quoted in `docs/sapience.md`'s
"Where your data goes" section) runs unconditionally on every chunk regardless of `CLASSIFY`, so
`NO_CLASSIFY=1` does not weaken redaction.

### Caching classifier verdicts like `source_skip()` is a different shape of problem than it first appears

`upload.py:77-119` implements the existing cache this task's description points to:
`source_skip(fp)` keys a dict by absolute path, validates a cached entry by file size (for the
`''`/`'subagent'` verdicts, which are permanent; `'harness-started'` is a third, re-checked verdict
not relevant here), and persists to `~/.sapience/source_rules.json`, loaded lazily and saved once
at `source_cache_save()`. This is read-only infrastructure as far as `extract_local.py` is
concerned -- it never calls `is_personal()` from inside this cache, and `is_personal()` has no
cache of its own anywhere in the payload.

Implementing an analogous cache for classify verdicts would require **patching
`~/.sapience/extract_local.py` itself** (adding a read/write to `source_rules.json` or a sibling
state file around `is_personal()`'s call site, :2200) -- not a Nix-module-level change like the
`NO_MEMFILES`/`NO_CLASSIFY` env-var pattern above. This module's own header comment
(`modules/home/services/sapience.nix:4-6`) states the payload is "deliberately mutable state that
activation seeds only when absent" because "upstream has no releases, tags or content hashes" and
"self-updates in the background." `sapience_upkeep.py`'s `auto_update()`, invoked once a day from
`client_upkeep()` (`upload.py:150-161`) whenever a token exists, refetches the vendor's `CLIENT_FILES`
tuple (which includes `extract_local.py`) and silently overwrites it. A hand-patch (or an
activation-script `sed` reapplied on every `home-manager switch`, coupled to exact vendor line
content) would be undone by the next self-update within at most a day, with no error or warning
surfaced anywhere -- the module's own health-check recipes (`docs/sapience.md`'s `## Inspection
recipes`) have no probe for "is my patch still present." This is a materially more fragile lever
than the env-var toggle above, for a problem (a persistent but modest ~136-session reclassify)
that the env-var toggle already solves completely.

A lighter-weight variant -- caching only within a single run, i.e. a module-level wrapper that
pre-filters the file list before invoking `extract_local.py` -- is not available either: the
classify-vs-skip decision happens deep inside `extract_local.py`'s own `sync()` loop
(:2173-2217), using its own session-done ledger and per-session delta text; nothing in the wrapper
layer (`modules/home/services/sapience.nix`) has visibility into which files that invocation will
classify before it runs.

### A second, independently-maintained copy of this module exists and would also need updating

`packages/sapience-flake/{modules/sapience.nix,lib/wrappers.nix}` is a standalone,
reusable flake-module export of a simplified version of this same Sapience wrapper (its own header
comment: "one set of script bodies backs both `../modules/sapience.nix`'s `homeManagerModules.sapience`
and this flake's standalone `packages.<system>.*` outputs"). It independently duplicates the same
`memoryFiles`/`NO_MEMFILES` option and wiring (`packages/sapience-flake/modules/sapience.nix:179-194`,
wired at `lib/wrappers.nix` and at `modules/sapience.nix:434`) but is a hand-maintained parallel
copy, not generated from `modules/home/services/sapience.nix` -- it lacks several of this repo's
options entirely (`sourceDirs`, `desktopEntry`, `terminal`, `webAppCommand`). A complete
`NO_CLASSIFY` implementation that wants the two to stay consistent would need the equivalent
change in both trees; whether that is in scope for this task's implement phase, or deferred as a
documented follow-up (as this module's own `memoryFiles` precedent appears to have been wired in
both already, suggesting the convention is to keep them in sync), is a planning decision this
report surfaces rather than makes.

### No per-pass dollar or token cost figure is obtainable, confirmed again

`evaluate_sapience_coverage_and_tune_extraction_scope`'s record 01 states this was checked at
three separate points in that series (`sapience stats`, `sapience coverage`, and the systemd
journal) and none exposes a $/token figure -- only wall clock and CPU time
(`Consumed 3.461s CPU time over 29min 4.283s wall clock time`, Pass 1). This session did not
re-attempt that check (it would require a new paid pass to produce a journal entry, out of scope
per Context & Scope above) and treats it as already-settled: wall clock is the only cost signal
this client exposes, and 20 of ~29-48 minutes measured being classify time is the figure
`docs/sapience.md`'s `## Cost shape` section should carry forward.

## Decisions

1. **The classifier's per-pass cost is real, persistent (not self-draining), and concentrated**:
   confirmed by a fresh, free `sapience coverage` reading in this session (136, materially
   unchanged from the prior task's 134) layered onto that task's own re-derived finding that the
   eligible backlog does not shrink between passes.
2. **Verdict caching inside `source_rules.json` is rejected as the lever to implement.** It
   requires patching vendor payload code this module's own design explicitly treats as
   self-updating, mutable state outside Nix's control -- a fragile coupling that `sapience
   update`'s daily auto-update can silently undo, for a problem the env-var toggle already solves
   without touching vendor code at all.
3. **`NO_CLASSIFY=1`, wired as a new `programs.sapience.*` boolean option mirroring the
   `memoryFiles`/`NO_MEMFILES` precedent, is the recommended lever.** The measured marginal
   privacy cost on this specific corpus is one skip event in the entire recorded series; the
   measured benefit is removing the dominant share (roughly two-thirds) of a recurring, persistent
   per-pass wall-clock cost, using a change shape this module already has three working examples
   of.
4. **"Accept and document" is not recommended as the sole outcome**, because a low-risk,
   already-precedented fix exists and the cost it would otherwise leave unaddressed was just
   confirmed persistent rather than self-resolving by this session's own fresh measurement.
   `docs/sapience.md`'s `## Cost shape` section should still be updated regardless of which lever
   is implemented, per the task's explicit instruction -- documenting the measured shape of the
   cost is not an alternative to fixing it, it is a required part of either outcome.

## Recommendations

1. **Add `programs.sapience.classifyPersonal` (or an equivalently named boolean option)** to
   `modules/home/services/sapience.nix`, `type = lib.types.bool`, default `false` (flips the
   vendor default, matching the `memoryFiles` precedent's own "defaults against the vendor default
   when this machine's measured usage supports it" framing at `:753-757`), with a description
   naming the measured one-skip-in-the-series hit rate and the fact that redaction still runs
   unconditionally regardless of this option.
2. **Wire it at the same four sites `memoryFiles`/`NO_MEMFILES` already uses**: `sapienceCli`
   (`:88`), `sf1Cli` (`:177`, documented no-op), `sapienceBootstrap`'s extraction call (`:362`),
   and `sapience-sync.service`'s `ExecStart` script (`:1229`) -- `lib.optionalString (!cfg.classifyPersonal)
   "export NO_CLASSIFY=1"` alongside the existing `NO_MEMFILES` line at each.
3. **Decide, at plan time, whether `packages/sapience-flake` needs the matching change** for
   consistency with its own `memoryFiles` precedent, or whether that is an explicitly deferred
   follow-up -- this report surfaces the duplication (see Findings) but does not resolve it, since
   it depends on whether that flake package is treated as a published, externally-consumed
   artifact in its own right.
4. **Update `docs/sapience.md`'s `## Cost shape` section** to state, as settled fact rather than a
   future question: the classifier is the dominant per-pass cost (roughly two-thirds of a 22-48
   minute pass, per the closed measurement series), the backlog it reclassifies holds steady
   around 130-140 sessions rather than draining, no $/token figure is obtainable from the client's
   own output (confirmed three times), and -- once implemented -- that `NO_CLASSIFY=1` is set by
   default here given the measured near-zero hit rate on this machine's captured folders, with a
   pointer to how to re-enable classification (`programs.sapience.classifyPersonal = true;`) if a
   captured folder's content profile ever changes.
5. **Do not implement verdict caching inside `~/.sapience/extract_local.py`.** If a future
   measurement shows `NO_CLASSIFY=1`'s privacy trade-off is unacceptable after all (e.g. a new
   captured folder with materially different content), the right escalation is re-enabling
   `classifyPersonal` and accepting the classify cost, not patching vendor code.

## Risks & Mitigations

- **Risk**: disabling classification could let a genuinely personal session reach Anthropic
  unfiltered (redaction still strips secret-shaped strings, but not ordinary personal prose).
  **Mitigation**: the option is scoped per this machine's own configuration and reversible with a
  one-line `home.nix` change; the measured hit rate informing the default is specific to the four
  folders actually captured here (`nvim`, `dotfiles`, `app`, `abood`), and the recommendation names
  that scope explicitly rather than presenting it as a universal vendor-default change.
- **Risk**: a future captured-folder addition (e.g. a non-technical project) could change the
  content profile this default was based on. **Mitigation**: name this explicitly in the new
  option's description and in the updated `docs/sapience.md` text, so a future `sourceDirs`/folder
  change is the trigger to revisit the default, not a silent gap.
- **Risk**: `packages/sapience-flake` drifting out of sync with `modules/home/services/sapience.nix`
  if only one tree is updated. **Mitigation**: named as an open planning decision above rather than
  silently resolved in either direction.

## Appendix

- Live probe output (this session, `sapience coverage`, no model call):
  `would ingest now: 136`; `skipped (headless/agent): 45`; `skipped (subagent / harness-started
  transcripts): 1402`; `skipped (folder not chosen): 216`; `Folders selected (4): nvim, dotfiles,
  app, abood`.
- Vendor code citations: `~/.sapience/extract_local.py:168` (`CLASSIFY` env read),
  `:1625-1636` (`is_personal()`), `:2173-2217` (classify-then-chunk loop and the
  `skip_personal` all-flagged-as-personal override), `:979-1046` (`coverage()`, confirmed no
  model call); `~/.sapience/upload.py:77-119` (`source_skip()` / `SRC_CACHE`); `:150-161`
  (`client_upkeep()` daily auto-update).
- Cross-record citation: `evaluate_sapience_coverage_and_tune_extraction_scope`'s record 03
  (`records/03_extraction-scope-decision.md`), Cost Dimension and Drain Question sections, and
  record 01 (`records/01_coverage-pass-ledger.md`), Pass 1-3 blocks.

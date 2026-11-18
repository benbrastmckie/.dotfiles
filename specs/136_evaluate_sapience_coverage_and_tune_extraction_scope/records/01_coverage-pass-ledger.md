# Sapience Coverage Measurement Ledger

Measures how much of this machine's session history Sapience actually captures under manual
extraction, across a series of hand-run passes, so that the extraction-scope decision rests on
collected numbers rather than a single reading. Every block below is a verbatim capture taken at
the stated timestamp. No figure in this ledger is carried forward from a plan, a report, or an
earlier block in this same file -- each pass re-measures fresh.

## Fixed Per-Pass Block Shape

Every pass block below (Pass 0 baseline and every numbered pass that follows) states these
fields, in this order, so later phases can tabulate across blocks without re-deriving the shape:

- **Pass number** and **ISO 8601 UTC timestamp** of the reading (or of the run, for a pass block).
- **Invocation path used** (`sapience sync`, `systemctl --user start sapience-sync.service`, or
  "journal-reconstructed" for a pass with no live before/after capture).
- **Wall clock** from `systemctl --user status` / `systemctl --user show`, when available.
- **Chunk count** attempted for the run.
- **Objects staged** by the run (and objects awaiting review after it).
- **`sapience pending`** before and after the run.
- **`Available on disk`** total and all five sub-counters (`would ingest now`; `skipped (outside
  Nd window)`; `skipped (headless/agent)`; `skipped (subagent / harness-started transcripts)`;
  `skipped (folder not chosen)`) verbatim, before and after.
- **`Per-run extraction cap`** line, verbatim.
- **`Folders selected`** line, verbatim.
- **The day's `sapience yield` line** against the 2000-objects/day cap, verbatim.
- **Every `extract error:` line** from the journal for that run, with an explicit `0 errors`
  stated when there are none.
- **Redaction / set-aside counts** (`Redacted N secret/PII value(s)`, `Set aside N transient
  rows (...)`), verbatim.

A block that cannot supply one of these fields (for example because it is reconstructed from the
journal rather than captured live) states so explicitly against that field rather than omitting
it silently.

---

## Pass 0 -- Baseline (post-138, post-Pass-1)

**Pass number**: 0 (baseline reading; not an extraction run)
**ISO 8601 UTC timestamp**: 2026-11-13T21:07:34Z
**Invocation path used**: N/A (read-only `sapience coverage` / `sapience pending`)

### Backend wiring -- three independent confirmations

1. `jq -c '{backend, model, api_key_env}' ~/.sapience/config.json` →
   `{"backend":"anthropic","model":null,"api_key_env":"ANTHROPIC_API_KEY"}`
2. The sync unit's `ExecStart` (`systemctl --user cat sapience-sync.service`) resolves to
   `/nix/store/qc34qy2m0g978zlqisblv4lghzajyf4p-sapience-sync`, whose script body (read directly)
   invokes:
   ```
   python3 extract_local.py --sync --yes --backend "anthropic" --model "claude-haiku-4-5"
   ```
3. `sapience coverage`'s own header: `Window: last 30 days   Backend: anthropic`

All three agree: the live backend is `anthropic`, and the systemd unit's model is the
floating alias `claude-haiku-4-5` (as set by `home.nix`'s `programs.sapience.model`).

### Model-mismatch residue (live, unresolved, not changed by this phase)

`~/.sapience/config.json` carries `"model": null`. `home.nix` sets
`programs.sapience.model = "claude-haiku-4-5"`, and that value is what the systemd unit passes
via `--model` (confirmation 2 above), so **the unit is unaffected by the `null` in config.json**.

The bare CLI (`sapience sync`, `sapience coverage`, `sapience pending`, ...) is a different story:
reading the `sapience` wrapper script directly shows it execs `extract_local.py --sync --yes
"$@"` with **no `--backend`/`--model` flags passed at all** for any subcommand. Reading
`extract_local.py` (lines ~184-189) shows the bare-CLI fallback logic:

```python
BACKEND = _arg('--backend', None)
if BACKEND is None:
    BACKEND = ((up._load(up.CONF, {}) or {}).get('backend')) or 'ollama'
MODEL   = _arg('--model', {'ollama': 'llama3.1', 'anthropic': 'claude-haiku-4-5-20251001',
                           'openai': 'gpt-4o-mini', 'relay': 'hosted'}.get(BACKEND, 'llama3.1'))
```

So a bare-CLI pass resolves `BACKEND` from `config.json` (`anthropic`, matching the unit) but
resolves `MODEL` from its own hardcoded per-backend default table: `claude-haiku-4-5-20251001` --
a dated snapshot identifier, distinct from the floating alias `claude-haiku-4-5` the unit passes
explicitly. `home.nix`'s own comment at the `model` option states "The client's own per-backend
default for anthropic is this same model" -- true as of this reading (the alias and the
2025-10-01 dated snapshot currently point at the same release), but the two are different literal
model strings sent to the Anthropic API, and the alias can move to a newer snapshot independently
of the dated one without `home.nix` changing. **This makes a bare-CLI pass and a unit pass
potentially non-comparable in the future**, though they are not known to differ today. Series
passes in this task use the unit (`systemctl --user start sapience-sync.service`) exclusively, so
this residue does not affect this task's own readings, but is recorded here because the plan's
Scope Hypothesis for this phase named it as a required observation.

### Coverage reading (verbatim, `sapience coverage`)

```
==================================================================
Sapience coverage
==================================================================
Window: last 30 days   Backend: anthropic
Per-run extraction cap: 50 chunks (MAX_CHUNKS); backfill raises it so a wide window isn't truncated.
Folders selected (4): nvim, dotfiles, app, abood
------------------------------------------------------------------
Ingested: 36 session files across 4 repos
    BimodalLogic, PossibleWorlds, dotfiles, nvim
------------------------------------------------------------------
Curated memory files (CLAUDE.md / MEMORY.md / AGENTS.md / dumps): 0 ingested first each run
------------------------------------------------------------------
Available on disk: 1157 session files
  would ingest now:          78
  skipped (outside 30d window): 0
  skipped (headless/agent):    30   (add --include-agents to keep them)
  skipped (subagent / harness-started transcripts): 904   (thread mechanics; never read)
  daily extraction cap: 2000 objects/day (sapience yield: 1211 objects today (cap 2000), 100 chunks in 2 runs; top sources: -home-benjamin--dotfiles/2e4da16e-c8fc-4453-a9bb- (2 chunks), -home-benjamin--config-nvim/f20a6129-926e-4619-8cca- (2 chunks), -home-benjamin--config-nvim/3fc7d32e-0fce-4a6a-b9a4- (2 chunks))
  skipped (folder not chosen): 145
------------------------------------------------------------------
Widen the window:    sapience backfill 365
Include agent runs:  add --include-agents  (or set SAPIENCE_INCLUDE_HEADLESS=1)
==================================================================
```

**`sapience pending`**: `1208`

**Summation check**: `would ingest now` (78) + `skipped (outside 30d window)` (0) +
`skipped (headless/agent)` (30) + `skipped (subagent / harness-started)` (904) +
`skipped (folder not chosen)` (145) = **1157**, matching the stated `Available on disk: 1157`
exactly. No remainder.

**Note on the `sapience yield` line's two counts**: the line reports `1211 objects today` but the
most recent run (Pass 1, below) staged `1208` objects, and `sapience pending` also reads `1208`.
The 3-object discrepancy between the cumulative "yield" counter (1211) and both the staged count
and the pending count (1208 each) is recorded verbatim rather than reconciled; no explanation for
it is available from the coverage/pending output alone, and reconciling it is out of this task's
scope.

**This reading is taken AFTER Pass 1 (below) already ran**, so it is the "current state" baseline
against which Pass 2 (phase 2) will measure its own before/after delta -- it is not a pre-Pass-1
snapshot. The Premise Re-Validation table in the plan recorded a similar but not identical reading
taken at plan-authoring time (`Available on disk: 1153`, `would ingest now: 74`); this reading
(1157, 78) is 4 session files larger, confirming the plan's own observation that "Available on
disk" grows between readings purely from new transcripts. The plan's table is plan-time and
superseded by this block, per the next section.

### `reports/02_baseline-and-extraction-backend-blocked.md` -- figures superseded, not usable

That report measured every one of 50 chunk-extraction calls failing with `HTTP Error 402: Payment
Required` against the `ollama` backend (`gemma4:cloud`), staging 0 objects, and recorded a
blocking `user_decision` on Ollama billing. Commit `2b713bf` ("sapience: move extraction to the
anthropic backend") resolved that blocker by a route the report's own four options did not name:
switching `programs.sapience.backend` to `"anthropic"`. Every coverage/pending/yield figure in
that report (`Available on disk: 1133`, `would ingest now: 74`, `pending: 0`, `0 objects staged`,
`16.677s` wall clock) characterizes the pre-migration, all-failing backend and **must not be
carried forward into this task's measurement**. This ledger's Pass 0 and Pass 1 blocks are the
first post-migration readings and are the correct baseline going forward.

---

## Pass 1 -- Journal-Reconstructed (first successful anthropic-backend run)

**This block is explicitly flagged as reconstructed from the journal, not captured live.** No
agent captured a before/after `sapience coverage`/`sapience pending` pair around this run -- it
ran before this task's measurement series began. It therefore supplies a **cost/duration datum**
(wall clock, chunk count, objects staged, redaction/set-aside counts, error count) but **no
drain-rate datum** (no before-reading exists to diff against an after-reading). Phase 7's series
analysis must treat it accordingly: usable for the cost/duration tabulation, excluded from any
before/after delta computation.

**Pass number**: 1
**ISO 8601 UTC timestamp**: run started 2026-11-13T11:37:47Z (per `journalctl --user -u
sapience-sync`; local system clock, timezone not re-derived -- same timestamp format the plan's
Premise Re-Validation section already used), finished 2026-11-13T12:06:52Z
**Invocation path used**: `systemctl --user start sapience-sync.service` (reconstructed from the
journal entry `Starting Sapience: extract and redact new AI session transcripts on-device...` at
11:37:47 through `Finished ...` at 12:06:52)
**Wall clock**: `29min 4.283s` (`systemd[2504]: sapience-sync.service: Consumed 3.461s CPU time
over 29min 4.283s wall clock time, 150.5M memory peak.`)
**Chunk count**: 50 (inferred from `MAX_CHUNKS` default and the coverage line "100 chunks in 2
runs" minus the 50 chunks already attributed to the earlier same-day ollama run below)
**Objects staged**: `Staged 1208 new knowledge objects locally (1208 awaiting review). Nothing was
shared.`
**`sapience pending` before / after**: before -- not captured (no reading exists); after -- `1208`
(matches the live Pass-0 reading above, confirming no further pass has run between Pass 1 and
this dispatch)
**`Available on disk` before / after**: before -- not captured; after -- not independently
captured at run time either (the first live reading after this run is the Pass-0 baseline block
above, taken 2026-11-13T21:07:34Z, roughly 9 hours after Pass 1 finished, so it is NOT treated as
Pass 1's "after" reading -- there may have been additional transcript accrual in that gap).
**`Per-run extraction cap` line**: not captured live for this run; the current line (Pass 0 above)
reads `Per-run extraction cap: 50 chunks (MAX_CHUNKS); backfill raises it so a wide window isn't
truncated.` and `MAX_CHUNKS` has not changed between the two readings.
**`Folders selected` line**: not captured live for this run; current line (Pass 0 above) reads
`Folders selected (4): nvim, dotfiles, app, abood`, unchanged since task 138's reconciliation.
**Day's `sapience yield` line**: `sapience yield: 1211 objects today (cap 2000), 100 chunks in 2
runs; top sources: -home-benjamin--dotfiles/2e4da16e-c8fc-4453-a9bb- (2 chunks),
-home-benjamin--config-nvim/f20a6129-926e-4619-8cca- (2 chunks),
-home-benjamin--config-nvim/3fc7d32e-0fce-4a6a-b9a4- (2 chunks)` -- this is the CUMULATIVE
same-day figure covering both the 08:58:51 ollama run (0 objects, 50 chunks, all failed) and this
11:37:47 anthropic run (1208 objects, 50 chunks), for a combined "100 chunks in 2 runs" today.
**`extract error:` lines**: **0 errors** in the 11:37:47-12:06:52 window (`journalctl --user -u
sapience-sync --since "2026-11-13 11:37:00" --until "2026-11-13 12:07:00"` shows no
`extract error:` line at all for this run; the one `(skipped a personal session)` line at
11:58:16 is a per-source skip notice, not an extraction error). This pass's yield IS usable as a
cost/duration datum.
**Redaction / set-aside counts**: `Redacted 1 secret/PII value on-device before staging.`;
`Set aside 6 transient rows (pid 5, dispatch 1): run/thread state, not knowledge.`
**Additional context from the journal**: `Extraction backend: anthropic (model claude-haiku-4-5,
billed to your ANTHROPIC_API_KEY)`; `sapience: skipped 6 harness-started transcripts (thread
mechanics, not knowledge; SAPIENCE_INCLUDE_HEADLESS=1 does not override this)`; `sapience capture
(opt-in): read nvim 63, .dotfiles 22; not enabled none`; `Skipping 4 sources already extracted
(results were staged/shared earlier).`; `Extracting knowledge from 71 sources (0 curated memory
files) locally ...`

### Earlier same-day run (ollama, pre-migration, all failed -- for context only)

Immediately before Pass 1, at 2026-11-13T08:58:51Z-08:59:08Z, the unit ran against the OLD
`ollama` backend configuration and every one of its 50 chunk calls failed:
`extract error: HTTP Error 402: Payment Required` (repeated 50 times), yielding `sapience yield: 0
objects today (cap 2000), 50 chunks in 1 run`, `Staged 0 new knowledge objects locally (0 awaiting
review)`. This is the live confirmation of `reports/02`'s finding and is recorded here for
completeness, not as a series pass -- it predates the `anthropic` backend migration (commit
`2b713bf`) that made Pass 1 possible, and its 0-yield is correctly attributed to total provider
failure, not to low-information content, per the plan's own risk mitigation for this failure mode.

### Cost signal availability (established once for the series to reuse)

No per-pass token or dollar-cost counter is exposed by `sapience stats`, `sapience coverage`, the
journal, or any file under `~/.sapience/` that was inspected for this pass. The journal exposes
wall clock and CPU time (`Consumed 3.461s CPU time over 29min 4.283s wall clock time`) and object
counts, but no Anthropic token usage or billed-dollar figure. **No per-pass cost signal is
obtainable from the client's own output.** Phase 7's decision must state this plainly and must not
recommend a cap increase or a scheduling change on an unmeasured cost, per the plan's own
instruction.

---

## Pass 2 -- First Fully Observed Pass (before/after pair, non-zero error count)

**24-hour spacing check**: Pass 1 finished 2026-11-13T12:06:52Z. This pass started
2026-11-17T21:00:38Z, a gap of roughly 104.9 hours (approx. 4 days 9 hours) -- well clear of the
24-hour floor.

**Pass number**: 2
**ISO 8601 UTC timestamp**: run started 2026-11-17T21:00:38Z, finished 2026-11-17T21:23:08Z
(both from `systemctl --user status` / journal; local clock recorded PST, converted to UTC)
**Invocation path used**: `systemctl --user start sapience-sync.service`
**Wall clock**: `22min 29.800s` (`systemd[2504]: sapience-sync.service: Consumed 4.349s CPU time
over 22min 29.800s wall clock time, 173.1M memory peak.`)
**Chunk count**: 50 (`sapience yield: 550 objects today (cap 2000), 50 chunks in 1 run`)
**Objects staged**: 539 (`Staged 539 new knowledge objects locally (1747 awaiting review).
Nothing was shared.`) -- 10.78 objects/chunk

### Before reading (captured immediately before `systemctl --user start`, ~2026-11-17T21:00:30Z)

```
Available on disk: 1611 session files
  would ingest now:          118
  skipped (outside 30d window): 0
  skipped (headless/agent):    40
  skipped (subagent / harness-started transcripts): 1253
  skipped (folder not chosen): 200
Per-run extraction cap: 50 chunks (MAX_CHUNKS); backfill raises it so a wide window isn't truncated.
Folders selected (4): nvim, dotfiles, app, abood
sapience yield: 0 objects today (cap 2000), 0 chunks in 0 runs; top sources: none
```
**`sapience pending` (before)**: `1208`
**Summation check (before)**: 118+0+40+1253+200 = **1611**, matches exactly.

### After reading (captured 2026-11-17T21:26Z, immediately after the unit settled to `inactive`)

```
Available on disk: 1617 session files
  would ingest now:          118
  skipped (outside 30d window): 0
  skipped (headless/agent):    40
  skipped (subagent / harness-started transcripts): 1258
  skipped (folder not chosen): 201
Per-run extraction cap: 50 chunks (MAX_CHUNKS); backfill raises it so a wide window isn't truncated.
Folders selected (4): nvim, dotfiles, app, abood
sapience yield: 550 objects today (cap 2000), 50 chunks in 1 run; top sources: -home-benjamin--dotfiles/1821076e-9267-43c1-93cf- (1 chunks), -home-benjamin--dotfiles/a4de42a5-8e50-4989-b1f6- (1 chunks), -home-benjamin--config-nvim/8c6cd67b-4454-4f78-a79d- (1 chunks)
```
**`sapience pending` (after)**: `1747`
**Summation check (after)**: 118+0+40+1258+201 = **1617**, matches exactly.

### Computed deltas

| Field | Before | After | Delta |
|---|---|---|---|
| Available on disk | 1611 | 1617 | +6 |
| would ingest now | 118 | 118 | **0** |
| skipped (headless/agent) | 40 | 40 | 0 |
| skipped (subagent/harness-started) | 1253 | 1258 | +5 |
| skipped (folder not chosen) | 200 | 201 | +1 |
| `sapience pending` | 1208 | 1747 | +539 |
| day's `sapience yield` objects | 0 | 550 | +550 |

**Headline finding: `would ingest now` did not drop at all despite a 50-chunk pass that staged
539 objects.** New session files accrued during the 22.5-minute run at a rate that exactly offset
whatever the pass consumed from the backlog -- `Available on disk` grew +6 while `would ingest
now` held flat at 118. This is the series' first direct evidence bearing on the drain question
phase 7 must answer: on this reading, one pass did not visibly shrink the "would ingest now"
backlog at all.

### `extract error:` lines -- NON-ZERO, this pass flagged per the plan's risk mitigation

**34 total `extract error:` lines** in the run window (`journalctl --user -u sapience-sync
--since "2026-11-17 13:00:30" --until "2026-11-17 13:23:10"`), breakdown by message:

| Message | Count |
|---|---|
| `<urlopen error [Errno -2] Name or service not known>` | 30 |
| `The read operation timed out` | 3 |
| `<urlopen error _ssl.c:1015: The handshake operation timed out>` | 1 |

All 34 are clustered in the final ~2 minutes of the run (13:16:33-13:23:08 PST), consistent with a
transient network/DNS outage on this machine rather than a provider billing/auth failure (contrast
the earlier all-`402`-failing ollama run, where every one of 50 calls failed identically). Unlike
that total-failure case, this run still staged 539 objects from its 50-chunk batch, so it is a
**partial** failure, not a zero-yield one. Per the plan's risk mitigation and phase 2's own
verification criterion, **this pass's yield is flagged as unusable as a clean drain-rate datum**
and must be excluded (or specially annotated) in phase 7's drain-rate tabulation rather than
averaged in with error-free passes. Recorded via `issue-record.sh` (class
`external-dependency-failure`, severity `costly`) at this dispatch.

**Redaction / set-aside counts**: No `Redacted N secret/PII value(s)` line appeared in this run's
journal window (0 secret/PII values redacted this pass, contrast Pass 1's 1). `Set aside 2
transient rows (dispatch 2): run/thread state, not knowledge.`

**Additional context from the journal**: `sapience: skipped 15 harness-started transcripts
(thread mechanics, not knowledge; SAPIENCE_INCLUDE_HEADLESS=1 does not override this)`; `sapience
capture (opt-in): read nvim 82, .dotfiles 27, sapience-app 26; not enabled none`; `Skipping 13
sources already extracted (results were staged/shared earlier).`; `Extracting knowledge from 105
sources (0 curated memory files) locally ...`; one new informational line not seen in Pass 1 --
`a cut-off reply was re-extracted as two halves (54 facts, the cut-off reply had 57)` -- a
content-handling note, not an error.

### Cost signal (re-checked, confirms Phase 1's finding unchanged)

`sapience stats` was re-run at this dispatch and still exposes no per-run token or dollar-cost
counter -- only cumulative lifetime counts (`2,818 things you know, across 72 work sessions`,
etc.) with no per-pass breakdown. The journal exposes only wall clock and CPU time, as in Pass 1.
**No per-pass cost signal is obtainable from the client's own output**, confirming Phase 1's
finding rather than superseding it; phase 7 must continue to state this plainly and must not
recommend a cap increase or scheduling change on an unmeasured cost.

---

## Pass 3 -- Second Fully Observed Pass (clean run, zero errors; first mid-series filter check)

**24-hour spacing check**: Pass 2 finished 2026-11-17T21:23:08Z. This pass started
2026-11-18T21:23:48Z, a gap of roughly 24h00m40s -- clears the 24-hour floor by 40 seconds. (The
dispatch itself arrived 16 seconds short of the floor at 2026-11-18T21:21:52Z; the implementer
waited a further ~2 minutes doing non-gated setup work, by which point the floor had cleared, so
no work was attempted before the gate was satisfied.)

**Pass number**: 3
**ISO 8601 UTC timestamp**: run started 2026-11-18T21:23:48Z, finished 2026-11-18T22:11:46Z
**Invocation path used**: `systemctl --user start sapience-sync.service`
**Wall clock**: `47min 58.532s` (`systemd[2565]: sapience-sync.service: Consumed 10.221s CPU time
over 47min 58.532s wall clock time, 217.8M memory peak.`) -- well under the 60-minute cap, but the
longest of the three fully-observed/reconstructed runs so far (Pass 1: 29min 4.283s; Pass 2:
22min 29.8s; Pass 3: 47min 58.532s).
**Chunk count**: 50 chunks in 1 run
**Objects staged**: `Staged 2010 new knowledge objects locally (3757 awaiting review). Nothing was
shared.` -- 2010/50 = 40.2 objects/chunk, the richest single-pass yield in the series so far
(Pass 1: 24.16/chunk; Pass 2: 10.78/chunk; Pass 3: 40.2/chunk).

### Before reading (captured immediately before `systemctl --user start`, 2026-11-18T21:23:35Z)

```
Available on disk: 1781 session files
  would ingest now:          134
  skipped (outside 30d window): 0
  skipped (headless/agent):    45
  skipped (subagent / harness-started transcripts): 1388
  skipped (folder not chosen): 214
Per-run extraction cap: 50 chunks (MAX_CHUNKS); backfill raises it so a wide window isn't truncated.
Folders selected (4): nvim, dotfiles, app, abood
sapience yield: 0 objects today (cap 2000), 0 chunks in 0 runs; top sources: none
```
**`sapience pending` (before)**: `1747`
**Summation check (before)**: 134+0+45+1388+214 = **1781**, matches exactly.

### After reading (captured 2026-11-18T22:12:22Z, immediately after the unit settled to `inactive`)

```
Available on disk: 1786 session files
  would ingest now:          134
  skipped (outside 30d window): 0
  skipped (headless/agent):    46
  skipped (subagent / harness-started transcripts): 1391
  skipped (folder not chosen): 215
Per-run extraction cap: 50 chunks (MAX_CHUNKS); backfill raises it so a wide window isn't truncated.
Folders selected (4): nvim, dotfiles, app, abood
sapience yield: 2051 objects today (cap 2000), 50 chunks in 1 run; top sources: -home-benjamin--dotfiles/c1e0b710-3bfe-4d71-8947- (1 chunks), -home-benjamin--dotfiles/8fde2a97-68a7-4065-8e3a- (1 chunks), -home-benjamin--config-nvim/7b2db151-7b23-4c5c-a641- (1 chunks)
```
**`sapience pending` (after)**: `3757`
**Summation check (after)**: 134+0+46+1391+215 = **1786**, matches exactly.

### Computed deltas

| Field | Before | After | Delta |
|---|---|---|---|
| Available on disk | 1781 | 1786 | +5 |
| would ingest now | 134 | 134 | **0** |
| skipped (headless/agent) | 45 | 46 | +1 |
| skipped (subagent/harness-started) | 1388 | 1391 | +3 |
| skipped (folder not chosen) | 214 | 215 | +1 |
| `sapience pending` | 1747 | 3757 | +2010 |
| day's `sapience yield` objects | 0 | 2051 | +2051 |

**Headline finding: `would ingest now` held flat a second consecutive time (134 before and
after), this time despite the pass staging 2010 objects -- the largest single-pass yield in the
series.** As in Pass 2, new session files accrued during the run at a rate that offset whatever
the pass consumed from the backlog (`Available on disk` grew +5). Two of two fully-observed
passes now show `would ingest now` unmoved by the pass itself; phase 7's drain question must
weigh this directly.

**Daily-cap finding: a single ordinary pass exceeded the stated daily cap.** The after-reading's
own `sapience yield` line reads `2051 objects today (cap 2000)` -- this one run, by itself,
pushed the cumulative daily counter past the 2000-objects/day cap, yet the run was not truncated:
it attempted and completed all 50 chunks (matching the `Per-run extraction cap` line, unchanged
at 50), and nothing in the journal (reproduced in full below) indicates an early stop, a dropped
chunk, or any cap-triggered behavior. The cap line appears to be purely informational/cumulative
bookkeeping, not an enforced ceiling that interrupts a run in progress.

### `extract error:` lines -- ZERO, this pass is usable as a clean drain-rate datum

**0 `extract error:` lines** in the run window (`journalctl --user -u sapience-sync --since
"2026-11-18 13:23:40" --until "2026-11-18 14:12:00"`, local machine time PST = UTC-8, matching the
21:23:48Z-22:11:46Z UTC run window). Unlike Pass 2's 34-error partial failure, this run completed
with no provider errors at all and is therefore fully usable in phase 7's clean drain-rate
tabulation.

**Redaction / set-aside counts**: No `Redacted N secret/PII value(s)` line appeared in this run's
journal window (0 secret/PII values redacted this pass). `Set aside 6 transient rows (pid 3,
dispatch 2, running 1): run/thread state, not knowledge.`

**Additional context from the journal**: `sapience: skipped 18 harness-started transcripts
(thread mechanics, not knowledge; SAPIENCE_INCLUDE_HEADLESS=1 does not override this)`; `sapience
capture (opt-in): read nvim 87, sapience-app 35, .dotfiles 33; not enabled none`; `Skipping 14
sources already extracted (results were staged/shared earlier).`; `Extracting knowledge from 120
sources (0 curated memory files) locally ...`; `Extraction backend: anthropic (model
claude-haiku-4-5, billed to your ANTHROPIC_API_KEY)`; one content-handling note, as in Pass 2 --
`a cut-off reply was re-extracted as two halves (46 facts, the cut-off reply had 57)`.

### Cost signal (re-checked, confirms Phase 1/2's finding unchanged)

`sapience stats` was re-run at this dispatch and still exposes no per-run token or dollar-cost
counter -- only cumulative lifetime counts (`2,971 things you know, across 73 work sessions`,
etc.) with no per-pass breakdown. The journal exposes only wall clock and CPU time, as in Passes 1
and 2. **No per-pass cost signal is obtainable from the client's own output**, confirming the
prior two findings rather than superseding them.

### Mid-series filter-ratio check (first of the plan's required checks)

**Denominator**: the ledger holds 5 individual coverage readings carrying both skip counters so
far -- Pass 0 (one reading), Pass 2 (before and after), Pass 3 (before and after). Pass 1 is
journal-reconstructed and supplies no coverage reading, so it is excluded from this count, per
the plan's own Scope Hypothesis instruction to count what is actually present rather than assume
three.

| Reading | Timestamp (UTC) | skipped (headless/agent) | skipped (subagent/harness-started) | Ratio (harness-started ÷ headless/agent) |
|---|---|---|---|---|
| Pass 0 | 2026-11-13T21:07:34Z | 30 | 904 | 30.13x |
| Pass 2 before | 2026-11-17T21:00:30Z | 40 | 1253 | 31.33x |
| Pass 2 after | 2026-11-17T21:26:00Z | 40 | 1258 | 31.45x |
| Pass 3 before | 2026-11-18T21:23:35Z | 45 | 1388 | 30.84x |
| Pass 3 after | 2026-11-18T22:12:22Z | 46 | 1391 | 30.24x |

**The non-overridable filter (`subagent`/`harness-started`) continues to dominate the overridable
one (`headless/agent`) at every reading, and the ratio is stable, not drifting.** Across all five
readings the ratio holds in a narrow 30.13x-31.45x band (spread of 1.32, about 4% of the mean).
This is the first mid-series confirmation that the roughly-30x asymmetry `reports/02` first
observed from a single reading persists across independent readings taken days apart, under the
anthropic backend, and across growth in both counters (headless/agent grew 30->46, +53%;
harness-started grew 904->1391, +54% -- both counters are growing at essentially the same rate,
which is itself consistent with a stable ratio rather than a coincidence of this particular
window).

### Daily-cap headroom check (first of the plan's required checks)

**Observed per-run yields across the three real (non-reconstructed-as-zero) extraction runs**:
Pass 1 = 1208 objects; Pass 2 = 550 objects (partial-failure pass, 34 errors); Pass 3 = 2051
objects (clean pass). This is a 3.7x range (550 to 2051) across passes of identical chunk count
(50), confirming per-pass yield is driven by the actual content of the 50 chunks selected that
day, not by a fixed per-chunk rate.

**No truncation by the daily cap has been observed in any of the three runs.** Each ran to
completion on all 50 chunks regardless of where the cumulative daily yield stood relative to the
2000-object cap -- Pass 3 in particular ran its full 50 chunks and finished 51 objects past the
cap (2051 vs. 2000), with no journal line indicating an early stop or a dropped chunk.

**How many 50-chunk passes a day would admit before the cap truncates one cannot be stated as a
single number, because no truncation mechanism has been observed at all.** The honest figure, as
measured so far: a single pass's yield alone has already both stayed comfortably under the cap
(Pass 2: 550, 27.5% of cap) and exceeded it outright (Pass 3: 2051, 102.6% of cap) -- so the
answer to "how many passes admit before truncation" ranges from "more than one, if yields stay as
low as Pass 2's" to "zero, if a pass yields as richly as Pass 3's", and the client does not appear
to enforce the cap as a stop condition in either case. This variability, not a fixed headroom
number, is phase 7's actual daily-cap finding so far; a longer series may narrow the range.
**No pass in the series to date is flagged as cap-truncated**, since no evidence of truncation
exists to flag.

---

<!-- Phases 4-5 append one Pass-N block each below this line, in the fixed shape documented
     above. Each requires at least 24 hours since the previous pass's timestamp before it may
     run. -->

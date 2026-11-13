# Research Report: Sapience coverage baseline and pass-1 extraction-backend failure

- **Task**: 136 - Measure Sapience capture coverage under manual extraction and decide whether to widen the scope, the cap, or the cadence
- **Started**: 2026-11-13T16:47:00Z
- **Completed**: 2026-11-13T17:05:00Z
- **Effort**: ~45 minutes (precondition re-verification, baseline capture, one attempted hand-run pass via each of the two documented methods)
- **Dependencies**: Task 138 (owner-action reconciliation of `~/.sapience/config.json`) -- confirmed applied, see below
- **Sources/Inputs**:
  - Live read of `~/.sapience/config.json` (outside this repository, owner-only state)
  - `sapience coverage` / `sapience pending` command output (live runs, before and after pass 1)
  - `journalctl --user -u sapience-sync` (full unit-run log for the pass-1 attempt)
  - `ps`/`ollama ps`/`ollama list` live process inspection
  - `/nix/store/vrlfwqq67bczbls4nv6h856mkn4sbcgw-sapience-sync` (the deployed systemd unit script)
  - `/home/benjamin/.nix-profile/bin/sapience` (the CLI wrapper script) and `~/.sapience/extract_local.py` (grepped for `MODEL` default)
  - `home.nix` (`programs.sapience` block), `docs/sapience.md`
  - `specs/138_retire_machine_wide_sapience_surface/records/02_sapience-config-owner-instruction.md`
  - `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/reports/01_coverage-baseline-blocked.md` (prior dispatch's artifact)
- **Artifacts**:
  - This report
  - `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/handoffs/research-handoff-20261113T170500Z.md`
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The task 138 precondition is now confirmed applied, live.** `~/.sapience/config.json` shows
  `BimodalLogic`, `PossibleWorlds`, and `Verification` all `enabled: false`; `abood` and
  `sapience-app` both `enabled: true`; `folders` reduced to exactly the 4-entry target set
  (`nvim`, `dotfiles`, `abood`, `sapience-app`). `sapience coverage` independently corroborates:
  "Folders selected (4): nvim, dotfiles, app, abood". The measurement window named in this task's
  own dispatch is open.
- **The baseline (METHOD step 1) is captured against the correct, post-138 population.** Of 1,133
  session files on disk, 74 "would ingest now", 30 are skipped as headless/agent, 885 are skipped
  as subagent/harness-started, 144 are skipped as folder-not-chosen, with `MAX_CHUNKS=50` and
  `pending=0`. Full verbatim block is in Findings below.
- **Both documented ways to hand-run a pass failed to produce a real extraction on this first
  attempt, for two different reasons** -- this is the dispatch's central, unplanned finding:
  - The systemd-unit path (`systemctl --user start sapience-sync.service`), which is the one path
    that actually threads `--model gemma4:cloud` through to `extract_local.py`, completed all 50
    queued chunks in 16.677 seconds -- but every single one of those 50 calls failed with `HTTP
    Error 402: Payment Required` from Ollama's cloud endpoint. Zero knowledge objects were staged.
    The 16.677s is a fast-fail, not a fast success.
  - The bare `sapience` CLI's `sync` subcommand (the other documented way) passes no `--model`
    flag at all, so `extract_local.py` falls back to its own per-backend default (`llama3.1`, a
    local, non-cloud model) rather than the `gemma4:cloud` model `home.nix` actually configures.
    That default cold-started a local, single-threaded (`-t 1`), CPU-bound `llama-server` process
    that had not completed even one of the queued chunks after 580 seconds, at which point this
    dispatch's own guard timeout killed it (exit 124) with zero progress recorded.
- **This is a genuine blocker to continuing the required 5-pass series**, distinct in kind from
  the prior dispatch's precondition blocker: that one was a config-reconciliation gap now closed;
  this one is a live extraction-backend failure (cloud billing) plus a method-level gap (the CLI
  wrapper not honoring the configured model) that together mean neither of the two ways this
  task's own dispatch names to run a pass currently produces real findings in practical time.
  Resolving the billing issue is an external-cost decision only the user can make; a
  `user_decision` is set accordingly (see `.return-meta.json`).
- **No conclusion is drawn yet on the CANDIDATE OUTCOMES** (widen scope, raise the chunk cap,
  schedule extraction, or leave as-is). The one partial technical signal available -- that 50
  chunks process in ~17 seconds once a call actually completes -- does not, by itself, support
  raising `MAX_CHUNKS`; see Decisions and Risks below for why that signal is provisional.

## Context & Scope

This dispatch (task 136, phase research, dispatch_seq 5) picks up directly from the prior
dispatch's report (`01_coverage-baseline-blocked.md`), which stopped at the task 138 precondition
check because `~/.sapience/config.json` had not yet been reconciled. This task's `.decisions.json`
records that the user directed the orchestrator to run the recorded owner instruction on their
behalf between that dispatch and this one, with an explicit obligation: make the live file match
the four-repository capture set so a subsequent reading characterizes the post-138 population.

Per this dispatch's own "Prior Decisions" instruction, that obligation was re-verified live here
rather than taken on trust (see Findings, "Precondition re-verification" below) before any
baseline reading was taken.

The scope of this dispatch was, going in: take the baseline (METHOD step 1) and begin the
five-pass series (METHOD step 2). What actually happened is that the first attempt at a pass,
run both documented ways, surfaced a backend-level blocker neither this dispatch's `.decisions.json`
nor task 138's record anticipated. The scope narrowed, on discovery, to: confirm the precondition,
take the baseline, attempt pass 1 by both documented methods, and report the blocker precisely
enough that the user's next decision is well-grounded -- mirroring the shape of the prior
dispatch's own narrowing, but at a different point in the METHOD.

## Findings

### Precondition re-verification: task 138's reconciliation is applied, live

Reading `~/.sapience/config.json` directly at this dispatch's start (2026-11-13T16:47Z):

```
$ jq -c '.capture.projects[] | {name: (.name // .path // .), enabled}' ~/.sapience/config.json
{"name":"BimodalLogic","enabled":false}
{"name":".dotfiles","enabled":true}
{"name":"Vision","enabled":false}
{"name":"Theory","enabled":false}
{"name":"Wedding","enabled":false}
{"name":"PossibleWorlds","enabled":false}
{"name":"nvim","enabled":true}
{"name":"PersonalWebsite","enabled":false}
{"name":"Applications","enabled":false}
{"name":"Verification","enabled":false}
{"name":"abood","enabled":true}
{"name":"sapience-app","enabled":true}

$ jq -c '.folders' ~/.sapience/config.json
["-home-benjamin--config-nvim","-home-benjamin--dotfiles","-home-benjamin-Projects-abood","-home-benjamin-Projects-Sapience-sapience-app"]

$ stat -c '%a' ~/.sapience/config.json
600
```

This matches task 138's owner-instruction record exactly: `BimodalLogic`/`PossibleWorlds`/
`Verification` disabled, `abood`/`sapience-app` added and enabled, `folders` reduced to the
4-entry target set, mode 600 preserved. The reconciliation is applied. `sapience coverage`
(below) independently corroborates the same four-repo folder set. The measurement window is
open; this dispatch proceeded past the point the prior dispatch stopped at.

### Baseline reading (METHOD step 1), against the correct population

```
$ sapience coverage
==================================================================
Sapience coverage
==================================================================
Window: last 30 days   Backend: ollama
Per-run extraction cap: 50 chunks (MAX_CHUNKS); backfill raises it so a wide window isn't truncated.
Folders selected (4): nvim, dotfiles, app, abood
------------------------------------------------------------------
Ingested: 24 session files across 4 repos
    BimodalLogic, PossibleWorlds, dotfiles, nvim
------------------------------------------------------------------
Curated memory files (CLAUDE.md / MEMORY.md / AGENTS.md / dumps): 0 ingested first each run
------------------------------------------------------------------
Available on disk: 1133 session files
  would ingest now:          74
  skipped (outside 30d window): 0
  skipped (headless/agent):    30   (add --include-agents to keep them)
  skipped (subagent / harness-started transcripts): 885   (thread mechanics; never read)
  daily extraction cap: 2000 objects/day (sapience yield: 0 objects today (cap 2000), 0 chunks in 0 runs; top sources: none)
  skipped (folder not chosen): 144
------------------------------------------------------------------

$ sapience pending
0
```

(Captured 2026-11-13T16:47:44Z, immediately after the precondition re-verification above and
before any pass was run.)

The "Ingested: 24 session files across 4 repos: BimodalLogic, PossibleWorlds, dotfiles, nvim"
line is historical -- it lists repos with previously-ingested vault content from before the
reconciliation, not the live folder selection. The live selection, reported one line above it
("Folders selected (4): nvim, dotfiles, app, abood"), is the one that governs this and future
readings.

74 + 0 + 30 + 885 + 144 = 1,133, matching "Available on disk" exactly -- the four counters
partition the full backlog with no remainder.

The two-filter divergence the task exists to measure is visible immediately, even before any
pass: 30 skipped as headless/agent vs. 885 skipped as subagent/harness-started -- the
subagent/harness-started filter removes roughly 29x more than the headless/agent filter, under
the now-correct population. This matches, almost exactly, the ratio the prior (pre-reconciliation)
dispatch observed under the stale population (30 vs. 874, ~29x) -- the four-repository narrowing
changed the denominator (`Available on disk` fell from a presumed-larger pre-138 figure, though
the two populations are not directly comparable since folder selection itself changed) but did not
change the *shape* of which filter dominates. Whether this persists across the five-pass series
is still the open question; one baseline reading is not enough to call it settled, and it is
recorded here as a first data point, not a conclusion.

### Pass-1 attempt, method A: bare `sapience sync` (terminal) -- stalled, zero progress

Per this task's own dispatch text ("The two ways to run a pass are `sapience sync` in a terminal
and `systemctl --user start sapience-sync.service`"), this dispatch first tried the terminal
form, wrapped in a 580-second guard timeout (`timeout 580 sapience sync`) consistent with this
agent's local-wait discipline.

Live process inspection while it ran showed:

```
benjamin  192855  0.3  /nix/.../python3 /home/benjamin/.sapience/extract_local.py --sync --yes
benjamin  192877 98.7  /nix/.../ollama-0.32.3/lib/ollama/llama-server --model <local-blob-sha256> \
                       --port 43597 --no-webui --offline -c 4096 -np 1 ... -t 1 ...
```

After 578-580 seconds of wall-clock/CPU time with the `llama-server` process pinned at ~98-100%
CPU on a single thread, the guard timeout fired: `timeout 580 sapience sync` exited 124. A
post-kill `sapience coverage`/`sapience pending` reading showed the backlog completely unchanged
("would ingest now: 74" still, "sapience yield: 0 objects today ... 0 chunks in 0 runs") --
zero chunks were completed before the kill.

Root cause, confirmed by reading the two relevant scripts:

- `/home/benjamin/.nix-profile/bin/sapience`'s `sync` case execs
  `extract_local.py --sync --yes "$@"` with **no `--model` flag**.
- `~/.sapience/extract_local.py` sets `MODEL = _arg('--model', {'ollama': 'llama3.1', ...})` --
  i.e. absent an explicit `--model` argument, the ollama backend defaults to `llama3.1`, not to
  `home.nix`'s configured `programs.sapience.model = "gemma4:cloud"`.

So the bare CLI silently extracts against a different, local, much larger model (`llama3.1`,
4.9 GB per `ollama list`) than the one `home.nix`'s own extensive comment block says was chosen
specifically for its low per-chunk latency. The observed behavior -- a cold-started,
single-threaded (`-t 1`) local CPU inference process that had not finished even one chunk after
580 seconds -- is consistent with that mismatch, though this dispatch did not let it run long
enough to learn whether it would eventually succeed, or at what per-chunk rate once warm (see
Risks below).

### Pass-1 attempt, method B: `systemctl --user start sapience-sync.service` -- fast, but every chunk failed

Started immediately after method A's kill, at 2026-11-13T16:58:51Z:

```
$ systemctl --user start sapience-sync.service
$ systemctl --user status sapience-sync.service --no-pager
...
Consumed 2.848s CPU time over 16.677s wall clock time, 116.5M memory peak.
```

16.677 seconds is dramatically faster than method A's 580+ seconds with zero progress. Reading
the deployed unit script
(`/nix/store/vrlfwqq67bczbls4nv6h856mkn4sbcgw-sapience-sync`) shows why: unlike the bare CLI, it
passes the model explicitly --

```
/nix/store/.../python3 "/home/benjamin/.sapience/extract_local.py" \
  --sync --yes --backend "ollama" \
  --model "gemma4:cloud"
```

-- so it correctly uses the `home.nix`-configured cloud-forwarded model rather than the CLI's
local fallback. But `journalctl --user -u sapience-sync` for this run shows the real outcome:

```
Nov 13 08:59:0[2-7] ... extract error: HTTP Error 402: Payment Required
  [repeated; every one of the 50 attempted chunk-extraction calls failed identically]
Nov 13 08:59:08 ... Extraction backend: ollama (model gemma4:cloud, billed to nobody (runs on this machine))
Nov 13 08:59:08 ... sapience: skipped 6 harness-started transcripts (thread mechanics, not knowledge; ...)
Nov 13 08:59:08 ... sapience capture (opt-in): read nvim 63, .dotfiles 21; not enabled none
Nov 13 08:59:08 ... Skipping 4 sources already extracted (results were staged/shared earlier).
Nov 13 08:59:08 ... Extracting knowledge from 70 sources (0 curated memory files) locally ...
Nov 13 08:59:08 ... sapience yield: 0 objects today (cap 2000), 50 chunks in 1 run; top sources: ...
Nov 13 08:59:08 ... Staged 0 new knowledge objects locally (0 awaiting review). Nothing was shared.
```

Every one of the 50 chunk-extraction HTTP calls to Ollama's cloud endpoint for `gemma4:cloud`
returned `402 Payment Required`. The run's "0 objects" yield is total extraction failure, not
low-information content -- the fast completion time is a fast-fail, not a fast success. A
post-run `sapience coverage`/`sapience pending` reading confirms nothing moved:

```
Available on disk: 1136 session files      (+3 vs. baseline -- new transcripts since baseline, unrelated to the pass)
  would ingest now:          74             (unchanged)
  skipped (headless/agent):    30            (unchanged)
  skipped (subagent / harness-started transcripts): 888   (+3, tracks the +3 available)
  daily extraction cap: ... (sapience yield: 0 objects today (cap 2000), 50 chunks in 1 run; ...)
  skipped (folder not chosen): 144           (unchanged)
sapience pending -> 0
```

`home.nix`'s own comment for `programs.sapience.model` states `gemma4:cloud` is "Free on
Ollama's usage page, same as beam." That characterization does not match what this account is
being charged for right now, at least for this call pattern: every call billed instead of
free-tier-accepted. This dispatch did not investigate the live Ollama account's billing state
further than reading the error itself -- resolving it is an external-cost action, not something
this dispatch can verify or fix from inside the repository.

### Net effect: neither documented way to run a pass currently produces real findings

Taken together: the fast path (systemd unit, correct model) fails every call with a payment
error; the slow path (bare CLI, wrong model by default) did not complete a single chunk inside
this dispatch's bounded wait. Neither produced a usable "post-pass" coverage/pending delta. The
"would ingest now: 74" figure is therefore still, after this dispatch's whole pass-1 attempt,
the same figure the baseline reading captured -- no real extraction has happened against the
post-138 population yet.

## Decisions

- **The precondition is treated as satisfied and the baseline is treated as valid.** Both are
  independently corroborated (config.json content, folder-set line in `sapience coverage`), so
  this dispatch proceeded past them rather than re-raising the already-answered question from
  `.decisions.json`.
- **This dispatch will not retry method A (bare `sapience sync`) with a longer timeout
  unsupervised.** Doing so risks tying up this dispatch's own time budget on an open-ended local
  CPU inference run with no confirmed completion time, for a method this report has already
  shown defaults to the wrong model. A future pass using method A should pass `--model
  gemma4:cloud --backend ollama` explicitly (matching the systemd unit) rather than relying on
  the CLI's own default, once the billing issue below is resolved -- or should be run by the user
  directly in an interactive terminal where an open-ended wait is unproblematic.
- **This dispatch will not attempt to resolve the Ollama cloud billing issue itself.** Topping up
  an account, switching billing plans, or re-authenticating `OLLAMA_API_KEY` are all actions
  outside this repository that only the user can authorize and verify -- exactly the external-cost
  shape `context/standards/user-decision-contract.md` names. A `user_decision` is set on
  `.return-meta.json` (blocking) naming this choice.
- **The two-filter divergence ratio (30 headless/agent vs. 885 subagent/harness-started) is
  recorded as a first data point, not yet a trend** -- see Findings above and Risks below for why
  it should not be treated as settled from one reading.
- **The zero-yield result from the systemd-unit run is attributed to the HTTP 402 failures, not
  to low-information content**, per the journal evidence above; see `issues.jsonl`'s
  `vacuous or silent pass` entry for the earlier, more tentative framing recorded before the
  journal was read in full, which this report's own Findings supersede with the actual root cause.

## Recommendations

1. **Resolve the Ollama cloud billing/account issue before resuming the five-pass series.** Check
   the Ollama account `OLLAMA_API_KEY` authenticates as (`ollama.com` account dashboard) for
   billing status, quota, or a plan change that would explain why `gemma4:cloud` -- documented in
   `home.nix` as free -- is now returning `402 Payment Required` on every call. This is the
   `user_decision`'s primary recommended option.
2. **Independently of the billing fix, close the model-mismatch gap in the `sapience` CLI
   wrapper** (or in `packages/sapience-flake/lib/wrappers.nix`, wherever the wrapper is sourced
   from) so that `sapience sync`/`sapience backfill`/`sapience review` pass `--model
   "gemma4:cloud" --backend "ollama"` the same way the systemd unit's `ExecStart` already does.
   Today the two "ways to run a pass" this task's own dispatch names are not equivalent, and a
   future hand-run pass via the bare CLI will keep silently falling back to a different, much
   larger local model unless this is fixed or the flag is passed by hand every time.
3. **Once a pass actually completes successfully (non-zero chunks with no call-level errors),
   resume the required five-pass series from there**, spaced at least a day apart, preferring
   `systemctl --user start sapience-sync.service` (detached, logs to journal, no local
   guard-timeout risk) over the bare CLI for each pass, and recording `sapience coverage`/
   `sapience pending` plus that pass's own skip counts in this task's artifacts after each one.
4. **Do not draw the CHUNK CAP conclusion from this dispatch's 16.677s figure.** That number
   measured 50 rapid HTTP failures, not 50 successful extractions; it says nothing about whether
   `MAX_CHUNKS=50` drains the real backlog at a useful rate. The next successful pass's duration
   is the number this task actually needs for that question.
5. **Re-check the headless/agent vs. subagent/harness-started skip ratio after two or three
   successful passes**, not after only this dispatch's single (failed) one, before concluding
   whether `includeAgentSessions` is worth adding.

## Risks & Mitigations

- **Risk**: the local `llama3.1` fallback (method A) might actually work fine once warm, and this
  dispatch's 580-second kill may have interrupted it mid-model-load rather than mid-inference,
  making "impractically slow" an overclaim. **Mitigation**: a future dispatch or the user should
  let `sapience sync --model llama3.1 --backend ollama` (or the bare CLI, now that its default is
  understood) run to completion once, uninterrupted, ideally in an interactive terminal rather than
  inside a dispatched agent's bounded wait, to learn its real steady-state per-chunk rate before
  ruling it out as a cloud-independent fallback.
- **Risk**: the `402 Payment Required` could be transient (a momentary account hiccup, a stale
  cached credential) rather than a genuine billing gap. **Mitigation**: before spending money,
  the user should retry `systemctl --user start sapience-sync.service` once more on its own,
  independent of this dispatch, and check whether the error persists; this report deliberately
  does not claim certainty about the underlying account cause, only about the observed, repeated
  failure.
- **Risk**: a future dispatch re-reads this report's "would ingest now: 74" and "0 chunks
  completed" figures and treats them as still current without re-running `sapience coverage`
  itself -- `config.json` and the vault both self-update, and new transcripts accrue daily even
  without a successful extraction pass (the post-pass reading already shows "Available on disk"
  grew from 1,133 to 1,136 in the ~12 minutes between readings, purely from new transcripts).
  **Mitigation**: every future reading in this series should be freshly captured, exactly as this
  report's own baseline was, never carried forward from an earlier dispatch's snapshot.
- **Risk**: the five-pass series, spaced a day apart over a week, outlives several `/orchestrate`
  invocations, and a future dispatch loses track of why task 136 is still open. **Mitigation**:
  the handoff artifact accompanying this report names the exact next action and the current
  state; each future pass's dispatch should append its own reading to this task's artifacts
  rather than requiring a full re-read of this report to reconstruct the series.

## Context Extension Recommendations

- **Topic**: Divergent CLI-vs-systemd-unit argument wiring for a Home-Manager-configured tool.
- **Gap**: No existing context file documents the general pattern this dispatch found --
  a Home Manager module (`programs.sapience.model`) threading a configured value correctly into
  one invocation path (the systemd unit) while a sibling invocation path (the bare CLI) silently
  falls back to the underlying tool's own default instead. `context/project/nix/domain/home-manager.md`
  covers module structure but not this specific "two paths, one wired, one not" failure shape.
- **Recommendation**: if this pattern recurs in another Home-Manager-wrapped CLI, a short pattern
  note under `context/patterns/` describing "verify every documented invocation path threads the
  same configured values, not just the one path the module's own service unit uses" would have
  caught this before a hand-run pass silently extracted against the wrong model.

## Appendix

- Commands run: `jq` reads of `~/.sapience/config.json`; `stat -c '%a'`; `sapience coverage`
  (x3: pre-pass, post-method-A-kill, post-method-B); `sapience pending` (x3); `timeout 580
  sapience sync`; `ps -o pid,etimes,%cpu,cmd`; `systemctl --user start sapience-sync.service`;
  `systemctl --user status sapience-sync.service`; `journalctl --user -u sapience-sync`;
  `ollama ps`; `ollama list`; `grep` of `~/.sapience/extract_local.py` for `MODEL`;
  `cat` of `/home/benjamin/.nix-profile/bin/sapience` and
  `/nix/store/vrlfwqq67bczbls4nv6h856mkn4sbcgw-sapience-sync`.
- Files read: `~/.sapience/config.json` (owner-only, outside this repository); `home.nix`
  (`programs.sapience` block); `docs/sapience.md`;
  `specs/138_retire_machine_wide_sapience_surface/records/02_sapience-config-owner-instruction.md`;
  `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/reports/01_coverage-baseline-blocked.md`;
  `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/.decisions.json`;
  `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/.dispatch/5.md`.
- Issue log entries (`issues.jsonl` in this task's directory): win (orchestration defect,
  minor) for precondition confirmation; issue (tooling bug or gap, costly) for the CLI
  model-default mismatch; win (tooling bug or gap, minor) for the 16.677s per-50-chunk figure
  (superseded in interpretation by the 402 finding above, but retained as the raw timing data
  point); issue (vacuous or silent pass, minor) for the initial zero-yield observation; issue
  (infrastructure/transport unavailable, blocking) for the HTTP 402 root cause.

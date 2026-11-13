# Research Handoff - 2026-11-13T17:05:00Z (task 136)

## Immediate Next Action
Do not retry a pass yet. Wait for the user's decision on `.return-meta.json`'s blocking
`user_decision` (Ollama cloud billing for `gemma4:cloud` is returning `HTTP 402: Payment
Required` on every chunk). Once the user confirms the account is funded again (or picks a
different model), run `systemctl --user start sapience-sync.service` for pass 1 proper, then
`sapience coverage` and `sapience pending`, and record both verbatim in this task's next report.

## Current State
- Precondition (task 138's `~/.sapience/config.json` reconciliation): confirmed applied, live.
- Baseline (METHOD step 1): captured cleanly, 74 "would ingest now" of 1,133 available, 30
  headless/agent skips, 885 subagent/harness-started skips, 144 folder-not-chosen skips,
  `MAX_CHUNKS=50`, `pending=0`. See `reports/02_baseline-and-extraction-backend-blocked.md`,
  "Baseline reading" section, for the full verbatim block.
- Pass 1: attempted twice, both failed (see below). Zero real chunks extracted so far against
  the post-138 population. "Would ingest now" is still 74 as of the last reading.
- 5 systemic issue-log entries recorded for this dispatch (`issues.jsonl`, dispatch_seq 5): one
  win (precondition), one issue + one win (CLI model-default mismatch and the raw 16.677s timing),
  one issue (initial zero-yield framing, since superseded), one blocking issue (the actual 402
  root cause).

## Key Decisions Made
1. Treated the precondition and baseline as settled without re-raising the already-answered
   `.decisions.json` question -- both are independently corroborated live.
2. Did not retry the local (`llama3.1`) fallback path with a longer timeout inside this dispatch
   -- open-ended local CPU inference with no confirmed completion time is a bad use of a bounded
   dispatch's wait budget; left as a user/future-dispatch action in an interactive terminal.
3. Did not attempt to fix the Ollama billing issue -- that is an external-cost action outside
   this repository; recorded as a blocking `user_decision` instead.

## What NOT to Try
1. Bare `sapience sync` with no `--model` flag: silently defaults to the local `llama3.1` model
   (not the configured `gemma4:cloud`), cold-starting a single-threaded CPU `llama-server` that
   did not finish one chunk in 580 seconds. If retried, pass `--model gemma4:cloud --backend
   ollama` explicitly, or expect a long, unbounded wait.
2. `systemctl --user start sapience-sync.service` *before* the billing issue is resolved: it is
   correctly wired to `gemma4:cloud`, but every call currently returns `HTTP 402 Payment
   Required`. Running it again before the user confirms billing is fixed will just repeat the
   same 50-failure, 0-objects outcome.
3. Treating the 16.677s / 50-chunk timing as a throughput measurement for the CHUNK CAP question
   -- it measured 50 fast HTTP failures, not 50 successful extractions.

## Critical Context (max 5 items)
- The two "ways to run a pass" this task's dispatch names are NOT equivalent on this machine:
  only the systemd unit threads `--model gemma4:cloud` through; the bare CLI falls back to
  `llama3.1`. Source: `/nix/store/vrlfwqq67bczbls4nv6h856mkn4sbcgw-sapience-sync` vs.
  `/home/benjamin/.nix-profile/bin/sapience`'s `sync` case vs. `extract_local.py`'s `MODEL` default.
- `journalctl --user -u sapience-sync` is the authoritative source for what a systemd-unit pass
  actually did -- `sapience coverage`'s own yield line can look like success ("50 chunks in 1
  run") while every underlying call failed; always check the journal, not just the summary line.
- `home.nix`'s comment claims `gemma4:cloud` is free; the live `402` contradicts that right now.
  This dispatch does not know whether that's a genuine billing gap or a transient account issue.
- `sapience coverage`'s "Ingested: ... across 4 repos: BimodalLogic, PossibleWorlds, dotfiles,
  nvim" line is historical vault content from before the reconciliation -- do not read it as the
  live folder selection; the "Folders selected (N): ..." line one row above it is authoritative.
- New transcripts accrue even with zero successful passes: "Available on disk" grew 1,133 ->
  1,136 in ~12 minutes between readings in this dispatch, purely from new session activity.

## References (read only if stuck)
- Report: `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/reports/02_baseline-and-extraction-backend-blocked.md`
  (this dispatch's full findings, all command output, Recommendations 1-5)
- Prior report: `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/reports/01_coverage-baseline-blocked.md`
  (precondition-blocked dispatch, now resolved)
- Metadata/decision: `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/.return-meta.json`
  (`user_decision`, blocking)

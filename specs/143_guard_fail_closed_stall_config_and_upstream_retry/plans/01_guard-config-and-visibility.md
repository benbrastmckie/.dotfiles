# Implementation Plan: Guard fail-closed stall — config, visibility, upstream defect

- **Task**: 143 - Guard fail-closed stall: config and upstream retry
- **Status**: [IMPLEMENTING]
- **Effort**: 5.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/143_guard_fail_closed_stall_config_and_upstream_retry/reports/01_guard-fail-closed-config-and-retry.md
- **Artifacts**: plans/01_guard-config-and-visibility.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Bring the oliver-ben guard's three network knobs (`coalesce_s`, `net_timeout_s`, `deadline_s`)
under declarative control via a `home.activation` step in
`modules/home/services/sf1-hub-ben.nix` that patches the live per-checkout `config.json` in
place, add a systemd-user watch surface that makes a fail-closed marker visible without reading
`log.jsonl`, write up the upstream no-retry defect for Oliver rather than patching the
sha256-pinned vendor file, and record the attached-mode-with-empty-ruleset stance.
Definition of done: both attached checkouts carry the chosen values after a switch, a new
`stopped.json` or `breaker.json` produces a desktop notification, `docs/sf1-hub.md` documents
the config surface and the unstop/reset procedures, and the defect write-up plus the open
question to Oliver exist as a sendable record.

### Premise Re-Validation

The dispatch's `## Premise Re-Validation` section flagged the MEASURED EVIDENCE paragraph. Each
claim was re-derived against live state at plan-authoring time (2026-11-17, this dispatch), not
carried:

| Dispatch claim | Live re-derivation | Verdict |
|---|---|---|
| 3675 log records | 3827 records in `sapience-app/.git/oliver-ben-guard/log.jsonl` | Grown, consistent |
| 1715 `304`, 105 `coalesced` | 1717 `304`, 176 `coalesced` | Grown, consistent; the extra `coalesced` hits post-date the live `coalesce_s` 1.0 -> 300.0 edit |
| "35 failures — 24 TimeoutError, 11 URLError" | 38 blocks, all `reason: "suspended"`; **only 3 are initiating** events (TimeoutError 2026-11-13 13:35, TimeoutError 2026-11-17 09:46, URLError 2026-11-17 11:49); the other 35 carry `stopped earlier:` and are downstream repeats of the sticky marker | **CORRECTED** |
| "~2% per-call failure rate" | 3 initiating failures over ~1720 network round trips (1717 `304` + 3 failures) = **~0.17%** | **CORRECTED** — the 2% figure counts sticky repeats as independent failures |
| "expected survival ~50 controlled actions" | Derived from the 2% figure; at ~0.17% per round trip and `coalesce_s=1.0` (~1 round trip per controlled action) expected survival is ~580 actions | **CORRECTED** |
| "two dispatches died mid-flight on 2026-11-17, each needing a hand-run unstop" | Two of the three initiating suspends are dated 2026-11-17 (09:46, 11:49); last block 12:25:37, no `stopped.json` present now | Confirmed |
| `hubcache.json` success 11s before `stopped.json` — transient, not an outage | Not re-derivable (that `stopped.json` was cleared by the hand-run unstop); current `hubcache.json` `checked_at` is recent and `n_kos` is 0 | CARRIED-UNVERIFIED, from the dispatch description |
| config surface `mode=attached, coalesce_s=1.0, net_timeout_s=2.0, deadline_s=8.0` | `sapience-app`: 300.0 / 15.0 / **8.0** (hand-edited 2026-11-17 12:30:41); `sf1-engine`: 1.0 / 2.0 / 8.0 (untouched since 2026-11-12) | **CORRECTED** — the hand-edit the research report found is still the live state |
| "nothing in this repository declares these values" | `grep` over `modules/` and `packages/` finds the three key names only inside the vendored `guard.py`/`install.sh` | Confirmed |

The corrections do not change the task's direction: 3 transient blips still produced 38 blocked
actions and killed two dispatches, which is the defect. They do change two numbers that must not
be repeated as-is in `docs/sf1-hub.md` or in the write-up to Oliver.

### Research Integration

The plan adopts the research report's decisions D1 (activation-step mechanism, modelled on
`modules/home/core/dotfiles.nix`'s `claudeSettings` enforced-key `jq` merge), D2 (`coalesce_s=300`,
`net_timeout_s=15`, `deadline_s=20`), D3 (stay attached in both repos), D4 (defect write-up, not
a local patch — the vendor file is sha256-pinned and the build's `sha256sum -c` gate rejects an
edited copy), and D5 (mako notification + polling timer over a waybar module). Two of the
report's open points are resolved here: the optional one-click `unstop` action is **declined**
(see Decisions D7), and a surface the report did not cover is **added** (D8).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap phases are
included.

## Goals & Non-Goals

**Goals**:
- Declare `coalesce_s`/`net_timeout_s`/`deadline_s` durably for every attached checkout, so a
  re-`attach` (which re-runs `install.sh` and rewrites `config.json` from scratch) cannot
  silently revert them.
- Apply the chosen values (300 / 15 / 20) to both attached checkouts, converging `sf1-engine`,
  which is still on the installer defaults.
- Make a fail-closed marker — `stopped.json` (admission suspend) **and** `breaker.json` (sender
  breaker) — visible as a desktop notification, without reading `log.jsonl`.
- Produce a sendable write-up of the upstream no-retry defect covering both surfaces, plus the
  one question that genuinely needs Oliver's answer.
- Record the attached-vs-detached stance and its reasoning.
- Document the config surface, the corrected failure history, and the unstop/reset procedures in
  `docs/sf1-hub.md`.

**Non-Goals**:
- Editing `packages/sf1-hub-ben/vendor/guard/guard.py` or any other vendored file. The build's
  integrity gate (`modules/home/services/sf1-hub-ben.nix` `installPhase`, `sha256sum -c` against
  `vendor.lock.json`) fails on a mismatch; a behavioural fix here would be a deliberate fork plus
  a lock update, which this task does not do.
- Writing a consent marker, handling `SAPIENCE_TOKEN`, or touching `key_file`. Everything that
  grants consent or holds a credential stays manual, per that module's "What stays manual"
  section.
- Automating `sf1-hub-ben attach`, `token`, `consent`, `enable`, or `golive` — all TTY-only by
  design.
- Adding `mkOption`s for the three values. This is a single-machine dotfiles module and the values
  are not meant to vary per invocation; they are `let`-bound constants. (Adding an option would
  also force an edit to `home.nix`, which a concurrent sibling task holds in its declared file
  scope.)
- Draining the stranded commit-event outboxes unattended (see Decisions D9 and the
  `user_decision` on this dispatch's return metadata).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Activation script corrupts a live `config.json` | H | L | Same fail-safe shape as `claudeSettings`: `jq -e .` parse guard, write to a `mktemp` file, `mv` only on success, skip (never error) a missing or unparseable file |
| Activation script fails the whole `home-manager switch` | H | L | Every external call guarded; the block ends in a successful status regardless of per-checkout outcome; honors `DRY_RUN` like its two sibling blocks |
| Watch unit ends up `failed`, degrading the systemd user session on every switch | M | M | Reaper precedent: PATH export, every external call guarded, script always exits 0 |
| Notification flood from one stuck marker | M | M | mtime-keyed state file per checkout per marker (memory-monitor `COOLDOWN_FILE` idiom); one new marker fires exactly one notification, not one per tick |
| `deadline_s=20` still under the Claude Code hook's own `timeout: 30` | M | L | 20 leaves 10s for interpreter startup, JSON encode/decode and `evaluate_hub`'s `git` subprocesses; verified the hook entries carry `"timeout": 30` in the live `sapience-app/.claude/settings.local.json` |
| `coalesce_s=300` delays a newly accepted rule by up to 5 minutes | M | H (by design) | Stated explicitly in the module comment and in `docs/sf1-hub.md`; the drop to ~60 once the rule set is non-empty is a one-line manual change plus a switch, flagged in both places |
| **Concurrency**: a sibling task holds `home.nix` in its file scope, and `home.nix` is evaluated by both the NixOS and standalone home-manager paths | H | M | Phase 3 checks `git status --short home.nix modules/` immediately before switching; if `home.nix` carries a foreign uncommitted edit, STOP and report rather than applying a sibling's in-flight work. Treat a build failure outside this task's file scope as possibly a sibling's edit |
| A re-`attach` between the switch and a later read reverts the values | L | L | That is exactly what the activation step re-converges; the next switch restores them, and the behaviour is documented |

## Decisions

- **D1 — Mechanism**: a `home.activation` entry in `modules/home/services/sf1-hub-ben.nix`,
  inside `lib.mkIf cfg.enable`, that discovers attached checkouts from
  `${config.xdg.stateHome}/sf1-hub-ben/manifest.json`'s `checkouts` keys, resolves each one's
  `git rev-parse --git-common-dir`, and force-sets exactly three numeric keys in
  `oliver-ben-guard/config.json`. Rejected: a documented manual post-attach step (non-durable —
  it is how today's split state, fixed on `sapience-app` and unfixed on `sf1-engine`, arose) and
  an `attach` wrapper (only ever fixes a fresh `attach`, never an already-attached checkout).
- **D2 — Values**: `coalesce_s = 300`, `net_timeout_s = 15`, `deadline_s = 20`. `net_timeout_s=15`
  because the initiating failures are `TimeoutError` against a 2s socket timeout on a hosted TLS
  endpoint that was reachable before and after. `coalesce_s=300` because coalescing, not the
  timeout, is the lever on failure *volume*: at 1.0 nearly every controlled action makes its own
  round trip, and 300 turns a several-hundred-tool-call dispatch into roughly one admission
  request per 5 minutes. `deadline_s=20` because `deadline_s` is an internal `SIGALRM` around the
  whole `evaluate_hub()` call and must exceed `net_timeout_s` (otherwise the alarm pre-empts the
  socket timeout — the live gap on `sapience-app` right now, 15.0 > 8.0) while staying under the
  Claude Code hook's own 30s timeout.
- **D3 — `MIN_PULL_GAP_S`**: `coalesce_s` stays above the vendored `MIN_PULL_GAP_S = 10` floor at
  both 300 and the eventual ~60, but the plan does not treat that floor as protective: it is
  enforced only in the legacy (pre-attached) `get_rules()` path, and attached mode's `admit()`
  never references it. The docstring's "network pulls are at least 10 s apart" claim does not
  cover attached mode; that is called out in the write-up to Oliver.
- **D4 — Freshness cost, stated**: at `coalesce_s=300` a rule Oliver Accepts in the room does not
  bind on this machine until the window expires — up to 5 minutes. Dropping to ~60 once the rule
  set is non-empty cuts that to at most 1 minute at roughly 5x the admission round trips (and so
  ~5x the suspension exposure at the same per-round-trip rate). Nix evaluation cannot see the
  live `n_kos`, so this remains a deliberate manual change, recorded in the module comment.
- **D5 — No upstream patch**: the defect is reported, not fixed locally (vendor file sha256-pinned;
  the build gate rejects an edited copy).
- **D6 — Attached stance**: stay attached in both checkouts. `main_postcommit`/`main_postrewrite`
  gate commit-event queuing on `mode == "attached"`, so detaching also stops the
  `hub_commit_events` / `share_unpushed_branches` reporting consented in
  `CONSENT-benjamin.json`; and an attached guard with `n_kos = 0` already enforces nothing, so
  staying attached pays no enforcement cost once the stall behaviour is addressed. Whether and
  when Oliver intends to Accept real `RULE`/`decision` KOs is his to answer, and is carried as
  the one open question in the Phase 4 record.
- **D7 — Notification is notify-only**: the optional one-click `-A default=Unstop` action the
  research report left to planning is **declined**. The mako single-default-action idiom in
  `.claude/scripts/claude-refresh.sh` depends on `notify-send --wait` with `-t 0`, which inside a
  timer-driven oneshot would hold the unit active indefinitely and block later timer activations.
  The notification instead carries the exact command to paste, which satisfies the dispatch's
  own bar ("make a suspension *diagnosable*").
- **D8 — Second fail-closed surface, added to scope**: `guard.py send()` has the same no-retry
  shape as `admit()` — one sink error writes `breaker.json` and every later send refuses
  ("breaker open, no retry") until `guard.py send --reset`. Measured at plan time: the breaker is
  **open in both checkouts** (`sapience-app` since 2026-11-15 17:16, `sf1-engine` since
  2026-11-14 23:04) with commit events stranded in `outbox/`. This was not in the dispatch
  description or the research report. It is in scope because it changes all three of: the write-up
  to Oliver (same root cause, two surfaces), the attach/detach calculus (the consented reporting
  has in fact been silently dead for days), and the watch surface (which must check both markers,
  not just `stopped.json`).
- **D9 — The stranded outboxes are not drained unattended**: resetting the breakers causes an
  immediate outward delivery of several days of queued commit metadata to a hosted sink. The kind
  of data is already consented, but the burst is an outward-facing, irreversible action, so Phase
  3 records the counts and the exact reset command and leaves the run to the user. Surfaced as a
  non-blocking `user_decision` on this dispatch's return metadata.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel. Phases 1 and 2 both edit
`modules/home/services/sf1-hub-ben.nix` and are therefore deliberately sequential, not parallel.

### Phase 1: Declare the three guard network knobs [COMPLETED]

**Goal**: `modules/home/services/sf1-hub-ben.nix` force-sets `coalesce_s`/`net_timeout_s`/`deadline_s`
in every attached checkout's `config.json` on every `home-manager switch`, preserving every other
key.

**Tasks**:
- [x] Re-read `modules/home/services/sf1-hub-ben.nix` immediately before editing (concurrent
      sibling is live in this tree).
- [x] Add three `let`-bound constants near `cfgDir`: `guardCoalesceS = 300`,
      `guardNetTimeoutS = 15`, `guardDeadlineS = 20`.
- [x] Add a comment block above them recording: why these values (D2), the freshness cost and the
      manual drop to ~60 once the rule set is non-empty (D4), that `deadline_s` must stay above
      `net_timeout_s` and below the Claude Code hook's 30s timeout, and that `MIN_PULL_GAP_S` is
      not enforced in attached mode (D3).
- [x] Add `home.activation.sf1HubBenGuardConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ...`
      inside `config = lib.mkIf cfg.enable`, following `modules/home/core/dotfiles.nix`'s
      `claudeSettings` shape: a `[[ -v DRY_RUN ]]` branch that only echoes, and a real branch that
      for each checkout path in `${config.xdg.stateHome}/sf1-hub-ben/manifest.json`'s `checkouts`
      object resolves `${pkgs.git}/bin/git -C "$co" rev-parse --git-common-dir`, appends
      `oliver-ben-guard/config.json`, and — only if that file exists and `${pkgs.jq}/bin/jq -e .`
      parses it — writes `jq '.coalesce_s=$c|.net_timeout_s=$n|.deadline_s=$d'` with `--argjson`
      into a `mktemp` sibling and `mv`s it into place.
- [x] Guard every path: missing or unparseable `manifest.json` -> skip silently; relative
      `--git-common-dir` output -> resolve against the checkout; missing `config.json` -> skip
      (that checkout was never attached, and nothing here should create one); failed `jq` -> remove
      the temp file and leave the live file untouched.
- [x] Confirm the block writes no consent marker, reads no token, and never touches `key_file`,
      `me`, `source`, `sink`, `since_ts`, `require_accept` or `mode`.
- [x] Run `nixfmt` on the edited file so the flake's `nixfmt` check passes.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for
`modules/home/services/sf1-hub-ben.nix` (no shell suite maps to this consumer-repo path), so the
covering check is run directly: `nix build --no-link .#checks.x86_64-linux.nixfmt
.#checks.x86_64-linux.deadnix .#checks.x86_64-linux.home-eval`, which evaluates this module end
to end.

**Files to modify**:
- `modules/home/services/sf1-hub-ben.nix` - add the three `let` constants, their rationale
  comment, and the `home.activation.sf1HubBenGuardConfig` block

**Verification**:
- `nix build --no-link .#checks.x86_64-linux.nixfmt .#checks.x86_64-linux.deadnix .#checks.x86_64-linux.home-eval`
  all succeed (`home-eval` forces full evaluation of the standalone home-manager generation, which
  is where a bad option or missing attribute surfaces).
- Read the generated activation script out of the evaluated generation (or the built
  `activationPackage`) and confirm the `jq` filter names exactly the three keys.

---

### Phase 2: Fail-closed marker watch and notification [COMPLETED]

**Goal**: a new marker — `stopped.json` or `breaker.json` — in any attached checkout produces one
`-u critical` desktop notification naming the checkout, the marker kind, the recorded error, and
the exact remediation command.

**Tasks**:
- [x] Re-read `modules/home/services/sf1-hub-ben.nix` immediately before editing.
- [x] Add `systemd.user.services.sf1-hub-ben-guard-watch` (`Type = "oneshot"`) inside
      `lib.mkIf cfg.enable`, with its body a `pkgs.writeShellScript` modelled on
      `modules/home/services/claude-session-reaper.nix`: explicit PATH export, every external call
      guarded, always exits 0.
- [x] Script body: for each checkout in `${config.xdg.stateHome}/sf1-hub-ben/manifest.json`'s
      `checkouts`, resolve the guard state dir via `git -C "$co" rev-parse --git-common-dir`; for
      each of `stopped.json` and `breaker.json`, if present, compare its mtime against a per-
      checkout, per-marker state file under `${config.xdg.stateHome}/sf1-hub-ben/watch/` (the
      `COOLDOWN_FILE` idiom in `modules/home/memory/monitor.nix`); on a new or newer mtime, fire
      one `notify-send -a sf1-hub-ben -u critical -t 0` and record the mtime.
- [x] Notification body names the remediation verbatim: for `stopped.json`,
      `python3 ${sf1-hub-ben}/share/sf1-hub-ben/vendor/guard/guard.py unstop --root <checkout>`;
      for `breaker.json`, the same path with `send --reset`. Interpolate the store path from the
      `sf1-hub-ben` derivation rather than resolving it at runtime (the CLI on PATH is a
      `makeWrapper` wrapper, so `readlink` does not reach the payload).
- [x] Skip the notification silently when `notify-send` is unavailable or no DBus session bus is
      reachable; the unit must still exit 0.
- [x] Add `systemd.user.timers.sf1-hub-ben-guard-watch` with `OnCalendar = "*:0/2"`,
      `Persistent = true`, a small `RandomizedDelaySec`, and `Install.WantedBy = [ "timers.target" ]`.
      Do **not** add `Requires` on the service — the reaper module's own comment records why
      (stop-propagation silently ends the schedule).
- [x] Run the generated script through `shellcheck` by hand (the flake's `shellcheck` check scans
      `*.sh` files and `.githooks/*`, so a `writeShellScript` body is not covered by it).
- [x] Run `nixfmt` on the edited file.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this path, so the
covering checks are run directly: `nix build --no-link .#checks.x86_64-linux.nixfmt
.#checks.x86_64-linux.deadnix .#checks.x86_64-linux.home-eval` plus
`shellcheck` on the generated watch script, which together cover a new unit confined to this one
module.

**Files to modify**:
- `modules/home/services/sf1-hub-ben.nix` - add the `sf1-hub-ben-guard-watch` oneshot service and
  its timer

**Verification**:
- The three `nix build` checks above succeed.
- `shellcheck` on the generated script reports no findings.
- Dry-run the script logic against live state with a temporary state dir: with the live
  `breaker.json` present in both checkouts it must report two findings on the first run and zero
  on an immediate second run (mtime dedupe working).

---

### Phase 3: Apply, converge both checkouts, and record the breaker state [NOT STARTED]

**Goal**: both attached checkouts carry 300 / 15 / 20; the watch timer is active; the stranded
commit-event counts and the exact reset command are recorded without draining them.

**Tasks**:
- [ ] Run `git status --short home.nix modules/ docs/` first. If `home.nix` carries a foreign
      uncommitted modification, STOP and report it (a concurrent sibling declares `home.nix` in
      its file scope) rather than applying another task's in-flight work; confirm against
      `git log` that the work is not this task's own before concluding anything.
- [ ] Apply: `sudo nixos-rebuild switch --flake .#hamsa` then
      `home-manager switch --flake .#benjamin` (the standalone generation is the one that owns
      `~/.nix-profile` and runs `home.activation`; `scripts/update.sh` runs both for the same
      reason).
- [ ] Assert convergence: for each checkout in `~/.local/state/sf1-hub-ben/manifest.json`, `jq`
      the resolved `config.json` and confirm `coalesce_s == 300`, `net_timeout_s == 15`,
      `deadline_s == 20`, and that `me`, `source`, `sink`, `since_ts`, `key_file`,
      `require_accept` and `mode` are unchanged from a pre-switch capture of the same files.
- [ ] Confirm `systemctl --user is-active sf1-hub-ben-guard-watch.timer` and that one manual
      `systemctl --user start sf1-hub-ben-guard-watch.service` produces a notification for the
      live open breakers and exits 0.
- [ ] Capture, into `records/02_convergence-and-breaker-state.md`: the pre- and post-switch values
      per checkout, the `outbox/` counts, each `breaker.json`'s `at`/`error`, and the exact
      `guard.py send --reset --root <checkout>` command for each. Do **not** run it (D9).
- [ ] Re-read `log.jsonl`'s block tally and note whether any new initiating suspend has appeared
      since the 2026-11-17 11:49 event.

**Timing**: 0.75 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this phase's paths,
so the covering check is run directly: the two switch commands' own exit status plus a `jq`
assertion that each checkout's `config.json` carries 300/15/20 with every other key unchanged.

**Scope Hypothesis**: Two attached checkouts (`~/Projects/Sapience/sapience-app`,
`~/Projects/Sapience/sf1-engine`), measured at plan time from
`~/.local/state/sf1-hub-ben/manifest.json`'s `checkouts` keys; `outbox/` held 85 and 106 events
respectively and both `breaker.json` files were present. Confirm by re-reading the manifest and
re-counting `outbox/*.json` at implementation time rather than asserting these numbers — a
`detach`, a fresh `attach`, or a hand-run `send --reset` between plan and implementation moves
all of them.

**Files to modify**:
- `specs/143_guard_fail_closed_stall_config_and_upstream_retry/records/02_convergence-and-breaker-state.md`
  - new file: pre/post values per checkout, stranded-event counts, breaker details, the reset
  commands left unrun

**Verification**:
- Both switch commands exit 0.
- `jq` assertion passes for every checkout the manifest lists.
- `systemctl --user is-active sf1-hub-ben-guard-watch.timer` reports `active`, and the unit is not
  in a `failed` state after a manual start.
- The record file exists and names a reset command per checkout.

---

### Phase 4: Upstream defect write-up and the open question for Oliver [NOT STARTED]

**Goal**: a single sendable record carrying the two-surface no-retry defect, the corrected
measurements, the proposed fixes, and the one question only Oliver can answer.

**Tasks**:
- [ ] Write `records/01_upstream-defect-and-attach-question.md`, starting from the research
      report's Appendix write-up and correcting it on three points.
- [ ] Correction 1 — the numbers: report 3 initiating admission failures over ~1720 network round
      trips (~0.17%), 38 blocked actions total because the marker is sticky, and two dispatches
      killed mid-flight. Do not repeat "35 failures" or "~2%".
- [ ] Correction 2 — the line range: `hub_fetch`/`admit` span `guard.py` 537-607, with the
      hosted-route branch (where every observed failure originates) beginning at 546 — not
      553-607.
- [ ] Correction 3 — add the second surface: `send()`'s `breaker.json` has the same shape (one
      sink error, sticky refusal, the code's own message says "breaker open, no retry"), it is
      currently open in both checkouts, and commit events have been accumulating undelivered in
      `outbox/` since 2026-11-14/15. Name it as one root cause with two expressions, not two
      unrelated bugs.
- [ ] State the two proposed fixes, either of which would have prevented the observed stalls: one
      bounded retry after a short backoff inside the existing `net_timeout_s`/`deadline_s` budget,
      or a grace window that keeps enforcing from the last good cache for N seconds (~10-30)
      before writing `stopped.json`. Note that the sender needs the same treatment.
- [ ] Include the secondary observation that `MIN_PULL_GAP_S` / the docstring's "pulls are at
      least 10 s apart" claim is enforced only in the legacy path, not in attached mode's
      `admit()`.
- [ ] Record the attached-mode stance (D6) and its reasoning, and state the single open question
      plainly: whether and when Oliver intends to Accept real `RULE`/`decision` KOs in the
      `oliver-ben` room, given that the cached rules doc is revision 1, schema
      `sf1-hub-rules/1`, members `[oliver, benjamin]`, `n_kos = 0`. Note that detaching would
      also stop the `hub_commit_events` / `share_unpushed_branches` reporting he consented to —
      and that, per the breaker finding, that reporting is in fact already stalled.
- [ ] Keep the record self-contained and sendable: no task numbers inside quoted text meant for
      Oliver, and no reliance on this repository's own conventions to be intelligible.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: Every touched path lies under `specs/**` and `suite_selection_select`
returns `__FULL_SWEEP__` for it, so no suite covers it; the covering check is the `prose` row's
diff read-through confirming the record is prose only, with no executable or configuration
surface.

**Scope Hypothesis**: The write-up asserts 3 initiating failures, ~1720 round trips, 38 blocked
actions, and open breakers dated 2026-11-15 17:16 and 2026-11-14 23:04 — all measured at plan
time from `sapience-app/.git/oliver-ben-guard/log.jsonl` and both checkouts' `breaker.json`.
Re-derive each figure from those same files at implementation time before writing it into a
record that will be sent outside this machine.

**Files to modify**:
- `specs/143_guard_fail_closed_stall_config_and_upstream_retry/records/01_upstream-defect-and-attach-question.md`
  - new file: the two-surface defect write-up, the proposed fixes, the attached-mode stance, and
  the open question

**Verification**:
- Diff read-through confirms the record contains prose only.
- The corrected figures appear and neither "35 failures" nor "~2%" survives anywhere in it.
- Both surfaces (`stopped.json` via `admit`, `breaker.json` via `send`) are described, with the
  proposed fix covering each.

---

### Phase 5: Document the config surface and close out [NOT STARTED]

**Goal**: `docs/sf1-hub.md` records the config surface, the corrected failure history, the
unstop/reset procedures and the watch timer; the full gate set runs clean.

**Tasks**:
- [ ] Re-read `docs/sf1-hub.md` immediately before editing.
- [ ] Add a config-surface table: the three knobs, their declared values, that
      `modules/home/services/sf1-hub-ben.nix`'s activation step is where they are declared, that
      `attach`/`install.sh` writes 1.0/2.0/8.0 and the activation step re-converges them, and the
      explicit freshness cost at `coalesce_s=300` plus the manual drop to ~60 once the rule set is
      non-empty.
- [ ] Add the measured failure history, using the corrected figures only: 3 initiating admission
      failures over ~1720 round trips, 38 blocked actions from a sticky marker, two dispatches
      killed on 2026-11-17, and the fact that the route was reachable before and after.
- [ ] Document both remediation procedures under `## Stopping it` (or a sibling section): the
      `guard.py unstop --root <checkout>` invocation for a suspend and
      `guard.py send --reset --root <checkout>` for an open sender breaker, including how to find
      the `guard.py` store path (the attached repo's own `.claude/settings.local.json` hook
      command names it, and the watch notification prints it).
- [ ] Document the watch timer: unit name, 2-minute cadence, that it is notify-only by design
      (D7), and that it checks both markers.
- [ ] Extend the `## Known gaps` empty-ruleset bullet with the attached-mode stance (D6), and add
      a bullet for the sender-breaker surface and its stranded outbox.
- [ ] Keep the document free of task-number references
      (`.claude/rules/no-task-references-in-deliverables.md`) and of record-versioning language
      (`.claude/rules/no-record-versioning-in-deliverables.md`): state the current design, not
      this plan's history.

**Timing**: 1 hour

**Depends on**: 3, 4

**Verification Tier**: full

**Scope Hypothesis**: Asserts the same measured figures as Phase 4 (3 initiating failures,
~1720 round trips, 38 blocked actions) plus "two attached checkouts". Re-derive all of them from
`log.jsonl` and `manifest.json` at implementation time; a document is the worst place for a stale
carried number.

**Files to modify**:
- `docs/sf1-hub.md` - config-surface table, corrected failure history, unstop and breaker-reset
  procedures, watch-timer section, extended `## Known gaps`

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` — the complete gate set for this repository, run and
  observed green (not narrowed by `--only-gate`, `--only` or `--skip-slow`, and not trusted on
  sight).
- `nix flake check` succeeds (the repository-specific check set no gate of `verify-deploy.sh`
  covers: `nixfmt`, `deadnix`, `home-eval`, `shellcheck`, and every host evaluation).
- `bash .claude/scripts/check-task-references.sh` reports no new findings for `docs/sf1-hub.md`.
- A read-through confirms every figure in the document matches a value re-derived in this phase.

## Testing & Validation

- [ ] `nix build --no-link .#checks.x86_64-linux.nixfmt .#checks.x86_64-linux.deadnix .#checks.x86_64-linux.home-eval` succeeds after each module edit.
- [ ] `nix flake check` succeeds once, after the final edit.
- [ ] `shellcheck` on the generated watch script reports no findings.
- [ ] Both switch commands exit 0 and both checkouts' `config.json` carry 300 / 15 / 20 with every
      other key byte-identical to a pre-switch capture.
- [ ] A second `home-manager switch` leaves both `config.json` files unchanged (idempotence).
- [ ] `home-manager switch --flake .#benjamin -n` (or the `DRY_RUN` path) only echoes, writing
      nothing.
- [ ] The watch unit, started by hand with the live open breakers present, notifies once per
      checkout and exits 0; an immediate second start notifies nothing.
- [ ] `systemctl --user is-failed sf1-hub-ben-guard-watch.service` reports not-failed after a run.
- [ ] `bash .claude/scripts/verify-deploy.sh` runs clean before the task completes.

## Artifacts & Outputs

- `modules/home/services/sf1-hub-ben.nix` — three `let` constants with rationale, the
  `home.activation.sf1HubBenGuardConfig` enforced-key `jq` block, and the
  `sf1-hub-ben-guard-watch` oneshot plus timer.
- `docs/sf1-hub.md` — config surface, corrected failure history, unstop and breaker-reset
  procedures, watch-timer documentation, extended `## Known gaps`.
- `specs/143_guard_fail_closed_stall_config_and_upstream_retry/records/01_upstream-defect-and-attach-question.md`
  — the sendable two-surface defect write-up, the attached-mode stance, and the open question for
  Oliver.
- `specs/143_guard_fail_closed_stall_config_and_upstream_retry/records/02_convergence-and-breaker-state.md`
  — pre/post config values per checkout, stranded-event counts, breaker details, and the reset
  commands deliberately left unrun.
- Live state: both attached checkouts converged on 300 / 15 / 20; the watch timer active.

## Rollback/Contingency

- **A module edit breaks evaluation**: fix forward — `home-eval` names the failing option or
  attribute. Nothing is applied to the machine until Phase 3, so a broken edit cannot leave the
  system in a bad state.
- **The switch fails**: `nixos-rebuild`/`home-manager` leave the previous generation active;
  `home-manager generations` plus a rollback to the prior generation restores it, and the
  activation step only ever rewrote three numeric keys in files outside the store.
- **The activation step damages a `config.json`**: the file is reconstructible by hand — only
  three keys are touched, and `sf1-hub-ben attach` (TTY, by hand) rewrites the whole file from
  scratch if needed. `records/02_convergence-and-breaker-state.md` holds the pre-switch capture
  for exactly this case.
- **The watch unit misbehaves**: `systemctl --user disable --now sf1-hub-ben-guard-watch.timer`
  stops it immediately; removing the two attribute sets and switching removes it declaratively.
- **Uncommitted work must be discarded**: this plan prescribes no destructive git operation. If
  one becomes genuinely necessary, follow `context/contracts/recovery.md`'s rollback rung for the
  snapshot-then-rollback invocation shape — never a bare precautionary `git-snapshot.sh` as a
  routine checkpoint.

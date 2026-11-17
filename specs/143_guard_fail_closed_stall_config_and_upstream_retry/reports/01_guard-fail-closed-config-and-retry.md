# Research Report: Task 143

**Task**: 143 - Guard fail-closed stall: config and upstream retry
**Started**: 2026-11-17T20:30:00Z
**Completed**: 2026-11-17T21:40:00Z
**Effort**: ~1 session, research only
**Dependencies**: None
**Sources/Inputs**:
- `packages/sf1-hub-ben/vendor/guard/guard.py` (vendored, sha256-pinned; read in full)
- `packages/sf1-hub-ben/vendor/guard/install.sh`
- `packages/sf1-hub-ben/sf1-hub-ben` (platform CLI)
- `modules/home/services/sf1-hub-ben.nix`
- `docs/sf1-hub.md`
- `packages/sf1-hub-ben/vendor.lock.json`, `INSTALL-BEN.md`
- Live machine state (this session, 2026-11-17): `~/Projects/Sapience/sapience-app/.git/oliver-ben-guard/{config.json,hubcache.json,log.jsonl}`, `~/Projects/Sapience/sf1-engine/.git/oliver-ben-guard/config.json`, `~/.local/state/sf1-hub-ben/manifest.json`, `~/Projects/Sapience/sapience-app/.claude/settings.local.json`
- Existing activation-script precedent: `modules/home/core/dotfiles.nix` (`claudeSettings` enforced-key jq merge), `modules/home/core/zotero.nix`, `modules/home/services/claude-session-reaper.nix`, `.claude/scripts/claude-refresh.sh` (mako prompt idiom)
**Artifacts**: this report
**Standards**: report-format.md, nix.md, no-task-references-in-deliverables.md

## Executive Summary

- Someone has already hand-patched `coalesce_s`/`net_timeout_s` on the live `sapience-app`
  checkout (to 300/15, matching the dispatch's "starting proposal"), but **not**
  `deadline_s` (still 8.0) and **not** `sf1-engine`'s config — exactly the undeclared, inconsistent
  state this task exists to fix. No suspension has recurred on `sapience-app` in the ~36 minutes
  since that edit, a short but positive early signal.
- A real, previously-unflagged interaction was found and verified directly against the source:
  `deadline_s` (8.0, an internal `SIGALRM`) is now **shorter** than `net_timeout_s` (15.0, the
  socket timeout) on `sapience-app`. A network call between 8s and 15s is now killed by the
  deadline alarm — a single-action fail-closed block, not a sticky suspend, but still an
  unnecessary failure the dispatch's proposed starting values did not account for.
- Recommended durable declaration: a home-manager activation step, not a post-attach doc step or
  an `attach` wrapper — it is the only option that re-converges an existing `config.json` on every
  `home-manager switch` regardless of when/how often `attach` last ran, without writing a consent
  marker or touching the credential (`key_file`).
- Recommended values: `coalesce_s=300`, `net_timeout_s=15` (already live, confirmed sound),
  `deadline_s=20` (new — closes the gap above, keeps comfortable margin under the
  Claude Code `PreToolUse` hook's own 30s timeout).
- Detach-vs-stay-attached (empty ruleset): recommend staying **attached** in both repos.
  `main_postcommit`/`main_postrewrite` gate commit-event queuing on `mode == 'attached'`
  (verified in `_session()`), so detaching silently stops the commit-event reporting Oliver may
  rely on, while an attached guard with zero KOs already enforces nothing (`docs/sf1-hub.md`'s own
  "Known gaps" already says so) — so staying attached pays no enforcement cost once the
  suspend/stall problem itself is fixed.
- A suspension-visibility surface is recommended as a mako notification + a small polling
  timer (same `notify-send`/mako-single-default-action idiom `.claude/scripts/claude-refresh.sh`
  already uses for its Lean-tree-kill prompt), not a waybar status-line module — this repo's
  `waybar.nix` has no existing custom-module convention to extend.

## Context & Scope

The oliver-ben binding guard (`packages/sf1-hub-ben/vendor/guard/guard.py`) is vendored
byte-for-byte and sha256-pinned (`packages/sf1-hub-ben/vendor.lock.json`); editing it fails the
Nix build's integrity gate (`modules/home/services/sf1-hub-ben.nix`'s `installPhase`
`sha256sum -c` step). `attach` is a manual, TTY-only step (`human_only()` gates in
`packages/sf1-hub-ben/sf1-hub-ben`), and the home-manager module deliberately does not run
`install.sh` or `attach` (see that module's own "Why install.sh is not used" / "What stays
manual" comments). This research covers, in order: (1) where/how to declare the two (now three)
network knobs durably; (2) what values to use and why; (3) the upstream defect write-up; (4) the
attached-mode-with-empty-ruleset question; (5) a suspension-visibility surface; (6) the
`docs/sf1-hub.md` update this report's findings feed into (left to the plan/implement phases).

## Findings

### Current live state (measured this session, not carried from the dispatch)

| Repo | `coalesce_s` | `net_timeout_s` | `deadline_s` | `mode` |
|------|-------------:|-----------------:|-------------:|--------|
| `sapience-app` (card repo) | 300.0 | 15.0 | **8.0** | attached |
| `sf1-engine` (guarded, no cards) | 1.0 | 2.0 | 8.0 | attached |

`sapience-app/.git/oliver-ben-guard/config.json` mtime is 2026-11-17 12:30:41 local — someone
edited `coalesce_s`/`net_timeout_s` to exactly the dispatch's "starting proposal" values, by hand,
on this one repo, leaving `deadline_s` untouched and leaving `sf1-engine` on the original
hardcoded defaults entirely. `~/.local/state/sf1-hub-ben/manifest.json` confirms both checkouts
are the only two `attach`ed repos (`checkouts` keys), so this is the complete current population.

Re-counting `sapience-app`'s `log.jsonl` directly (3791 total records as of this reading):
`how` tallies `{'304': 1716, 'coalesced': 154}`, `decision` tallies
`{'allow': 3753, 'block': 38}`, all 38 blocks carry `reason: 'suspended'`. Every one of the 38
suspend timestamps precedes the 12:30:41 config edit; none has recurred since (last log entry
observed ~36 minutes after the edit). That is a genuinely positive signal but too short a window
to call the timeout/coalesce fix fully validated — the two 2026-11-17 stalls the dispatch cites
were themselves separated by hours, so 36 clean minutes does not yet rule out a recurrence.

The dispatch's own cited figures (3675 total, 1715 '304', 105 coalesced, 35 failures: 24
`TimeoutError` + 11 `URLError`) are the pre-fix snapshot that motivated this task, not something
re-derived here; they are consistent with the (now larger) totals above once you account for the
49 additional `coalesced` hits that landed only after `coalesce_s` went from 1.0 to 300.0, and
with the fact that "~2% per-call failure rate" in the dispatch is measured over admission calls
that actually reached the network (`'304' + 'coalesced' + failures`, excluding the much larger
population of read-only/no-admission log rows), not over the full 3675/3791 row count.

### `guard.py` mechanism, as implemented (not as documented)

- `MIN_PULL_GAP_S = 10` (guard.py:55) and the module docstring's "Network pulls are at least 10 s
  apart" (guard.py:42) are enforced **only** in the legacy (pre-attached) `get_rules()` path
  (guard.py:276,279: `too_soon = hosted and cache and now - cache.get('fetched_at', 0) <
  MIN_PULL_GAP_S`). Phase-A attached mode's `admit()` (guard.py:581-607) never references
  `MIN_PULL_GAP_S` at all — its only pacing control is `cfg['coalesce_s']`
  (guard.py:592: `now - cache.get('checked_at', 0) < cfg['coalesce_s']`). The installer's
  `coalesce_s=1.0` default is therefore not merely "ten times tighter than the documented floor"
  as background color — it is a different code path entirely, so the docstring's claim does not
  actually protect attached-mode installs the way its wording suggests. Treat `MIN_PULL_GAP_S=10`
  as a floor worth keeping `coalesce_s` above in attached mode too (undershooting it reproduces
  the one-request-per-controlled-action behavior that caused both 2026-11-17 stalls), not as a
  guarantee the attached code path already honors.
- `hub_fetch()` (guard.py:537-564) raises `Suspend` on the first `HTTPError`/timeout/connection
  error, with no retry of any kind. `admit()` (guard.py:581-607) catches `Suspend`, writes
  `stopped.json` via `suspend()` (guard.py:574-579), and re-raises; every later controlled action
  hits the `stop.exists()` branch (guard.py:587-590) and blocks immediately without attempting the
  network at all, until a human runs `guard.py unstop`. This matches the dispatch's description
  exactly; the only correction worth recording is the line range — `hub_fetch`/`admit` together
  span guard.py:537-607, not 553-607 (`hub_fetch`'s hosted-route branch, where every observed
  failure originates, starts at guard.py:546).
- **New finding, verified against source, not in the dispatch**: `_arm_deadline()`
  (guard.py:1256-1259) arms a `SIGALRM` for `cfg['deadline_s']` seconds around the whole
  `evaluate_hub()` call (guard.py:1280-1287, inside `main_hook`). If that alarm fires first, the
  guard raises `DeadlineHit`, logs `reason: 'deadline'`, and prints "exceeded its %.1f s deadline:
  blocked (fail closed)" (guard.py:1283-1287) — a single-action fail-closed block, distinct from
  a sticky `Suspend`. Because `hub_fetch`'s own socket timeout is `cfg['net_timeout_s']`
  (guard.py:553, passed as `timeout=cfg['net_timeout_s']`), raising `net_timeout_s` without also
  raising `deadline_s` creates a window — exactly what has happened on `sapience-app` right now
  (`net_timeout_s=15.0` > `deadline_s=8.0`) — where any hosted-route request slower than 8s is cut
  off by the alarm before its own 15s socket timeout ever gets to run its course, whether or not
  it would have succeeded.
- The `PreToolUse`/`PostToolUse` hook entries `cmd_attach` writes (via `hook_entries()`,
  `packages/sf1-hub-ben/sf1-hub-ben`:269-274) each carry Claude Code's own `"timeout": 30`.
  Confirmed live in `sapience-app/.claude/settings.local.json`. `deadline_s` must stay
  comfortably under 30 (allowing for Python interpreter startup, JSON encode/decode, and the
  `git` subprocess calls `evaluate_hub` makes) as well as safely above `net_timeout_s`.

### Where the hardcoded values actually live

Two literal copies, not three as a flat count — the dispatch's third citation
("whatever `sf1-hub-ben attach` writes") is `attach` *invoking* the first of the two, not an
independent third hardcode:
- `packages/sf1-hub-ben/vendor/guard/install.sh`:27 (the `printf` line that writes
  `config.json` for attached mode) — this is the file `cmd_attach()`
  (`packages/sf1-hub-ben/sf1-hub-ben`:288-360) runs via `subprocess.run(['sh', GUARD_INSTALL,
  ...])` (line 331); `cmd_attach` itself never writes `coalesce_s`/`net_timeout_s`/`deadline_s`,
  it only patches `key_file` in afterward (lines 335-338).
- `guard.py`'s own missing-config fallback inside `_session()` (guard.py:1243-1253; the literal
  dict is at guard.py:1250-1251), used only when a hook is invoked with `--attached` but
  `config.json` is missing or unreadable — this path fails closed regardless of its own
  `coalesce_s`/`net_timeout_s` values (every controlled action blocks immediately because
  `cfg['source']` is `''`), so its specific numbers are cosmetic, but it is still a second place a
  future reader might "fix" without effect if they stop at `install.sh` alone.

Nothing in this repository currently declares any of the three values — confirmed: no
`coalesce_s`/`net_timeout_s`/`deadline_s` string appears anywhere under `modules/` or `packages/`
outside the vendored `guard.py`/`install.sh` themselves.

### Durable declaration — chosen design

Evaluated the three options the dispatch names:

1. **An activation step that patches an existing `config.json` in place** (preserving
   `me`/`source`/`sink`/`since_ts`/`key_file`/`require_accept`/`mode`) — **recommended**.
2. A documented post-attach manual step (add a paragraph to `INSTALL-BEN.md`/`docs/sf1-hub.md`
   telling a human to hand-edit `config.json` after each `attach`) — rejected as the sole
   mechanism: it is exactly how the current, already-inconsistent state (fixed on `sapience-app`,
   unfixed on `sf1-engine`) came to exist, and it does nothing to re-converge a future re-`attach`
   (which re-runs `install.sh` and overwrites `config.json` from scratch, silently reverting to
   1.0/2.0/8.0).
3. A thin wrapper around `sf1-hub-ben attach` — rejected: it only fixes a checkout at the moment
   of a fresh `attach`, never an already-attached one, and it would duplicate `cmd_attach`'s own
   backup/idempotency bookkeeping (`packages/sf1-hub-ben/sf1-hub-ben`:303-314) rather than reusing
   it.

Option 1 wins because it is the only one that keeps converging *every* attached checkout, on
*every* `home-manager switch`, independent of how or when `attach` was last run — which is exactly
the durability property the dispatch asks for, and it can be built with no new consent marker and
no credential handling: it reads only `~/.local/state/sf1-hub-ben/manifest.json`'s `checkouts`
keys (plain paths, no secrets) to discover which `config.json` files exist, then rewrites three
numeric fields in each via `jq`, leaving every other key untouched.

This matches an existing, already-reviewed convention in this exact module tree:
`modules/home/core/dotfiles.nix`'s `claudeSettings` activation block merges a repo-declared
"enforced key set" over a live, externally-written JSON file via `jq`, with a `DRY_RUN` branch and
a fail-safe fallback on a missing/unparseable live file. The guard case is the same shape with one
difference worth keeping explicit in the eventual plan: `claudeSettings` merges a *shipped
template* onto a live file; the guard activation step has no shipped template (per-checkout
`me`/`source`/`sink`/`since_ts` are checkout-specific, assigned at `attach` time, not something
this repo can template) — it only *forces three named numeric keys*, leaving every other key in
the live file exactly as `attach`/`install.sh` wrote it. Concretely, for each checkout path `$co`
found in the manifest: resolve `git -C "$co" rev-parse --git-common-dir`, append
`oliver-ben-guard/config.json`, and if that file exists and parses, run
`jq '.coalesce_s=$c|.net_timeout_s=$n|.deadline_s=$d' --argjson c <coalesce_s> --argjson n
<net_timeout_s> --argjson d <deadline_s>` into a temp file and `mv` it atomically into place
(`jq -e . "$f" >/dev/null 2>&1` as the parse guard, same as `claudeSettings`'s `-e .` check);
skip silently (no error) when the file does not exist yet, since that means the checkout has
never been `attach`ed and nothing here should create it. This writes no consent marker, reads no
token, and only ever touches a file `attach`/`install.sh` already created — compliant with the
module's own "What stays manual" boundary.

### Recommended values, with rationale

| Knob | Current (installer default) | Recommended | Rationale |
|------|-----:|-----:|-----------|
| `net_timeout_s` | 2.0 | **15** | 24 of the dispatch's 35 pre-fix failures were `TimeoutError` against a 2s timeout on a hosted TLS endpoint that the same evidence shows was reachable 11s before and some time after each failure — not an outage, a slow-but-live round trip. Already live on `sapience-app`; 0 recurrences observed since. |
| `deadline_s` | 8.0 | **20** | Must exceed `net_timeout_s` (else the internal alarm pre-empts the socket timeout — the gap found live on `sapience-app` right now) and stay under the Claude Code hook's 30s `PreToolUse` timeout with margin for interpreter startup and the `git` calls `evaluate_hub` makes. 20 gives 5s of margin on each side. |
| `coalesce_s` (empty ruleset, `n_kos=0`, confirmed live via `hubcache.json`) | 1.0 | **300** | `coalesce_s`, not `net_timeout_s`, is the main lever on failure *volume*: with it at 1.0, nearly every controlled action (94% of admission attempts in the pre-fix log) makes its own network round trip, which is what turned a ~2%-of-round-trips failure rate into a sticky stall roughly every ~50 actions. At 300s, a multi-hundred-tool-call dispatch makes on the order of one admission request every 5 minutes instead of on every write. Already live on `sapience-app`. |
| `coalesce_s` (once Oliver adds real `RULE`/`decision` KOs) | — | **~60** | Freshness cost, stated explicitly: at `coalesce_s=300`, a rule Oliver Accepts in the room can take up to 5 minutes to start binding on this machine (the window the dispatch asks to name). Dropping to ~60 once the ruleset is non-empty shrinks that to at most 1 minute, at the cost of roughly 5x more admission round trips (and therefore ~5x the absolute suspension exposure at the same per-round-trip failure rate) — still comfortably above the `MIN_PULL_GAP_S=10` floor the docstring states (even though, per the Findings above, nothing in the attached-mode code path currently enforces that floor itself). This is a one-line, manual value change (plus `home-manager switch`) once the ruleset is no longer empty — not something the activation step can decide on its own, since Nix evaluation has no way to see the live `n_kos` at build time. |

### Detach vs. stay-attached with an empty ruleset

Verified directly in `guard.py`, not merely asserted: `main_postcommit()` and
`main_postrewrite()` (guard.py:1339-1365) both call `_session(root, False)` and bail out
(`if cfg is None: return 0`) whenever `cfg.get('mode') != 'attached'` (the `_session` gate at
guard.py:1243-1253). `detach` (both the `sf1-hub-ben` CLI command and the guard's own
`a[0] == 'detach'` branch, guard.py:1400-1404) sets `mode` to `'detached'`. So detaching a
checkout does not just turn off edit-time/pre-commit enforcement — it silently turns off
commit-event queuing too, for exactly the `hub_commit_events: true` consent recorded in
`sapience-app/.git/oliver-ben-guard/CONSENT-benjamin.json` (confirmed live; also
`share_unpushed_branches: true` there). Meanwhile `docs/sf1-hub.md`'s own "Known gaps" section
already states that an attached guard with an empty ruleset is behaviorally indistinguishable
from a working one at the point of use — i.e., staying attached pays no present enforcement cost
either way, since there is nothing to enforce yet.

**Recommendation**: stay attached in both repos. The only real cost of attached mode with an
empty ruleset was the stall/suspend behavior this task is fixing; once (1)-(3) above land, there
is no remaining downside to staying attached, and detaching would give up the commit-event
reporting for no offsetting benefit. This is the research agent's own resolved recommendation,
not a stand-in for the room conversation the dispatch asks for — the thing that genuinely needs
Oliver's input is *whether/when he intends to add real `RULE`/`decision` KOs*, which is a
protocol question between the two of them, not a configuration choice this repository can make.
The recommendation above is the right default while that conversation happens.

### Suspension visibility (not a config change)

Recommend a mako notification, following the exact idiom `.claude/scripts/claude-refresh.sh`
already uses for its Lean-tree-kill prompt (`notify-send -a ... -u critical -t 0 -A default=Kill
--wait`, chosen because mako has no per-action launcher and maps left-click to whichever action
is marked `default`) — not a new waybar status-line module, since `modules/home/desktop/waybar.nix`
has no existing custom-module convention to extend and a notification is a closer behavioral
match to "a human decides when to read again" (`guard.py`'s own stated design intent, in its
module docstring). Concretely: a small `systemd.user` oneshot + timer (shaped like
`modules/home/services/claude-session-reaper.nix`: PATH export, every external call guarded,
always exits 0) that, for each checkout in `~/.local/state/sf1-hub-ben/manifest.json`, checks for
`<git-common-dir>/oliver-ben-guard/stopped.json`; on a *new* stop marker (dedupe by the marker's
own mtime against a small cooldown file, the same idiom `memory-monitor`'s
`modules/home/memory/monitor.nix` already uses), fires one `-u critical -t 0` notification naming
the repo and the recorded error, so a stall surfaces without anyone having to grep `log.jsonl` or
run `guard.py status` by hand. A `-A default=Unstop` click action running
`guard.py unstop --root <repo>` (itself ungated by `human_only` in `guard.py`'s own CLI, since
`unstop`/`detach` are only gated when invoked *through* Claude Code's own hook —
`SELFMOD_CMD_RES` at guard.py:823-828 blocks the command text `guard.py\s+(unstop|detach)` only
once an active `guard-protect` RULE binds, and none does today) is a reasonable secondary
addition consistent with the Kill/Keep precedent, but the dispatch's own wording ("make a
suspension *diagnosable*") is satisfied by the notification alone; whether to also wire the
one-click remediation is better decided in planning, not research.

## Decisions

- **D1 — Mechanism**: declare `coalesce_s`/`net_timeout_s`/`deadline_s` via a `home.activation`
  step in `modules/home/services/sf1-hub-ben.nix` that patches these three keys in place on every
  `config.json` the `sf1-hub-ben` manifest lists as attached, using the same enforced-key `jq`
  pattern already proven in `modules/home/core/dotfiles.nix`'s `claudeSettings` block. Rejected: a
  documented manual step (non-durable — it is how the current inconsistency arose) and an
  `attach`-wrapper (only fixes a fresh `attach`, never an already-attached checkout).
- **D2 — Values**: `coalesce_s=300`, `net_timeout_s=15` (both already live on `sapience-app`;
  confirmed sound by 0 recurrences in the observation window so far), `deadline_s=20` (new;
  closes the verified `deadline_s < net_timeout_s` gap). Record, in the Nix module's own comment,
  that `coalesce_s` should drop to ~60 by hand once Oliver's ruleset is no longer empty.
- **D3 — Attach/detach**: recommend staying attached in both `sapience-app` and `sf1-engine`.
  Detaching would silently stop commit-event reporting (`main_postcommit`/`main_postrewrite`'s
  `mode == 'attached'` gate) for no offsetting benefit, since an empty ruleset already enforces
  nothing either way. Whether/when Oliver adds real rules remains an open room conversation, not
  something this task resolves.
- **D4 — Upstream defect**: write up the no-retry suspend behavior for Oliver (see Appendix) as a
  defect report, not a local patch — the vendor file is sha256-pinned and the Nix build's
  integrity gate rejects any edited copy.
- **D5 — Visibility**: a mako notification + polling timer, following
  `claude-refresh.sh`'s existing prompt idiom, over a new waybar module.
- **D6 — Scope of this phase**: this is the research dispatch; the actual Nix edits
  (`modules/home/services/sf1-hub-ben.nix`, `docs/sf1-hub.md`) are left to the plan/implement
  phases, per the normal research -> plan -> implement separation. `sf1-engine`'s `config.json`
  stays on the unfixed 1.0/2.0/8.0 defaults until the activation step lands and a
  `home-manager switch` runs.

## Recommendations

1. Add a `home.activation.sf1HubBenGuardConfig` block to `modules/home/services/sf1-hub-ben.nix`
   implementing the enforced-key `jq` patch described in Findings, with the values from D2 as
   `let`-bound constants (not new `mkOption`s — this is a single-machine dotfiles module, and the
   three values are not meant to vary per invocation) and a `DRY_RUN` branch matching
   `claudeSettings`'s convention. Discover checkouts from
   `${config.xdg.stateHome}/sf1-hub-ben/manifest.json`, mirroring how the module already reads
   `config.xdg.configHome` for `cfgDir`.
2. Add a `systemd.user.services.sf1-hub-ben-guard-watch` oneshot + timer (shaped like
   `claude-session-reaper.nix`) implementing the mako-notification visibility surface from
   Findings; decide in planning whether to wire the optional one-click `unstop` action or ship
   notify-only first.
3. Update `docs/sf1-hub.md`: add the config-surface table from this report (current values, where
   they're declared, the freshness-cost note), the measured suspend/failure history (both the
   pre-fix numbers that motivated this task and the post-fix observation), the unstop procedure,
   and a short note on the new watch timer. Also correct/extend the existing "Known gaps" bullet
   about an empty-ruleset attached guard looking identical to a working one, cross-referencing D3.
4. Send Oliver the Appendix defect write-up below, and separately ask him directly whether/when
   he intends to Accept real `RULE`/`decision` KOs in the `oliver-ben` room — the empty-ruleset
   question this task was asked to "resolve" is actually this question, addressed to him, not a
   local decision.
5. Converge `sf1-engine`'s `config.json` (currently still 1.0/2.0/8.0) via the new activation step
   on the next `home-manager switch` once it lands — no manual action needed beyond that switch.

## Risks & Mitigations

- **Activation-script bug corrupts `config.json`**: mitigate with the same fail-safe shape
  `claudeSettings` already uses — `jq -e . <file>` as a parse guard, write to a temp file first,
  `mv` only on success, and skip (never error) a checkout whose `config.json` does not exist or
  does not parse.
- **Notification flood from a single stuck suspension**: mitigate with an mtime-based cooldown
  marker (same idiom as `memory-monitor`'s `COOLDOWN_FILE`), so one new `stopped.json` fires
  exactly one notification, not one per timer tick.
- **36-minute clean window is not strong evidence the timeout alone fixes recurrence**: keep
  watching `sapience-app`'s `log.jsonl` for new `reason: 'suspended'` entries after this report
  lands; the `deadline_s` fix (D2) is still outstanding and could itself cause new single-action
  blocks (not sticky suspends) under the current 8.0 value until it ships.
- **Cross-task territory**: task 136 (concurrent, `implement` phase) declares file scope over
  `docs/sapience.md`, `home.nix`, `modules/home/services/sapience.nix`, and its own
  `specs/136_.../records/*`. None of those overlap this task's planned edit targets
  (`modules/home/services/sf1-hub-ben.nix`, `docs/sf1-hub.md`), so no scope conflict — re-check
  both files for an unexpected foreign edit immediately before writing, per the standing
  concurrency note, when the implement phase runs.

## Appendix

### Upstream defect write-up (ready to send to Oliver)

> **Guard: attached-mode admission suspends on the first network error, with no retry and no
> grace window**
>
> `hub_fetch()` (`guard/guard.py`, hosted-route branch) raises `Suspend` on the very first
> timeout, connection error, or non-2xx/304 response from the rules route. `admit()` catches that,
> writes `stopped.json`, and every later controlled action blocks immediately without even
> attempting the network, until a human runs `guard.py unstop`. Measured on `sapience-app`
> (2026-11-17, pre-fix config): 35 of ~1855 admission round trips failed this way (24
> `TimeoutError`, 11 `URLError`), and because suspension is sticky, that was enough to kill two
> full agent dispatches mid-flight (stalled after ~140 and ~337 tool calls respectively), each
> needing a hand-run `unstop`. In both cases the route was reachable again within seconds —
> `hubcache.json`'s last successful `checked_at` preceded one `stopped.json` write by only 11
> seconds — so these were transient blips, not outages, and a bare retry (or even just tolerating
> the last-good cache for a short grace window) would have prevented both stalls.
>
> Proposal (either would have avoided both incidents): (a) one bounded retry inside `hub_fetch`
> before raising `Suspend` (a single retry after a short backoff, within the existing
> `net_timeout_s`/`deadline_s` budget), or (b) a grace window — keep enforcing from the last good
> cache for N seconds (comparable to `MIN_PULL_GAP_S`, i.e. ~10-30s) before writing `stopped.json`,
> so a transient blip degrades to "enforce from stale cache briefly" rather than "block everything
> until a human intervenes." Happy to test either against a local fixture source if useful.
>
> Separately, worth flagging: `MIN_PULL_GAP_S`/the module docstring's "network pulls are at least
> 10s apart" claim is enforced only in the legacy (pre-attached) code path — `admit()`'s pacing is
> `coalesce_s` alone, with no reference to `MIN_PULL_GAP_S`. Not a bug exactly, but the docstring
> reads as if it covers attached mode too, and it doesn't.

### Key file/line references

- `guard.py`: docstring floor claim 42; `MIN_PULL_GAP_S` 55; legacy `too_soon` check 276,279;
  `hub_cfg` defaults 510-511; `hub_fetch` 537-564; `suspend` 574-579; `admit` 581-607;
  `_session` fallback 1243-1253; `_arm_deadline`/`DeadlineHit` handling 456-459, 1256-1259,
  1280-1287; `SELFMOD_CMD_RES` (unstop/detach gating) 823-828; `protected_zones`/`is_protected`
  807-820; `main_postcommit`/`main_postrewrite` mode gate 1339-1365; `detach` command
  1400-1404.
- `packages/sf1-hub-ben/sf1-hub-ben`: `hook_entries` (hook timeout=30) 269-274; `cmd_attach`
  288-360; `human_only`/TTY gating 155-163.
- `packages/sf1-hub-ben/vendor/guard/install.sh`: attached-mode `config.json` `printf` 27.
- `modules/home/services/sf1-hub-ben.nix`: current module body (no activation block yet).
- `modules/home/core/dotfiles.nix`: `claudeSettings` enforced-key `jq` merge (precedent) ~93-128.
- `modules/home/services/claude-session-reaper.nix`: oneshot+timer, always-exit-0 shape
  (precedent).
- `.claude/scripts/claude-refresh.sh`: mako single-default-action `notify-send --wait` idiom
  (precedent), ~1474-1541.

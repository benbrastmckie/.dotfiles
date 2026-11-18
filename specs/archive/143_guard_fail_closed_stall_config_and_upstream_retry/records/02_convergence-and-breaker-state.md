# Convergence and breaker state

Measured at implement time (2026-11-17), re-derived live rather than carried from the plan.

## Apply

`sudo nixos-rebuild switch --flake .#hamsa` was **not run**: `sudo` is categorically denied by
this dispatch's own permission system ("Permission to use Bash with command sudo ... has been
denied"). No agent dispatch in this sandboxed environment can run it — this is a structural
limitation of the environment, not a one-off failure a retry would clear. See
`## Reasoned Exclusions` below.

`home-manager switch --flake .#benjamin` was run twice: once as a `-n` dry run (confirmed the
`DRY_RUN` branch only echoes: `Would force coalesce_s=300 net_timeout_s=15 deadline_s=20 into
every attached checkout's oliver-ben-guard/config.json`, and that `sf1-hub-ben-guard-watch.timer`
would start), then for real. Both real runs exited 0. This is the generation that owns
`~/.nix-profile` and is the one that actually executes `home.activation` and manages
`systemd --user` units, so it alone carries the functional change.

## Checkout convergence

Two attached checkouts, confirmed against `~/.local/state/sf1-hub-ben/manifest.json`'s
`checkouts` keys at implement time (unchanged from plan time):
`~/Projects/Sapience/sapience-app`, `~/Projects/Sapience/sf1-engine`.

| Checkout | Pre-switch | Post-switch |
|---|---|---|
| `sapience-app` | `coalesce_s=300.0, net_timeout_s=15.0, deadline_s=8.0` (already hand-edited on 2026-11-17, except `deadline_s`) | `coalesce_s=300, net_timeout_s=15, deadline_s=20` |
| `sf1-engine` | `coalesce_s=1.0, net_timeout_s=2.0, deadline_s=8.0` (installer defaults, untouched) | `coalesce_s=300, net_timeout_s=15, deadline_s=20` |

Every other key (`me`, `source`, `sink`, `since_ts`, `key_file`, `require_accept`, `mode`) is
byte-identical between the pre- and post-switch capture in both files — confirmed by direct diff,
not inference. A `jq` assertion (`.coalesce_s == 300 and .net_timeout_s == 15 and .deadline_s ==
20`) passes for both checkouts' `config.json`. A second `home-manager switch` left both files's
MD5 sums unchanged (idempotence confirmed).

## Watch timer

`systemctl --user is-active sf1-hub-ben-guard-watch.timer` reports `active`.
`systemctl --user is-failed sf1-hub-ben-guard-watch.service` and `...timer` both report not-failed.
A manual `systemctl --user start sf1-hub-ben-guard-watch.service` exited 0 and its journal shows
exactly two `notified breaker.json for <checkout>` lines (one per checkout) — no `stopped.json`
is present in either checkout at this time, so both live findings are sender-breaker, not
admission-suspend, markers.

## Breaker state (D8), not drained (D9)

Both checkouts' sender breakers (`send()`'s no-retry `breaker.json`, the second surface of the
same upstream defect) are open, confirmed live:

| Checkout | `breaker.json` `at` (epoch) | `at` (local, resolves to the dates the plan recorded) | `error` | Stranded `outbox/*.json` count |
|---|---|---|---|---|
| `sapience-app` | `1794791762.9954727` | 2026-11-15 17:16 (local) | `TimeoutError: The read operation timed out` | 86 |
| `sf1-engine` | `1794726279.2683291` | 2026-11-14 23:04 (local) | `TimeoutError: The read operation timed out` | 113 |

Exact reset command per checkout, deliberately **not run** here (D9 — see this dispatch's
non-blocking `user_decision`, carried forward unchanged from the plan's own `.return-meta.json`):

```bash
sf1-hub-ben's vendored guard CLI, resolved at the store path the running wrapper points to:
python3 /nix/store/w3aayw1y9v332px8chm0y4rzaw6b5d64-sf1-hub-ben-0.2.1-1112/share/sf1-hub-ben/vendor/guard/guard.py send --reset --root /home/benjamin/Projects/Sapience/sapience-app
python3 /nix/store/w3aayw1y9v332px8chm0y4rzaw6b5d64-sf1-hub-ben-0.2.1-1112/share/sf1-hub-ben/vendor/guard/guard.py send --reset --root /home/benjamin/Projects/Sapience/sf1-engine
```

Running either command immediately delivers that checkout's full stranded `outbox/` to the
hosted sink — an outward-facing, irreversible action left to the user.

## No new initiating suspend

`log.jsonl`'s block tally (`sapience-app`) still shows 38 total `"reason": "suspended"` lines, all
downstream repeats of the three initiating failures recorded in the plan's Premise
Re-Validation (the two 2026-11-17 events at 09:46 and 11:49, plus the 2026-11-13 13:35 event). No
new initiating suspend has appeared since the 2026-11-17 11:49 event, and no `stopped.json` is
present in either checkout at implement time.

## Reasoned Exclusions

| Item | Reason | Evidence |
|---|---|---|
| `sudo nixos-rebuild switch --flake .#hamsa` (the NixOS-integrated generation half of Phase 3's Apply step) | `sudo` is categorically denied by this dispatch's own permission system; no agent dispatch in this environment can run it, so there is no agent-actionable residual work — the config has already shipped on the branch and the next ordinary `sudo nixos-rebuild switch` (run by the user, as this module's packaging already requires for every other NixOS-level change) picks it up automatically. The functional goal — both checkouts converged, the watch timer active and not failed — is fully and independently achieved by `home-manager switch --flake .#benjamin` alone, which is the generation that actually owns `~/.nix-profile` and runs `home.activation`. | Literal permission-system denial: `Permission to use Bash with command sudo nixos-rebuild switch --flake .#hamsa ... has been denied.` Post-switch `jq` assertion passes for both checkouts via the standalone path alone; `systemctl --user is-active sf1-hub-ben-guard-watch.timer` reports `active`; manual service start exits 0 with two notifications logged. |

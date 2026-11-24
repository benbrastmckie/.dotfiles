# SF-1 hub runner

The worker half of SF-1 delegation, built for this machine. A background runner reads task
cards from a shared two-person room on [app.spnc.ai](https://app.spnc.ai) and runs each one in a
throwaway git worktree here, driven by this machine's own Claude Code login. A per-repo guard
blocks edits and commits that break a rule both parties accepted in the room. When it cannot
reach the rules it suspends: the action is blocked, a stop marker is written, and every later
controlled action stays blocked until a person runs `guard.py unstop` in a terminal.

This is the piece the client alone cannot reach. `sf1` ships the client half of delegation —
`/delegate claude|codex <task>` is implemented — but it discovers before it posts, and
`GET /v1/sf1/delegate` answers 404 from here, so it prints "Delegation is not on this server
yet" and stops. No runner module is served alongside the client payload under any name. The
worker side is distributed out of band, as a per-person tarball; this is that tarball,
packaged.

Runs nothing on its own. `home-manager switch` installs the CLI and declares the unit, and the
runner makes zero network and zero model calls until [go-live](#5-go-live). Every step that
grants consent or holds a credential is manual by design and cannot be automated — see
[What stays manual](#what-stays-manual).

## How this machine is configured

| Setting | Value | Meaning |
|---------|-------|---------|
| `services.sf1-hub-ben.enable` | `true` | CLI on PATH, unit declared |
| `services.sf1-hub-ben.autoStart` | `false` (default) | Nothing starts at login; start it by hand |
| `services.sf1-hub-ben.claudeBin` | `/etc/profiles/per-user/benjamin/bin/claude` | Pinned, not PATH-resolved |
| Card repo | `~/Projects/Sapience/sapience-app` | Where cards run; named by `SF1_HUB_CARD_REPO` in the env file |
| Consented repos | `sapience-app`, `sf1-engine` | Two markers, each typed by hand; the guard is attached in both |
| Room | `oliver-ben` | Rules at `/v1/projects/oliver-ben/rules` |

Two credentials, neither in the Nix store: the Sapience account token in
`~/.config/sf1-hub-ben/sapience-token` and as `SAPIENCE_TOKEN` in
`~/.config/sf1-hub-ben/env` (both mode 600). It is the same account token Sapience itself uses —
see [sapience.md](sapience.md).

## What is installed

| Component | Origin | Notes |
|-----------|--------|-------|
| `packages/sf1-hub-ben/vendor/` (7 files) | Vendor | Pinned by sha256; the build fails on a mismatch |
| `packages/sf1-hub-ben/sf1-hub-ben` | Vendor | The CLI: `token`, `attach`, `enable`, `serve`, `status`, `kill` |
| `packages/sf1-hub-ben/hub_core_linux.py` | Vendor | Linux platform layer; runs `vendor/hub-runner/runner.py` |
| `modules/home/services/sf1-hub-ben.nix` | This repo | Derivation plus the systemd user unit |
| `sf1-hub-ben.service` | This repo | `Type=simple`, `RestartPreventExitStatus=78`, not `WantedBy` anything |

The vendored tree carries runtime files only. The upstream tarball also ships the author's test
artifacts — a 96KB NixOS container build log among them — which are not kept here. Dropping
them changes nothing about the build: `vendor.lock.json` covers `vendor/` alone, and all seven
hashes verify.

### Why not the upstream flake or install.sh

The package ships both, and both are declined.

Its **flake** pins nixpkgs to `nixos-25.05` while this configuration tracks `nixos-26.05`.
Consumed as an input it would evaluate and realise a second nixpkgs for a derivation whose
entire closure is `python3` and `git`. A `path:` input aimed at a directory inside this very
repository is fragile besides: it records an absolute path in `flake.lock` and complains about a
dirty tree. So the derivation and the unit are restated in
`modules/home/services/sf1-hub-ben.nix`, against the vendored tree, with the same sha256 gate
the upstream build applies.

Its **install.sh** writes a systemd user unit into `~/.config/systemd/user`. That directory is
home-manager's, every entry in it a store symlink, so install.sh detects the conflict and
refuses to write the unit — after having already scattered a non-declarative copy of the binary
under `~/.local/state`. The home-manager route is the only clean one here, which is what this
module is.

## Setup

Steps 1 and 2 are done. The rest is manual and belongs in a real terminal.

### 1. Switch

```bash
cd ~/.dotfiles && ./scripts/update.sh
sf1-hub-ben status          # version, no token, no consented repo, unit inactive
```

Both home-manager paths carry this module, since both import `home.nix` — see
[dual-home-manager.md](dual-home-manager.md). `update.sh` runs them in sequence; either one
alone also works, and `claudeBin` is pinned to the `/etc/profiles/per-user/` path so the unit
resolves the same binary whichever instance rendered it.

### 2. Token

In the web app: Settings, then "Sign in on another device", then copy the private link.

```bash
sf1-hub-ben token           # paste the link; nothing is shown or printed
```

It keeps only the token part, at mode 600. This is the whole credential for the account — there
is no password or second factor — so it never belongs in a chat, a commit or a desktop entry.

### 3. Attach the guard

```bash
sf1-hub-ben attach ~/Projects/Sapience/sapience-app
sf1-hub-ben attach ~/Projects/Sapience/sf1-engine
```

`sapience-app` is the card repo; `sf1-engine` is guarded but never runs cards. Each attach
writes `.git/hooks/{pre-commit,post-commit,post-rewrite}` and adds two hook entries to that
repo's `.claude/settings.local.json`, backing up every file it touches byte-for-byte first.
Then restart Claude Code in each repo, run `/hooks`, and check the guard entry is listed.

The hook entries survive a regeneration of that repo's `.claude/` tree — see
[the generated-tree interaction](#the-guard-and-a-generated-claude-tree) for why that is true
rather than lucky.

### 4. Consent

```bash
sf1-hub-ben enable ~/Projects/Sapience/sapience-app
sf1-hub-ben enable ~/Projects/Sapience/sf1-engine
```

Type the line it shows, exactly. A second question asks whether to share unpushed branches;
pressing Enter keeps it off. It is **on** for both repos here. One marker per repo.

That answer is not recorded in `repos.json` or `manifest.json` — the room holds it, so local
state cannot be used to check which repos share unpushed work.

It refuses to run from Claude Code, from a script, or without a real terminal, and once the
guard is attached no Claude Code session can write the marker either.

### 5. Go live

```bash
systemctl --user start sf1-hub-ben.service
sf1-hub-ben status
sf1-hub-ben golive
```

`golive` is the first network call the runner ever makes. It reads the room once, and goes on
only if the room shows the other side's go-live — its labelled test post, then its digest
message. If not, it stops there, with no other call. Then it makes one rules request and mints
the hub key at mode 600.

A card addressed to this machine then looks like:

```
CARD for:benjamin repo:<slug> base:<sha> files:<glob> accept:<cmd> cites:none dirty:no
<the task, on the next lines>
```

A card waits for an explicit `TAKE C-<n>`. Either side can `HOLD C-<n>`.

Those worktrees sit outside any project path, and Sapience activation here is per-repo, so a
card session sees none of the vault. That is the intent rather than a gap, but it bounds what a
card can draw on — see [sapience.md](sapience.md).

## What stays manual, and why

Every step above from the token onward. `enable` refuses a non-TTY, a script and Claude Code
outright; `attach` and `golive` want a terminal too. None of it belongs in an activation script,
and the module attempts none of it. The point of a typed consent line is that a person typed it.

This also means a `home-manager switch` can never arm the runner, and re-running one over a
working setup changes nothing about consent, tokens or attached repos — those live outside the
store, under `~/.config/sf1-hub-ben/` and `~/.local/state/sf1-hub-ben/`.

## Preflight, and why a refusal does not loop

`serve` runs preflight first and exits 78 (`EX_CONFIG`) if there is no consented repo, the kill
switch is on, the guard is not attached, or the core cannot run cards with the guard hook. The
unit carries `RestartPreventExitStatus=78`, so a refusal is a clean stop rather than a restart
loop — `Restart=on-failure` still covers a genuine crash, at `RestartSec=30`.

Cards run in ONE repo. With a single consented repo that is the one; with several, set
`SF1_HUB_CARD_REPO=<slug>` in `~/.config/sf1-hub-ben/env`.

The unit reads that file through `EnvironmentFile`, so `serve` resolves the card repo. The CLI
does not: `card_repo()` consults `os.environ` alone, while `PERSON` and `BASE` fall back to the
env file. So `sf1-hub-ben preflight`, run by hand with two consented repos, refuses with
`2 consented repos; set SF1_HUB_CARD_REPO=<one of ...> in <env file>` — naming the file it
declined to read. The refusal is not real and the unit is unaffected; export the variable in the
shell to check preflight by hand. `sf1-hub-ben status` is unaffected either way, since it
reports the core's own state, which carries `card_repo`.

That env file is also where `SAPIENCE_TOKEN` lives, and optionally `ANTHROPIC_API_KEY` or
`OPENROUTER_API_KEY` for the card-plan pair (off without them). The runner never hands any
`*_TOKEN` or `*_KEY` variable down to a card.

## What it does not touch

- Nothing under `/usr`, nothing as root. The unit carries `NoNewPrivileges=true`.
- Nothing under `~/.claude` except the memory sync below.
- No working tree. Cards run in worktrees under
  `~/.local/state/sf1-hub-ben/hub/runner/work/`.
- No unpushed branch by default. Opted into per repo at consent time, which is the case for
  both repos here.

Outbound hosts in the entire tree are `app.spnc.ai`, plus `openrouter.ai` when an
`OPENROUTER_API_KEY` is set, which it is not here.

## The guard and a generated `.claude` tree

Worth recording, because the package's own safety check does not cover the arrangement on this
machine and the outcome is nevertheless fine.

`attach` refuses to write `<repo>/.claude/settings.local.json` when that path is Nix-managed,
and its test for that is whether the path resolves into `/nix/store`. The `.claude/` trees here
are not in the store: they are mutable deploy artifacts generated by the agent system's
extension loader from a source store. The test does not fire, and `attach` writes.

Two independent properties of the loader make that safe:

- `settings.local.json` is an **install-once root file**. It is never removed on an extension
  unload, and a full wipe-and-regenerate snapshots it and restores it as the merge base *before*
  the load loop runs, so in-place edits survive.
- The loader's **orphan hook sweep** removes only hook registrations it can assign an identity
  to, which means a `.claude/hooks/*.sh` invocation. The guard's command is an absolute
  interpreter path against a store path, which resolves to no identity — and an identity-less
  registration is explicitly never touched, moved or deduped. Feeding the guard's exact command
  string through the loader's own `hook_identity_cli.lua` returns empty, confirming it.

So the guard's `PreToolUse`/`PostToolUse` entries persist across deploys, and no `.syncprotect`
entry is needed. If either property ever changes, the commit-time `.git` hooks still cover the
repo; only the edit-time check would be lost.

## Memory sync

On by default. Room rulings go into `hub-rulings.md`, plus one pointer line in `MEMORY.md`,
under this machine's Claude Code memory for the card repo. `MEMORY.md` is backed up first and
restored byte-for-byte on uninstall.

Home-manager owns none of `~/.claude` here — `sf1-hub-ben status` reports
`claude_dir_nix_managed` as false for the directory, `settings.json` and `projects` alike — so
the sync works rather than silently disabling itself. Were any of that path to become a
read-only store link, sync would turn itself off and `status` would say why; the guard and the
room would still carry the rulings.

## Guard network knobs, and the Transient/Suspend split that governs a route fault

The guard's admission path (`admit()` in `vendor/guard/guard.py`) consults the hosted rules
route on nearly every controlled action, bounded by three knobs in each attached checkout's own
`.git/oliver-ben-guard/config.json`:

| Knob | Declared value | Meaning |
|---|---|---|
| `coalesce_s` | `300` | How long a cached rules check is trusted before the next controlled action makes a fresh network round trip |
| `net_timeout_s` | `15` | Socket timeout on the rules-route request |
| `deadline_s` | `20` | Internal `SIGALRM` around the whole rules evaluation; must exceed `net_timeout_s` and stay under the Claude Code hook's own 30-second timeout |

`modules/home/services/sf1-hub-ben.nix`'s `home.activation.sf1HubBenGuardConfig` is where these
are declared. `sf1-hub-ben attach` (and the vendored `install.sh`, were it used) writes the
installer defaults — `coalesce_s=300.0`, `net_timeout_s=5.0`, `deadline_s=10.0`, preserving
`net_timeout_s`/`deadline_s`/`retry_timeouts`/`transient_cooldown_s`/`cache_grace_s` from an
existing `config.json` on a re-attach — into a fresh `config.json`; the activation step
re-converges every attached checkout's `config.json` back to the declared values on every
`home-manager switch`, so a re-`attach` cannot silently revert them. These three knobs are a
**frequency lever only**: they bound how often the guard talks to the route and how long it
waits, but they do not decide what happens on a failure. That decision belongs to a separate
split in the guard's own source.

**These knobs are a frequency lever, not the mechanism that decides a failure's outcome.** The
guard's `Transient`/`Suspend` exception split is what governs that: on the engine-free rules
route, a transport fault, a 5xx, a timeout, or a `DeadlineHit` raises `Transient`, which serves
the last cached rules revision and logs a warning to `log.jsonl` — it never writes `stopped.json`
and never blocks the action. An HTTP 401/403, a not-a-member response, a wrong-schema reply, or a
missing local source raises `Suspend`, which does write the sticky `stopped.json`, exactly as a
deliberate human `guard.py stop` does. A one-time migration (`migrations/nostall-1117.json`)
moves aside any `stopped.json` or `breaker.json` a network error caused, leaving an authority
stop in place; it fires once per checkout, on the first run of the fixed guard.

**Freshness cost, paid deliberately**: at `coalesce_s=300`, a rule accepted in the room does not
bind on this machine until the window expires — up to 5 minutes. Once the room's rule set stops
being empty (see the `Known gaps` entry below), this should drop to roughly 60 seconds by hand,
cutting the lag to at most 1 minute at roughly 5x the admission round trips. Nix evaluation
cannot see the room's live rule count, so this stays a deliberate manual edit plus a switch, not
something this module infers on its own.

**Measured incident history**: ten distinct suspension episodes are recorded in this machine's
`.git/oliver-ben-guard/outbox/*.json` `what: "suspended"`/`"unstopped"` pairs between
2026-11-15T07:04Z and 2026-11-22T17:58Z, every one a transient network or server fault against
`app.spnc.ai` and none an authority refusal: 5 `URLError`, 3 `TimeoutError`, 1 `DeadlineHit`, 1
HTTP 502. Each episode latched `stopped.json` until a person ran `guard.py unstop`, which is the
`Transient`/`Suspend` split's reason for existing: `net_timeout_s=15` gives the round trip real
headroom against a blip like this, and `coalesce_s=300` cuts how often a dispatch makes the round
trip at all (the lever on failure *volume*), but neither knob stops a failure that does happen
from latching a stop — only the Transient/Suspend split does that, by not suspending on a
transport/5xx/timeout/`DeadlineHit` failure in the first place. The vendored guard's own
`MIN_PULL_GAP_S = 10` floor, and its docstring's "network pulls are at least 10 s apart" claim,
are enforced only in the legacy pre-attached code path — attached mode's `admit()` never
references it, so it is not treated as a protective floor here.

### Watch timer

`systemd.user.services.sf1-hub-ben-guard-watch` (oneshot) plus
`systemd.user.timers.sf1-hub-ben-guard-watch` (`OnCalendar = "*:0/2"`) make a new fail-closed
marker visible without reading `log.jsonl`. Every two minutes it checks each attached checkout
for a new or newer `stopped.json` (admission suspend) or `breaker.json` (sender breaker, see
below) and fires one `notify-send -a sf1-hub-ben -u critical -t 0` per new marker, naming the
checkout, the marker kind, the recorded error, and the exact remediation command. It is
notify-only by design: a one-click action would need `notify-send --wait -t 0`, which inside a
timer-driven oneshot would hold the unit active indefinitely and block later timer activations.
A per-checkout, per-marker mtime file under `~/.local/state/sf1-hub-ben/watch/` keeps a marker
from re-notifying on every two-minute tick once it has already been reported once.

## Known gaps

- An nvim plugin that calls the API directly, without Claude Code, gets no edit-time check. Only
  the commit-time hook covers it.
- Claude Code hook behaviour has to be re-measured per version. On 2.1.322 a hook that exits 1
  or times out lets the action through, which is why the guard's command ends in `|| exit 2`.
- The guard enforces nothing until a rule is accepted in the room. Both repos currently cache
  revision 1 with an empty `kos` list, and `require_accept` is on. Attached mode admits every
  controlled action silently in that state; only the detached path prints `NO RULES LOADED`. An
  attached guard with an empty ruleset looks identical to a working one at the point of use.
- `prepare()` restages the runner files with `shutil.copy2`, which carries the source mode
  across. From the read-only store the copies land read-only and the next start cannot overwrite
  them: `PermissionError` on `runner.py`, reported as `core prepare failed`, exit 78. The unit's
  `ExecStartPre` chmod covers it — see [Upgrading](#upgrading).
- An attached guard with an empty ruleset enforces nothing and looks identical to a working one
  at the point of use, which is also why staying attached in both repos costs nothing in false
  positives right now. Whether and when real rules land in the room is one open question for
  Oliver. The other is server-side: `app.spnc.ai`'s rules route itself returns a 5xx or times out
  often enough to be the dominant initiating cause behind every admission episode recorded in
  [Guard network knobs](#guard-network-knobs-and-the-transientsuspend-split-that-governs-a-route-fault)
  above; the client-side `Transient`/`Suspend` split makes that survivable (no stop latches), but
  does not address the route's own failure rate, which is not reachable from this machine.
- The sender half of the guard (`send()`, `breaker.json`) shares the same `Transient`/`Suspend`
  split as the admission half: a sink timeout, connection error, or 5xx keeps the event in the
  outbox and the next event (or the next successful rules read) re-attempts delivery, with no
  sticky breaker opened and nothing lost. A sink's own HTTP 400 (a real protocol refusal, not a
  transport fault) still opens the breaker, exactly as a commit-event authority refusal should.
  `sf1-hub-ben send --reset` remains the way to force an immediate flush of everything still
  queued in a checkout's `outbox/` — see [Stopping it](#stopping-it) for the command.

## Stopping it

```bash
sf1-hub-ben kill                              # stops the runner and every card it started
sf1-hub-ben unkill                            # only you, in a terminal, undo it
sf1-hub-ben detach ~/Projects/Sapience/sapience-app    # guard off in one repo, hooks restored byte-for-byte
sf1-hub-ben uninstall                         # kill, detach everywhere, remove every installed file
```

`kill` writes `~/.config/sf1-hub-ben/KILL`, which the unit carries as
`ConditionPathExists=!…`. Being a file rather than a unit state, it holds across a restart, a
relogin and a `home-manager switch`. Anyone may run it, an agent included; only `unkill`, typed
in a terminal, lifts it.

### Clearing a fail-closed marker

The watch timer's notification already carries the exact command for whichever marker it found;
both forms are recorded here too. `guard.py`'s own store path is also printed in the attached
repo's `.claude/settings.local.json` hook command, if the notification is not at hand.

```bash
# Admission suspended (stopped.json): the next controlled action reads the rules source once more
python3 <guard.py store path> unstop --root <checkout>

# Sender breaker open (breaker.json): drains the outbox to the sink immediately on reset
python3 <guard.py store path> send --reset --root <checkout>
```

`unstop` is cheap and reversible-in-effect — it only clears the local marker, and the next
controlled action simply tries the network again. `send --reset` is not: it immediately delivers
every event queued in that checkout's `outbox/` since the breaker opened, which can be several
days' worth, so check the sink is actually wanted before running it.

To remove the packaging as well, set `services.sf1-hub-ben.enable = false` in `home.nix` and
switch. Run `sf1-hub-ben uninstall` **first** — once the CLI is off PATH, the attached repos'
hooks and the state directory are left behind with nothing to clean them up.

## Upgrading

A new per-person tarball replaces `packages/sf1-hub-ben/`: drop in the runtime files, keep
`test/` and `tests/` out, and rebuild. The sha256 gate in the derivation verifies the new
`vendor/` against the new `vendor.lock.json`, so a truncated or tampered payload fails the build
instead of reaching the runner. `VERSION` feeds the derivation's version string, so the store
path moves and the unit picks up the new binary on the next switch.

Check `sf1-hub-ben status` afterwards: `core_sha256` and `guard_sha256` should both change, and
`consented_repos` should not.

Keep the unit's `ExecStartPre` chmod when editing the module. `prepare()` restages the runner
files on every start with `shutil.copy2`, so without it the first start after a rebuild succeeds
and every later one fails with exit 78 — which reads as a consent fault rather than a
permissions one.

**The store path moving reaches the systemd unit automatically; it does not reach a Claude Code
hook on its own.** `claudeBin` and the unit's `ExecStart` are declared against the Nix store or
against `/home/benjamin/.nix-profile/...`, so the unit picks up a new store path on the next
`home-manager switch` with no further action. A per-repo Claude Code hook command is different:
its `PreToolUse`/`PostToolUse` entries in `<repo>/.claude/settings.local.json` are literal
strings, each resolved once at `attach` time. Writing a fresh store path into that string
(`/nix/store/<hash>-sf1-hub-ben-.../share/sf1-hub-ben/vendor/guard/guard.py`) would need
re-pointing on every single re-vendor, because the derivation's output hash moves on every
content change. Both attached checkouts here instead name the generation-tracking profile path —
`/home/benjamin/.nix-profile/bin/python3` and
`/home/benjamin/.nix-profile/share/sf1-hub-ben/vendor/guard/guard.py` — which resolves through
the active home-manager generation and so follows every future `home-manager switch` without
edit. A `sf1-hub-ben attach` re-run writes a literal store path back into the hook command
(it does not know about the profile-path convention) and would need this same correction again.

**Vendor-lineage drift.** `packages/sf1-hub-ben/vendor/guard/` here and the sf1-engine
repository's own `hub/guard/` are separate lineages: a commit to the latter does nothing on this
machine until it is re-vendored into the former with `vendor.lock.json`'s sha256 pins updated
(see [What is installed](#what-is-installed)), and the two can silently diverge in the meantime.
Check the live drift with:

```bash
cmp ~/Projects/Sapience/sf1-engine/hub/guard/guard.py $(readlink -f ~/.nix-profile/share/sf1-hub-ben/vendor/guard/guard.py)
```

No output means the two are byte-identical; any `differ` line means sf1-engine's `hub/guard/`
carries a change this machine has not yet re-vendored.

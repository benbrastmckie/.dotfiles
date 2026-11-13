# SF-1 hub runner

The worker half of SF-1 delegation, built for this machine. A background runner reads task
cards from a shared two-person room on [app.spnc.ai](https://app.spnc.ai) and runs each one in a
throwaway git worktree here, driven by this machine's own Claude Code login. A per-repo guard
blocks edits and commits that break a rule both parties accepted in the room, and fails closed
when it cannot reach the rules.

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
| Card repo | `~/Projects/Sapience/sapience-app` | The shared project; one consent marker, typed by hand |
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
```

This writes `.git/hooks/{pre-commit,post-commit,post-rewrite}` and adds two hook entries to that
repo's `.claude/settings.local.json`, backing up every file it touches byte-for-byte first.
Then restart Claude Code in that repo, run `/hooks`, and check the guard entry is listed.

The hook entries survive a regeneration of that repo's `.claude/` tree — see
[the generated-tree interaction](#the-guard-and-a-generated-claude-tree) for why that is true
rather than lucky.

### 4. Consent

```bash
sf1-hub-ben enable ~/Projects/Sapience/sapience-app
```

Type the line it shows, exactly. A second question asks whether to share unpushed branches;
press Enter to keep that off. One marker per repo.

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

That env file is also where `SAPIENCE_TOKEN` lives, and optionally `ANTHROPIC_API_KEY` or
`OPENROUTER_API_KEY` for the card-plan pair (off without them). The runner never hands any
`*_TOKEN` or `*_KEY` variable down to a card.

## What it does not touch

- Nothing under `/usr`, nothing as root. The unit carries `NoNewPrivileges=true`.
- Nothing under `~/.claude` except the memory sync below.
- No working tree. Cards run in worktrees under
  `~/.local/state/sf1-hub-ben/hub/runner/work/`.
- No unpushed branch, unless opted into per repo at consent time.

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

## Known gaps

- An nvim plugin that calls the API directly, without Claude Code, gets no edit-time check. Only
  the commit-time hook covers it.
- Claude Code hook behaviour has to be re-measured per version. On 2.1.322 a hook that exits 1
  or times out lets the action through, which is why the guard's command ends in `|| exit 2`.

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

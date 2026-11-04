# Sapience

[Sapience](https://app.spnc.ai) reads AI-session transcripts (`~/.claude/projects`,
`~/.codex/sessions`), extracts durable facts from them, and serves those facts back as a
searchable vault plus an MCP server that Claude Code can query mid-session.

The vendor ships a macOS-only installer that writes a launchd plist, drops shims in `~/bin`, and
appends to a shell rc file. None of that works or belongs on NixOS. Its payload, however, needs
no packaging work at all: ten pure-stdlib Python 3 files, no third-party imports, with `git` the
only external binary any of them invokes. So `modules/home/services/sapience.nix` replaces the
installer's plumbing and leaves the payload alone.

**If you are setting this up for the first time, skip to [First-time
setup](#first-time-setup).** The short version is `sapience-bootstrap`, then
`home-manager switch` a second time, then `sapience review`. Nothing reads a transcript until
you bootstrap, and nothing is uploaded until you review.

## What is installed

| Component | Origin | Notes |
|-----------|--------|-------|
| `~/.sapience/*.py` (10 files) | Vendor | Seeded on activation when absent, then left alone |
| `sapience` | Reimplemented | Same subcommand dispatch as the vendor's `~/bin` shim |
| `sf1` | Reimplemented | Terminal chat with the vault |
| `sapience-bootstrap` | This repo | No vendor counterpart; replaces the installer's macOS half |
| `sapience-sync.service` / `.timer` | This repo | Replaces the launchd plist; hourly |
| `ollama.service` / `ollama-model-loader.service` | This repo | `modules/home/services/ollama.nix` |
| `mcpServers.sapience` in `~/.claude.json` | This repo | Merged on activation, preserving every other key |
| Three hooks and seven tool grants | This repo | In `config/claude/settings.json`; see [below](#why-the-hooks-live-in-the-repo) |

The vendor docs will tell you to "run the install line again" to re-point a machine or recover a
token. Do not — that is the macOS script. The equivalents here are `sapience-bootstrap` for a
fresh setup or a new token, and `sapience update` (which is the vendor's own, and works) to
refresh the payload.

## First-time setup

The module is enabled in `home.nix`, but it is inert until a token exists. The sync unit carries
`ConditionPathExists=~/.sapience/config.json`, so before bootstrap it reports `condition failed`
rather than running or failing.

1. **Get a token.** In the web app: Settings, then "Sign in on another device", then copy the
   private link. The token is that link's `token=` parameter. It is the entire credential for
   the account — there is no password or second factor — so treat it like one.

2. **Bootstrap.** Run it in a terminal — the vendor refuses onboarding without a TTY, to avoid
   silently replacing your folder choices (`SAPIENCE_ALLOW_ONBOARD=1` overrides, but then it
   picks for you):

   ```bash
   sapience-bootstrap                      # prompts for the token
   SAPIENCE_TOKEN=<tok> sapience-bootstrap # or skip the prompt
   ```

   This writes `~/.sapience/config.json` (mode 600) with the token, backend and host, confirms
   the payload is present, then hands off to the vendor's own onboarding, which lists every
   candidate project folder with file counts for you to tick.

   If a scheduled sync is running, bootstrap says so and stops it, so your run has the local
   model to itself. Nothing is lost by that; the timer picks the work up again on schedule.
   Re-running bootstrap later skips the token step and just re-opens the picker.

3. **Switch again.**

   ```bash
   cd ~/.dotfiles && home-manager switch --flake .#benjamin
   ```

   The first switch could not put a token in `~/.claude.json` because none existed. This one
   can. Without it, `sapience status` keeps reporting Claude Code as "not registered". Restart
   Claude Code afterwards: MCP servers are snapshotted at session start.

4. **Run and review.**

   ```bash
   systemctl --user start sapience-sync.service   # rather than waiting for the timer
   sapience coverage                              # what was read, what was skipped, and why
   sapience pending                               # how many findings are staged
   sapience review                                # approve; only now does anything upload
   ```

For history rather than only new work, `sapience backfill 365`. Expect it to be slow: an 8B
model on CPU, one chunk at a time.

## Everyday use

`sapience help` lists every subcommand; `sapience review`, `coverage`, `pending` and
`sf1 "a question"` are the ones used day to day.

### Watching a run

Extraction is **silent by design**: the vendor prints "Extracting knowledge from N sources" and
then nothing until it finishes. There is no verbose flag, nothing is flushed per source, and the
staging queue is written only at the end, so mid-run there is no file to inspect either. On a
local model a capped run is roughly 50 model calls at tens of seconds each, so several silent
minutes are normal and indistinguishable from a hang.

`sapience-bootstrap` therefore shows progress itself, with nothing extra to run:

```
  extracting: 96 chunks done (~36s each), 40m00s elapsed
```

It rewrites that single line every ten seconds, counting completed model calls from the Ollama
journal — which logs one `release:` per completion, the only live signal there is. The line goes
to stderr so it cannot corrupt the vendor's stdout, appears only when stderr is a terminal, and
stays silent until the first call completes, which keeps it clear of the interactive folder
picker that runs first.

Only bootstrap has this. `sapience sync` and `sapience backfill` go straight to the vendor
script and are as silent as it is, as is the timer; for those, watch the model directly with
`journalctl --user -fu ollama`, or the unit with `journalctl --user -fu sapience-sync`, and
check `sapience pending` afterwards.

Scheduling is systemd rather than launchd, which is the other thing the vendor docs get wrong:

```bash
systemctl --user status sapience-sync.timer
systemctl --user start sapience-sync.service      # run now
systemctl --user disable --now sapience-sync.timer # pause background learning
journalctl --user -fu sapience-sync                # logs (not ~/.sapience/sync.log)
```

## Where your data goes

This is the part worth understanding before ticking folders.

**In scope:** transcripts under `~/.claude/projects` and `~/.codex/sessions`, for the projects
you tick. The vendor's deny list refuses `$HOME` itself, `~/Documents` and `~/Downloads`
wholesale, `Desktop`/`Pictures`/`Library`, every dotfolder, `.env`, `*.pem` and SSH keys — with
`.claude` and `.codex` carved out as the exception, since those hold the transcripts.

**Redaction** runs on-device before anything leaves, but catches high-confidence secret shapes
only: PEM blocks, provider key prefixes, JWTs, `password|secret|token|api_key = value`
assignments, connection strings with inline credentials, emails, phones, SSNs and Luhn-valid
card numbers. It deliberately leaves ordinary prose alone, so your text, code, file paths,
project names and architecture are not redacted.

Backend choice decides what crosses the wire:

| Backend | Transcript text leaves? | Gated by review? |
|---------|------------------------|------------------|
| `ollama` (configured here) | No | — |
| `relay` (vendor default) | Yes, redacted chunks via `app.spnc.ai` | **No** |
| `anthropic` / `openai` | Yes, redacted, to that provider on your own API key | No |

Redaction applies on every path, including the API backends — `extract_local.py:2264` redacts
each chunk before the provider call, with the comment "keep secrets out of the model's view (and
your own provider)". The installer's phrase "raw text goes straight to your provider" means
*direct rather than via us*, not *unredacted*.

The `relay` row is the one that surprises people: extraction happens server-side, so chunks are
POSTed before the review gate applies. Auto-approve controls whether facts are *stored in your
vault*, not whether transcripts are *transmitted*.

On every backend, approved findings are uploaded, and those findings are model-written sentences
instructed to keep "exact numbers, thresholds, config values, decisions and their reason". So
"conversations never leave this machine" is true under `ollama` and still not the whole story.
With `auto_approve: false` as configured here, they sit staged until `sapience review`.

## Design decisions

### Not packaged as a derivation

Upstream has no releases, tags or content hashes; it serves the payload live from
`app.spnc.ai/<name>.py` and self-updates two ways (`sapience update`, and a background
`--auto-update` that `mcp.py` spawns on its own). A pinned `fetchurl` would break its hash on
every upstream push *and* be fought by the updater. So `~/.sapience/*.py` is deliberately
mutable state: activation seeds files only when absent and never overwrites them. Nix owns the
wrappers, the units and the registration; upstream owns the payload.

### Home-manager, not NixOS

The NixOS `services.ollama` has `loadModels`, which the home-manager module lacks, so the model
pull is hand-rolled here. That cost buys one rebuild path: the server runs as this user against
`~/.ollama`, needs no sudo, and the whole feature applies with `home-manager switch` rather than
splitting the model store across a system rebuild and its only consumer across a home rebuild.

### CPU inference

This machine's GPU is a Radeon 890M (`gfx1150`, RDNA 3.5), where ROCm is experimental and
typically needs an `HSA_OVERRIDE_GFX_VERSION` override plus a multi-gigabyte closure. The
workload is an hourly background job on 24 Ryzen cores, where latency is irrelevant. To revisit,
set `services.ollama.acceleration = "rocm"` and expect to tune the gfx override.

### Memory-file ingestion is off

Sapience walks each selected project root for `CLAUDE.md`, `MEMORY.md`, `AGENTS.md`,
`docs/BACKLOG.md` and `.claude/rules/*.md`, then tags the result at its highest confidence tier
as "curated truth" outranking session-extracted findings.

On this machine those files are not curated truth. Every `.claude/` tree is a generated deploy
artifact, produced from the source store at `~/.config/nvim/agent-system` by the extension
loader in `~/.config/nvim/lua/neotex/plugins/ai/shared/extensions/`, and over twenty
repositories carry one — the generated `CLAUDE.md` says so in its own header. Ingesting them
would import twenty-odd near-identical copies of scaffolding at the highest trust tier,
outranking real findings. Turn it on only if the source store itself becomes the selected
project, where those files are authored rather than deployed.

### One bootstrap at a time, and never during a switch

Two separate hazards, both found by running this for real.

`sapience-bootstrap` takes a dedicated `.bootstrap.lock`, deliberately **not** the vendor's
shared `.run.lock`, so the only thing that can turn a bootstrap away is another bootstrap. A
scheduled sync never blocks it: bootstrap stops that sync instead and takes precedence, which
loses no work because the vendor leaves its files un-marked for the next run. It then holds
`.run.lock` for the extraction alone, so a timer firing mid-run is skipped by the vendor's own
guard rather than competing for the model; if that lock cannot be had it continues anyway, since
being slower beats refusing a run you asked for.

There is no cooldown and no stale-lock state to clear. `flock` holds nothing on disk — the lock
lives only as long as some process holds the open file descriptor — so an interrupted, crashed
or killed bootstrap frees it the instant the process goes, and the next run starts immediately.

Separately, `sapience-sync.service` is marked `X-SwitchMethod = "keep-old"`. Without it
`sd-switch` restarts the unit on every activation, which kills an in-flight extraction *and*
blocks `home-manager switch` until the replacement finishes — tens of minutes on CPU. The timer
picks up a changed definition on its next fire instead.

### The token never enters the Nix store

Every client falls back to `~/.sapience/config.json` when `SAPIENCE_TOKEN` is unset, so the
wrappers and the sync unit pass no token at all. The `~/.claude.json` entry gets one, read at
activation time from that mode-600 file, purely so `sapience status` can report matching
fingerprints across surfaces. The `tokenFile` option exists for a non-interactive bootstrap and
must point outside the store — a store path would be world-readable.

### Why the hooks live in the repo

`home.activation.claudeSettings` treats `hooks` and `permissions` as enforced keys, resetting
them from `config/claude/settings.json` on every switch, so anything a vendor installer wrote
into the live file would be reverted. The three hooks and seven `mcp__sapience__*` grants live
in the repo file for that reason, each guarded with a `[ -f ~/.sapience/mcp.py ]` test and
`|| true` so they are inert before bootstrap and harmless if the client is removed.

`statusLine` is deliberately not wired: that slot belongs to `hooks/statusline-push.sh`, and
composing them would mean editing the agent-system source store rather than the deployed
artifact. Append `python3 ~/.sapience/mcp.py --statusline` output to that script there if you
want the segment.

The `Stop` hook makes one outbound request per assistant turn. It uploads no content — a session
id out, a line back — but it is a continuous activity signal. Drop that entry if you would
rather not have it; nothing else depends on it.

## Module options

`programs.sapience`:

| Option | Default | Purpose |
|--------|---------|---------|
| `enable` | `false` | CLI, timer, payload seed, MCP registration |
| `backend` | `"ollama"` | `relay`, `anthropic`, `openai`, `ollama` |
| `host` | `"https://app.spnc.ai"` | API host, also the payload source |
| `tokenFile` | `null` | Path outside the store for non-interactive bootstrap |
| `syncInterval` | `"hourly"` | `OnCalendar` for the background sync |
| `memoryFiles` | `false` | See [above](#memory-file-ingestion-is-off) |
| `registerMcpServer` | `true` | Merge into `~/.claude.json` |

`services.ollamaModels`:

| Option | Default | Purpose |
|--------|---------|---------|
| `enable` | `false` | Local server plus the model loader |
| `load` | `[ "llama3.1" ]` | Models to pull; roughly 4.9 GB for this one |
| `pullTimeoutSec` | `3600` | Ceiling for a cold multi-gigabyte pull |

Setting `backend = "ollama"` without `services.ollamaModels.enable` emits a build warning rather
than an assertion, so a missing inference server never blocks an unrelated rebuild.

## Inspection recipes

```bash
# Is the whole chain healthy?
systemctl --user is-active ollama.service sapience-sync.timer
systemctl --user show sapience-sync.service -p ConditionResult -p Result

# Pre-bootstrap, the expected answer is ConditionResult=no with Result=success:
# condition-failed, so the unit never latches a false success and recovers once
# config.json appears.

# Did the model land, and does inference actually work?
curl -fsS http://127.0.0.1:11434/api/tags | jq -r '.models[].name'
journalctl --user -u ollama-model-loader -n 20

# Is the payload seeded, and is the MCP server registered?
ls ~/.sapience/
jq '.mcpServers.sapience' ~/.claude.json

# What did the last sync actually read?
sapience coverage
journalctl --user -u sapience-sync -n 50
```

## Known gaps

**Most sessions here will be skipped, by two separate filters.** Expect coverage well below
the session counts the folder picker shows.

The first is overridable. A transcript must have at least two distinct substantive human turns,
a predicate that exists to drop "benchmark loops, agent runs, probes"; `sapience coverage`
reports these as `skipped (headless/agent)`. Widen one run with `sapience sync
--include-agents`. The hourly unit would need `SAPIENCE_INCLUDE_HEADLESS=1` in its environment,
which is deliberately not an option here: agent transcripts are long and repetitive, and on a
local 8B model they would dominate both runtime and the vault.

The second is not overridable at all. `source_skip()` in `upload.py` classifies each transcript
as `subagent` or `harness-started` from its opening turns and those are never read — the run
logs them as `skipped (subagent / harness-started transcripts) ... thread mechanics; never
read`, and the message states outright that `SAPIENCE_INCLUDE_HEADLESS=1` does not override it.
Verdicts are cached in `~/.sapience/source_rules.json`. Given how much work here runs through
orchestrated dispatch, this filter removes more than the first one does.

**One deny-list gap worth knowing.** `~/Documents/Personal/...` is correctly refused, because
`personal` is on the vendor's denied-names list. `~/Documents/Employment/Applications` is not:
neither word is on that list, and `Applications` is only denied as a top-level folder. Both
carry `.claude/` trees, so untick that one in the folder picker.

**Stopping the sync service does not stop the timer**, deliberately. The sibling timer modules
in this repo carry `Requires = [ "<name>.service" ]`, which stop-propagates: stopping the
service would also deactivate the timer and silently end background learning. This module's
timer omits it, because the service does get stopped in normal use — `sapience-bootstrap` stops
it to claim the model, and the pause recipe above stops it by hand. A timer activates its
same-named service by default, so the dependency bought nothing.

**The hourly run skips the per-run keep prompt.** `--sync` is non-interactive by design, so
staging is all-or-nothing until you run `sapience review`.

**A run is capped at 50 chunks.** `MAX_CHUNKS` defaults to 50, so a first pass over a large
backlog covers only part of it and the rest waits for later runs; files are left un-marked, so
nothing is lost. `sapience backfill 365` raises the cap for one wide pass.

## Rollback

The two modules are independent and revert separately.

```nix
programs.sapience.enable = false;      # removes CLI, units, activation entries
services.ollamaModels.enable = false;  # removes the server and the model loader
```

Disabling `programs.sapience` leaves three things behind on purpose, since none are Nix-managed
state: `~/.sapience/` (payload, token, folder choices, review queue), the
`mcpServers.sapience` key in `~/.claude.json`, and the models in `~/.ollama`. Remove them by
hand if you want them gone:

```bash
rm -rf ~/.sapience
jq 'del(.mcpServers.sapience)' ~/.claude.json > /tmp/cj && mv /tmp/cj ~/.claude.json
ollama rm llama3.1
```

The hooks and tool grants go away by deleting their entries from
`config/claude/settings.json`; because those keys are enforced, the next switch resets the live
file to match. The hosted vault is untouched by any of this — `sapience reset` clears local
state only.

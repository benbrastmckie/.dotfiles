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
`home-manager switch` a second time, then `sapience review`. Nothing reads a transcript and
nothing is uploaded until you do both.

## What is installed

| Component | Origin | Notes |
|-----------|--------|-------|
| `~/.sapience/*.py` (10 files) | Vendor | Seeded on activation when absent, then left alone |
| `sapience` | Reimplemented | Same subcommand dispatch as the vendor's `~/bin` shim |
| `sf1` | Reimplemented | Terminal chat with the vault |
| `sapience-bootstrap` | This repo | No vendor counterpart; replaces the installer's macOS half |
| `sapience-progress` | This repo | No vendor counterpart; makes a silent run observable |
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

2. **Bootstrap.** Needs a real TTY for the folder picker, so run it in a terminal:

   ```bash
   sapience-bootstrap                      # prompts for the token
   SAPIENCE_TOKEN=<tok> sapience-bootstrap # or skip the prompt
   ```

   This writes `~/.sapience/config.json` (mode 600) with the token, backend and host, confirms
   the payload is present, then hands off to the vendor's own onboarding, which lists every
   candidate project folder with file counts for you to tick.

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

`sapience-progress` exists for that. It reports which run is active and for how long, completed
and started model calls, mean seconds per call, and the staged count once the queue appears:

```bash
sapience-progress            # one snapshot
sapience-progress --watch    # refresh every 5s; --watch 10 for a slower tick
```

Its numbers come from the Ollama journal, which logs one `processing task` per model call and
one `release` per completion — the only live signal available. That is server-wide, so if two
extractions overlap the counts are shared; the output says so when it detects more than one.

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
| `anthropic` / `openai` | Yes, raw, to that provider on your own API key | No |

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

### One run at a time, and never during a switch

Two separate hazards, both found by running this for real.

`extract_local.py` takes its own `.run.lock` only for `--sync` and `--backfill`, so the
interactive onboarding run is unprotected. Since bootstrap writes `config.json` before
onboarding, and the timer's `ConditionPathExists` is satisfied the moment that file appears, the
timer can fire straight into an in-progress onboarding — two extractions then share one local
model and both crawl. `sapience-bootstrap` therefore re-execs itself under `flock` on the
vendor's own lock file, holding it across the whole run rather than inventing a second mutex, so
the vendor's guard sees it held and skips. If a scheduled run already holds it, bootstrap refuses
with the command to stop that run.

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

# Is a run in progress, and how fast?
sapience-progress --watch

# What did the last sync actually read?
sapience coverage
journalctl --user -u sapience-sync -n 50
```

## Known gaps

**Most sessions here will be skipped.** The vendor filters transcripts through a predicate
requiring at least two distinct substantive human turns, which exists to drop "benchmark loops,
agent runs, probes". Orchestrated dispatches and subagent runs read as headless, and
`sapience coverage` reports them as `skipped (headless/agent)`. Widen a single run with
`sapience sync --include-agents`. The hourly unit would need `SAPIENCE_INCLUDE_HEADLESS=1` in
its environment, which is not currently an option: agent transcripts are long and repetitive,
and on a local 8B model they would dominate both runtime and the vault.

**One deny-list gap worth knowing.** `~/Documents/Personal/...` is correctly refused, because
`personal` is on the vendor's denied-names list. `~/Documents/Employment/Applications` is not:
neither word is on that list, and `Applications` is only denied as a top-level folder. Both
carry `.claude/` trees, so untick that one in the folder picker.

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

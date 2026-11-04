# Sapience

[Sapience](https://app.spnc.ai) reads AI-session transcripts (`~/.claude/projects`,
`~/.codex/sessions`), extracts durable facts from them, and serves those facts back as a
searchable vault plus an MCP server that Claude Code can query mid-session.

The vendor ships a macOS-only installer that writes a launchd plist, drops shims in `~/bin`, and
appends to a shell rc file. None of that works or belongs on NixOS. Its payload, however, needs
no packaging work at all: ten pure-stdlib Python 3 files, no third-party imports, with `git` the
only external binary any of them invokes. So `modules/home/services/sapience.nix` replaces the
installer's plumbing and leaves the payload alone.

## How this machine is configured

| Setting | Value | Meaning |
|---------|-------|---------|
| `programs.sapience.backend` | `"ollama"` | All traffic goes through the local Ollama daemon |
| `programs.sapience.model` | `"gemma4:cloud"` | …which forwards it to `ollama.com`; nothing is inferred locally |
| `services.ollamaModels.load` | `[ ]` | A cloud model has no weights to pull |
| `programs.sapience.memoryFiles` | `false` | `CLAUDE.md` and friends are not ingested |
| `config.json: auto_approve` | `false` | Findings stage until `sapience review` |
| `programs.sapience.backgroundSync` | `false` | No timer; extraction runs only when asked |

Two credentials, in two places, neither in the Nix store: the Sapience account token in
`~/.sapience/config.json` (mode 600), and the Ollama account keypair in `~/.ollama/id_ed25519`.

**Setting up a new machine** is three commands: `ollama signin`, `sapience-bootstrap`,
`home-manager switch`. See [First-time setup](#first-time-setup). Nothing reads a transcript
until you bootstrap, nothing re-reads one until you ask
([no schedule](#nothing-extracts-on-a-schedule)), and nothing is uploaded until you review.

## What is installed

| Component | Origin | Notes |
|-----------|--------|-------|
| `~/.sapience/*.py` (10 files) | Vendor | Seeded on activation when absent, then left alone |
| `sapience` | Reimplemented | Same subcommand dispatch as the vendor's `~/bin` shim |
| `sf1` | Reimplemented | Terminal chat with the vault |
| `sapience-bootstrap` | This repo | No vendor counterpart; replaces the installer's macOS half |
| `sapience-sync.service` | This repo | On-demand detached run; replaces the launchd plist |
| `ollama.service` / `ollama-model-loader.service` | This repo | `modules/home/services/ollama.nix` |
| `mcpServers.sapience` in `~/.claude.json` | This repo | Merged on activation, preserving every other key |
| Token shape repair in `config.json` | This repo | Activation entry; runs before the MCP merge |
| Three hooks and seven tool grants | This repo | In `config/claude/settings.json`; see [below](#why-the-hooks-live-in-the-repo) |

The vendor docs will tell you to "run the install line again" to re-point a machine or recover a
token. Do not — that is the macOS script. The equivalents here are `sapience-bootstrap` for a
fresh setup or a new token, and `sapience update` (which is the vendor's own, and works) to
refresh the payload.

## First-time setup

The module is enabled in `home.nix`, but it is inert until a token exists. The sync unit carries
`ConditionPathExists=~/.sapience/config.json`, so before bootstrap it reports `condition failed`
rather than running or failing.

1. **Sign in to Ollama**, which is what lets the daemon reach cloud models:

   ```bash
   ollama signin                             # browser flow; registers ~/.ollama/id_ed25519
   systemctl --user restart ollama.service   # pick up the credential
   ```

   Verify before going further — this should answer rather than `{"error":"Unauthorized"}`:

   ```bash
   curl -sS http://127.0.0.1:11434/api/chat -H 'content-type: application/json' \
     -d '{"model":"gemma4:cloud","messages":[{"role":"user","content":"say OK"}],"stream":false}'
   ```

2. **Get a Sapience token.** In the web app: Settings, then "Sign in on another device", then
   copy the private link. It is the entire credential for the account — there is no password or
   second factor — so treat it like one.

   Paste either the whole link or just its `token=` value; bootstrap reads the value out of a
   link, and also tolerates surrounding quotes, `<...>` brackets and trailing query parameters.
   What it stores is always the bare token, because every client sends that field verbatim and a
   link in its place authenticates as nothing: `/v1/stats` answers 401, and `/ingest-kos`
   answers 403 `an invite code is needed to build a new Sapience`, since a token that opens no
   brain reads server-side as a request to create one.

3. **Bootstrap.** Run it in a real terminal; the vendor refuses onboarding without a TTY, to
   avoid silently replacing your folder choices (`SAPIENCE_ALLOW_ONBOARD=1` overrides, but then
   it picks for you):

   ```bash
   sapience-bootstrap                      # prompts for the token or link
   SAPIENCE_TOKEN=<tok> sapience-bootstrap # or skip the prompt
   ```

   It checks the token against `/v1/stats` before writing anything, so one the server does not
   recognise costs a second rather than a full extraction that fails at the upload. An
   unreachable host is not fatal: a well-formed token is accepted with a warning, because an
   outage must not block setup.

   It then writes `~/.sapience/config.json` (mode 600) with the token, backend and host,
   confirms the payload is present, and hands off to the vendor's own onboarding, which lists
   every candidate project folder with file counts for you to tick. Re-running it later keeps a
   valid token and just re-opens the picker; re-running it over a config that stores a link
   repairs the token in place. Either way the folder selection, capture map and `auto_approve`
   choice survive — a rewrite preserves them rather than replacing the object.

   If a sync unit happens to be running, bootstrap stops it so the two do not compete. Nothing
   is lost by that: the vendor leaves un-extracted files un-marked, so a later run re-reads them.

4. **Switch again.**

   ```bash
   cd ~/.dotfiles && home-manager switch --flake .#benjamin
   ```

   The first switch could not put a token in `~/.claude.json` because none existed. This one
   can. Without it, `sapience status` keeps reporting Claude Code as "not registered". Restart
   Claude Code afterwards: MCP servers are snapshotted at session start.

   Activation also repairs a link-shaped token in `config.json` before registering the MCP
   server, so the two surfaces cannot disagree. `sapience status` prints a fingerprint per
   surface; they should match.

5. **Review.** Only this step uploads anything.

   ```bash
   sapience coverage   # what was read, what was skipped, and why
   sapience pending    # how many findings are staged
   sapience review     # approve
   ```

`sapience coverage` currently reports `skipped (outside 30d window): 0`, so every eligible
transcript already falls inside the default window and `sapience backfill 365` would add
nothing. Reach for it only after a long gap.

## Everyday use

`sapience help` lists every subcommand; `sapience review`, `coverage`, `pending` and
`sf1 "a question"` are the ones used day to day.

```bash
sapience sync                                # extract now, in this terminal
systemctl --user start sapience-sync.service # or detached, logging to the journal
journalctl --user -fu sapience-sync          # logs (not ~/.sapience/sync.log)
```

### Nothing extracts on a schedule

`backgroundSync` is `false`, so no timer is installed and nothing reads a transcript unless you
ask. Extraction spends real money or real CPU per run and reads whatever the folder picker has
selected, so it is a decision rather than a consequence of enabling the module. `sapience help`
prints the current arrangement, whichever way it is set.

The two ways to run one are above: `sapience sync` in the terminal, or
`sapience-sync.service` for a detached run that logs to the journal. Both stage findings for
`sapience review`; neither uploads anything on its own unless `auto_approve` is on.

To put it back on a schedule, in `home.nix`:

```nix
programs.sapience.backgroundSync = true;   # syncInterval then applies, default "hourly"
```

`syncInterval` on its own schedules nothing — it is the `OnCalendar` expression the timer uses
once `backgroundSync` turns the timer on.

### Watching a run

Extraction is **silent by design**: the vendor prints "Extracting knowledge from N sources" and
then nothing until it finishes. There is no verbose flag, nothing is flushed per source, and the
staging queue is written only at the end — so mid-run `sapience pending` and `coverage` both
read zero, which is not a failure. `sapience-bootstrap` therefore shows progress itself, one
line per thirty seconds of actual progress:

```
  classifying: 151/~255 (59%) ~0.3s each, 1m01s elapsed
  extracting: 222/~255 (87%) ~3.5s each, 3m01s elapsed
```

Each line is appended whole, on stderr so it cannot corrupt the vendor's stdout, and only when
the call count has moved. Both properties matter, because the vendor's extraction ends with an
interactive review prompt that carries no trailing newline: a rewritten line would contend with
that prompt for one physical line and erase the question, making a finished run look like a hung
one. Appending cannot erase anything, and printing only on a change means the display falls
silent by itself once the last call lands — so nothing follows the prompt, and no threshold or
liveness probe exists that could stop it for the wrong reason. A slow call simply produces no
line until it completes.

**The phase word explains the rate.** A run classifies every source first, one call each at a
six-token reply budget, which lands in tenths of a second; only then does it enter the chunk
loop at an 8,000-token budget, where calls take seconds. Seeing the rate drop ten-fold partway
through is that handover, not a stall. The label flips when the count passes the source
estimate, so it can lag the real handover by a few calls — `--coverage` counts sources before
the delta and interactivity filters the run itself applies, so it tends to over-count slightly.

**The percentage is against an estimate, and the estimate is a floor.** It is sources plus the
50-chunk cap, resolved lazily after the picker since your selection changes it. The cap counts
chunks, not calls: a chunk costs one call per 12,000-character window, and a reply that stops at
the 8,000-token limit is re-extracted as two halves recursively to depth 2, so one chunk can
spend 1, 3 or 7 calls. A run can therefore pass its own denominator — `284/~255` is a normal
sight and means truncation re-splits happened. The `~` marks the denominator as approximate, and
the percentage is clamped to 99 while the run is live, so a progress line never claims
completion; only the closing message gets to say a run finished.

One more thing the count cannot do: it cannot tell Sapience's calls apart from any other
client's, so a `curl` probe against `127.0.0.1:11434` mid-run inflates it.

The count comes from the Ollama journal's GIN access log, one line per completed HTTP call. A
`slot release:` grep would not do: only a *local* inference slot emits it, and a `:cloud` model
never does.

Only bootstrap has this, and only on the `ollama` backend — the signal is the local daemon's own
access log, and on `relay`, `anthropic` or `openai` no call transits this machine. `sapience
sync`, `sapience backfill` and `sapience-sync.service` go straight to the vendor script and are
as silent as it is; for those, watch `journalctl --user -fu ollama` and check `sapience pending`
afterwards.

### How a bootstrap ends

The vendor's own last word is either a review prompt or an upload error, neither of which says
what the run achieved. Bootstrap adds that:

```
sapience-bootstrap: done in 15m13s.
  808 findings are staged on this machine, waiting for your review.
  Next: sapience review        approve them and upload to your Sapience
  Nothing syncs on a schedule; run sapience sync when you want another pass.
```

The staged count is the honest measure of a run's yield. Extraction is local, so findings
survive a failed upload: "staged but not sent" is a normal outcome, not a loss, and
`sapience review` retries the upload whenever you like. A non-zero exit says so and notes that
the ledger only advances over work that was staged, so the next run re-reads whatever this one
did not finish.

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
| `ollama` + a local model | No | — |
| `ollama` + a `:cloud` model (configured here) | Yes, redacted chunks to `ollama.com` | No |
| `relay` (vendor default) | Yes, redacted chunks via `app.spnc.ai` | **No** |
| `anthropic` / `openai` | Yes, redacted, to that provider on your own API key | No |

Redaction applies on every path — `extract_local.py:2264` redacts each chunk before the provider
call, with the comment "keep secrets out of the model's view (and your own provider)". The
installer's phrase "raw text goes straight to your provider" means *direct rather than via us*,
not *unredacted*.

Auto-approve controls whether facts are *stored in your vault*, not whether transcripts are
*transmitted* — on the `relay` backend, chunks are POSTed before the review gate applies at all.
Findings themselves are model-written sentences instructed to keep "exact numbers, thresholds,
config values, decisions and their reason", so they are not a summary that drops specifics.

Under the configuration here: redacted chunks reach `ollama.com` during extraction, and approved
findings reach `app.spnc.ai` when you run `sapience review`. Nothing reaches either before that.

## How extraction reaches the cloud model

`backend = "ollama"` with `model = "gemma4:cloud"`. The local daemon authenticates, forwards to
`ollama.com`, and runs no inference; it is a credential-holding proxy.

### Why the backend stays "ollama"

Four facts about `extract_local.py` decide the design:

| Line | Fact |
|------|------|
| `:167` | The `ollama` endpoint is `OLLAMA_HOST` + `/api/chat` — overridable |
| `:1511` | That request carries **only** `content-type`. No `Authorization` header, ever |
| `:1526` | The `anthropic` URL is a hardcoded literal |
| `:1537` | The `openai` URL is a hardcoded literal |

The two backends built for remote providers cannot be aimed at a different one, and the one
backend with a configurable endpoint cannot authenticate to anything. So the only route to a
remote model that touches no vendor code is something local holding the credential — and the
Ollama daemon already is that, for free: a model name ending in `:cloud` makes it authenticate
against `ollama.com` and forward the call.

### The credential is a keypair, not an API key

`ollama signin` registers `~/.ollama/id_ed25519` with your account, and the daemon signs cloud
requests with it. The subcommand has no flags, so this one step is interactive and not
declarative.

An `ollama.com` API key cannot replace it, and `sops-nix` therefore has no role here, despite
`opencode-serve` already receiving `sops.secrets."ollama_api_key"`:

- `OLLAMA_API_KEY` does not appear in the daemon's own `"server config"` env dump
  (`routes.go:1947`), which enumerates every variable it recognises. A daemon started with it
  set still answers `401`.
- In the binary that string occurs only under `cmd/launch` — *"OLLAMA_API_KEY is required for
  Claude Desktop"*. It is a **client-side** variable for pointing other apps at `ollama.com`,
  which is exactly what `opencode-serve` uses it for. It is not a server credential.

The key's only use is a direct `Authorization: Bearer` call to `https://ollama.com/api/chat` —
the one call the vendor client cannot make. If the interactive step ever becomes intolerable, a
local listener could inject that header and forward upstream with `OLLAMA_HOST` aimed at it; the
API shape is identical, so no translation is needed. That is still a new daemon to own, in
exchange for removing one once-per-machine command.

### Model choice

What this workload needs is compact JSON inside a fixed reply budget, not reasoning depth.
`llm()` caps replies at `num_predict` 8000 and never sends `think: false`, so on a reasoning
model the thinking tokens compete with the JSON for that budget — and losing that race produces
no output at all.

Ollama's usage page lists seven models as free-usage eligible: `beam`, `gemma4:31b`,
`gpt-oss:120b`, `gpt-oss:20b`, `nemotron-3-nano:30b`, `nemotron-3-super`, `nemotron-3-ultra`.
Probed with a trivial prompt capped at 32 output tokens, **only gemma4 emitted no thinking**;
`gpt-oss` (both sizes) and the nemotrons spent the whole budget thinking and returned *empty
content*.

On a realistic extraction prompt at the client's actual `num_predict` of 8000:

| | `gemma4:cloud` | `beam:cloud` |
|---|---|---|
| Wall time | **1.7s** | 20.5s |
| Output tokens | **552** | 2152 |
| Thinking | **0 chars** | 6156 chars |
| Facts returned | 9 | 20 |

beam was tried first and abandoned for this reason. On real chunks it overran the 8000 cap
repeatedly, logging *"the cut-off reply had 0"* — the whole budget spent before any JSON — and
each overrun costs two further calls through the re-split path, recursively to depth 2.
Extraction calls were taking 37–86s each. gemma4's 552 tokens leave roughly 15× headroom.

The cost of the swap is recall: 9 facts against 20 on the same chunk. Revisit if `sapience
review` shows findings are too thin — but beam's extra facts were not reliably realised, since
a truncated reply yields none.

Privacy does not separate these models: all are open-weight and served on Ollama's "NCPs to
host open models" track under one policy — *"Prompt or response data is never logged or trained
on"*, and partners *"must have no logging, no training, and zero data retention policies in
place"*. Hosting is US-primary and *"may route to Europe for additional capacity"*. These are
contractual assurances, not architectural ones; unlike a local model they cannot be verified
from here.

Free status is a promotion, not a guarantee, and Ollama retires cloud models with notice in its
usage settings. `gemma4:cloud` follows whatever size the tag points at (31b today); pin
`gemma4:31b-cloud` if that ever matters.

### Performance and failure modes

Measured on this corpus. A run makes one small classifier call per session, then works through
chunks:

| Phase | Calls | Latency |
|-------|-------|---------|
| Work/personal classification | one per session (203 here) | ~1.2s each |
| Chunk extraction | 50-chunk cap, ≥1 call per chunk | ~2s on a representative prompt |

So while a backlog exists the classifier phase dominates the call count, and a run spends its
first few minutes there before the slower chunk work begins. A ticker that appears to stall has
usually just crossed that boundary.

For comparison, local `llama3.1` on this CPU ran ~40s per call and some calls exceeded the
client's hardcoded 180s `urlopen` timeout outright, surfacing as HTTP 500s — which is why the
local configuration never managed to ingest anything.

Two things to watch:

**Reply truncation.** `llm()` caps replies at `num_predict` 8000 and never sends
`think: false`, so on a reasoning model the thinking competes with the JSON for that budget.
When it trips, stderr says *"a cut-off reply was re-extracted as two halves"* and
`_extract_chunk` recovers by re-extracting each half, recursively to depth 2 — so one overrun
can cost up to seven calls. Occasional warnings are the safety net working; a steady stream
means the model is too verbose for the cap. This is what ruled beam out (see
[Model choice](#model-choice)); `gemma4` emits no thinking and has not tripped it.

**No retry.** The `anthropic` and `openai` branches wrap their call in `_llm_call(...)`; the
`ollama` branch calls `urlopen` bare. Against localhost that was sound — nothing about a
loopback socket is transient — but against `ollama.com` a passing 502 raises, is caught by the
chunk loop's `except Exception`, and logs `extract error`. Nothing is lost: the file is left
un-marked and retried next run. But each blip costs one chunk from that run's budget of 50.
Fixing it properly means editing vendor code, which this setup does not do; the right place
would be the proxy layer described above, if it is ever built.

**The classifier re-runs across the whole backlog.** It classifies every not-yet-extracted
session on every run, so while a backlog exists most of a run's calls are classification rather
than extraction. `NO_CLASSIFY=1` skips it — the client's own comment is that "redaction is the
privacy guarantee, not this filter" — at the cost of no longer filtering personal conversations
out. Raising `MAX_CHUNKS` for a catch-up pass is the alternative.

## Design decisions

### Not packaged as a derivation

Upstream has no releases, tags or content hashes. It serves the payload live from
`app.spnc.ai/<name>.py` under `cache-control: no-cache`, with no ETag, no `Last-Modified` and no
version or manifest endpoint; `sapience_upkeep.py` treats a per-file sha256 that the server
compares against what it currently serves as the client's "version", self-updates two ways
(`sapience update`, and a background `--auto-update` that `mcp.py` spawns on its own), and
honours a server-side `CLIENT_AUTO_UPDATE=0` kill switch. A pinned `fetchurl` would break its
hash on the next upstream push *and* be fought by the updater.

So `~/.sapience/*.py` is deliberately mutable state: activation seeds files only when absent and
never overwrites them. Nix owns the wrappers, the units and the registration; upstream owns the
payload.

This is also why there is no nixpkgs package. Beyond the missing hashable artifact, the client
carries no license grant — no headers in the ten `.py` files, no LICENSE or terms on the site,
patents claimed, and the vendor's reserved PyPI names (`sapience-ai`, `spnc`) are placeholders
declaring `License: Proprietary` — and the service is an invite-only private beta, which fails
nixpkgs' userbase and testability expectations even if the rest were resolved.

### Home-manager, not NixOS

The NixOS `services.ollama` has `loadModels`, which the home-manager module lacks, so the model
pull is hand-rolled here. That cost buys one rebuild path: the server runs as this user against
`~/.ollama`, needs no sudo, and the whole feature applies with `home-manager switch` rather than
splitting the model store across a system rebuild and its only consumer across a home rebuild.

### The Ollama daemon stays enabled with nothing to serve

It holds the credential and proxies to `ollama.com`, so disabling it would break extraction even
though it loads no weights and sits at roughly 20 MB resident. Whether anything runs locally is
decided by the *consumer's* model name, not by `services.ollamaModels`.

This also retires the GPU question. This machine's Radeon 890M (`gfx1150`, RDNA 3.5) has only
experimental ROCm support, typically needing an `HSA_OVERRIDE_GFX_VERSION` override plus a
multi-gigabyte closure. With extraction remote there is nothing left for it to accelerate.

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
running sync unit never blocks it: bootstrap stops that sync instead and takes precedence, which
loses no work because the vendor leaves its files un-marked for the next run. It then holds
`.run.lock` for the extraction alone, so another run starting mid-extraction is skipped by the
vendor's own guard rather than competing; if that lock cannot be had it continues anyway, since
being slower beats refusing a run you asked for.

There is no cooldown and no stale-lock state to clear. `flock` holds nothing on disk — the lock
lives only as long as some process holds the open file descriptor — so an interrupted, crashed
or killed bootstrap frees it the instant the process goes, and the next run starts immediately.

Separately, `sapience-sync.service` is marked `X-SwitchMethod = "keep-old"`. Without it
`sd-switch` restarts the unit on every activation, which kills an in-flight extraction *and*
blocks `home-manager switch` until the replacement finishes. A changed definition is picked up
by the next run instead.

### The token never enters the Nix store

Every client falls back to `~/.sapience/config.json` when `SAPIENCE_TOKEN` is unset, so the
wrappers and the sync unit pass no token at all. The `~/.claude.json` entry gets one, read at
activation time from that mode-600 file, purely so `sapience status` can report matching
fingerprints across surfaces. The `tokenFile` option exists for a non-interactive bootstrap and
must point outside the store — a store path would be world-readable.

### The token is validated, not just stored

`config.json` is mutable state: bootstrap, the vendor client and the web onboarding all write
it, and every consumer reads `.token` verbatim. A field holding the private link instead of its
`token=` value therefore breaks every surface at once — the sync, and Claude Code's MCP tools
via the `~/.claude.json` copy — while the server's answers name neither cause (401 on
`/v1/stats`; 403 `an invite code is needed to build a new Sapience` on `/ingest-kos`).

So the shape is checked rather than assumed, in two places. Bootstrap normalises a paste,
refuses anything that is not `[A-Za-z0-9_-]{8,}`, and confirms the token against `/v1/stats`
before writing. A `sapienceTokenRepair` activation entry heals an already-stored link and is
ordered before `sapienceMcpServer`, so the registration can never copy one. A value that is
neither token-shaped nor repairable is reported with the remedy rather than silently kept.

### Why the hooks live in the repo

`home.activation.claudeSettings` treats `hooks` and `permissions` as enforced keys, resetting
them from `config/claude/settings.json` on every switch, so anything a vendor installer wrote
into the live file would be reverted. The three hooks and seven `mcp__sapience__*` grants live
in the repo file for that reason, each guarded with a `[ -f ~/.sapience/mcp.py ]` test and
`|| true` so they are inert before bootstrap and harmless if the client is removed.

`statusLine` is deliberately not wired: that slot belongs to `hooks/statusline-push.sh`, and
composing them would mean editing the agent-system source store rather than the deployed
artifact. Append `python3 ~/.sapience/mcp.py --statusline` output to that script there if you
want the segment. The `Stop` hook makes one outbound request per assistant turn — no content, a
session id out and a line back, but a continuous activity signal. Drop that entry if you would
rather not have it; nothing else depends on it.

## Module options

`programs.sapience`:

| Option | Default | Set here | Purpose |
|--------|---------|----------|---------|
| `enable` | `false` | `true` | CLI, sync unit, payload seed, MCP registration |
| `backend` | `"ollama"` | `"ollama"` | `relay`, `anthropic`, `openai`, `ollama` |
| `model` | `""` | `"gemma4:cloud"` | `--model`; empty keeps the client's per-backend default |
| `host` | `"https://app.spnc.ai"` | default | API host, also the payload source |
| `apiKeyFile` | `""` | default | Provider key for `anthropic`/`openai`; no role under `ollama` |
| `tokenFile` | `null` | default | Path outside the store for non-interactive bootstrap |
| `backgroundSync` | `false` | default | Install the timer at all; off means on-request only |
| `syncInterval` | `"hourly"` | default | `OnCalendar`, only when `backgroundSync` is true |
| `memoryFiles` | `false` | default | See [above](#memory-file-ingestion-is-off) |
| `registerMcpServer` | `true` | default | Merge into `~/.claude.json` |

`services.ollamaModels`:

| Option | Default | Set here | Purpose |
|--------|---------|----------|---------|
| `enable` | `false` | `true` | Local server plus the model loader |
| `load` | `[ "llama3.1" ]` | `[ ]` | Models to pull; cloud models need none |
| `pullTimeoutSec` | `3600` | default | Ceiling for a cold multi-gigabyte pull |

Setting `backend = "ollama"` without `services.ollamaModels.enable` emits a build warning rather
than an assertion, so a missing inference server never blocks an unrelated rebuild. Selecting an
API backend with no `apiKeyFile` warns the same way.

## Inspection recipes

```bash
# Is the whole chain healthy?
systemctl --user is-active ollama.service
systemctl --user show sapience-sync.service -p ConditionResult -p Result

# Pre-bootstrap, the expected answer is ConditionResult=no with Result=success:
# condition-failed, so the unit never latches a false success and recovers once
# config.json appears.

# Does the cloud model answer? (Unauthorized here means `ollama signin` is needed.)
curl -sS http://127.0.0.1:11434/api/chat -H 'content-type: application/json' \
  -d '{"model":"gemma4:cloud","messages":[{"role":"user","content":"say OK"}],"stream":false}'

# Confirm nothing is running locally: all three should be empty or zero.
ollama ps
journalctl --user -u ollama --since -1h | grep -cE 'slot[[:space:]]+release:|llama_model_loader'

# Call volume and latency for the last hour.
journalctl --user -u ollama --since -1h | grep -cE '\[GIN\].*POST +"/api/chat"'

# Is the payload seeded, and is the MCP server registered?
ls ~/.sapience/
jq '.mcpServers.sapience' ~/.claude.json

# Does the token open the account? 200 with a JSON body is healthy; 401 means the
# stored value is not a token the server knows.
curl -sS -o /dev/null -w '%{http_code}\n' \
  "https://app.spnc.ai/v1/stats?token=$(jq -r .token ~/.sapience/config.json)"

# Do all surfaces agree? The fingerprints must match; a token is never printed.
sapience status

# What did the last sync actually read?
sapience coverage
journalctl --user -u sapience-sync -n 50
```

## Known gaps

**Most sessions here will be skipped, by two separate filters.** Expect coverage well below the
session counts the folder picker shows.

The first is overridable. A transcript must have at least two distinct substantive human turns,
a predicate that exists to drop "benchmark loops, agent runs, probes"; `sapience coverage`
reports these as `skipped (headless/agent)`. Widen one run with `sapience sync
--include-agents`. The sync unit would need `SAPIENCE_INCLUDE_HEADLESS=1` in its environment,
which is deliberately not an option here: agent transcripts are long and repetitive, and would
dominate both the run's chunk budget and the vault.

The second is not overridable at all. `source_skip()` in `upload.py` classifies each transcript
as `subagent` or `harness-started` from its opening turns and those are never read — the run
logs them as `skipped (subagent / harness-started transcripts) ... thread mechanics; never
read`, and the message states outright that `SAPIENCE_INCLUDE_HEADLESS=1` does not override it.
Verdicts are cached in `~/.sapience/source_rules.json`. Given how much work here runs through
orchestrated dispatch, this filter removes more than the first one does: 1013 of 1295
transcripts on disk, against 203 eligible.

**One deny-list gap worth knowing.** `~/Documents/Personal/...` is correctly refused, because
`personal` is on the vendor's denied-names list. `~/Documents/Employment/Applications` is not:
neither word is on that list, and `Applications` is only denied as a top-level folder. Both
carry `.claude/` trees, so untick that one in the folder picker.

**The timer, when enabled, carries no `Requires` on its service**, deliberately. The sibling
timer modules in this repo carry `Requires = [ "<name>.service" ]`, which stop-propagates:
stopping the service would also deactivate the timer and silently end background learning. This
module's timer omits it, because the service does get stopped in normal use — `sapience-bootstrap`
stops it to claim the run. A timer activates its same-named service by default, so the
dependency buys nothing.

**The unit run skips the per-run keep prompt.** `--sync` is non-interactive by design, so
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
state: `~/.sapience/` (payload, token, folder choices, review queue), the `mcpServers.sapience`
key in `~/.claude.json`, and anything still in `~/.ollama`. Remove them by hand if you want them
gone:

```bash
rm -rf ~/.sapience
jq 'del(.mcpServers.sapience)' ~/.claude.json > /tmp/cj && mv /tmp/cj ~/.claude.json
ollama signout
ollama rm llama3.1          # the old local model, still on disk at ~4.9 GB
```

The hooks and tool grants go away by deleting their entries from
`config/claude/settings.json`; because those keys are enforced, the next switch resets the live
file to match. The hosted vault is untouched by any of this — `sapience reset` clears local
state only.

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
| `programs.sapience.model` | `"beam:cloud"` | …which forwards it to `ollama.com`; nothing is inferred locally |
| `services.ollamaModels.load` | `[ ]` | A cloud model has no weights to pull |
| `programs.sapience.memoryFiles` | `false` | `CLAUDE.md` and friends are not ingested |
| `config.json: auto_approve` | `false` | Findings stage until `sapience review` |
| `syncInterval` | `hourly` | Background extraction, capped at 50 chunks per run |

Two credentials, in two places, neither in the Nix store: the Sapience account token in
`~/.sapience/config.json` (mode 600), and the Ollama account keypair in `~/.ollama/id_ed25519`.

**Setting up a new machine** is three commands: `ollama signin`, `sapience-bootstrap`,
`home-manager switch`. See [First-time setup](#first-time-setup). Nothing reads a transcript
until you bootstrap, and nothing is uploaded until you review.

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

1. **Sign in to Ollama**, which is what lets the daemon reach cloud models:

   ```bash
   ollama signin                             # browser flow; registers ~/.ollama/id_ed25519
   systemctl --user restart ollama.service   # pick up the credential
   ```

   Verify before going further — this should answer rather than `{"error":"Unauthorized"}`:

   ```bash
   curl -sS http://127.0.0.1:11434/api/chat -H 'content-type: application/json' \
     -d '{"model":"beam:cloud","messages":[{"role":"user","content":"say OK"}],"stream":false}'
   ```

2. **Get a Sapience token.** In the web app: Settings, then "Sign in on another device", then
   copy the private link. The token is that link's `token=` parameter. It is the entire
   credential for the account — there is no password or second factor — so treat it like one.

3. **Bootstrap.** Run it in a real terminal; the vendor refuses onboarding without a TTY, to
   avoid silently replacing your folder choices (`SAPIENCE_ALLOW_ONBOARD=1` overrides, but then
   it picks for you):

   ```bash
   sapience-bootstrap                      # prompts for the token
   SAPIENCE_TOKEN=<tok> sapience-bootstrap # or skip the prompt
   ```

   This writes `~/.sapience/config.json` (mode 600) with the token, backend and host, confirms
   the payload is present, then hands off to the vendor's own onboarding, which lists every
   candidate project folder with file counts for you to tick. Re-running it later skips the
   token step and just re-opens the picker.

   If a scheduled sync is running, bootstrap stops it so the two do not compete. Nothing is lost
   by that; the timer picks the work up again on schedule.

4. **Switch again.**

   ```bash
   cd ~/.dotfiles && home-manager switch --flake .#benjamin
   ```

   The first switch could not put a token in `~/.claude.json` because none existed. This one
   can. Without it, `sapience status` keeps reporting Claude Code as "not registered". Restart
   Claude Code afterwards: MCP servers are snapshotted at session start.

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
systemctl --user status sapience-sync.timer
systemctl --user start sapience-sync.service       # run now
systemctl --user disable --now sapience-sync.timer # pause background learning
journalctl --user -fu sapience-sync                # logs (not ~/.sapience/sync.log)
```

### Watching a run

Extraction is **silent by design**: the vendor prints "Extracting knowledge from N sources" and
then nothing until it finishes. There is no verbose flag, nothing is flushed per source, and the
staging queue is written only at the end — so mid-run `sapience pending` and `coverage` both
read zero, which is not a failure. `sapience-bootstrap` therefore shows progress itself:

```
  extracting: 143/253 model calls (56%) ~1.1s each, 2m22s elapsed
```

It rewrites that line every ten seconds, on stderr so it cannot corrupt the vendor's stdout, and
stays silent until the first call completes — which keeps it clear of the interactive folder
picker that runs first.

The count comes from the Ollama journal's GIN access log, one line per completed HTTP call.
(Not from `slot release:`, which only a *local* inference slot emits and which a `:cloud` model
never produces.) The denominator is sources + the 50-chunk cap, where sources is `--coverage`'s
"would ingest now", resolved lazily after the picker since your selection changes it. It is an
upper bound in one term and a lower bound in the other: a session with a tiny delta skips its
classifier call, while a wide chunk spends several calls on windows and re-splits. So the
percentage is a guide, not a promise, and can saturate at 100% shortly before the run ends.

Only bootstrap has this. `sapience sync`, `sapience backfill` and the timer go straight to the
vendor script and are as silent as it is; for those, watch `journalctl --user -fu ollama` and
check `sapience pending` afterwards.

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

## How extraction reaches beam:cloud

`backend = "ollama"` with `model = "beam:cloud"`. The local daemon authenticates, forwards to
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

`beam:cloud` is Reflection's 501B-total / 23B-active Apache-2.0 model, picked over the two
other plausible open-weight options:

| | beam | gemma4 | nemotron-3-super |
|---|---|---|---|
| Price per Mtok | **free** (no pricing-table row) | $0.14 / $0.40 | $0.015 / $0.60 |
| GPQA Diamond | 90.5 (self-reported) | 84.3 | 79.2 |
| Artificial Analysis index | not listed | 29 | 25 |
| Context on Ollama | 1M | 256K | 256K |

Privacy does not separate them: all three are open-weight models served on Ollama's "NCPs to
host open models" track under one policy — *"Prompt or response data is never logged or trained
on"*, and partners *"must have no logging, no training, and zero data retention policies in
place"*. Hosting is US-primary and *"may route to Europe for additional capacity"*. These are
contractual assurances, not architectural ones; unlike a local model they cannot be verified
from here.

`free` reads as a launch promotion, and Ollama retires cloud models with notice in its usage
settings. `gemma4:cloud` is the drop-in fallback — one word in `home.nix`.

### Performance and failure modes

Measured on this corpus. A run makes one small classifier call per session, then works through
chunks:

| Phase | Calls | Latency |
|-------|-------|---------|
| Work/personal classification | one per session (203 here) | ~1.2s each |
| Chunk extraction | 50-chunk cap, >1 call per chunk | median 2.3s, mean 10.6s, max 78s |

For comparison, local `llama3.1` on this CPU ran ~40s per call and some calls exceeded the
client's hardcoded 180s `urlopen` timeout outright, surfacing as HTTP 500s — which is why the
local configuration never managed to ingest anything.

Two things to watch:

**Reply truncation.** Every current cloud model is a reasoning model, while `llm()` caps replies
at `num_predict` 8000 and never sends `think: false`, so thinking tokens compete with the JSON
for that budget. When it trips, stderr says *"a cut-off reply was re-extracted as two halves"*
and `_extract_chunk` recovers by splitting. Occasional warnings are the safety net working;
a steady stream means the model is too verbose for the cap, and `gemma4:cloud` is the swap.

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
scheduled sync never blocks it: bootstrap stops that sync instead and takes precedence, which
loses no work because the vendor leaves its files un-marked for the next run. It then holds
`.run.lock` for the extraction alone, so a timer firing mid-run is skipped by the vendor's own
guard rather than competing; if that lock cannot be had it continues anyway, since being slower
beats refusing a run you asked for.

There is no cooldown and no stale-lock state to clear. `flock` holds nothing on disk — the lock
lives only as long as some process holds the open file descriptor — so an interrupted, crashed
or killed bootstrap frees it the instant the process goes, and the next run starts immediately.

Separately, `sapience-sync.service` is marked `X-SwitchMethod = "keep-old"`. Without it
`sd-switch` restarts the unit on every activation, which kills an in-flight extraction *and*
blocks `home-manager switch` until the replacement finishes. The timer picks up a changed
definition on its next fire instead.

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
want the segment. The `Stop` hook makes one outbound request per assistant turn — no content, a
session id out and a line back, but a continuous activity signal. Drop that entry if you would
rather not have it; nothing else depends on it.

## Module options

`programs.sapience`:

| Option | Default | Set here | Purpose |
|--------|---------|----------|---------|
| `enable` | `false` | `true` | CLI, timer, payload seed, MCP registration |
| `backend` | `"ollama"` | `"ollama"` | `relay`, `anthropic`, `openai`, `ollama` |
| `model` | `""` | `"beam:cloud"` | `--model`; empty keeps the client's per-backend default |
| `host` | `"https://app.spnc.ai"` | default | API host, also the payload source |
| `apiKeyFile` | `""` | default | Provider key for `anthropic`/`openai`; no role under `ollama` |
| `tokenFile` | `null` | default | Path outside the store for non-interactive bootstrap |
| `syncInterval` | `"hourly"` | default | `OnCalendar` for the background sync |
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
systemctl --user is-active ollama.service sapience-sync.timer
systemctl --user show sapience-sync.service -p ConditionResult -p Result

# Pre-bootstrap, the expected answer is ConditionResult=no with Result=success:
# condition-failed, so the unit never latches a false success and recovers once
# config.json appears.

# Does the cloud model answer? (Unauthorized here means `ollama signin` is needed.)
curl -sS http://127.0.0.1:11434/api/chat -H 'content-type: application/json' \
  -d '{"model":"beam:cloud","messages":[{"role":"user","content":"say OK"}],"stream":false}'

# Confirm nothing is running locally: all three should be empty or zero.
ollama ps
journalctl --user -u ollama --since -1h | grep -cE 'slot[[:space:]]+release:|llama_model_loader'

# Call volume and latency for the last hour.
journalctl --user -u ollama --since -1h | grep -cE '\[GIN\].*POST +"/api/chat"'

# Is the payload seeded, and is the MCP server registered?
ls ~/.sapience/
jq '.mcpServers.sapience' ~/.claude.json

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
--include-agents`. The hourly unit would need `SAPIENCE_INCLUDE_HEADLESS=1` in its environment,
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

**Stopping the sync service does not stop the timer**, deliberately. The sibling timer modules
in this repo carry `Requires = [ "<name>.service" ]`, which stop-propagates: stopping the
service would also deactivate the timer and silently end background learning. This module's
timer omits it, because the service does get stopped in normal use — `sapience-bootstrap` stops
it to claim the run, and the pause recipe above stops it by hand. A timer activates its
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

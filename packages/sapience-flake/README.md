# sapience-flake

A standalone, shareable NixOS/Home Manager packaging of the [Sapience](https://app.spnc.ai)
client — a generalized fork of a working flake maintained elsewhere, forked out so this directory
evaluates and builds entirely on its own. Copy it anywhere, point a flake at it, and it works with
no other input from the repository it was forked from. It replaces the vendor's macOS-only
installer on Linux/NixOS.

Fork source: `modules/sapience.nix` in this directory is a generalized fork of a home-manager
module named `sapience.nix`, maintained in a private configuration repository, as it stood on
2026-11-04, the date this directory was forked out.

## What this is

CLI wrappers (`sapience`, `sf1`), a first-run bootstrap (`sapience-bootstrap`), an opt-in
background sync timer, and MCP server registration for the Sapience client — all built from the
same shared script bodies in `lib/wrappers.nix`, offered two ways:

- `homeManagerModules.sapience` — the full experience: CLI wrappers, activation-time payload
  seeding, the opt-in sync timer, and MCP server registration into `~/.claude.json`.
- `packages.<system>.{sapience,sf1,sapience-bootstrap}` — the same three CLI wrappers alone, for
  anyone not using home-manager. **No systemd timer and no MCP registration** on this path; both
  are home-manager-module-only concerns with no equivalent here.

## Using it

### `homeManagerModules.sapience`

```nix
{
  inputs.sapience-flake.url = "path:/absolute/path/to/sapience-flake"; # or a git/github URL once hosted

  # in your home-manager configuration's imports:
  imports = [ inputs.sapience-flake.homeManagerModules.sapience ];

  programs.sapience = {
    enable = true;
    # Every other option already has a working vendor default -- see "Defaults" below.
  };
}
```

Enabling the module adds:

- The `sapience` and `sf1` CLI wrappers to `home.packages`.
- `sapience-bootstrap` for first-run setup (token entry, payload seed, project selection).
- An opt-in `sapience-sync` systemd user timer (`programs.sapience.backgroundSync = true;`) —
  the on-demand `sapience-sync.service` is always defined regardless, so
  `systemctl --user start sapience-sync.service` works even with the timer off.
- MCP server registration: merges `mcpServers.sapience` into `~/.claude.json` at activation time
  (`programs.sapience.registerMcpServer`, default `true`), so Claude Code sessions can reach the
  `mcp__sapience__*` tools once a token exists. See "Known gap" below for what this does **not**
  give you.

### `packages.<system>.*`

```bash
nix shell path:/absolute/path/to/sapience-flake#sapience path:/absolute/path/to/sapience-flake#sf1 path:/absolute/path/to/sapience-flake#sapience-bootstrap
# or, once installed into a profile:
nix profile install path:/absolute/path/to/sapience-flake#sapience
```

This builds the identical three wrapper scripts, with `stateDir` resolved at **runtime** from
`$HOME/.sapience` rather than an evaluation-time home-manager path. It gives you the CLI and
`sapience-bootstrap` only — no systemd timer (run `sapience sync` by hand, or your own cron/systemd
unit) and no MCP registration (merge `mcpServers.sapience` into your own `~/.claude.json` by hand
if you want it; `sapience-bootstrap`'s activation does not do this for you on this path).

## Defaults

Three option defaults were generalized from the repository this was forked out of, so a stranger
enabling the module gets a working, zero-setup configuration instead of that repository's own
machine-specific choices:

| Option | Vendor default (this fork) | Why |
|--------|------------------------------|-----|
| `backend` | `"relay"` | No local inference server and no API key required — the vendor's own zero-setup path. The forked-from repository overrode this to `"ollama"` because its own Claude Code transcripts were the input corpus and a local model was already available there; that reasoning does not generalize. |
| `memoryFiles` | `true` | Matches the vendor default. The forked-from repository overrode this to `false` because its own `.claude/` trees are generated deploy scaffolding duplicated across many repositories, which is not true of an arbitrary consumer's project. |
| `apiKeyFile` (`example`) | `/run/secrets/sapience_openai_key` | The forked-from repository's example string baked in that machine's own home directory; replaced with a generic secrets-manager-shaped path, matching `tokenFile`'s own example one field up. |

`model`'s default (`""`, meaning "use the client's own per-backend default") already matched the
vendor default and needed no change.

## Privacy

`backend` controls where transcript text is processed, and that choice has a real privacy
consequence:

- `"relay"` (this fork's default) sends **redacted** chunks through `app.spnc.ai` to Anthropic at
  the vendor's expense. This is the one backend where the **vendor itself** sees those redacted
  chunks, before any local review gate, because the relay is in the request path.
- `"anthropic"` / `"openai"` send raw text from your machine directly to that provider, on your
  own API key. The vendor never sees it; your chosen provider does. Both providers' URLs are
  hardcoded in the vendor client, so neither has a configurable endpoint.
- `"ollama"` keeps conversation text on your machine entirely, talking only to a local Ollama
  server on `127.0.0.1:11434` — the only backend with a configurable endpoint, and the only one
  where nothing leaves the machine unless your chosen Ollama model itself forwards the request
  (e.g. a `:cloud`-suffixed model).

## The payload is deliberately mutable

Activation seeds `~/.sapience/*.py` with a plain `curl`, and only when a file is absent; the
client self-updates itself in the background afterward. This is a direct consequence of
"Nothing hashable upstream" below, **not** an oversight — do not "fix" this into a `fetchurl`
derivation. A pinned hash would break on the vendor's next edit to `app.spnc.ai`, with no warning
and no version bump to signal the change, and would actively fight the client's own updater, which
tries to overwrite the (in that scenario, read-only) Nix-store copy on every machine that has it
installed.

## Known gap: Claude Code hooks and statusline

This flake delivers the Sapience **MCP server** — once a token exists and the registration above
has been merged into your `~/.claude.json`, the `mcp__sapience__*` tools become reachable inside
Claude Code sessions. It delivers **no per-turn visibility**: no session-start briefing, no
session-end receipt, no stop-hook effect line, and no statusline segment.

The reason is structural, not an oversight: hooks and statusline entries are Claude Code
*settings* concerns (they live in a `~/.claude/settings.json`-shaped file, under `hooks` and
`permissions`), not Nix module concerns, and this flake ships no settings file at all — there is
nothing analogous to merge them into. If you want the same visibility, add these to your own
Claude Code settings yourself, each one guarded so it is an inert no-op until the client exists:

- Permission grants (seven, under `permissions.allow`):
  ```
  mcp__sapience__sapience
  mcp__sapience__sapience_search
  mcp__sapience__sapience_briefing
  mcp__sapience__sapience_context
  mcp__sapience__sapience_ask
  mcp__sapience__sapience_outstanding
  mcp__sapience__sapience_papers
  ```
- `SessionStart` hook:
  ```
  [ -f "$HOME/.sapience/mcp.py" ] && python3 "$HOME/.sapience/mcp.py" --briefing-text 2>/dev/null || true
  ```
- `SessionEnd` hook (run `async: true`):
  ```
  [ -f "$HOME/.sapience/mcp.py" ] && python3 "$HOME/.sapience/mcp.py" --receipt 2>/dev/null || true
  ```
- `Stop` hook (`timeout: 3` seconds — this one makes one outbound request per assistant turn, no
  content, a session id out and a line back, but a continuous activity signal; drop it if you
  would rather not have that):
  ```
  [ -f "$HOME/.sapience/mcp.py" ] && python3 "$HOME/.sapience/mcp.py" --effect-line 2>/dev/null || true
  ```

`statusLine` is not addressed here at all; wiring a Sapience segment into a statusline is left
entirely to you.

## Why this is not in nixpkgs

Three independent reasons, each sufficient on its own, verified live rather than assumed:

### 1. No license grant anywhere

- **No headers in the client files.** A case-insensitive search for `license`, `copyright`,
  `proprietary`, or `all rights reserved` across all ten client `.py` files
  (`extract_local.py`, `mcp.py`, `sapience_adddir.py`, `sapience_capture.py`, `sapience_devin.py`,
  `sapience_filter.py`, `sapience_redact.py`, `sapience_upkeep.py`, `sf1.py`, `upload.py`) returns
  zero matches.
- **No LICENSE or terms on the site.** Live HTTP requests to
  `https://app.spnc.ai/{terms,tos,legal,license,privacy}` all return `HTTP 404`.
- **Patents claimed.** The site's own root page states: *"We have filed patents covering the
  architecture."*
- **The vendor's own PyPI reservations declare `Proprietary`.** Live queries against
  `https://pypi.org/pypi/{sapience-ai,spnc}/json` — the two package names CoreTx Inc. has already
  reserved — both return `"version": "0.0.1"`, `"license": "Proprietary"`,
  `"summary": "Reserved by CoreTx Inc. Package under development."`.

With zero license grant of any kind, the only legally defensible `meta.license` for a nixpkgs
submission is `lib.licenses.unfree` — which means Hydra does not build or cache it, and every user
must opt in with `allowUnfree` and build (or fetch) it themselves.

### 2. Nothing hashable upstream

- **No caching headers.** `https://app.spnc.ai/extract_local.py` and `.../mcp.py` both respond
  `cache-control: no-cache, no-store, must-revalidate`, with no `ETag` and no `Last-Modified`.
- **No version or manifest endpoint.** `/version`, `/manifest`, `/install.sh`, `/VERSION`,
  `/version.json`, and `/api/version` all return `HTTP 404` — there is no way to ask "what version
  is this?" independent of fetching and hashing every file by hand.
- **The client treats a live hash comparison as its own version.** `sapience_upkeep.py` computes a
  per-file sha256 and compares it against what the server currently serves to decide whether to
  self-update; it self-updates on two separate paths and honours a server-side
  `CLIENT_AUTO_UPDATE=0` kill switch. A `fetchurl` derivation pinned to today's hash would break
  the instant the vendor edits anything on `app.spnc.ai`, with no warning, and would actively fight
  the client's own updater trying to overwrite that pinned copy.

### 3. Invite-only private beta, macOS-only official support

- The site's own root page: *"Sapience is in private beta. Start with your invite code and
  name."*
- The same page, on the terminal install path this fork replaces: *"Mac + Python 3 · about ten
  minutes."* — no Linux/NixOS path is mentioned anywhere on the page.

This one is **practical-consequence reasoning**, not a quoted written nixpkgs rule — no such
written rule was found. The practical consequence: nixpkgs packages are built by anonymous Hydra
CI and reviewed by maintainers who, for an invite-only service, cannot obtain an account to verify
the package works, and the package would be useless to most of nixpkgs' Linux userbase even if it
built, since the vendor's only officially tested platform is macOS.

## What would unblock it

Two narrow, concrete asks — each answers one of the blockers above:

1. **Publish versioned, checksummed release artifacts under the two already-reserved PyPI names**
   (`sapience-ai`, `spnc`). This directly answers blocker 2: a real PyPI release gives
   `fetchurl`/`fetchPypi` a stable, versioned, sha256-checkable artifact that does not change
   under a pinned hash, decoupling packaging from the live, mutable `app.spnc.ai` payload
   entirely.
2. **State a license permitting redistribution of the build output.** This does not need to be a
   fully open-source license — nixpkgs' `lib.licenses.unfreeRedistributable` exists exactly for
   unfree software whose *build output* may legally be redistributed (unlike plain `unfree`,
   where only the inputs may be redistributed and every user must build or fetch it themselves).
   Securing that single statement would let a future nixpkgs package be built once by Hydra and
   substituted from the binary cache for everyone.

Neither ask touches blocker 3 (invite-only beta, macOS-only official support) — that remains a
product decision the vendor would need to make independently; no Nix-side change routes around it.

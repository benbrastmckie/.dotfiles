# sapience-flake

A standalone NixOS/Home Manager packaging of the [Sapience](https://app.spnc.ai) client. This
directory evaluates and builds entirely on its own — copy it anywhere, point a flake at it, and
it works with no other inputs. It extends the vendor's macOS-only installer to Linux, while also
including Windows via WSL2.

## What this is

CLI wrappers (`sapience`, `sf1`), a first-run bootstrap (`sapience-bootstrap`), an opt-in
background sync timer, and MCP server registration for the Sapience client — all built from the
same shared script bodies in `lib/wrappers.nix`, offered two ways:

- `homeManagerModules.sapience` — the full experience: CLI wrappers, activation-time payload
  seeding, the opt-in sync timer, and MCP server registration into `~/.claude.json`.
- `packages.<system>.{sapience,sf1,sapience-bootstrap}` — the same three CLI wrappers alone, for
  anyone not using home-manager. **No systemd timer and no MCP registration** on this path; both
  are home-manager-module-only concerns with no equivalent here.

## Platforms

**Linux (`x86_64-linux`, `aarch64-linux`), and Windows through WSL2 — which is the same thing.**

There is no native-Windows Nix to target. The upstream project ships none; the native-Windows
efforts that exist ([nova-nix](https://hackage.haskell.org/package/nova-nix-0.1.4.0), a
from-scratch Haskell reimplementation, and the NLnet-funded
[libnix](https://nlnet.nl/project/libnix/)) are third-party and do not run nixpkgs' stdenv, so
nothing here could be built with them. In practice "Nix on Windows" means WSL2, which runs a real
Linux kernel and reports `x86_64-linux` — or `aarch64-linux` on an ARM Windows machine. Both are
in this flake's `systems`, so a WSL2 user is already a first-class consumer and needs no
Windows-specific output.

**macOS is not supported**, and that is a deliberate exclusion rather than an untested platform.
`runtimePath` in `lib/wrappers.nix` carries `pkgs.systemd`, which refuses to *evaluate* off Linux,
and every scheduling path here is `systemd.user` with no launchd equivalent written. Supporting it
would mean guarding that dependency, branching the help text, and writing launchd agents. (The
vendor's own installer is macOS-only; this packaging is the Linux answer to it, which is why
the direction looks inverted.)

### The two Windows routes

| Route | What you get |
|-------|--------------|
| **NixOS-WSL** as your WSL distribution | `homeManagerModules.sapience` — the full experience, same as any NixOS machine |
| **Nix on an existing WSL distro** (Ubuntu, Debian, …) | `packages.<system>.*`, or `homeManagerModules.sapience` under standalone home-manager |

### Scheduled sync needs two one-time steps on WSL

This is the one place where WSL genuinely differs, and it is worth reading before you set
`backgroundSync = true`. The timer is a `systemd.user` timer, and WSL does not start a systemd
user manager by default:

1. Put `systemd=true` under a `[boot]` section in `/etc/wsl.conf`, then run `wsl --shutdown` from
   Windows and reopen the distro. ([Microsoft's docs](https://learn.microsoft.com/el-gr/windows/wsl/wsl-config);
   requires WSL 0.67.6 or later.)
2. Run `loginctl enable-linger $USER`. Without lingering there is frequently no user manager and
   no session bus for `systemctl --user` to reach at all
   ([microsoft/WSL#8842](https://github.com/microsoft/WSL/issues/8842)).

Neither step is something this flake can perform for you: `/etc/wsl.conf` lives on the Windows
side of the boundary, and lingering is a host-level grant a user-scope activation cannot make for
itself. So rather than print timer instructions that would silently never fire, the wrappers
**detect WSL at runtime and name these two steps** — in `sapience help`, at the end of
`sapience-bootstrap`, and once at `home-manager switch` time when `backgroundSync` is on but no
user manager is reachable.

Everything else is unaffected. `sapience sync`, `sapience review`, `sf1` and the MCP server are
ordinary foreground processes that need no systemd at all, and nothing is lost by running sync by
hand — the vendor leaves unprocessed transcripts un-marked, so the next run picks them up.

### Claude Code must run *inside* WSL

MCP registration writes `~/.claude.json` inside the WSL filesystem. A Windows-native Claude Code
install reads a different `~/.claude.json` and will not see the `mcp__sapience__*` tools. Run
Claude Code from inside the WSL distro, or register the server in the Windows-side config
yourself.

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

`<system>` is `x86_64-linux` or `aarch64-linux` (see "Platforms" above — WSL2 reports these too).

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

## Verifying it

Run the hermetic checks yourself — this is the point of them. They need no credentials, no
network beyond the Nix cache, and never contact the vendor:

```bash
nix flake check -L        # from this directory
```

| Check | What it establishes |
|-------|---------------------|
| `shellcheck` | Every generated wrapper passes shellcheck at **default severity, no exclusions**, plus `bash -n`. The scripts are assembled by Nix string interpolation, so a quoting bug is invisible in the `.nix` source and only becomes shell at build time; this reads what is actually produced. |
| `help-output` | Byte-for-byte golden files for `sapience help` across both scheduling settings × both platforms, plus that the two WSL detection signals produce identical text, plus that `help` works before the payload exists and that a real subcommand refuses without it. |
| `token-functions` | 25 table-driven cases over `sap_token_clean`/`sap_token_ok` — every paste shape the invite email produces, and the rejections that stop a pasted *link* from reaching `config.json` and turning into a misleading 401/403. |
| `wsl-probe` | Both WSL detection signals, their negative cases, and the invariant that a degraded-but-live systemd user manager counts as **present** — which is what keeps the WSL advice away from users whose timer already works. |
| `hm-module` | The module evaluated across six option combinations, asserting which units and activation steps exist, that `syncInterval` reaches the timer verbatim, that `registerMcpServer` gates the `~/.claude.json` merge, and that `host` redirects every payload fetch. Two generations are **built**, not just evaluated. |

### The end-to-end install test

```bash
bash tests/install-test.sh
```

A real `home-manager` activation against a throwaway `$HOME`, on an ordinary non-NixOS Linux. The
vendor is stubbed by a local HTTP server, which `programs.sapience.host` redirects every fetch to,
so it needs no token and cannot flake on a vendor outage. It asserts the payload is seeded from
the stub, the state directory is mode 700, `~/.claude.json` gains `mcpServers.sapience`, the
wrappers run, and the WSL branch prints its prerequisites. It is a script rather than a flake
check because it needs a live `$HOME` and a network port, which a Nix build sandbox has neither of.

CI runs exactly these two commands and nothing else, on `x86_64-linux` and `aarch64-linux`, plus
weekly — nixpkgs moves under the pinned release branch and the vendor rewrites the payload without
notice, so a green commit says little three months later.

### What is NOT verified, and cannot be

Worth stating plainly, because the checks above could otherwise be read as covering more than
they do:

- **The vendor.** Sapience is an invite-only private beta with no CI-accessible credentials, and
  the payload self-updates with no versions or hashes. Nothing here proves `sapience sync` really
  extracts, redacts and uploads. Every test stops at the boundary of code this flake owns; the
  payload in the install test is a stub.
- **A timer actually firing.** `hm-module` proves the timer is generated with the right
  `OnCalendar`. Proving one *fires* needs a live systemd user manager, which a build sandbox has
  not got. That would want a VM test.
- **WSL2 end to end.** The WSL code paths are covered by forcing detection, which tests this
  flake's logic, not WSL. GitHub-hosted Windows runners cannot be relied on for WSL2 — it needs
  nested virtualization that the hosted images lack — so there is deliberately no WSL job rather
  than a job that might silently pass on WSL1. End-to-end WSL verification is manual.

## Defaults

`programs.sapience.enable = true;` is enough on its own. Every option already carries a working
default, and they match the vendor's own zero-setup path:

| Option | Default | Meaning |
|--------|---------|---------|
| `backend` | `"relay"` | Inference through `app.spnc.ai` at the vendor's expense — no local model, no API key. See "Privacy". |
| `model` | `""` | Use the client's own per-backend default. |
| `host` | `"https://app.spnc.ai"` | Used for the payload seed and every sync call. Point it elsewhere to stub the vendor, which is how `tests/install-test.sh` stays hermetic. |
| `memoryFiles` | `true` | Let the client ingest curated memory files (`CLAUDE.md`, `AGENTS.md`). |
| `backgroundSync` | `false` | Nothing syncs on a schedule. Extraction spends real money or real CPU and reads whatever the folder picker selected, so it happens on request rather than because the module was enabled. |
| `syncInterval` | `"hourly"` | The timer's `OnCalendar`, matching the vendor LaunchAgent's 3600-second interval. Takes effect only when `backgroundSync` is true. |
| `registerMcpServer` | `true` | Merge `mcpServers.sapience` into `~/.claude.json` so Claude Code can reach the vault. |
| `tokenFile` | `null` | `sapience-bootstrap` prompts for the token. Set it to a path outside the Nix store (e.g. `/run/secrets/sapience_token`) for a non-interactive bootstrap. |
| `apiKeyFile` | `""` | Required only for the `anthropic` and `openai` backends; a secrets-manager path such as `/run/secrets/sapience_openai_key`. |

## Privacy

`backend` controls where transcript text is processed, and that choice has a real privacy
consequence:

- `"relay"` (the default) sends **redacted** chunks through `app.spnc.ai` to Anthropic at
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
- The same page, on the terminal install path this packaging replaces: *"Mac + Python 3 · about ten
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

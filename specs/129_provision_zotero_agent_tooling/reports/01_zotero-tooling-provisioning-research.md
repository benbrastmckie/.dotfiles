# Zotero Agent Tooling: Provisioning Research

- **Task**: 129
- **Date**: 2026-08-11
- **Type**: Seed research report (findings verified live during the literature-extension Zotero
  review conducted in the agent-system repo at ~/.config/nvim; its tasks 38-39 are the consumers
  of everything provisioned here)

## What this machine needs and why

The literature extension in the agent-system repo (~/.config/nvim) has a designed, implemented,
but inactive Zotero write-back path: during literature research it discovers new sources online
and should create Zotero items with PDF attachments via the `zot` CLI, then ingest them into
`~/Projects/Literature/`. Activation is blocked on tooling this repo provisions. Verified state
as of 2026-08-11:

1. **`zot` is not installed** (`command -v zot` fails everywhere). This is the single hard
   blocker for the write path.
2. **`ZOTERO_API_KEY` exists but is unmanaged**: hardcoded in
   `~/.config/fish/conf.d/private.fish` (line 49), outside any Nix-managed file. Verified via
   `GET https://api.zotero.org/keys/current`: userID 2622830, username benbrastmckie, access
   `{library: true, files: true, write: true}` — full write + file privileges. Because it lives
   in a fish conf.d file, it reaches interactive fish sessions and their children, but NOT
   non-fish login shells or systemd user services — headless/scheduled agent runs will not see
   it.
3. **Zotero itself is already packaged** (`modules/system/packages.nix` line 128) with an
   autostart entry in `modules/home/desktop/gnome.nix`. The active data dir is
   `~/Documents/Zotero` (948 stored attachments, Better BibTeX installed, prefs enable the
   local API at 127.0.0.1:23119). A decoy `~/Zotero` directory with an April-era sqlite also
   exists; nothing should read it.

## Item 1: the `zot` CLI (zotero-cli-cc)

- PyPI package `zotero-cli-cc`, current **0.10.0 (released 2026-07-15)**, summary: "Zotero CLI
  for Claude Code — SQLite reads + Web API writes". Actively maintained (0.7.0 was 2026-05-29).
- The consuming scripts invoke bare `zot`, so the binary must be on PATH for interactive shells
  AND agent-spawned bash.
- **Known PATH gap in this configuration** (established during the MCP-registration research
  recorded in this repo's task 128): `uv tool install` places binaries in `~/.local/bin`, which
  is NOT on PATH here — that gap is exactly why `setup-lean-mcp.sh` needed a wrapper script.
  Options, in preference order:
  1. A Nix-built wrapper package on `home.packages` (the pattern already used for
     playwright-mcp): e.g. a `writeShellScriptBin "zot"` that execs
     `uvx --from zotero-cli-cc zot "$@"` (uvx resolves at `/run/current-system/sw/bin/uvx`,
     reliably on PATH), or a proper python package build if reproducibility is preferred over
     uvx's runtime resolution.
  2. `uv tool install zotero-cli-cc` plus adding `~/.local/bin` to PATH — larger blast radius;
     avoid unless PATH policy is being changed anyway.
- `zot` needs `ZOTERO_API_KEY` in the environment (item 2) and reads the local
  `zotero.sqlite`/data dir for its read operations; no additional config file is required.

## Item 2: managed `ZOTERO_API_KEY`

Move the key out of the hand-edited fish conf.d file into the repo's secrets mechanism
(`secrets/`), and export it so that all consumers see it:

- interactive shells (fish AND bash),
- systemd user services / headless agent sessions (e.g. via
  `systemctl --user import-environment` at session start, an `environment.d` drop-in, or the
  home-manager session-variables path — whichever matches existing repo practice).

Note honestly: the key value lives in plaintext in `private.fish` and has appeared in
interactive session logs; if the secrets policy treats that as exposure, rotate the key at
zotero.org/settings/keys during migration (a new key needs the same `library + files + write`
grants).

## Item 3: translation-server (optional but recommended)

The agent-system repo's follow-on task integrates metadata resolution via the official
`zotero/translation-server` (Node service; official Docker image, port 1969; endpoints
`POST /search` for DOI/ISBN/PMID/arXiv → Zotero JSON, `POST /web` for URL → Zotero JSON). It is
stateless and needs no credentials. Provision as an on-demand or always-on localhost service —
`virtualisation.oci-containers` / podman user service, or a packaged Node service if
container-free is preferred. The consumer degrades gracefully when the service is down, so
disabled-by-default with easy enablement is acceptable; document the toggle.

## Item 4: zotero-mcp — explicitly deferred

The de-facto standard MCP server (54yyyu/zotero-mcp, hybrid local-read/web-write mode) is under
evaluation in the agent-system repo (its task 39). Do NOT register it here yet. If that
decision lands on "adopt", registration belongs in the `claudeMcpServers` activation block in
`modules/home/core/dotfiles.nix` with permission grants at the same scope, following the
grant-at-registration-scope principle recorded in this repo's task 128 description.

## Verification checklist for implementation

1. `home-manager switch` (or full rebuild) succeeds; `nix flake check` clean.
2. `command -v zot` resolves from a fresh bash AND fish shell; `zot --version` reports ≥0.10.0.
3. `echo $ZOTERO_API_KEY` non-empty in fresh bash and fish; `systemctl --user show-environment`
   contains it (or the chosen headless path is demonstrated another way).
4. `curl -s -d '10.1093/mind/fzab048' -H 'Content-Type: text/plain' localhost:1969/search`
   returns Zotero JSON when the service is enabled.
5. The agent-system repo's write-path task can then run its live envelope confirmation
   (`zot add --pdf` dry-run first) — coordinate, since that step writes to the real library.

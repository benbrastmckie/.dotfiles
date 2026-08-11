# Zotero Agent Tooling

Machine-level tooling that unblocks the literature extension's Zotero write-back path
(`~/.config/nvim`, its tasks 38/39): the `zot` CLI on PATH, managed credentials reachable from
every context that needs them, and an optional local metadata-resolution service.

## `zot` CLI

`zot` (zotero-cli-cc) is packaged as a `writeShellScriptBin` wrapper
(`packages/zot.nix`, registered in `overlays/unstable-packages.nix`, installed via
`modules/home/packages/misc.nix`). It resolves from every shell (fish, bash) and from
agent-spawned bash — no global PATH policy change. See [`docs/packages.md`](packages.md#zot--zotero-cli-cc-packageszotnix)
for packaging details.

## Translation Server (metadata resolution)

`services.zoteroTranslationServer` (`modules/home/services/zotero-translation-server.nix`) runs
the nixpkgs `zotero-translation-server` package as a `systemd --user` service, bound to
**`127.0.0.1:1969` only** — **disabled by default**.

**Enable it** by setting, in your home-manager config:

```nix
services.zoteroTranslationServer.enable = true;
```

then `home-manager switch --flake .#benjamin`.

**Endpoints** (once enabled):

- `POST /search` — resolve metadata by identifier (DOI, ISBN, PMID, arXiv ID). Body: the raw
  identifier string. Example:
  ```bash
  curl -s -d '10.1093/mind/fzab048' -H 'Content-Type: text/plain' http://127.0.0.1:1969/search
  ```
- `POST /web` — resolve metadata by URL. Body: the URL, `Content-Type: text/plain`.

**Properties**:
- Stateless — no persistent data, no credentials, no auth required (the service itself carries
  no Zotero API key; it only translates page/identifier metadata into Zotero-compatible JSON).
- The consuming repo degrades gracefully when the service is down (metadata resolution is an
  enhancement, not a hard dependency of the write-back path).
- The package's own default config listens on `0.0.0.0`; the module overrides this to
  `127.0.0.1` via `NODE_CONFIG` (the `config` npm module's standard env-var override). Verify
  with `ss -lntp | grep 1969` after enabling — it must show `127.0.0.1:1969`, never `0.0.0.0:1969`.

**Default state**: off. Toggling it on is a deliberate, explicit action.

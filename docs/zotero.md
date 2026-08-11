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

## Declarative `~/.config/zot/config.toml`

`modules/home/core/zotero.nix` writes `~/.config/zot/config.toml` from a `home.activation`
script, sourced from the same sops secret as everything else below. This gives `zot` credentials
with **zero** dependence on environment propagation — a plain file under `$HOME` needs no
propagation at all, so it works from interactive shells, agent-spawned bash, and `systemd --user`
units alike.

- `data_dir` points at `~/Documents/Zotero` — the **active** data directory. The decoy `~/Zotero`
  directory is never referenced.
- Written with `umask 077` + explicit `chmod 0600`.
- Respects `home-manager switch --dry-run` (prints `Would write ...`, mutates nothing).
- Idempotent: unchanged input produces byte-identical output on repeated `home-manager switch`
  runs.
- `zot config init` is **never** invoked against this path by this repo — see the design
  rationale in the module header.

## Credentials and rotation

**Every location the Zotero API key lands, derived from one source of truth**:

| Location | Form | Regenerates from |
|----------|------|-------------------|
| `secrets/secrets.yaml` (`zotero_api_key`) | age-encrypted (source of truth) | manual `sops` edit |
| `/run/secrets/zotero_api_key` | plaintext, tmpfs, mode `0400`, owner `benjamin` | sops-nix decryption at NixOS activation |
| `~/.config/zot/config.toml` | **plaintext, mode `0600`, under `$HOME`** | `home-manager switch` (`home.activation.zotConfig`) |
| Fish `ZOTERO_API_KEY`/`ZOT_API_KEY`/`ZOT_LIBRARY_ID` | shell env, fresh shells only | `programs.fish.interactiveShellInit` (`modules/system/shell.nix`) |
| Bash `ZOTERO_API_KEY`/`ZOT_API_KEY`/`ZOT_LIBRARY_ID` | shell env, fresh shells only | `programs.bash.interactiveShellInit` (`modules/system/shell.nix`) |
| `systemctl --user show-environment` | systemd user-manager env, units started after activation | `zotero-env.service` oneshot (`modules/home/services/zotero-env.nix`) |

`~/.config/zot/config.toml` is the **one plaintext-at-rest copy** on the filesystem outside of
`/run/secrets` (which is tmpfs, not disk). `zot` offers no keyring or encrypted-storage
alternative for its own config — this is the accepted trade-off for headless reach (an agent
process or a `systemd --user` unit needs credentials with no shell/session context available).

### Rotation runbook

Rotating the key means editing `secrets/secrets.yaml` and rebuilding — **nothing else**. Every
derived location above regenerates automatically; none needs a manual edit.

1. Create a replacement key at `https://www.zotero.org/settings/keys` with the same grants as the
   current one — `library: true`, `files: true`, `write: true` on the personal library (userID
   `2622830`, username `benbrastmckie`).
2. Verify the new key's grants before adopting it (read-only, no library write):
   `curl -s -H "Zotero-API-Key: <NEW_KEY>" https://api.zotero.org/keys/current` — must report
   `"userID": 2622830` and `"access": {"user": {"library": true, "files": true, "write": true}}}`.
3. `sops secrets/secrets.yaml` (or `sops --set '["zotero_api_key"] "<NEW_KEY>"' secrets/secrets.yaml`)
   and replace the `zotero_api_key` value.
4. `sudo nixos-rebuild switch --flake .#$(hostname)` — re-decrypts `/run/secrets/zotero_api_key`.
5. `home-manager switch --flake .#benjamin` — rewrites `~/.config/zot/config.toml`.
6. `systemctl --user restart zotero-env` — repopulates `systemctl --user show-environment`.
7. Open a **fresh** shell (fish and bash) to pick up the new exports.
8. Only after steps 1-7 are confirmed working, revoke the **old** key at
   `https://www.zotero.org/settings/keys`.

**Provisioning history**: this tooling was seeded with the pre-existing key (rotation deferred to
an operator with zotero.org browser access — no new key was created or revoked by the
implementing agent). Run the full runbook above at the earliest opportunity to complete the
rotation this task was scoped to perform, and to retire the plaintext export that previously
lived at `~/.config/fish/conf.d/private.fish` (see that file's line 49 — left in place until the
precedence assertion in this repo's task plan is proven live).

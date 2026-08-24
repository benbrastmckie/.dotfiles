# Research Report: Task #129 (Round 2 — Live Re-Verification + Credential Bootstrap Gap)

- **Task**: 129 - Provision the machine-level tooling that unblocks the literature extension's
  Zotero write-back path
- **Started**: 2026-08-11T08:53:17-07:00
- **Completed**: 2026-08-11
- **Effort**: ~2-3 hours implementation (revised up from seed estimate — see Item 5)
- **Dependencies**: None (re-confirms and supersedes report 01 where facts diverge)
- **Sources/Inputs**: Live repo inspection (`~/.dotfiles`), live `nix search`/`nix build` against
  the pinned `nixos-26.05` channel, live web fetches of zotero-cli-cc's PyPI page, GitHub repo,
  and documentation site (`agents365-ai.github.io/zotero-cli-cc`), and direct inspection of the
  consuming repo's scripts/docs at `~/.config/nvim/agent-system/extensions/literature/`
- **Artifacts**: this report; supersedes/refines
  `specs/129_provision_zotero_agent_tooling/reports/01_zotero-tooling-provisioning-research.md`
  (report 01's Items 1, 3, 4 are reconfirmed as written; Item 2 is materially revised — see below)
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Item 1 (`zot` on PATH) reconfirmed unchanged.** `zotero-cli-cc` 0.10.0 (PyPI, released
  2026-07-15) is still current (latest release ~25 days old as of this check). `command -v zot`
  still fails on this machine. `uvx` still resolves reliably at
  `/run/current-system/sw/bin/uvx`. The `writeShellScriptBin "zot"` wrapper plan is correct and
  has three ready-made precedents in this exact repo (`packages/aristotle.nix`,
  `packages/playwright-mcp.nix`, `packages/loogle.nix` + `overlays/unstable-packages.nix` +
  `modules/home/packages/misc.nix`).
- **Item 2 (managed `ZOTERO_API_KEY`) needs a design revision, not just relocation.** The
  variable name this task and the consuming repo's scripts use throughout — `ZOTERO_API_KEY` —
  is **not** an environment variable `zot` itself recognizes. `zot`'s own documented environment
  variables are `ZOT_API_KEY`, `ZOT_LIBRARY_ID`, `ZOT_DATA_DIR`, `ZOT_PROFILE` (plus unrelated
  `S2_API_KEY`/embedding vars). Simply relocating `ZOTERO_API_KEY` into sops and exporting it
  more broadly (report 01's plan) fixes visibility for the consuming repo's *gate-check* scripts
  but does **not** by itself give `zot` credentials it can actually use. See Item 2 (revised)
  and Item 5 (new) below for the reconciled design.
- **Item 3 (translation-server) has a better option than Docker/podman.** `nixpkgs` (on the
  pinned `nixos-26.05` channel already used by this flake) ships `zotero-translation-server`
  directly — no container runtime needed. Verified: builds/fetches from cache, self-contained
  (694 translator files bundled), single binary `translation-server`, default `port = 1969`,
  default `host = "0.0.0.0"` (needs an override to bind localhost-only per the task's
  requirement).
- **Item 4 (zotero-mcp) reconfirmed as-is: do not register yet.**
- **Item 5 (new, coordinator-directed): `zot config init` is a real, separate gap from Item 2**,
  not covered by the original task description. `zot`'s Web API write path is documented as
  needing `~/.config/zot/config.toml` (TOML) with `library_id` + `api_key` (+ `data_dir`),
  written by `zot config init` — which fully supports non-interactive flag invocation
  (`--library-id`, `--api-key`, `--data-dir`, `--config-path`), so it does not have to be run by
  a human at a prompt. Recommendation: generate this file declaratively via a Nix activation
  script sourced from the same sops secret as `ZOTERO_API_KEY`, rather than running `zot config
  init` imperatively — this keeps a single source of truth and avoids a second manual
  credential-management surface. Full analysis below.

## Context & Scope

This is a second research pass over the same task, requested to (a) re-verify report 01's facts
live since some time may have passed in-session, and (b) fold in field evidence surfaced after
report 01 was written: an attempted `zot add --pdf` write in the consuming repo failed because
"`zot config init` hasn't been run in this environment." That failure is the concrete signal
that Item 2 as originally scoped (just relocate/export `ZOTERO_API_KEY`) is incomplete. This
report documents why, and what else is needed.

No writes were made to the real Zotero library, and `zot config init` was not run, per
instruction — this is research/documentation only.

## Findings

### Item 1: `zot` on PATH — reconfirmed, no changes to report 01's recommendation

- PyPI: `zotero-cli-cc`, latest release **0.10.0, 2026-07-15**, ~25 days old at time of this
  check (2026-08-11) — actively maintained, 26 total releases. `pip install zotero-cli-cc`
  installs `zot`.
- `command -v zot` still fails on this machine (confirmed live via Bash tool in this session).
- `command -v uvx` / `command -v uv` both resolve to `/run/current-system/sw/bin/{uvx,uv}` —
  reliably on PATH, confirming the seed report's PATH-gap analysis and preferred fix.
- **Established wiring pattern in this repo** (verified by reading all three files):
  1. `packages/{name}.nix` — a `writeShellScriptBin` derivation. Closest precedent is
     `packages/aristotle.nix`:
     ```nix
     { writeShellScriptBin, uv }:
     writeShellScriptBin "aristotle" ''
       exec ${uv}/bin/uvx --from aristotlelib@latest aristotle "$@"
     ''
     ```
     A `zot` wrapper is the same shape: `exec ${uv}/bin/uvx --from zotero-cli-cc zot "$@"`.
  2. `overlays/unstable-packages.nix` registers it: `zot = final.callPackage ../packages/zot.nix
     { };` (mirrors the `loogle`/`aristotle`/`playwright-mcp` lines already there).
  3. `modules/home/packages/misc.nix` (the file that already lists `playwright-mcp` under "AI
     and coding assistant tools") adds `zot` to `home.packages`.
- No changes needed to this plan from report 01.

### Item 2 (REVISED): managed credentials — `ZOTERO_API_KEY` is not what `zot` reads

**The core new fact**: `zot`'s own documentation (fetched live from
`https://agents365-ai.github.io/zotero-cli-cc/getting-started/setup/`, raw HTML grepped directly
to avoid summarization drift) lists exactly these environment variables:

| Variable | Purpose |
|---|---|
| `ZOT_DATA_DIR` | Override Zotero data directory path |
| `ZOT_LIBRARY_ID` | Override Library ID (write operations) |
| `ZOT_API_KEY` | Override API Key (write operations) |
| `ZOT_PROFILE` | Override default config profile |
| `S2_API_KEY` | Semantic Scholar key (unrelated, for `update-status`) |
| `ZOT_EMBEDDING_URL` / `ZOT_EMBEDDING_KEY` / `ZOT_EMBEDDING_MODEL` / `ZOT_EMBEDDING_PROVIDER` | Optional semantic search (unrelated) |

`ZOTERO_API_KEY` does not appear anywhere in `zot`'s README, CLI reference, or setup docs. This
was cross-checked in three independent places (raw README from GitHub, raw setup-page HTML, raw
CLI-reference HTML) and confirmed absent throughout — this is not a summarization artifact.

**Meanwhile, the consuming repo (`~/.config/nvim`) uses `ZOTERO_API_KEY` exclusively**, verified
by grepping its literature-extension scripts directly:
- `agent-system/extensions/literature/scripts/zotero-write.sh` — gates all write operations on
  `[[ -z "${ZOTERO_API_KEY:-}" ]]`, exits 2 with `"run /zotero --setup or: zot config init"` if
  unset, but never re-exports it as `ZOT_API_KEY` before invoking `zot`.
- `agent-system/extensions/literature/scripts/zotero-setup.sh` — its `--status` subcommand
  reports `ZOTERO_API_KEY: set/unset`, nothing about `ZOT_API_KEY` or `~/.config/zot/config.toml`.
- `agent-system/extensions/literature/scripts/zotero-attach-chunks.sh` — same gate.
- `agent-system/extensions/literature/context/project/literature/patterns/zotero-item-creation.md`
  — documents the "`$ZOTERO_API_KEY` dependency."
- This machine's `~/.config/fish/conf.d/private.fish` line 49 also exports `ZOTERO_API_KEY`
  (confirmed still present, unmanaged by Nix, as in report 01).

**Consequence**: setting only `ZOTERO_API_KEY` (report 01's plan, and the task description's
Item 2 as originally worded) satisfies the consuming repo's own precondition *checks*, but does
**not** give `zot` a credential it will actually use for its Web API calls — those calls need
`ZOT_API_KEY` (env) or `api_key` (config file). This is a highly plausible root cause of the
field evidence: `ZOTERO_API_KEY` may already be set in some shells, yet `zot add --pdf` still
failed for lack of configured credentials, because `zot` was never given `ZOT_API_KEY` or a
config file.

**Revised recommendation for Item 2**:

1. Keep the sops relocation plan from report 01 (move the key out of `private.fish` into
   `secrets/secrets.yaml`, following the existing `link_api_token`/`ollama_api_key` pattern in
   `modules/system/optional/discord-bot.nix`). Rotation-at-migration is still an open decision
   for the user (see report 01's honest note on plaintext exposure/session-log history) —
   unchanged by this report.
2. **Export both names** from the decrypted secret at the same call sites:
   `ZOTERO_API_KEY` (compat with the consuming repo's existing gate-check scripts, until/unless
   that repo updates them) **and** `ZOT_API_KEY` (what `zot` itself reads). Same mechanism,
   twice — cheap and low-risk.
3. **Also export `ZOT_LIBRARY_ID`** — this is the Zotero *userID*, already established as
   `2622830` in report 01 via `GET https://api.zotero.org/keys/current` (username
   `benbrastmckie`). It is not a sensitive value in the same sense as the API key (Zotero user
   IDs are not secret), but `zot`'s write path needs it and it is not currently exported
   anywhere on this machine under any name.
4. **`programs.fish.interactiveShellInit`** already has the established pattern for this exact
   shape of problem — `modules/system/shell.nix` currently does:
   ```nix
   programs.fish.interactiveShellInit = ''
     zoxide init fish | source
     if test -r /run/secrets/link_api_token
       set -gx DISCORD_BOT_LINK_TOKEN (cat /run/secrets/link_api_token)
     end
   '';
   ```
   The same `if test -r /run/secrets/X ... set -gx` block, repeated for
   `zotero_api_key`/`ZOTERO_API_KEY`+`ZOT_API_KEY`, is the fish half of the fix.
5. **Bash has no equivalent today** — grepped the whole repo; only `programs.fish` is configured
   at `modules/system/shell.nix`, no `programs.bash.interactiveShellInit` or
   `environment.interactiveShellInit` exists anywhere. Both are real, confirmed NixOS options
   (`programs.bash.interactiveShellInit` is Bash-specific and the documented preferred place for
   Bash-only logic; `environment.interactiveShellInit` is the shell-agnostic sibling but NixOS
   docs advise not to assume Bash there). A `programs.bash.interactiveShellInit` block mirroring
   the fish one is the correct fix for "fresh bash" reach in the verification checklist.
6. **`systemctl --user show-environment` reach — `home.sessionVariables` will NOT do this.**
   Verified live via web search against `nix-community/home-manager` issue #5542 ("systemd
   services do not have `home.sessionVariables` in their environment") — this is a known,
   still-open gap: Home Manager's `home.sessionVariables` writes a profile script sourced by
   login shells, but systemd `--user` units do not automatically inherit it. The correct
   mechanisms, in order of fit for this repo:
   - **Preferred, matches existing repo idiom**: a `systemd.user.services.zotero-env` oneshot
     (home-manager), `wantedBy = [ "default.target" ]`, that runs (via `bash -c`, since
     `ExecStart` does not get shell expansion by default):
     ```
     systemctl --user set-environment ZOTERO_API_KEY="$(cat /run/secrets/zotero_api_key)" ZOT_API_KEY="$(cat /run/secrets/zotero_api_key)" ZOT_LIBRARY_ID=2622830
     ```
     `systemctl --user set-environment` is the standard idiom for exactly this problem — it
     updates the user manager's default environment (visible to `systemctl --user
     show-environment` and inherited by every unit started afterward), independent of shell
     inheritance.
   - **Alternative**: home-manager's `systemd.user.sessionVariables` option (confirmed real via
     MyNixOS docs), which renders an `environment.d(5)`-format drop-in under
     `~/.config/environment.d/`. This is declarative and avoids a oneshot unit, but its value is
     a plain Nix string baked at build time — it **cannot** read a runtime-decrypted secret path
     (no `$(cat ...)` expansion in `environment.d` files, which systemd's generator parses
     literally, not through a shell). This option is only usable here if paired with sops-nix's
     `sops.templates` mechanism (which does support runtime secret interpolation into a
     generated file) — more moving parts than the oneshot-unit approach above. Documented here
     as an alternative for the planning phase to weigh, not a first recommendation.
7. Note: `sops-nix` is currently wired into this flake **only at the NixOS system level**
   (`sops-nix.nixosModules.sops`, used for the ISO/host configs) — there is no
   `sops-nix.homeManagerModules.sops` import anywhere in this repo. All existing secret
   consumption (`discord-bot.nix`) is a NixOS *system* module reading `config.sops.secrets`. A
   new `zotero_api_key` secret should follow the same system-level pattern (a new
   `sops.secrets."zotero_api_key" = { owner = config.users.users.${username}.name; };`
   declaration), decrypting to `/run/secrets/zotero_api_key`, exactly like the existing
   `link_api_token` secret consumed by `modules/system/shell.nix`.
8. **Structural note for whoever implements this**: `discord-bot.nix` currently sets
   `sops.defaultSopsFile` and `sops.age.keyFile` **inside** `lib.mkIf cfg.enable`. Both real
   hosts (`nandi`, `hamsa`) happen to enable `services.discordBot`, so this "just works" today,
   but it means secrets availability is accidentally coupled to an unrelated feature toggle. A
   new always-on `zotero_api_key` secret either needs its own unconditional
   `sops.defaultSopsFile`/`age.keyFile` declaration, or that pair should be hoisted out of the
   `mkIf` block in `discord-bot.nix` into always-on config. Flagging this now so the planning
   phase makes it a deliberate choice rather than an accidental dependency on the Discord bot
   being enabled.

### Item 3 (REVISED, simpler than report 01): translation-server — use the nixpkgs package directly

Report 01 recommended `virtualisation.oci-containers`/podman with the official Docker image.
Live verification found a **better, container-free option already on the pinned channel**:

- `nix search nixpkgs zotero` (against this flake's pinned `nixpkgs` input, `nixos-26.05`)
  returns `zotero-translation-server` (version `2023-07-13`), description "Node.js-based server
  to run Zotero translators."
- `nix build nixpkgs#zotero-translation-server --no-link --print-out-paths` succeeds, fetching
  from the binary cache (10.7 MiB download) — confirms it is buildable/cacheable on this channel
  right now, no source build required.
- Inspected the built store path directly:
  - `bin/translation-server` execs `node .../src/server.js` — a single self-contained entry
    point, `meta.mainProgram = "translation-server"`.
  - `lib/node_modules/translation-server/modules/translators/` contains 694 bundled `.js`
    translator files — fully self-contained, no separate translators-repo fetch needed at
    runtime.
  - Default config (`share/zotero-translation-server/config/default.json5`):
    ```json5
    {
      "port": 1969,
      "host": "0.0.0.0",   // needs override for localhost-only, per this task's requirement
      "translatorsDirectory": "./modules/translators",  // relative — resolves against cwd
      ...
    }
    ```
- **Recommendation**: a `systemd.user.services.zotero-translation-server` (or system service,
  matching whatever pattern the planning phase picks for consistency with the rest of the repo)
  running `${pkgs.zotero-translation-server}/bin/translation-server`, with:
  - `WorkingDirectory = "${pkgs.zotero-translation-server}/lib/node_modules/translation-server"`
    (so the relative `translatorsDirectory` resolves correctly), **or** set
    `TRANSLATORS_DIR=<absolute path>` env var (the package's
    `custom-environment-variables.json` maps `TRANSLATORS_DIR` to `translatorsDirectory`,
    confirmed by direct inspection of that file in the store path) — either works.
  - `Environment = "NODE_CONFIG={\"host\":\"127.0.0.1\"}"` (the `config` npm module's standard
    env-var override, applies regardless of `custom-environment-variables.json`) to satisfy the
    task's "localhost-only" requirement, since the package default is `0.0.0.0`.
  - `disabled by default` per the task's toggle requirement: an `lib.mkEnableOption`-gated NixOS
    or home-manager option, same shape as `services.discordBot.enable`.
- This avoids podman/`virtualisation.oci-containers` entirely — no container runtime dependency,
  no image-pull step, no Docker Hub/GHCR credential surface. Simpler and more in keeping with
  this repo's general preference (seen throughout `packages/*.nix`) for native nix-store
  binaries over containers. Report 01's podman option is still viable as a fallback if the
  planning phase prefers process isolation, but is no longer the only or default-recommended
  path.
- Endpoints (`POST /search`, `POST /web`) and statelessness/no-credentials claims from report 01
  are unaffected by this packaging change and remain accurate (config file confirms no auth
  fields exist in `default.json5`).

### Item 4: zotero-mcp — reconfirmed, no changes

Still explicitly deferred to the agent-system repo's task 39 decision. No action here beyond
what report 01 already specified (register in `claudeMcpServers` activation block in
`modules/home/core/dotfiles.nix` at the same grant scope, only if/when that repo adopts it).

### Item 5 (NEW — coordinator-directed): the `zot config init` credential-bootstrap gap

This item did not exist in the original task description or report 01. It was surfaced by field
evidence after report 01 was written: an attempted `zot add --pdf` in the consuming repo failed
because `zot config init` had never been run. Investigated live against `zot`'s GitHub repo
(`Agents365-ai/zotero-cli-cc`) and documentation site; raw HTML/Markdown fetched directly and
grepped (not just summarized) to get literal field names.

**1. What `zot config init` writes.**

- Path: **`~/.config/zot/config.toml`** (confirmed literal text: "This saves your Library ID and
  API Key to `~/.config/zot/config.toml`.")
- Format: TOML, with (at minimum) a `[zotero]` section:
  ```toml
  [zotero]
  data_dir = "D:\\MyZotero"
  library_id = "12345"
  api_key = "xxx"

  [output]
  default_format = "table"
  limit = 50

  [export]
  default_style = "bibtex"
  ```
- The command supports non-interactive, flag-based invocation — confirmed from the raw CLI
  reference page:
  ```
  zot config init [OPTIONS]
    --config-path  path   Config file path
    --data-dir     text   Zotero data directory (auto-detected if not set)
    --library-id   text   Zotero library ID
    --api-key      text   Zotero API key
  ```
  It is **not** interactive-only — it can be scripted with all values supplied as flags. (Its
  idempotency — whether re-running it on an already-configured machine overwrites cleanly or
  errors — is not documented on the pages fetched; this is a genuine open question, deliberately
  not resolved here since actually invoking `zot config init` against the real setup was
  explicitly out of scope for this research task. Flag this for the implementation/verification
  phase: test idempotency in a way that does not touch the real library, e.g. `--config-path` to
  a scratch location first.)
- **Is `ZOTERO_API_KEY` alone sufficient, without running `config init`?** No — see Item 2's
  finding: `zot` does not recognize `ZOTERO_API_KEY` as an environment variable at all. Either
  `ZOT_API_KEY` (+ `ZOT_LIBRARY_ID`) must be exported, or `~/.config/zot/config.toml` must exist
  with `api_key` (+ `library_id`) populated. The env-var path and the config-file path are
  independent, either-sufficient mechanisms — not a strict requirement for `config init`
  specifically — but the *currently exported* variable name (`ZOTERO_API_KEY`) satisfies
  neither.

**2. Does the config file duplicate the API key in plaintext on disk?**

Yes — the documented example shows `api_key = "xxx"` as a bare TOML string; nothing on the
docs site or in the README references OS keyring integration, encryption, or restricted-mode
file creation. This **does** interact directly with Item 2's secrets/rotation decision, exactly
as the coordinator flagged: if this repo relocates `ZOTERO_API_KEY` into sops but a
`~/.config/zot/config.toml` also gets populated with the same key (whether by a human running
`zot config init` manually, or by this repo's own provisioning), there would be **two**
plaintext-adjacent locations to keep in sync and to consider during any future rotation:
`/run/secrets/zotero_api_key` (sops-decrypted, tmpfs, root/owner-restricted by sops-nix
convention) and `~/.config/zot/config.toml` (a plain file under `$HOME`, whatever permissions
`zot` itself sets — unverified, flag for implementation to check e.g. `stat -c %a` after any
test run against a scratch config path).

**3. Can the config be generated declaratively by Nix instead of run imperatively?**

Yes, and this is the recommended approach, for the same reason report 01 preferred a Nix-built
wrapper over `uv tool install` for Item 1 — it keeps one source of truth and survives rebuilds.
Two viable mechanisms:

- **(a) Nix activation script that shells out to `zot config init` with flags**, reading the
  decrypted secret at activation time (same idempotent-merge shape as the existing
  `activation.claudeMcpServers` block in `modules/home/core/dotfiles.nix`, which already
  demonstrates the pattern of a `home.activation.*` block that is safe to re-run on every
  `home-manager switch`, respects `DRY_RUN`, and reads from a runtime path rather than a
  build-time value):
  ```bash
  ${pkgs.zot}/bin/zot config init \
    --library-id 2622830 \
    --api-key "$(cat /run/secrets/zotero_api_key)" \
    --data-dir "${config.home.homeDirectory}/Documents/Zotero"
  ```
  Pro: uses the tool's own writer, forward-compatible if the TOML schema grows fields this
  report doesn't know about. Con: idempotency behavior unverified (see above); depends on `zot`
  package being present in the activation sandbox.
- **(b) Write `~/.config/zot/config.toml` directly** (a plain heredoc/`cat >` in an activation
  script, or `home.file`/`xdg.configFile` — though the latter two bake content into the Nix
  store at eval time and are unsuitable for the secret value specifically; only the non-secret
  fields like `data_dir` could safely go through `home.file`). Pro: no dependency on `zot`'s own
  CLI behavior or idempotency; full control over exact content. Con: hand-maintains a schema
  that could drift from what a future `zot` version expects.
- Either way, the **single source of truth** should be the sops-managed secret
  (`/run/secrets/zotero_api_key`), with the config file and the `ZOT_API_KEY`/`ZOTERO_API_KEY`
  env-var exports (Item 2) all derived from it at activation/session time. This directly answers
  the coordinator's rotation concern: rotating the key only ever means updating
  `secrets/secrets.yaml` via `sops` and re-running `home-manager switch` — the config file and
  env vars regenerate from the same source rather than needing separate manual updates.
- **Library-ID note**: `library_id` (`2622830`) is not independently re-derivable from the API
  key by `zot` at config-write time without a network call — the seed report already discovered
  it via a live `GET /keys/current` call. It should be recorded as a plain (non-secret) constant
  in the new Nix code (with a comment pointing at how it was derived and dated), not re-derived
  imperatively on every rebuild.

**4. Does the config need to exist for agent-spawned bash and systemd user services, not just
interactive shells?**

Yes, and this is actually the strongest argument for approach (a)/(b) above over relying on env
vars alone: **`~/.config/zot/config.toml` is a plain file under `$HOME`** — it needs no PATH or
environment-variable propagation at all to be visible to `zot`, regardless of whether `zot` is
invoked from an interactive fish/bash shell, an agent-spawned bash subprocess, or a `systemd
--user` unit. This sidesteps the entire `systemctl --user show-environment` propagation problem
documented under Item 2 point 6, for `zot`'s own authentication specifically. The env-var exports
(`ZOTERO_API_KEY`, `ZOT_API_KEY`, `ZOT_LIBRARY_ID`) remain necessary anyway, but only for the
consuming repo's own gate-check scripts (which read `ZOTERO_API_KEY` directly, not by asking
`zot` whether it is configured) — not for `zot`'s actual Web API calls once the config file
exists.

**Net implication for planning**: Item 2 and Item 5 should be planned as one unit, not two
separate phases — the recommended design writes the sops-sourced API key into three places from
one activation script or a small set of activation scripts: `/run/secrets/zotero_api_key`
(sops, unchanged mechanism), shell env vars (`ZOTERO_API_KEY` + `ZOT_API_KEY` + `ZOT_LIBRARY_ID`,
fish + new bash `interactiveShellInit`, and a `systemctl --user set-environment` oneshot for
headless reach), and `~/.config/zot/config.toml` (new, solves headless reach for `zot`'s own
auth independently of env-var propagation).

## Decisions

- Item 1: no change from report 01 — proceed with the `writeShellScriptBin "zot"` wrapper.
- Item 2: **revised** — export both `ZOTERO_API_KEY` (compat) and `ZOT_API_KEY`/`ZOT_LIBRARY_ID`
  (what `zot` actually reads); add `programs.bash.interactiveShellInit` (new, no precedent
  exists yet) alongside the existing fish pattern; use `systemctl --user set-environment` via a
  oneshot unit (not `home.sessionVariables`) for `systemctl --user show-environment` reach.
- Item 3: **revised** — prefer the native `nixpkgs#zotero-translation-server` package over
  podman/`oci-containers`; override `host` to `127.0.0.1` via `NODE_CONFIG`.
- Item 4: no change — do not register `zotero-mcp` yet.
- Item 5: **new** — treat `~/.config/zot/config.toml` generation as first-class, sourced from
  the same sops secret as Item 2, via a Nix activation script (not a manual `zot config init`
  run), rather than as an afterthought or something left to the consuming repo.

## Risks & Mitigations

- **Naming mismatch risk**: if the implementation phase only "relocates `ZOTERO_API_KEY`" per
  the original task wording without reading this report, the write path will remain broken
  exactly as the field evidence showed, just with the key living in a nicer place. Mitigation:
  this report's Item 2/Item 5 net-implication section explicitly calls this out as one unit.
- **`zot config init` idempotency unknown**: re-running an activation script that calls it on
  every `home-manager switch` could error or silently no-op if already configured. Mitigation:
  the implementation phase should verify this against a `--config-path` scratch location before
  wiring it into the real activation path, or prefer approach (b) (direct TOML write, fully
  Nix-controlled idempotency) if `config init`'s behavior proves unfriendly to repeated runs.
- **`sops.defaultSopsFile`/`age.keyFile` coupled to `discordBot.enable`**: a new always-on
  zotero secret must not silently depend on an unrelated toggle. Mitigation: called out
  explicitly in Item 2 point 8 for the planning phase to address.
- **Cross-repo coordination**: the consuming repo's gate-check scripts key off `ZOTERO_API_KEY`
  specifically; if a future edit to those scripts changes what they check, this repo's exported
  variable set should be revisited. Out of scope to fix here (this repo does not own those
  scripts), but worth a one-line note back to that repo's task 38/39 owner.

## Appendix: search queries and live checks used

- `nix search nixpkgs zotero`, `nix search nixpkgs translation-server` (against this flake's
  pinned `nixpkgs`)
- `nix build nixpkgs#zotero-translation-server --no-link --print-out-paths`
- Direct inspection of the built store path's `bin/`, `share/.../config/default.json5`,
  `custom-environment-variables.json`, and `modules/translators/` file count
- `command -v zot`, `command -v uvx`, `command -v uv`, `echo $PATH` (this session's shell)
- WebSearch: "zotero-cli-cc pypi", "home-manager systemd user sessionVariables environment.d
  import-environment", "nixpkgs zotero-translation-server package", "NixOS
  programs.bash.interactiveShellInit option environment.interactiveShellInit"
- `curl` (raw HTML/Markdown, not WebFetch-summarized) against:
  - `https://agents365-ai.github.io/zotero-cli-cc/getting-started/setup/`
  - `https://agents365-ai.github.io/zotero-cli-cc/reference/cli/`
  - `https://agents365-ai.github.io/zotero-cli-cc/getting-started/quickstart/`
  - `https://raw.githubusercontent.com/Agents365-ai/zotero-cli-cc/main/README.md`
- Repo greps: `secrets/`, `.sops.yaml`, `modules/system/optional/discord-bot.nix`,
  `modules/system/shell.nix`, `modules/home/core/dotfiles.nix`, `overlays/unstable-packages.nix`,
  `packages/{aristotle,playwright-mcp,loogle}.nix`, `modules/home/packages/misc.nix`,
  `hosts/{nandi,hamsa}/default.nix`
- Consuming-repo greps/reads (read-only, no writes): `~/.config/nvim/agent-system/extensions/
  literature/scripts/{zotero-setup.sh,zotero-write.sh,zotero-attach-chunks.sh}`,
  `~/.config/nvim/agent-system/extensions/literature/context/project/literature/domain/
  zotero-integration.md`, `~/.config/docs/common/zotero-setup.md`

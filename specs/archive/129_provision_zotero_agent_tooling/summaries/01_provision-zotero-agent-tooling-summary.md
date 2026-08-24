# Implementation Summary: Task #129

**Completed**: 2026-08-11
**Duration**: ~2.5 hours (initial pass) + verification/reconciliation dispatch

## Overview

Provisioned the machine-level tooling that unblocks the literature extension's Zotero write-back
path: a `zot` CLI wrapper on PATH, a single sops-encrypted source of truth for the Zotero API key
wired into shell exports / `systemd --user` environment / a declarative `~/.config/zot/config.toml`,
and an optional, disabled-by-default, localhost-only `zotero-translation-server`. All eight plan
phases are now complete and verified live: the operator ran `sudo nixos-rebuild switch --flake
.#hamsa` and `home-manager switch --flake .#benjamin`, rotated the Zotero API key (new key created
and confirmed working, old key confirmed revoked via HTTP 403), and removed the last plaintext
credential from `~/.config/fish/conf.d/private.fish`. Every credential-dependent check that was
previously deferred has now been re-run and confirmed independently in this dispatch.

## What Changed

- `packages/zot.nix` — `writeShellScriptBin` wrapper (`uvx --from zotero-cli-cc@latest`),
  mirroring `packages/aristotle.nix`. Registered in `overlays/unstable-packages.nix`, installed
  via `modules/home/packages/misc.nix`.
- `secrets/secrets.yaml` — encrypted `zotero_api_key`, rotated by the operator to a new key with
  `library`+`files`+`notes`+`write` grants (userID 2622830). The old key is confirmed revoked
  (`GET /keys/current` with the old key returns HTTP 403).
- `modules/system/secrets.nix` — always-on sops module (`defaultSopsFile`, `age.keyFile`,
  `sops.secrets."zotero_api_key"`), hoisted out of `modules/system/optional/discord-bot.nix`'s
  `lib.mkIf cfg.enable` so the secret no longer accidentally depends on `services.discordBot.enable`.
- `modules/system/shell.nix` — `programs.fish.interactiveShellInit` and
  `programs.bash.interactiveShellInit` both export `ZOTERO_API_KEY` / `ZOT_API_KEY` /
  `ZOT_LIBRARY_ID` from `/run/secrets/zotero_api_key`. Confirmed live in fresh bash and fresh
  fish, with the precedence assertion (`$ZOTERO_API_KEY` == `cat /run/secrets/zotero_api_key`)
  printing `MATCH` in both.
- `modules/home/services/zotero-env.nix` — `systemd --user` oneshot that calls `systemctl --user
  set-environment` with the same three variables, working around home-manager #5542.
  **Hardened post-initial-implementation (commit `11d7d7b`)**: fixed a latch defect where a
  not-yet-provisioned skip could exit 0 and permanently latch `RemainAfterExit` as a false
  success, masking a real subsequent failure to populate the environment. Now uses
  `ConditionPathExists` (re-evaluated every start, never latches the not-yet-provisioned case)
  plus a non-zero exit for the readable-but-not case. Confirmed live: `systemctl --user status
  zotero-env` reports `active (exited)`, `Result=success`, `ConditionResult=yes`, and
  `systemctl --user show-environment` carries all three variables.
- `modules/home/core/zotero.nix` — `home.activation.zotConfig` block writing
  `~/.config/zot/config.toml` (mode `0600`) directly from the sops secret, `DRY_RUN`-safe.
  Confirmed live: file exists, mode `600`, correct `data_dir` (the active
  `~/Documents/Zotero`, not the decoy `~/Zotero`), and `api_key` matching the rotated secret.
- `modules/home/services/zotero-translation-server.nix` — disabled-by-default `systemd --user`
  service wrapping nixpkgs' `zotero-translation-server`, `NODE_CONFIG`-overridden to
  `127.0.0.1`. Includes two fixes discovered during the initial live smoke test: (1) overrides
  the package onto `pkgs.nodejs_22` (the channel's default Node 24 crashes the bundled `config`
  npm package on every startup); (2) single-quotes the whole `NODE_CONFIG=...` pair so systemd's
  `Environment=` parser doesn't strip the JSON's inner double quotes. Currently disabled by
  default, confirmed (`0 unit files listed`), with no `enable = true` left anywhere in the repo.
- `docs/zotero.md` — toggle, endpoints, the `nodejs_22`/`NODE_CONFIG`-quoting notes, and a full
  "Credentials and rotation" section (location table + rotation runbook).
- `docs/packages.md`, `docs/unstable-packages.md`, `docs/applications.md` — documentation
  cross-references for the new package and doc.
- `modules/home/default.nix`, `modules/system/default.nix` — module imports.
- `modules/system/optional/discord-bot.nix` — removed the two hoisted `sops.*` lines; header
  updated to point at the new always-on module.
- `~/.config/fish/conf.d/private.fish` — line 49's plaintext `ZOTERO_API_KEY` export **removed**
  by the operator, after the precedence assertion confirmed the managed export was live and
  correct; replaced with an explanatory comment.

## Decisions

- Chose approach (b) (direct TOML write via activation script) over `zot config init` for
  `~/.config/zot/config.toml` — keeps idempotency under Nix's control and avoids depending on
  `zot`'s own CLI/network behavior during activation.
- Overrode `zotero-translation-server`'s `nodejs` input to `pkgs.nodejs_22` rather than
  `nodejs_20` (marked insecure on this channel) — the minimum-diff fix that keeps
  `util.isRegExp` present.
- Fixed the `NODE_CONFIG` systemd-quoting hazard by single-quoting the whole environment pair
  rather than switching to the plan's documented `TRANSLATORS_DIR` + `NODE_CONFIG`-file
  fallback — simpler, and verified working end-to-end.
- Fixed the `zotero-env` latch defect with `ConditionPathExists` + non-zero exit rather than any
  form of retry loop or timer — keeps the unit's semantics simple (systemd re-evaluates
  conditions on every start) and correctly distinguishes "not provisioned yet" from "genuinely
  broken."

## Plan Deviations

- **Phase 4 (iso/usb-installer build gate)** — altered: both fail at `nix build` time on a
  pre-existing, unrelated `zfs-kernel` package-broken error, confirmed via git-stash A/B testing
  to be present identically without this task's changes. `nix flake check` (full eval) passes
  cleanly for both. The per-host-import fallback the plan describes for this scenario was
  therefore not needed. This is a pre-existing, out-of-scope defect worth a follow-up task.
- **Phase 8 (translation-server smoke test)** — extended beyond the plan: two genuine bugs (Node
  24/`config`-package crash; systemd `Environment=` JSON quote-stripping) were discovered and
  fixed live during the initial smoke test, not anticipated by the original plan text.
- No other deviations. All operator-dependent items from the initial pass (key rotation, `sudo
  nixos-rebuild switch`, `private.fish` line 49 removal) have since been completed by the
  operator and independently re-verified in this dispatch.

## Verification

All items re-run and confirmed live in this dispatch unless noted otherwise:

- `nix flake check`: **pass** — all 5 hosts (nandi, hamsa, garuda, iso, usb-installer).
- `nix build .#nixosConfigurations.{nandi,hamsa}...toplevel`: **pass** (prior dispatch).
  `iso`/`usb-installer`: fail on pre-existing, unrelated `zfs-kernel` breakage (see Deviations).
- `nixos-rebuild build --flake .#hamsa`: **pass**.
- `sudo nixos-rebuild switch --flake .#hamsa`: **done** (operator).
- `home-manager switch --flake .#benjamin`: **pass**, idempotent.
- `zot --version` from fresh bash and fresh fish: **`0.10.0`** (>= 0.10.0 required).
- `secrets.yaml`, `/run/secrets/zotero_api_key` (mode `400 benjamin`), and
  `~/.config/zot/config.toml` (mode `600`) all agree on the new, rotated key.
- `systemctl --user show-environment` carries `ZOTERO_API_KEY`, `ZOT_API_KEY`, and
  `ZOT_LIBRARY_ID=2622830`.
- `zotero-env` unit: `active (exited)`, `Result=success`, `ConditionResult=yes` (post-latch-fix).
- Fresh interactive bash and fresh interactive fish both carry all three variables with the new
  key; precedence assertion (`$ZOTERO_API_KEY` == `cat /run/secrets/zotero_api_key`) prints
  `MATCH` in both.
- `GET https://api.zotero.org/keys/current` with the new key: userID 2622830,
  `library`+`files`+`notes`+`write` all `true`. The **old** key now returns HTTP `403` —
  rotation and revocation both confirmed.
- **Decisive headless-reach proof**: `env -i HOME="$HOME"
  PATH=/run/current-system/sw/bin:$HOME/.nix-profile/bin zot --json --limit 1 search "category"`
  returns `{"ok": true, "data": [...]}` with real library data, using zero environment
  variables — credentials come from `~/.config/zot/config.toml` alone.
- `zot config show` (read-only): populated `API Key`, `Library ID: 2622830`, correct (non-decoy)
  `Data Dir`, `Database: .../zotero.sqlite (OK)`.
- Translation-server smoke test (toggle on, tested, reverted — performed in the initial pass):
  **pass** end-to-end after fixing the `nodejs_22` and `NODE_CONFIG`-quoting bugs — `active
  (running)`, listener on `127.0.0.1:1969` (not `0.0.0.0`), `POST /search` returned real Zotero
  JSON for a DOI. Currently and correctly **disabled**: `0 unit files listed`, no
  `enable = true` anywhere in the repo.
- Discord bot (`discord-bot`, `opencode-serve`) unaffected: `systemctl status` shows both
  `active (running)`; discord-bot has been up since before this task's switch (2026-08-04),
  confirming the sops hoist did not disturb it.
- No `zot add`/`zot attach`/any write against the real Zotero library was executed at any point
  in this task: every Zotero-account command was `GET /keys/current` (read-only) or local `zot
  config show`/`--help`/`search` (read-only, no network write). The translation-server test hit
  only the local `127.0.0.1:1969` translation service, never `api.zotero.org`.
- No plaintext key material in the repo, in any commit, or in `~/.config/fish/`: `private.fish`
  line 49 has been removed and replaced with an explanatory comment; `grep -rn 'ZOTERO_API_KEY'
  ~/.config/fish/` returns nothing. `git log -p` across every commit in this task, grepped for
  both the old and new key values, returns nothing.

## Known Non-Defect (documented, not fixed)

Non-interactive, non-login bash does **not** get `ZOT_API_KEY`/`ZOT_LIBRARY_ID`, because
`programs.bash.interactiveShellInit` by definition does not run for non-interactive shells. This
does **not** break the headless requirement: `~/.config/zot/config.toml` covers it completely, as
proven by the `env -i` test above (zero environment variables, credentials supplied entirely by
the config file). No non-interactive shell hook has been added to chase this — it is the designed
fallback, not a gap.

## Handback Note (for the consuming repo's tasks 38/39 — not edited here)

- `zot` (`0.10.0`) is on PATH; credential plumbing (shell exports, `systemd --user` env,
  `~/.config/zot/config.toml`) is fully wired, rotated, and live-verified.
- The consuming repo's `ZOTERO_API_KEY` gate-check scripts and `zot`'s own credentials are
  sourced from the same secret and are live together now.
- Live `zot add --pdf` write verification is theirs, deliberately not performed here — this task
  remained read-only throughout, including in this final verification pass.
- `zotero-mcp` remains unregistered pending their task 39 decision — explicit Non-Goal, untouched.
- The translation-server toggle is `services.zoteroTranslationServer.enable` (off by default); see
  `docs/zotero.md` for the required `nodejs_22` override note if anyone enables it elsewhere.

## Notes

- Two genuine, previously-undiscovered bugs were found and fixed in the translation-server module
  during the initial live smoke test: the Node 24/`config`-package crash, and the systemd
  `Environment=` JSON quote-stripping. A third, the `zotero-env` latch defect, was found and fixed
  in a follow-up commit (`11d7d7b`) after the initial dispatch. All three are documented in their
  respective module headers and `docs/zotero.md`.
- The `iso`/`usb-installer` `zfs-kernel` build breakage is a separate, pre-existing, out-of-scope
  defect (confirmed unrelated to this task via git-stash A/B testing) — worth a follow-up task.
- Every phase's changes were committed separately (`task 129 phase N: ...`), so any single phase
  can be reverted surgically if needed.
- This task is now complete. No operator actions remain outstanding.

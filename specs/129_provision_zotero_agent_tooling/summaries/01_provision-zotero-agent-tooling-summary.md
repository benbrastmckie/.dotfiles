# Implementation Summary: Task #129

**Completed**: 2026-08-11 (partial — see Operator Actions Outstanding)
**Duration**: ~2.5 hours

## Overview

Provisioned the machine-level tooling that unblocks the literature extension's Zotero write-back
path: a `zot` CLI wrapper on PATH, a single sops-encrypted source of truth for the Zotero API key
wired into shell exports / `systemd --user` environment / a declarative `~/.config/zot/config.toml`,
and an optional, disabled-by-default, localhost-only `zotero-translation-server`. All eight plan
phases were executed; six landed fully verified live, and two carry explicit, honestly-reported
gaps caused by two anticipated capability boundaries (no zotero.org browser session, no `sudo` in
this session) rather than incomplete work. Along the way, two genuine upstream/systemd bugs were
discovered and fixed in the translation-server module — not present in the original plan.

## What Changed

- `packages/zot.nix` — new `writeShellScriptBin` wrapper (`uvx --from zotero-cli-cc@latest`),
  mirroring `packages/aristotle.nix`. Registered in `overlays/unstable-packages.nix`, installed
  via `modules/home/packages/misc.nix`.
- `secrets/secrets.yaml` — added encrypted `zotero_api_key`, seeded with the **existing**
  (pre-rotation) key value (grants verified: userID 2622830, `library`+`files`+`write` all true).
- `modules/system/secrets.nix` — new always-on sops module (`defaultSopsFile`, `age.keyFile`,
  `sops.secrets."zotero_api_key"`), hoisted out of `modules/system/optional/discord-bot.nix`'s
  `lib.mkIf cfg.enable` so the secret no longer accidentally depends on `services.discordBot.enable`.
- `modules/system/shell.nix` — extended `programs.fish.interactiveShellInit` and added a new
  `programs.bash.interactiveShellInit` block (no bash precedent existed before), both exporting
  `ZOTERO_API_KEY` / `ZOT_API_KEY` / `ZOT_LIBRARY_ID` from `/run/secrets/zotero_api_key`.
- `modules/home/services/zotero-env.nix` — new `systemd --user` oneshot that calls `systemctl
  --user set-environment` with the same three variables, working around home-manager #5542.
- `modules/home/core/zotero.nix` — new `home.activation.zotConfig` block writing
  `~/.config/zot/config.toml` (mode `0600`) directly from the sops secret, `DRY_RUN`-safe.
- `modules/home/services/zotero-translation-server.nix` — new, disabled-by-default `systemd
  --user` service wrapping nixpkgs' `zotero-translation-server`, `NODE_CONFIG`-overridden to
  `127.0.0.1`. **Includes two fixes discovered live, beyond the plan's original spec**: (1)
  overrides the package onto `pkgs.nodejs_22` (the channel's default Node 24 crashes the bundled
  `config` npm package on every startup); (2) single-quotes the whole `NODE_CONFIG=...` pair so
  systemd's `Environment=` parser doesn't strip the JSON's inner double quotes.
- `docs/zotero.md` — new: toggle, endpoints, the `nodejs_22`/`NODE_CONFIG`-quoting notes, and a
  full "Credentials and rotation" section (location table + 8-step rotation runbook).
- `docs/packages.md`, `docs/unstable-packages.md`, `docs/applications.md` — documentation
  cross-references for the new package and doc.
- `modules/home/default.nix`, `modules/system/default.nix` — module imports.
- `modules/system/optional/discord-bot.nix` — removed the two hoisted `sops.*` lines; header
  updated to point at the new always-on module.
- `home.nix` — touched transiently for the Phase 8 smoke test; net diff is empty (reverted).
- `~/.config/fish/conf.d/private.fish` — **NOT modified**, deliberately (see Operator Actions
  Outstanding).

## Decisions

- Seeded the sops secret with the pre-existing key rather than leaving it empty, per explicit
  scope instruction, so Phases 2-8's plumbing is fully testable today.
- Chose approach (b) (direct TOML write via activation script) over `zot config init` for
  `~/.config/zot/config.toml`, per report 02's recommendation — keeps idempotency under Nix's
  control and avoids depending on `zot`'s own CLI/network behavior during activation.
- Overrode `zotero-translation-server`'s `nodejs` input to `nodejs_22` rather than `nodejs_20`
  (marked insecure on this channel, refuses to build without an explicit allowlist entry) —
  `nodejs_22` is the minimum-diff fix that keeps `util.isRegExp` present.
- Fixed the `NODE_CONFIG` systemd-quoting hazard by single-quoting the whole environment pair
  rather than switching to the plan's documented `TRANSLATORS_DIR` + `NODE_CONFIG`-file
  fallback — simpler, and verified working end-to-end.
- Did not remove `~/.config/fish/conf.d/private.fish` line 49: the plan's own hard constraint
  requires proving the sops-sourced value is live (a precedence assertion) before that removal,
  and the precedence assertion is blocked on the same outstanding `sudo nixos-rebuild switch`.

## Plan Deviations

- **Phase 1** (rotation) — **skipped**: creating a new Zotero API key and revoking the old one
  requires a zotero.org browser session unavailable to this agent. This was an explicit,
  pre-declared capability boundary, not an oversight. The secret was seeded with the existing key
  instead (grants verified read-only).
- **Phase 4/5/6/7/8** (`sudo nixos-rebuild switch`-dependent verification) — **deferred**: `sudo`
  was denied outright by this session's permission policy on every invocation (not merely
  unauthenticated). All code is written, build-verified (`nix flake check`, `nixos-rebuild
  build`), and — where the verification doesn't require `/run/secrets/zotero_api_key` to exist —
  live-exercised via `home-manager switch`. Checks that require the secret to actually be
  decrypted on disk are recorded as outstanding for the operator, with exact commands provided.
- **Phase 5** (`private.fish` line 49 removal) — **skipped**, deliberately, per the plan's own
  precedence-assertion hard constraint (see above).
- **Phase 4** (iso/usb-installer build gate) — **altered**: both fail at `nix build` time on a
  pre-existing, unrelated `zfs-kernel` package-broken error, confirmed via git-stash A/B testing
  to be present identically without this task's changes. `nix flake check` (full eval, including
  `config.sops.secrets`) passes cleanly for both. The per-host-import fallback the plan describes
  for this scenario was therefore not needed.
- **Phase 8** (translation-server smoke test) — **extended beyond the plan**: two genuine bugs
  (Node 24/`config`-package crash; systemd `Environment=` JSON quote-stripping) were discovered
  and fixed live, not anticipated by the original plan text.

## Verification

- `nix flake check`: **pass** (re-run after every phase; all 5 hosts).
- `nix build .#nixosConfigurations.{nandi,hamsa}...toplevel`: **pass**. `iso`/`usb-installer`:
  fail on pre-existing, unrelated `zfs-kernel` breakage (see Deviations).
- `nixos-rebuild build --flake .#hamsa`: **pass** (re-run after every phase).
- `sudo nixos-rebuild switch --flake .#hamsa`: **NOT RUN** — sudo denied this session.
- `home-manager switch --flake .#benjamin`: **pass**, run live ~8 times across phases; idempotent.
- `home-manager switch --flake .#benjamin --dry-run`: **pass** — prints the expected "Would
  write ..." line, mutates nothing.
- `zot --version` from fresh bash and fresh fish: **`0.10.0`** (>= 0.10.0 required). Pass.
- `GET https://api.zotero.org/keys/current` (existing key): **pass** — `userID: 2622830`,
  `library`/`files`/`write` all `true`. Verified twice (Phase 1, Phase 8).
- Translation-server smoke test (toggle on, tested, reverted): **pass** end-to-end after fixing
  the two bugs above — `active (running)`, listener on `127.0.0.1:1969` (not `0.0.0.0`),
  `POST /search` returned real Zotero JSON for a DOI. Reverted: unit fully removed
  (`could not be found`), not listening, `0 unit files listed`.
- `systemctl --user status zotero-env`: **pass** — `active (exited)`, correctly logs a guarded
  skip notice pre-secret.
- `stat -c %a ~/.config/zot/config.toml`: **outstanding** — file not yet created (guarded skip
  confirmed correct pre-secret).
- Fresh-shell `ZOTERO_API_KEY`/`ZOT_API_KEY`/`ZOT_LIBRARY_ID` set: **outstanding** — code verified
  correct via direct inspection of rendered `/etc/bashrc` and `config.fish`, but not live-testable
  until the secret exists.
- `systemctl --user show-environment` carrying the three variables: **outstanding**, same reason.
- Read-only `zot` subcommand under `env -i` with only `config.toml` supplying credentials:
  **outstanding** — `zot config show` is the chosen subcommand (confirmed via `zot config --help`
  as the read-only, display-only option), currently and correctly shows `API Key: (not set)`
  since `config.toml` doesn't exist yet.
- Discord bot (`discord-bot`, `opencode-serve`) unaffected: pre-change baseline captured
  (`active (running)`, both, 6 days up); the sops hoist doesn't touch either service's own config,
  and every build involving hamsa (which enables both) succeeded throughout.
- No `zot add`/`zot attach`/any write against the real Zotero library: **confirmed** — every
  Zotero-account command run was `GET /keys/current` (read-only) or local `zot config
  show`/`--help`/`search` (empty local result, no network write).
- No plaintext key material in the repo or any commit: **confirmed** (`git log -p` across every
  commit in this pass, grepped for the literal key value, returns nothing). `private.fish` line
  49 still contains the plaintext key — pre-existing, deliberately not yet removed.

## Operator Actions Outstanding

These are the concrete next steps for a human operator with `sudo` and zotero.org access:

1. **Complete key rotation** (Phase 1): create a new Zotero API key at
   `https://www.zotero.org/settings/keys` with `library`+`files`+`write` grants, verify via `GET
   /keys/current`, then `sops --set '["zotero_api_key"] "<NEW_KEY>"' secrets/secrets.yaml` (or
   `sops secrets/secrets.yaml`). The secret currently holds the pre-existing, still-live key —
   functional but not yet rotated.
2. **Run `sudo nixos-rebuild switch --flake .#hamsa`** (or the current hostname). This is the
   single blocking step for everything below. Then verify:
   - `stat -c '%a %U' /run/secrets/zotero_api_key` -> expect `400 benjamin`.
   - `systemctl status discord-bot opencode-serve` -> expect unchanged, `active (running)`.
3. **Run `home-manager switch --flake .#benjamin`** again (repopulates `~/.config/zot/config.toml`
   and restarts `zotero-env`, or run `systemctl --user restart zotero-env` directly).
4. **Run the precedence assertion** (fish and bash): `test "$ZOTERO_API_KEY" = (cat
   /run/secrets/zotero_api_key)` should print `MATCH` in a **fresh** shell. Only after `MATCH` is
   confirmed:
5. **Remove `~/.config/fish/conf.d/private.fish` line 49** (`set -gx ZOTERO_API_KEY
   "3b73wxlrAKo4hbspIjMRW05U"`) — the last piece of the original plaintext exposure.
6. **Revoke the old key** at `https://www.zotero.org/settings/keys`, only after step 1's new key
   is confirmed working through steps 2-5.
7. Re-run the deferred verification items listed above (`env -i ... zot config show` should then
   show a populated `API Key`; `systemctl --user show-environment` should carry all three vars).

## Handback Note (for the consuming repo's tasks 38/39 — not edited here)

- `zot` (`0.10.0`) is on PATH; credential plumbing (shell exports, `systemd --user` env,
  `~/.config/zot/config.toml`) is fully wired and code-verified, going live once the operator
  completes the steps above.
- The consuming repo's `ZOTERO_API_KEY` gate-check scripts and `zot`'s own credentials are sourced
  from the same secret and will go live together — the two are no longer independent.
- Live `zot add --pdf` write verification is theirs, deliberately not performed here.
- `zotero-mcp` remains unregistered pending their task 39 decision.
- The translation-server toggle is `services.zoteroTranslationServer.enable` (off by default); see
  `docs/zotero.md` for the required `nodejs_22` override note if anyone enables it elsewhere.

## Notes

- Two genuine, previously-undiscovered bugs were found and fixed in the translation-server module
  during required live verification (report 02 had only confirmed the package builds/fetches, not
  that it runs): the Node 24/`config`-package crash, and the systemd `Environment=` JSON
  quote-stripping. Both fixes are documented in the module header and `docs/zotero.md`.
- The `iso`/`usb-installer` `zfs-kernel` build breakage is a separate, pre-existing, out-of-scope
  defect (confirmed unrelated to this task via git-stash A/B testing) — worth a follow-up task.
- Every phase's changes were committed separately (`task 129 phase N: ...`), so any single phase
  can be reverted surgically if needed.

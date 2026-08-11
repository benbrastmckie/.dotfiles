# Implementation Plan: Task #129

- **Task**: 129 - Provision the machine-level tooling that unblocks the literature extension's Zotero write-back path
- **Status**: [IMPLEMENTING]
- **Effort**: 4.75 hours
- **Dependencies**: None (this repo). Downstream consumers live in `~/.config/nvim` (its tasks 38 and 39) and are deliberately out of scope.
- **Research Inputs**:
  - `specs/129_provision_zotero_agent_tooling/reports/02_zotero-tooling-provisioning-verification.md` (authoritative)
  - `specs/129_provision_zotero_agent_tooling/reports/01_zotero-tooling-provisioning-research.md` (seed; superseded on Items 2, 3, and 5)
- **Artifacts**: plans/01_provision-zotero-agent-tooling.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, .claude/rules/nix.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Provision three machine-level capabilities so the literature extension's Zotero write-back path
stops being blocked on tooling: (1) a `zot` binary that resolves from every shell and from
headless/agent contexts, (2) Zotero credentials managed from a single sops-encrypted source of
truth and reachable by every consumer that needs them — including `zot` itself, whose variable
names differ from the consuming repo's — and (3) an optional, disabled-by-default, localhost-only
`zotero-translation-server` for metadata resolution. Definition of done is the concrete
verification matrix in Phase 8: builds green, `zot` resolving and reporting `>=0.10.0` from fresh
bash and fish, credentials visible in bash, fish, and `systemctl --user show-environment`, a
read-only exercise of `zot` that proves the credential actually works, and a `POST /search` smoke
test when the translation-server toggle is flipped on.

Hard scope limit: **no `zot add` or any other write against the real Zotero library.** Live write
verification belongs to the consuming repo's task and must be coordinated separately. Every check
in this plan is read-only, `--dry-run`, or against a scratch path.

### Research Integration

Report 02 is authoritative and materially revises report 01 in three places. This plan honors the
revisions rather than report 01's original recommendations:

- **`zot` does not read `ZOTERO_API_KEY`.** Its documented environment variables are
  `ZOT_API_KEY`, `ZOT_LIBRARY_ID`, `ZOT_DATA_DIR`, `ZOT_PROFILE`. Meanwhile the consuming repo's
  gate-check scripts (`zotero-write.sh`, `zotero-setup.sh`, `zotero-attach-chunks.sh`) test
  `ZOTERO_API_KEY` exclusively. Relocating only `ZOTERO_API_KEY` into sops — report 01's plan —
  would produce a **false green**: the consumer's precondition check passes while `zot` still has
  no usable credential. This plan therefore sets `ZOTERO_API_KEY`, `ZOT_API_KEY`, and
  `ZOT_LIBRARY_ID`, all derived from one secret, and verifies by exercising `zot`, not by
  testing a variable for non-emptiness.
- **`zot config init` has never been run here** (report 02 Item 5, surfaced by the field failure
  in the consuming repo). `~/.config/zot/config.toml` is a first-class deliverable of this plan,
  generated declaratively from the same sops secret. Because it is a plain file under `$HOME`, it
  gives `zot` credentials with no environment propagation at all — which is why it, not the env
  vars, is the durable answer to headless reach for `zot`'s own auth.
- **`nixpkgs#zotero-translation-server` builds from the pinned `nixos-26.05` binary cache**
  (report 02 verified the fetch, the 694 bundled translators, and `default.json5`). This replaces
  report 01's podman/`oci-containers` approach entirely — no container runtime, no image pull, no
  registry credential surface.
- **`home.sessionVariables` does not propagate to `systemd --user` units** (home-manager issue
  #5542). A `systemctl --user set-environment` oneshot is the mechanism, not session variables.
- Item 4 (`zotero-mcp`) is explicitly not implemented. See Non-Goals.

### Prior Plan Reference

No prior plan. This is the first plan for this task.

### Roadmap Alignment

`specs/ROADMAP.md` exists but Phase 1 contains only the placeholder item
`(No items yet -- add roadmap items here)`. No roadmap items are advanced or annotated by this
plan.

## Goals & Non-Goals

**Goals**:

- `zot` (zotero-cli-cc `>=0.10.0`) resolves from interactive fish, interactive bash, and
  agent-spawned bash, via a Nix-built wrapper on `home.packages` — without changing global PATH
  policy.
- One source of truth for the Zotero API key: a sops-encrypted `zotero_api_key` secret, from
  which the shell exports, the systemd `--user` environment, and `~/.config/zot/config.toml` are
  all derived. Rotating the key means editing `secrets/secrets.yaml` and rebuilding — nothing
  else.
- Both credential naming conventions satisfied: `ZOTERO_API_KEY` (consuming repo's gate checks)
  and `ZOT_API_KEY` + `ZOT_LIBRARY_ID` (what `zot` itself reads).
- The old plaintext key at `~/.config/fish/conf.d/private.fish` line 49 is rotated out and the
  line removed — with a check that the managed export actually wins the precedence contest.
- A localhost-only `zotero-translation-server` user service exists, **disabled by default**, with
  a documented enable toggle and a working `POST /search` smoke test when enabled.
- The plaintext-on-disk exposure created by `~/.config/zot/config.toml` is bounded (mode `0600`)
  and documented in the same place as the rotation runbook, so a future rotation knows every
  location that regenerates.

**Non-Goals**:

- **No `zot add`, `zot attach`, or any write to the real Zotero library.** Deferred to the
  consuming repo's task, coordinated separately.
- **No `zotero-mcp` registration.** The adoption decision lives in `~/.config/nvim` (its task
  39). If it lands on "adopt", registration belongs in the `claudeMcpServers` activation block in
  `modules/home/core/dotfiles.nix` at the same grant scope — not here, not now.
- No changes to the consuming repo's scripts. This repo does not own them; the `ZOTERO_API_KEY`
  compatibility export exists precisely so those scripts keep working unmodified.
- No global PATH policy change (`~/.local/bin` is deliberately left off PATH).
- No change to Zotero itself, its data directory (`~/Documents/Zotero`), or its autostart entry.
  The decoy `~/Zotero` directory stays untouched and unread.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| False green: only `ZOTERO_API_KEY` gets set, `zot` still uncredentialed | H | M | Phase 5/6/7 set all three names from one secret; Phase 8 exercises `zot` under `env -i` rather than echoing a variable |
| Stale `private.fish` export shadows the managed one (fish `conf.d` vs `/etc/fish/config.fish` ordering) | H | M | Phase 5 removes the line in the same step it adds the managed export, and asserts `$ZOTERO_API_KEY` equals `cat /run/secrets/zotero_api_key` |
| Hoisting `sops.defaultSopsFile`/`age.keyFile` out of `discordBot`'s `mkIf` regresses nandi/hamsa | H | L | Phase 4 hoists into a new always-on module and removes the duplicates atomically; `nix flake check` plus a `nixos-rebuild build` on the live host gate the phase |
| Always-on sops module breaks `iso`/`usb-installer` builds (no age key present) | M | M | Phase 4 explicitly builds `.#nixosConfigurations.iso` and `.#nixosConfigurations.usb-installer`; if broken, import from `hosts/{nandi,hamsa}/default.nix` instead of `modules/system/default.nix` |
| Plaintext API key at `~/.config/zot/config.toml` widens exposure | M | H (certain) | Written with `umask 077` + explicit `chmod 0600`; every derived location enumerated in `docs/zotero.md` alongside the rotation runbook so rotation is single-source |
| `zot config init` idempotency is undocumented and could clobber or error on re-run | M | M | Approach (b) chosen: write the TOML directly from an activation script. `zot config init` is never invoked against the real config path; if tested at all, only via `--config-path` to a scratch file |
| `uvx --from zotero-cli-cc@latest` re-resolves on every invocation (network dependency, silent version drift) | M | M | Matches the existing `packages/aristotle.nix` precedent; Phase 8 asserts `zot --version >= 0.10.0`. Pinning is a one-line change documented in the package header if drift becomes a problem |
| `NODE_CONFIG` JSON in a systemd `Environment=` line is mis-parsed (quotes/`=`) | M | M | Phase 3 verifies with `systemctl --user show ... -p Environment` and `ss -lntp` (must bind `127.0.0.1`, not `0.0.0.0`); documented fallback is `TRANSLATORS_DIR` + a `NODE_CONFIG` file |
| Rotation needs a browser login the implementer cannot perform | H | H (certain) | Phase 1 is an explicit operator runbook with exact commands; if the new key is unavailable the phase is marked `[BLOCKED]` and Phases 2 and 3 (which need no credential) still proceed |
| System-level changes need `nixos-rebuild`, not just `home-manager switch` | M | M | Phase 8's verification matrix requires both; each phase names which rebuild path it needs |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1 |
| 3 | 5, 6, 7 | 4 |
| 4 | 8 | 2, 3, 5, 6, 7 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Rotate the API key and seed the sops secret [BLOCKED]

**Goal**: Retire the exposed key and establish `secrets/secrets.yaml` as the single source of
truth. **The rotation decision is made, not deferred: rotate.** The existing key has sat in
plaintext in `~/.config/fish/conf.d/private.fish` line 49 and has appeared in session logs; it is
treated as compromised.

**Tasks**:
- [ ] **BLOCKED — Operator action required**: create a **new** key at
      `https://www.zotero.org/settings/keys` with the same grants as the current one —
      `library: true`, `files: true`, `write: true` on the personal library (userID `2622830`,
      username `benbrastmckie`). *(deviation: skipped — implementing agent has no browser session
      and no access to the user's zotero.org account; this is an explicit capability boundary set
      by the coordinator, not an oversight)*
- [x] Verify the *existing* (not-yet-rotated) key's grants, read-only, no library write:
      `curl -s -H "Zotero-API-Key: <KEY>" https://api.zotero.org/keys/current` — confirmed
      `"userID": 2622830` and `"access": {"user": {"library": true, "files": true, "write":
      true}}` on 2026-08-11. *(deviation: altered — exercised against the existing key, since no
      new key exists yet)*
- [x] Add the value to the encrypted store under the key name `zotero_api_key`:
      `sops --set '["zotero_api_key"] "<KEY>"' secrets/secrets.yaml`, alongside the existing
      `discord_bot_token` / `link_api_token` / `ollama_api_key` entries. *(deviation: altered —
      seeded with the EXISTING (not new/rotated) key value per coordinator instruction, so
      Phases 2-8's plumbing is testable end-to-end today; rotation to a new value is still
      outstanding)*
- [x] Confirm round-trip: `sops -d secrets/secrets.yaml | grep -c '^zotero_api_key:'` returns `1`.
      Confirmed.
- [ ] **BLOCKED — Operator action required**: revoke the **old** key at
      `https://www.zotero.org/settings/keys`. *(deviation: skipped — same capability boundary;
      the currently-encrypted secret value IS the "old" key, so revoking it now would strand the
      whole pipeline with no working credential. Revoke only AFTER a new key has been created and
      swapped in via the rotation runbook in `docs/zotero.md`.)*
- [ ] Do NOT yet touch `~/.config/fish/conf.d/private.fish` — its removal is Phase 5, so the
      machine is never simultaneously without a working key and without the managed path.
      (Unaffected by the above — still deferred to Phase 5 as planned.)

**OPERATOR ACTION OUTSTANDING**: the rotation itself (new key creation + old key revocation) was
not performed by this implementation pass — see the capability-boundary note above. The runbook
for completing rotation is recorded in `docs/zotero.md`'s "Credentials and rotation" section
(added in Phase 7) and restated in the implementation summary. The secret currently holds the
**pre-existing, still-live** key (grants verified above), so every downstream phase is fully
testable today; only the "retire the exposed key" goal of this phase remains open.

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `secrets/secrets.yaml` - add encrypted `zotero_api_key` entry

**Verification**:
- `sops -d secrets/secrets.yaml | grep -q '^zotero_api_key:'` exits 0.
- `git diff --stat secrets/secrets.yaml` shows a change and `git diff secrets/secrets.yaml`
  shows only ciphertext (no plaintext key material lands in the repo or in a commit message).
- The `keys/current` curl above returns the three required grants.

**If the operator cannot supply a new key in this session**: mark this phase `[BLOCKED]` with the
runbook above recorded verbatim, and proceed with Phases 2 and 3, which have no credential
dependency. Do not fall back to reusing the compromised key.

---

### Phase 2: Package `zot` and put it on PATH [COMPLETED]

**Goal**: `zot` resolves from every shell and from agent-spawned bash, via the repo's established
`writeShellScriptBin` + overlay + `home.packages` wiring — no PATH policy change.

**Tasks**:
- [x] Create `packages/zot.nix`, mirroring `packages/aristotle.nix` exactly in shape:
      ```nix
      # zot (zotero-cli-cc) - Zotero CLI for Claude Code, fetched via uvx on each invocation.
      # Custom because zotero-cli-cc is a PyPI/uvx-distributed tool, not packaged in nixpkgs.
      # Consumed by the literature extension's Zotero write-back path in ~/.config/nvim.
      { writeShellScriptBin, uv }:
      writeShellScriptBin "zot" ''
        exec ${uv}/bin/uvx --from zotero-cli-cc@latest zot "$@"
      ''
      ```
      Note in the header that `@latest` matches the `aristotle` precedent and that pinning
      (`zotero-cli-cc@0.10.0`) is a one-line change if version drift becomes a problem.
- [x] Register in `overlays/unstable-packages.nix` next to the `aristotle`/`loogle` lines:
      `zot = final.callPackage ../packages/zot.nix { }; # Zotero CLI (zotero-cli-cc wrapper, uvx-fetched)`
- [x] Add `zot` to `home.packages` in `modules/home/packages/misc.nix` under the
      "AI and coding assistant tools" group, with a trailing comment naming the consumer.
- [x] Add an entry to `docs/packages.md` (or `docs/unstable-packages.md`, matching where the
      other `writeShellScriptBin` wrappers are listed). Added to both.

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `packages/zot.nix` - new wrapper derivation
- `overlays/unstable-packages.nix` - register `zot`
- `modules/home/packages/misc.nix` - add `zot` to `home.packages`
- `docs/packages.md` - document the new wrapper

**Verification**:
- `nix flake check` succeeds. Confirmed.
- `nix build .#nixosConfigurations.hamsa.config.system.build.toplevel --no-link` succeeds
  (substituted the live hostname, hamsa). Confirmed.
- After `home-manager switch --flake .#benjamin`: `command -v zot` resolves to
  `/home/benjamin/.nix-profile/bin/zot` in both fresh bash and fresh fish. Confirmed.
- `zot --version` prints `0.10.0` in both fresh bash (`bash -lic 'zot --version'`) and fresh fish
  (`fish -lic 'zot --version'`). Confirmed.

---

### Phase 3: Localhost-only translation-server, disabled by default [COMPLETED]

**Goal**: A `zotero-translation-server` user service that binds `127.0.0.1:1969` only, ships
disabled, and has a documented enable toggle. Container-free, using the nixpkgs package already
available on the pinned `nixos-26.05` channel.

**Tasks**:
- [x] Confirm the package still resolves on the pinned channel before writing the module:
      `nix build .#nixosConfigurations.hamsa.pkgs.zotero-translation-server --no-link --print-out-paths`
      (substituted the live hostname, hamsa) — resolved to
      `/nix/store/f5xljw0px32hqkfx4iami9dnjd3hdj8z-zotero-translation-server-unstable-2023-07-13`.
- [x] Create `modules/home/services/zotero-translation-server.nix` following the Home Manager
      module structure in `.claude/rules/nix.md`:
      - `options.services.zoteroTranslationServer.enable = lib.mkEnableOption "the local Zotero
        translation-server (127.0.0.1:1969, metadata resolution)"` — **defaults to false**.
      - `options.services.zoteroTranslationServer.port` — `lib.types.port`, default `1969`, with
        a description.
      - `config = lib.mkIf cfg.enable { systemd.user.services.zotero-translation-server = ... }`
        with `Type = "simple"`, `Restart = "on-failure"`,
        `WorkingDirectory = "${pkgs.zotero-translation-server}/lib/node_modules/translation-server"`
        (so the package's relative `translatorsDirectory` resolves),
        `Environment` carrying `NODE_CONFIG={"host":"127.0.0.1","port":<port>}`, and
        `ExecStart = "${pkgs.zotero-translation-server}/bin/translation-server"`.
        Record in a header comment that the package default is `host = "0.0.0.0"` and that the
        `NODE_CONFIG` override is what makes it localhost-only.
- [x] Import the module unconditionally in `modules/home/default.nix` under the "Service modules"
      group. The module is always imported; the **service** is off until the option is set.
- [x] Write `docs/zotero.md` (new) documenting: the enable toggle
      (`services.zoteroTranslationServer.enable = true;`), the endpoints (`POST /search` for
      DOI/ISBN/PMID/arXiv, `POST /web` for URL), the statelessness/no-credentials property, and
      the fact that the consuming repo degrades gracefully when the service is down. Add the
      cross-reference from `docs/applications.md` in the same style as the `docs/discord-bot.md`
      entry.

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `modules/home/services/zotero-translation-server.nix` - new module
- `modules/home/default.nix` - import the module
- `docs/zotero.md` - new; toggle + endpoints (rotation runbook is appended in Phase 7)
- `docs/applications.md` - cross-reference

**Verification**:
- `nix flake check` succeeds. Confirmed.
- `home-manager switch --flake .#benjamin` succeeds and, with the toggle still off,
  `systemctl --user list-unit-files 'zotero-translation-server*'` shows **no** enabled unit.
  Confirmed (`0 unit files listed.`).
- Full smoke test (temporary enable, then revert) is deferred to Phase 8 so the repo is never
  left with the toggle on.

---

### Phase 4: Always-on sops wiring for `zotero_api_key` [PARTIAL]

**Goal**: Decrypt the secret to `/run/secrets/zotero_api_key` on every real host, **without**
that availability being accidentally coupled to `services.discordBot.enable`.

`modules/system/optional/discord-bot.nix` currently sets `sops.defaultSopsFile` and
`sops.age.keyFile` *inside* `lib.mkIf cfg.enable`. Both nandi and hamsa happen to enable the bot,
so it works today by coincidence. A new always-on secret must not inherit that coincidence.

**Tasks**:
- [x] Create `modules/system/secrets.nix` (always-on) holding the hoisted, unconditional
      `sops.defaultSopsFile = ../../secrets/secrets.yaml;` and
      `sops.age.keyFile = "${config.users.users.${username}.home}/.config/sops/age/keys.txt";`
      (`username` is already a `specialArgs` value — see `flake.nix`), plus:
      ```nix
      sops.secrets."zotero_api_key" = {
        owner = config.users.users.${username}.name;
        mode = "0400";
      };
      ```
      Header comment must state why these two lines were hoisted out of `discord-bot.nix`. Done.
- [x] Remove the now-duplicated `defaultSopsFile` and `age.keyFile` lines from the `mkIf` block in
      `modules/system/optional/discord-bot.nix`, leaving its `sops.secrets.*` declarations
      untouched. Update that file's header comment to point at the new always-on module. Done.
- [x] Import `./secrets.nix` from `modules/system/default.nix`. Done.
- [x] **Resolve the installer-image question explicitly** (do not leave it to chance): build
      `.#nixosConfigurations.iso` and `.#nixosConfigurations.usb-installer`. **Finding**: both
      fail with `error: Refusing to evaluate package 'zfs-kernel-2.4.2-7.1.3' ... broken` at
      `nix build` time (forced during the ZFS-import-enabled `installation-cd-minimal.nix`
      module's kernel evaluation). This is confirmed **pre-existing and unrelated** to the
      always-on secrets module: `git stash`-ing this phase's changes and rebuilding both
      `.#nixosConfigurations.iso` and `.#nixosConfigurations.usb-installer` reproduces the
      *identical* error at the *identical* evaluation point with the always-on secrets module
      absent. `nix flake check` (which fully evaluates the config tree, including
      `config.sops.secrets`, without forcing the broken zfs-kernel derivation) passes cleanly for
      all four hosts. Since the secrets hoist introduces no new or different failure, the
      per-host-import fallback described below was **not** needed and the always-on
      `modules/system/default.nix` import was kept as planned. The pre-existing zfs-kernel
      breakage on installer images is a separate, out-of-scope defect worth a follow-up task.

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `modules/system/secrets.nix` - new always-on sops module
- `modules/system/optional/discord-bot.nix` - remove hoisted lines, update header
- `modules/system/default.nix` - import `./secrets.nix`
- possibly `hosts/nandi/default.nix`, `hosts/hamsa/default.nix` - if the installer-image check
  forces per-host import

**Verification**:
- `nix flake check` succeeds. Confirmed for all four hosts (nandi, hamsa, garuda, iso,
  usb-installer).
- `nix build .#nixosConfigurations.{nandi,hamsa,iso,usb-installer}.config.system.build.toplevel --no-link`:
  nandi and hamsa succeed. iso and usb-installer fail on the pre-existing, unrelated zfs-kernel
  breakage documented above (reproduced identically without this phase's changes) — **not** a
  regression introduced here. `nixos-rebuild build --flake .#hamsa` (the live host) also
  succeeds independently, confirming the same result via the operator-facing build path.
- **OUTSTANDING — operator action required**: `sudo nixos-rebuild switch --flake .#$(hostname)`
  was not run. `sudo` is unavailable to this implementing agent in this session (every `sudo`
  invocation was denied by the environment's permission policy, not merely unauthenticated) — an
  explicit, anticipated capability boundary, not an oversight. Consequently
  `/run/secrets/zotero_api_key` does not yet exist on this host and the `stat -c '%a %U'`
  assertion and the "Discord bot unaffected" `systemctl status` comparison could not be executed
  post-switch. Pre-change baseline recorded for the operator's post-switch comparison:
  `systemctl status discord-bot opencode-serve` — both `active (running)`, discord-bot up 6 days,
  opencode-serve up 6 days (captured 2026-08-11 before any switch in this session). After the
  operator runs `sudo nixos-rebuild switch --flake .#hamsa`, both services are expected to remain
  `active (running)` (this phase does not touch their config), and
  `stat -c '%a %U' /run/secrets/zotero_api_key` is expected to report `400 benjamin`.

---

### Phase 5: Interactive-shell exports (fish + bash) and stale-key removal [PARTIAL]

**Goal**: `ZOTERO_API_KEY`, `ZOT_API_KEY`, and `ZOT_LIBRARY_ID` are set in fresh fish **and**
fresh bash, sourced from `/run/secrets/zotero_api_key`, with the unmanaged plaintext export gone
and the precedence contest explicitly settled.

**Tasks**:
- [x] Extend `programs.fish.interactiveShellInit` in `modules/system/shell.nix`, mirroring the
      existing `link_api_token` block. Done; verified rendered correctly into a built
      `config.fish` (comments + `if test -r ... set -gx ...` block present, in the same shape as
      planned).
- [x] Add a **new** `programs.bash.interactiveShellInit` block to the same file (no precedent
      existed in this repo — the file previously configured `programs.fish` only). Used the
      Bash-specific option over the shell-agnostic `environment.interactiveShellInit`. Done;
      verified rendered correctly into the built `/etc/bashrc` (inside the `if [ -n "$PS1" ]`
      interactive guard, ahead of the prompt-init code — `programs.bash.interactiveShellInit` is
      a `types.lines` option, so this repo's definition and `bash.nix`'s own internal definition
      concatenate rather than collide).
- [x] Record `2622830` as a plain, non-secret constant with a comment noting it is the Zotero
      userID for `benbrastmckie`, derived from `GET https://api.zotero.org/keys/current` on
      2026-08-11. Do not re-derive it on every rebuild. Done (comment present in both blocks).
- [ ] **BLOCKED — deferred pending operator switch**: Remove the `ZOTERO_API_KEY` export at
      `~/.config/fish/conf.d/private.fish` line 49. *(deviation: skipped — per the explicit hard
      constraint that this removal must be paired with a live precedence assertion proving the
      sops-sourced value is actually present first, and per Phase 4's finding that `sudo
      nixos-rebuild switch` could not be run this session (sudo denied), `/run/secrets/
      zotero_api_key` does not yet exist on this host. Removing line 49 now would strand the
      environment with no working `ZOTERO_API_KEY` in any shell. The line is left in place,
      unmodified, exactly as the plan's own risk mitigation intends for this scenario.)*
      **OPERATOR ACTION**: after running `sudo nixos-rebuild switch --flake .#hamsa`, run the
      precedence assertion below; only once it prints `MATCH` should line 49 be removed.

**Timing**: 0.5 hours

**Depends on**: 4

**Files to modify**:
- `modules/system/shell.nix` - fish block extension + new bash block
- `~/.config/fish/conf.d/private.fish` - remove line 49 (outside repo, not Nix-managed)

**Verification**:
- `nix flake check` succeeds. Confirmed. `nixos-rebuild build --flake .#hamsa` succeeds.
  Confirmed — rendered `config.fish` and `/etc/bashrc` inspected directly (see task notes above).
- **OUTSTANDING — requires the operator's `sudo nixos-rebuild switch --flake .#$(hostname)`**
  (not run this session, see Phase 4): the fresh-shell env-var checks, the precedence assertion,
  and the `private.fish` plaintext-grep cannot be executed until `/run/secrets/zotero_api_key`
  exists. Recorded here verbatim for the operator to run post-switch:
  - `bash -lic 'printf "%s|%s|%s\n" "${ZOTERO_API_KEY:+set}" "${ZOT_API_KEY:+set}" "$ZOT_LIBRARY_ID"'`
    should print `set|set|2622830`.
  - `fish -lic 'printf "%s|%s|%s\n" (test -n "$ZOTERO_API_KEY"; and echo set) (test -n "$ZOT_API_KEY"; and echo set) $ZOT_LIBRARY_ID'`
    should print the same.
  - **Precedence assertion** (the point of the phase, not a nicety — run this BEFORE removing
    `private.fish` line 49): `fish -lic 'test "$ZOTERO_API_KEY" = (cat /run/secrets/zotero_api_key); and echo MATCH'`
    should print `MATCH`. Same assertion in bash. Only after `MATCH` is confirmed, remove
    `~/.config/fish/conf.d/private.fish` line 49 and re-run the checks above.
  - `grep -rn 'ZOTERO_API_KEY' ~/.config/fish/` should return no plaintext key material — this
    check is only meaningful **after** line 49 is removed.
- Note: `private.fish` line 49 currently still contains the (still-live, unrotated) key value in
  plaintext, unchanged from before this task. This is not a regression — it is the pre-existing
  exposure this task exists to remove, deliberately left in place pending the precedence proof.

---

### Phase 6: systemd `--user` environment reach [PARTIAL]

**Goal**: `systemctl --user show-environment` carries the three variables, so headless and
agent-spawned units started after activation inherit them.

`home.sessionVariables` **cannot** do this — it writes a profile script sourced by login shells,
and systemd `--user` units do not inherit it (home-manager issue #5542, still open).
`systemd.user.sessionVariables` renders an `environment.d(5)` drop-in whose values are baked at
build time and parsed literally by systemd's generator — no `$(cat ...)` expansion — so it cannot
carry a runtime-decrypted secret either. A oneshot unit calling
`systemctl --user set-environment` is the mechanism.

**Tasks**:
- [x] Create `modules/home/services/zotero-env.nix` following the `cache-cleanup.nix` shape
      (`pkgs.writeShellScript` bound in a `let`, referenced from `ExecStart`):
      - `Type = "oneshot"`, `RemainAfterExit = true`, `Install.WantedBy = [ "default.target" ]`.
      - Script guards on `[ -r /run/secrets/zotero_api_key ]` and exits 0 with a logged notice if
        the secret is unreadable, so a fresh machine or a pre-Phase-4 state degrades visibly
        rather than failing activation.
      - Calls
        `systemctl --user set-environment ZOTERO_API_KEY="$key" ZOT_API_KEY="$key" ZOT_LIBRARY_ID=2622830`.
      - Header comment must cite home-manager #5542 and state why `home.sessionVariables` and
        `systemd.user.sessionVariables` were both rejected — otherwise a future editor will
        "simplify" this back into a broken form. Done.
- [x] Import the module in `modules/home/default.nix` under "Service modules". Done.
- [x] Note the ordering caveat in the header: `set-environment` affects units started *after* it
      runs; already-running units keep their old environment until restarted. Done.

**Timing**: 0.5 hours

**Depends on**: 4

**Files to modify**:
- `modules/home/services/zotero-env.nix` - new oneshot unit
- `modules/home/default.nix` - import the module

**Verification**:
- `nix flake check` succeeds. Confirmed.
- After `home-manager switch --flake .#benjamin`: `systemctl --user status zotero-env` shows
  `active (exited)` with no errors. Confirmed live — real switch run, service ran, exited 0
  (`code=exited, status=0/SUCCESS`).
- **OUTSTANDING**: `systemctl --user show-environment | grep -E '^(ZOTERO_API_KEY|ZOT_API_KEY|ZOT_LIBRARY_ID)='`
  currently returns nothing — confirmed live, and this is the *expected*, correctly-guarded
  outcome: `/run/secrets/zotero_api_key` does not exist yet (Phase 4's `nixos-rebuild switch` is
  outstanding), so the script's `[ -r /run/secrets/zotero_api_key ]` guard took the skip branch
  and logged `zotero-env: /run/secrets/zotero_api_key not readable; skipping ...` via
  `journalctl --user -u zotero-env` (also confirmed present). Once the operator runs `sudo
  nixos-rebuild switch --flake .#hamsa`, re-running `systemctl --user restart zotero-env` (or the
  next `home-manager switch`, which restarts changed units) will populate all three variables;
  `systemctl --user show-environment | grep '^ZOT_LIBRARY_ID=2622830$'` should then match exactly.

---

### Phase 7: Declarative `~/.config/zot/config.toml` [PARTIAL]

**Goal**: `zot` has usable credentials with **zero** dependence on environment propagation, in
every context — interactive shell, agent-spawned bash, `systemd --user` unit — because a plain
file under `$HOME` needs no propagation at all.

**Design decision**: approach (b) from report 02 — write the TOML directly from a
`home.activation` script — is chosen over approach (a) (`zot config init --api-key ...`).
Rationale: `config init`'s idempotency under repeated `home-manager switch` runs is undocumented
and unverified; approach (b) puts idempotency fully under Nix's control and does not require the
`zot` wrapper (and therefore a `uvx` network fetch) to be functional inside the activation
sandbox. `zot config init` is **not** run against the real config path at any point in this plan.

**Tasks**:
- [ ] Create `modules/home/core/zotero.nix` with a `home.activation.zotConfig` block using
      `config.lib.dag.entryAfter [ "writeBoundary" ]`, following the `claudeMcpServers` precedent
      in `modules/home/core/dotfiles.nix` — specifically its `[[ -v DRY_RUN ]]` self-guard, since
      this block also needs shell redirection that the `run` helper cannot express:
      ```nix
      home.activation.zotConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
        zotDir="${config.home.homeDirectory}/.config/zot"
        if [[ -v DRY_RUN ]]; then
          echo "Would write $zotDir/config.toml from /run/secrets/zotero_api_key"
        elif [ -r /run/secrets/zotero_api_key ]; then
          mkdir -p "$zotDir"
          ( umask 077
            cat > "$zotDir/config.toml" <<TOML
        [zotero]
        data_dir = "${config.home.homeDirectory}/Documents/Zotero"
        library_id = "2622830"
        api_key = "$(cat /run/secrets/zotero_api_key)"
        TOML
          )
          chmod 0600 "$zotDir/config.toml"
        else
          echo "zotConfig: /run/secrets/zotero_api_key not readable; skipping" >&2
        fi
      '';
      ```
      Adjust heredoc indentation to what the Nix `''` string actually emits — the emitted TOML
      must be left-aligned. Verify the rendered activation script with
      `nix eval --raw .#homeConfigurations.benjamin.config.home.activation.zotConfig.data` before
      switching. Done — `nix eval` output confirmed left-aligned TOML and a column-0 heredoc
      terminator, matching the plan's own worked example exactly.
- [x] Import the module in `modules/home/default.nix` under "Core modules". Done.
- [x] Point `data_dir` at `~/Documents/Zotero` — the **active** data directory (948 stored
      attachments, Better BibTeX, local API at 127.0.0.1:23119). The decoy `~/Zotero` directory
      must not be referenced. Done — confirmed in the rendered activation script.
- [x] **Address the plaintext exposure in the same breath as rotation.** Appended a "Credentials
      and rotation" section to `docs/zotero.md` enumerating every location the key lands (table:
      secrets.yaml, /run/secrets, config.toml, fish/bash exports, systemd --user env) and the
      single-source 8-step rotation runbook (create new key -> verify grants -> sops set ->
      nixos-rebuild switch -> home-manager switch -> systemctl --user restart zotero-env -> fresh
      shell -> revoke old key). States plainly that `~/.config/zot/config.toml` is the one
      plaintext-at-rest copy and that this is the accepted trade-off for headless reach. Also
      records the provisioning-history note that this task seeded the secret with the
      pre-existing key and that full rotation (steps 1 and 8) is still an outstanding operator
      action.

**Timing**: 0.75 hours

**Depends on**: 4

**Files to modify**:
- `modules/home/core/zotero.nix` - new activation module
- `modules/home/default.nix` - import the module
- `docs/zotero.md` - append the credentials and rotation section

**Verification**:
- `home-manager switch --flake .#benjamin --dry-run` prints the "Would write ..." line and
  creates/modifies nothing (`stat` on the file is unchanged).
- **OUTSTANDING**: a real `home-manager switch --flake .#benjamin` was run live (twice, in fact —
  once for this phase, matching Phases 2/3/6's pattern), but `~/.config/zot/config.toml` was
  **not** created: `/run/secrets/zotero_api_key` does not exist yet (Phase 4's `nixos-rebuild
  switch` is outstanding), so the activation script correctly took its `else` branch and logged
  `zotConfig: /run/secrets/zotero_api_key not readable; skipping` — confirmed live, no error, no
  file written. The `stat -c %a`, `head -1`, `library_id`/`api_key` content check, and idempotency
  (`sha256sum` across two switches) checks all require the file to exist first and are deferred to
  the operator, post-`nixos-rebuild switch`.
- `home-manager switch --flake .#benjamin --dry-run` prints `Would write
  /home/benjamin/.config/zot/config.toml from /run/secrets/zotero_api_key` and mutates nothing
  (`stat` before/after confirmed unchanged — file does not exist in either case). Confirmed live.

---

### Phase 8: Integrated verification, toggle smoke test, and handback note [PARTIAL]

**Goal**: Execute the full verification matrix end to end, prove the credential actually works
via a read-only exercise (not a non-emptiness check), smoke-test the translation-server toggle
and revert it, and leave a coordination note for the consuming repo.

**HARD SCOPE LIMIT — restated because this is the phase where it would be tempting to violate**:
no `zot add`, no `zot attach`, no `POST`/`PUT`/`DELETE` against `api.zotero.org`. Read-only or
`--dry-run` only. Live write verification is the consuming repo's task and must be coordinated
separately.

**Tasks**:
- [x] Build gates: `nix flake check` (passes for all 5 hosts including iso/usb-installer's
      pre-existing unrelated zfs-kernel eval, see Phase 4); `nix build` of nandi + hamsa
      toplevels (succeed; iso/usb-installer fail on the pre-existing, confirmed-unrelated
      zfs-kernel breakage — not this task's regression);
      `nixos-rebuild build --flake .#hamsa` (succeeds, re-confirmed after every subsequent
      phase's changes); `home-manager switch --flake .#benjamin` (succeeds, run live many times
      across phases 2/3/6/7/8). **NOT run**: `sudo nixos-rebuild switch` — sudo denied outright by
      this session's permission policy (every invocation refused before reaching a password
      prompt). This is the single largest outstanding item; see the summary's Operator Actions
      Outstanding section.
- [x] `zot` reach and version, from **fresh** shells: `bash -lic 'command -v zot && zot
      --version'` and `fish -lic 'command -v zot; and zot --version'` — both report `0.10.0`
      (>= 0.10.0 satisfied). Confirmed live (Phase 2/3 verification).
- [ ] **OUTSTANDING**: Credential visibility across all three reach paths (bash, fish,
      `systemctl --user show-environment`) — the code is wired and verified correct (Phases 5/6),
      but the actual variables cannot be populated in a live shell until
      `/run/secrets/zotero_api_key` exists, which requires the outstanding `sudo nixos-rebuild
      switch`.
- [x] **Exercise the credential, do not merely observe it.** Two checks, adapted for the
      no-`/run/secrets`-yet state:
      1. Grants check, read-only, against the (still pre-rotation) sops-stored value directly
         (the literal value matches what `sops -d secrets/secrets.yaml` would show; `/run/secrets`
         substitution is unavailable pre-switch): `curl -s -H "Zotero-API-Key: <value>"
         https://api.zotero.org/keys/current` returned `"userID": 2622830` with `library`,
         `files`, `write` all `true`. Confirmed live (re-run in this phase in addition to Phase 1).
      2. Config-file-only check under `env -i HOME="$HOME" PATH="$PATH" zot ...`: since
         `~/.config/zot/config.toml` does not exist yet (Phase 7 pending the same switch), this
         necessarily shows the **pre-provisioning** state rather than a positive credential
         exercise. Read-only subcommand used: **`zot config show`** (chosen from `zot config
         --help`'s subcommand list — `cache`, `init`, `profile`, `show` — as the one that reads
         and displays without creating/modifying/deleting anything). Live output:
         `API Key:    (not set)`, `Library ID:` (empty), `Data Dir: (auto-detect)`. This
         **correctly** demonstrates the guarded, pre-switch state (no config.toml means no
         auto-detected credential) rather than a false positive. Also surfaced a useful,
         independent finding: `zot`'s own auto-detection (unrelated to this repo's config)
         resolves `Database: /home/benjamin/Zotero/zotero.sqlite` — the **decoy** path — when no
         `config.toml` is present, which is exactly why Phase 7's `data_dir` override matters and
         must be re-verified once `config.toml` exists post-switch.
- [x] Translation-server smoke test, then revert — **fully executed live, including a real bug
      fix discovered and applied during this phase** (not in the original plan):
      1. Temporarily set `services.zoteroTranslationServer.enable = true;` in `home.nix` and ran
         `home-manager switch --flake .#benjamin`.
      2. **First attempt failed**: `TypeError: Utils.isRegExp is not a function` on every start
         (`start-limit-hit`) — a genuine, pre-existing upstream incompatibility between the
         bundled 2023-era `config` npm package and Node 24 (this channel's default `nodejs`),
         reproduced even with no `NODE_CONFIG` override at all. **Fixed** by overriding the
         package onto `pkgs.nodejs_22` in `modules/home/services/zotero-translation-server.nix`
         (documented in the module header and `docs/zotero.md`).
      3. **Second attempt surfaced a second genuine bug**: `systemctl --user show
         zotero-translation-server -p Environment` showed `NODE_CONFIG={host:127.0.0.1,port:1969}`
         — systemd's `Environment=` parser had stripped the JSON's double quotes, producing
         invalid JSON (`"$NODE_CONFIG environment variable is malformed JSON"` warning; server
         fell back to `0.0.0.0`). This is exactly the risk the plan's own risk table flagged
         ("NODE_CONFIG JSON in a systemd Environment= line is mis-parsed (quotes/=)"). **Fixed**
         by single-quoting the whole `NAME=value` pair (`NODE_CONFIG='{"host":...}'`) so systemd
         preserves the inner double quotes — simpler than the plan's documented
         `TRANSLATORS_DIR` + `NODE_CONFIG`-file fallback, and verified working.
      4. Re-ran `home-manager switch`: `systemctl --user status zotero-translation-server` ->
         `active (running)`; log line `Listening on 127.0.0.1:1969`.
      5. `ss -lntp | grep 1969` -> `LISTEN 0 511 127.0.0.1:1969 0.0.0.0:* users:(("node",...))`
         — confirmed `127.0.0.1`, not `0.0.0.0`. `systemctl --user show ... -p Environment` ->
         `Environment="NODE_CONFIG={\"host\":\"127.0.0.1\",\"port\":1969}"` (valid, no warning).
      6. `curl -s -d '10.1093/mind/fzab048' -H 'Content-Type: text/plain'
         http://127.0.0.1:1969/search` returned real Zotero-format JSON (title "The Modal Moving
         Spotlight Theory", DOI, creators, ISSN, etc.) — full smoke test **pass**.
      7. Reverted `services.zoteroTranslationServer.enable = true;` from `home.nix` entirely, ran
         `home-manager switch` again: log showed `Stopping units:
         zotero-translation-server.service`; `systemctl --user status` now reports "could not be
         found" (unit fully removed, not just stopped); `systemctl --user list-unit-files
         'zotero-translation-server*'` -> `0 unit files listed`; `ss -lntp | grep 1969` -> nothing
         listening. Repo confirmed left with the service off by default.
- [x] Plaintext hygiene: `grep -rn 'ZOTERO_API_KEY' ~/.config/fish/` still finds the pre-existing
      line 49 (expected and correct — its removal is deliberately deferred, see Phase 5; this
      check is only meaningful post-removal). `git log -p` across every commit made in this
      implementation pass, grepped for the literal key value, returns nothing — no plaintext key
      material landed in any commit.
- [x] Write `specs/129_provision_zotero_agent_tooling/summaries/01_provision-zotero-agent-tooling-summary.md`
      capturing the verification matrix results, the read-only `zot` subcommand used
      (`zot config show`), the two translation-server bugs found/fixed, and the rotation
      provisioning-history note (existing key seeded 2026-08-11; full rotation still outstanding).
- [x] Handback note for the consuming repo (`~/.config/nvim`, its tasks 38/39) — recorded in the
      summary, that repo not edited:
      - `zot` is on PATH (`0.10.0`); credential plumbing (shell exports, `systemd --user` env,
        `~/.config/zot/config.toml`) is fully wired and code-verified, but not yet live-populated
        pending the operator's `sudo nixos-rebuild switch` (see Operator Actions Outstanding).
      - Their scripts' `ZOTERO_API_KEY` gate and `zot`'s own credentials are sourced from the same
        secret and will go live together once the operator completes the outstanding switch — the
        two are no longer independent, matching the plan's intent.
      - Live `zot add --pdf` write verification is **theirs**, deliberately not performed here.
      - `zotero-mcp` remains unregistered pending their task 39 decision.
      - The translation-server toggle is `services.zoteroTranslationServer.enable`, off by
        default; see `docs/zotero.md` — includes a required `nodejs_22` override note relevant to
        anyone else who enables it.

**Timing**: 1.0 hours

**Depends on**: 2, 3, 5, 6, 7

**Files to modify**:
- `specs/129_provision_zotero_agent_tooling/summaries/01_provision-zotero-agent-tooling-summary.md` - new
- `docs/zotero.md` - fill in the verified read-only `zot` subcommand and the smoke-test recipe

**Verification**:
- Every checkbox above passes, with command output recorded in the summary.
- Repo left in the intended default state: translation-server disabled, no plaintext key in any
  tracked or untracked shell config.

---

## Testing & Validation

- [x] `nix flake check` succeeds.
- [x] `nix build .#nixosConfigurations.{nandi,hamsa,iso,usb-installer}.config.system.build.toplevel --no-link`:
      nandi + hamsa succeed; iso + usb-installer fail on a pre-existing, confirmed-unrelated
      zfs-kernel breakage (reproduced identically via git-stash A/B with this task's changes
      absent — see Phase 4).
- [ ] **OUTSTANDING (operator action)**: `sudo nixos-rebuild switch --flake .#$(hostname)` — sudo
      denied outright in this session. `nixos-rebuild build --flake .#hamsa` (the non-privileged
      equivalent) succeeds and was re-run after every phase.
- [x] `home-manager switch --flake .#benjamin` succeeds; run live many times across phases
      2/3/6/7/8, including twice in immediate succession in Phase 7/8 — idempotent (no errors, no
      unexpected diffs).
- [x] `home-manager switch --flake .#benjamin --dry-run` mutates nothing (activation blocks honor `DRY_RUN`) — confirmed for zotConfig.
- [x] `command -v zot` resolves and `zot --version` reports `0.10.0` (>= 0.10.0) from fresh bash **and** fresh fish.
- [ ] **OUTSTANDING (blocked on the switch above)**: `ZOTERO_API_KEY`, `ZOT_API_KEY`,
      `ZOT_LIBRARY_ID` all set in fresh bash, fresh fish, and `systemctl --user show-environment`
      — code verified correct (rendered scripts inspected directly), but cannot show as "set"
      until `/run/secrets/zotero_api_key` exists.
- [ ] **OUTSTANDING (same blocker)**: `$ZOTERO_API_KEY` in a fresh shell equals `cat
      /run/secrets/zotero_api_key` (precedence assertion) — this is also the gate for removing
      `private.fish` line 49, so it is deliberately not yet run.
- [x] `GET https://api.zotero.org/keys/current` with the (pre-rotation) key reports userID 2622830
      and `library`+`files`+`write` grants — confirmed live twice (Phase 1 and Phase 8).
- [ ] **OUTSTANDING (blocked on the switch above)**: a read-only `zot` subcommand succeeds under
      `env -i` with `~/.config/zot/config.toml` supplying credentials — `zot config show` is the
      chosen subcommand, but `config.toml` does not exist yet (Phase 7 activation correctly
      skipped, pending the secret existing), so this currently and correctly shows "API Key:
      (not set)" rather than a positive credential exercise.
- [ ] **OUTSTANDING (same blocker)**: `stat -c %a ~/.config/zot/config.toml` reports `600` — file
      does not exist yet.
- [x] With the toggle enabled: unit active, listener on `127.0.0.1:1969` (not `0.0.0.0`),
      `POST /search` returns Zotero JSON. Toggle reverted to disabled afterward — unit fully
      removed (`could not be found`), confirmed not listening. **Two real bugs found and fixed
      along the way** (Node 24/`config`-package incompatibility; systemd `Environment=` JSON
      quote-stripping) — see Phase 8 for full detail.
- [x] Discord bot services unaffected by the sops hoist: pre-change baseline captured
      (`active (running)`, both services, 6 days up) since a live switch to compare post-state
      was not possible this session; the sops hoist itself does not touch either service's
      config, and `nix build`/`nixos-rebuild build` on hamsa (which has `discordBot.enable`)
      succeeded cleanly throughout.
- [x] No `zot add` / `zot attach` / any write against the real Zotero library was executed —
      confirmed: every Zotero-account-touching command run this session was `GET
      /keys/current` (read-only) or local `zot config show`/`--help`/`search` (`search` returned
      an empty local result set, no network write). The translation-server test hit only the
      local `127.0.0.1:1969` translation service, never `api.zotero.org`.
- [x] No plaintext key material in the repo, in any commit, or in `~/.config/fish/` **beyond the
      pre-existing, deliberately-not-yet-removed `private.fish` line 49** (see Phase 5's hard
      constraint on ordering). `git log -p` across every commit in this pass, grepped for the
      literal key value, returns nothing.

## Artifacts & Outputs

- `packages/zot.nix` (new)
- `modules/system/secrets.nix` (new)
- `modules/home/services/zotero-translation-server.nix` (new; includes the live-discovered
  `nodejs_22` override and single-quoted `NODE_CONFIG` fix, beyond the plan's original spec)
- `modules/home/services/zotero-env.nix` (new)
- `modules/home/core/zotero.nix` (new)
- `docs/zotero.md` (new) — toggle, endpoints, credential locations, rotation runbook, and the
  `nodejs_22`/`NODE_CONFIG`-quoting notes
- `secrets/secrets.yaml` (modified — encrypted `zotero_api_key`, seeded with the pre-existing key)
- `overlays/unstable-packages.nix`, `modules/home/packages/misc.nix`, `modules/home/default.nix`,
  `modules/system/default.nix`, `modules/system/shell.nix`,
  `modules/system/optional/discord-bot.nix`, `docs/packages.md`, `docs/unstable-packages.md`,
  `docs/applications.md` (modified)
- `home.nix` — touched transiently for the Phase 8 smoke test (`services.zoteroTranslationServer.enable
  = true;` added then removed); net diff against the pre-task state is empty.
- `~/.config/fish/conf.d/private.fish` (outside repo, **NOT modified** — line 49 removal deferred
  to the operator per the precedence-assertion hard constraint; see Phase 5)
- `specs/129_provision_zotero_agent_tooling/summaries/01_provision-zotero-agent-tooling-summary.md` (new)
- Runtime, not tracked, not yet populated (pending operator's `sudo nixos-rebuild switch`):
  `/run/secrets/zotero_api_key`, `~/.config/zot/config.toml`

## Rollback/Contingency

- **Per-phase**: every code change is additive except the `discord-bot.nix` sops hoist (Phase 4)
  and the `private.fish` line removal (Phase 5). Revert the repo changes with
  `git revert` of the phase commit, then `sudo nixos-rebuild switch` and
  `home-manager switch`. Commit each phase separately so reverts stay surgical.
- **Phase 4 specifically**: if the hoist regresses nandi/hamsa or the installer images, restore
  `defaultSopsFile`/`age.keyFile` inside `discord-bot.nix`'s `mkIf` and instead declare
  `sops.secrets."zotero_api_key"` from `hosts/{nandi,hamsa}/default.nix`. This keeps the new
  secret working on the two real hosts without touching the installer images.
- **Runtime artifacts** are not reverted by `git revert`: after rolling back, remove
  `~/.config/zot/config.toml` manually and run `systemctl --user unset-environment ZOTERO_API_KEY
  ZOT_API_KEY ZOT_LIBRARY_ID`.
- **Rotation is not reversible**: the old key is revoked in Phase 1. If a rollback is needed after
  that point, the new key remains valid and remains the source of truth — do not attempt to
  restore the old key. Re-add the export to `private.fish` only as an emergency stopgap, and
  treat that as re-introducing the exposure this task exists to remove.
- **Translation-server**: disabled by default, so a rollback is `enable = false` plus
  `home-manager switch`. No container images, volumes, or registry state to clean up — a direct
  benefit of choosing the nixpkgs package over report 01's podman approach.

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

### Phase 6: systemd `--user` environment reach [NOT STARTED]

**Goal**: `systemctl --user show-environment` carries the three variables, so headless and
agent-spawned units started after activation inherit them.

`home.sessionVariables` **cannot** do this — it writes a profile script sourced by login shells,
and systemd `--user` units do not inherit it (home-manager issue #5542, still open).
`systemd.user.sessionVariables` renders an `environment.d(5)` drop-in whose values are baked at
build time and parsed literally by systemd's generator — no `$(cat ...)` expansion — so it cannot
carry a runtime-decrypted secret either. A oneshot unit calling
`systemctl --user set-environment` is the mechanism.

**Tasks**:
- [ ] Create `modules/home/services/zotero-env.nix` following the `cache-cleanup.nix` shape
      (`pkgs.writeShellScript` bound in a `let`, referenced from `ExecStart`):
      - `Type = "oneshot"`, `RemainAfterExit = true`, `Install.WantedBy = [ "default.target" ]`.
      - Script guards on `[ -r /run/secrets/zotero_api_key ]` and exits 0 with a logged notice if
        the secret is unreadable, so a fresh machine or a pre-Phase-4 state degrades visibly
        rather than failing activation.
      - Calls
        `systemctl --user set-environment ZOTERO_API_KEY="$key" ZOT_API_KEY="$key" ZOT_LIBRARY_ID=2622830`.
      - Header comment must cite home-manager #5542 and state why `home.sessionVariables` and
        `systemd.user.sessionVariables` were both rejected — otherwise a future editor will
        "simplify" this back into a broken form.
- [ ] Import the module in `modules/home/default.nix` under "Service modules".
- [ ] Note the ordering caveat in the header: `set-environment` affects units started *after* it
      runs; already-running units keep their old environment until restarted.

**Timing**: 0.5 hours

**Depends on**: 4

**Files to modify**:
- `modules/home/services/zotero-env.nix` - new oneshot unit
- `modules/home/default.nix` - import the module

**Verification**:
- `nix flake check` succeeds.
- After `home-manager switch --flake .#benjamin`:
  `systemctl --user status zotero-env` shows `active (exited)` with no errors.
- `systemctl --user show-environment | grep -E '^(ZOTERO_API_KEY|ZOT_API_KEY|ZOT_LIBRARY_ID)='`
  returns all three lines.
- `systemctl --user show-environment | grep '^ZOT_LIBRARY_ID=2622830$'` matches exactly.

---

### Phase 7: Declarative `~/.config/zot/config.toml` [NOT STARTED]

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
      switching.
- [ ] Import the module in `modules/home/default.nix` under "Core modules".
- [ ] Point `data_dir` at `~/Documents/Zotero` — the **active** data directory (948 stored
      attachments, Better BibTeX, local API at 127.0.0.1:23119). The decoy `~/Zotero` directory
      must not be referenced.
- [ ] **Address the plaintext exposure in the same breath as rotation.** Append a "Credentials and
      rotation" section to `docs/zotero.md` enumerating every location the key lands, and the
      single-source rotation runbook:
      - Source of truth: `secrets/secrets.yaml` (age-encrypted, `zotero_api_key`).
      - Derived at activation/session time: `/run/secrets/zotero_api_key` (tmpfs, `0400`
        benjamin), `~/.config/zot/config.toml` (**plaintext**, `0600`, under `$HOME`), the fish
        and bash exports, and the `systemd --user` environment.
      - Rotation runbook: create a replacement key with `library`+`files`+`write` grants, verify
        via `GET https://api.zotero.org/keys/current`, `sops secrets/secrets.yaml`,
        `sudo nixos-rebuild switch`, `home-manager switch`, `systemctl --user restart zotero-env`,
        then revoke the old key. Every derived location regenerates; none needs a manual edit.
      - State plainly that `~/.config/zot/config.toml` is the one plaintext-at-rest copy, that
        `zot` offers no keyring/encrypted-storage alternative, and that this is the accepted
        trade-off for headless reach.

**Timing**: 0.75 hours

**Depends on**: 4

**Files to modify**:
- `modules/home/core/zotero.nix` - new activation module
- `modules/home/default.nix` - import the module
- `docs/zotero.md` - append the credentials and rotation section

**Verification**:
- `home-manager switch --flake .#benjamin --dry-run` prints the "Would write ..." line and
  creates/modifies nothing (`stat` on the file is unchanged).
- After a real `home-manager switch --flake .#benjamin`:
  - `stat -c %a ~/.config/zot/config.toml` reports `600`.
  - `head -1 ~/.config/zot/config.toml` is `[zotero]`; the file contains `library_id = "2622830"`
    and a non-empty `api_key`.
  - Idempotency: run `home-manager switch` a second time; the file's content is byte-identical
    (`sha256sum` before and after match) and mode is still `600`.
- `grep -c 'Zotero"' ~/.config/zot/config.toml` confirms `data_dir` points at
  `~/Documents/Zotero`, not `~/Zotero`.

---

### Phase 8: Integrated verification, toggle smoke test, and handback note [NOT STARTED]

**Goal**: Execute the full verification matrix end to end, prove the credential actually works
via a read-only exercise (not a non-emptiness check), smoke-test the translation-server toggle
and revert it, and leave a coordination note for the consuming repo.

**HARD SCOPE LIMIT — restated because this is the phase where it would be tempting to violate**:
no `zot add`, no `zot attach`, no `POST`/`PUT`/`DELETE` against `api.zotero.org`. Read-only or
`--dry-run` only. Live write verification is the consuming repo's task and must be coordinated
separately.

**Tasks**:
- [ ] Build gates: `nix flake check`; `nix build` of all four `nixosConfigurations` toplevels;
      `sudo nixos-rebuild switch --flake .#$(hostname)`;
      `home-manager switch --flake .#benjamin`. All must succeed.
- [ ] `zot` reach and version, from **fresh** shells:
      `bash -lic 'command -v zot && zot --version'` and
      `fish -lic 'command -v zot; and zot --version'` — version must be `>= 0.10.0`.
- [ ] Credential visibility across all three reach paths (bash, fish,
      `systemctl --user show-environment`) per the assertions in Phases 5 and 6.
- [ ] **Exercise the credential, do not merely observe it.** Two independent checks:
      1. Grants check against the sops value, read-only:
         `curl -s -H "Zotero-API-Key: $(cat /run/secrets/zotero_api_key)" https://api.zotero.org/keys/current`
         must return `userID 2622830` with `library`, `files`, and `write` all `true`.
      2. Config-file-only check, proving headless reach independent of env propagation: run a
         **read-only** `zot` subcommand under a stripped environment so only
         `~/.config/zot/config.toml` can supply credentials, e.g.
         `env -i HOME="$HOME" PATH="$PATH" zot <read-only-subcommand>`.
         Determine the exact subcommand from `zot --help` / `zot config --help` at run time and
         record the one used; it must be one that reads (library listing, search, config display)
         and must not create, modify, or delete anything.
- [ ] Translation-server smoke test, then revert:
      1. Temporarily set `services.zoteroTranslationServer.enable = true;` and
         `home-manager switch --flake .#benjamin`.
      2. `systemctl --user status zotero-translation-server` is `active (running)`.
      3. `ss -lntp | grep 1969` shows the listener on **`127.0.0.1:1969`**, not `0.0.0.0:1969` —
         this is the assertion that proves the `NODE_CONFIG` override took effect. Cross-check
         with `systemctl --user show zotero-translation-server -p Environment`.
      4. `curl -s -d '10.1093/mind/fzab048' -H 'Content-Type: text/plain' http://127.0.0.1:1969/search`
         returns Zotero JSON.
      5. Revert the toggle to disabled, `home-manager switch` again, and confirm the unit is
         stopped and not enabled. The repo must be left with the service off by default.
- [ ] Plaintext hygiene: `grep -rn 'ZOTERO_API_KEY' ~/.config/fish/` returns nothing;
      `git diff` contains no plaintext key material anywhere.
- [ ] Write `specs/129_provision_zotero_agent_tooling/summaries/01_provision-zotero-agent-tooling-summary.md`
      capturing the verification matrix results, the exact read-only `zot` subcommand used, and
      the rotation date.
- [ ] Handback note for the consuming repo (`~/.config/nvim`, its tasks 38/39) — record in the
      summary, do not edit that repo:
      - `zot` is on PATH; credentials reach interactive shells, `systemd --user`, and — via
        `~/.config/zot/config.toml` — any context at all.
      - Their scripts' `ZOTERO_API_KEY` gate now passes **and** `zot` is genuinely credentialed;
        the two are no longer independent. If those scripts are ever changed to check a different
        variable, this repo's exported set must be revisited.
      - Live `zot add --pdf` write verification is **theirs**, deliberately not performed here.
      - `zotero-mcp` remains unregistered pending their task 39 decision.
      - The translation-server toggle is `services.zoteroTranslationServer.enable`, off by
        default; see `docs/zotero.md`.

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

- [ ] `nix flake check` succeeds.
- [ ] `nix build .#nixosConfigurations.{nandi,hamsa,iso,usb-installer}.config.system.build.toplevel --no-link` all succeed.
- [ ] `sudo nixos-rebuild switch --flake .#$(hostname)` succeeds.
- [ ] `home-manager switch --flake .#benjamin` succeeds; a second run is idempotent.
- [ ] `home-manager switch --flake .#benjamin --dry-run` mutates nothing (activation blocks honor `DRY_RUN`).
- [ ] `command -v zot` resolves and `zot --version` reports `>= 0.10.0` from fresh bash **and** fresh fish.
- [ ] `ZOTERO_API_KEY`, `ZOT_API_KEY`, `ZOT_LIBRARY_ID` all set in fresh bash, fresh fish, and `systemctl --user show-environment`.
- [ ] `$ZOTERO_API_KEY` in a fresh shell equals `cat /run/secrets/zotero_api_key` (precedence assertion).
- [ ] `GET https://api.zotero.org/keys/current` with the sops-sourced key reports userID 2622830 and `library`+`files`+`write` grants.
- [ ] A read-only `zot` subcommand succeeds under `env -i` with only `~/.config/zot/config.toml` supplying credentials.
- [ ] `stat -c %a ~/.config/zot/config.toml` reports `600`.
- [ ] With the toggle enabled: unit active, listener on `127.0.0.1:1969` (not `0.0.0.0`), `POST /search` returns Zotero JSON. Toggle reverted to disabled afterward.
- [ ] Discord bot services unaffected by the sops hoist.
- [ ] No `zot add` / `zot attach` / any write against the real Zotero library was executed.
- [ ] No plaintext key material in the repo, in any commit, or in `~/.config/fish/`.

## Artifacts & Outputs

- `packages/zot.nix` (new)
- `modules/system/secrets.nix` (new)
- `modules/home/services/zotero-translation-server.nix` (new)
- `modules/home/services/zotero-env.nix` (new)
- `modules/home/core/zotero.nix` (new)
- `docs/zotero.md` (new) — toggle, endpoints, credential locations, rotation runbook
- `secrets/secrets.yaml` (modified — encrypted `zotero_api_key`)
- `overlays/unstable-packages.nix`, `modules/home/packages/misc.nix`, `modules/home/default.nix`,
  `modules/system/default.nix`, `modules/system/shell.nix`,
  `modules/system/optional/discord-bot.nix`, `docs/packages.md`, `docs/applications.md` (modified)
- `~/.config/fish/conf.d/private.fish` (modified, outside repo — stale export removed)
- `specs/129_provision_zotero_agent_tooling/summaries/01_provision-zotero-agent-tooling-summary.md` (new)
- Runtime, not tracked: `/run/secrets/zotero_api_key`, `~/.config/zot/config.toml`

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

# Implementation Plan: NixOS Discord Bot Prerequisites

- **Task**: 53 - nixos_discord_bot_prerequisites
- **Status**: [COMPLETED]
- **Effort**: 5 hours
- **Dependencies**: External task 547 (bot project source at `~/.dotfiles/opencode-discord-bot/`)
- **Research Inputs**:
  - specs/053_nixos_discord_bot_prerequisites/reports/01_nixos-discord-bot-prerequisites.md
  - specs/053_nixos_discord_bot_prerequisites/reports/02_python-discord-bot-best-practices.md
- **Artifacts**: plans/02_nixos-discord-bot-prerequisites.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix

## Overview

Configure NixOS system prerequisites for the Phase 1 Discord bot component of the mobile agent management system. This includes: sops-nix for age-based secrets management, a dedicated Python 3.12 environment with nextcord/aiohttp/anyio, the `opencode-serve` systemd service running `opencode serve --hostname 127.0.0.1`, and the `discord-bot` systemd service connecting to the OpenCode server as a Nextcord bot relay. Secrets (Discord token, OpenCode server password) are injected via systemd `LoadCredential` and never touch disk unencrypted.

### Research Integration

Both research reports are integrated:
- **01_nixos-discord-bot-prerequisites.md**: Confirmed package availability (nextcord 3.1.1, sops 3.12.2, age 1.3.1), validated sops-nix flake/module patterns, defined service dependency chain, established bot project layout at `~/.dotfiles/opencode-discord-bot/`.
- **02_python-discord-bot-best-practices.md**: Confirmed nextcord as the library choice (Python 3.12+ compatible), established slash-command-first architecture, validated `LoadCredential` over `EnvironmentFile` for secrets, recommended system-level services over user-level for boot reliability.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Add `sops-nix` flake input and import the NixOS module on all hosts (hamsa, nandi, iso, usb-installer)
- Create `.sops.yaml` at repo root with age key configuration
- Generate age key at `~/.config/sops/age/keys.txt` and create encrypted `secrets/secrets.yaml`
- Configure sops-nix in `configuration.nix` to decrypt secrets at activation time
- Create a dedicated `discordBotPython` environment (`pkgs.python312.withPackages` with nextcord, aiohttp, anyio)
- Define `opencode-serve` systemd service (persistent daemon, LoadCredential for server password)
- Define `discord-bot` systemd service (requires opencode-serve, PYTHONPATH to bot project, LoadCredential for both secrets)

**Non-Goals**:
- Creating the bot Python source code (external task 547; lives at `~/.dotfiles/opencode-discord-bot/`)
- SSH, Mosh, firewall port rules, Raspberry Pi tooling (deferred to later phases)
- opencode-serve port binding beyond `--hostname 127.0.0.1` (default port discovery via mDNS)
- Replacing opencode binary with a custom version (existing `packages/opencode.nix` is used)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| sops-nix module import breaks builds on one or more hosts | High | Low | Add to all hosts in one pass; `nix flake check` before each host build; test with `nixos-rebuild build --flake .#hamsa` first |
| Age key lost after disk failure | High | Low | Document key path (`~/.config/sops/age/keys.txt`); back up age private key separately; include recovery procedure in plan |
| `discordBOTPython`/`pkgs` binding in `configuration.nix` fails because `pkgs` scope is wrong | Medium | Low | `pkgs` is available as a module argument in `configuration.nix` via `{ config, lib, pkgs, lectic, ... }`; verify with `nix eval` before adding services |
| Discord bot service starts before secrets are decrypted | Medium | Low | sops-nix activation runs before systemd starts services; `requires = [ "opencode-serve.service" ]` adds ordering; `LoadCredential` fails service startup if secret is missing |
| OpenCode picks random port, bot cannot find it | Medium | Medium | Accept default for now; follow-up task can add `--port 4096` if mDNS discovery is unreliable |
| `discord-bot` service references non-existent Python module (bot source not yet created) | High | Medium | Service will fail to start gracefully (this is expected); plan notes this as a known dependency on external task 547; verification phase includes manual service status check |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: sops-nix Integration [COMPLETED]

**Goal**: Wire up sops-nix for age-based secrets management — flake input, NixOS module import, `.sops.yaml`, age key generation, encrypted `secrets/secrets.yaml`, and sops-nix NixOS configuration block.

**Tasks**:
- [ ] Add `sops-nix` flake input to `flake.nix` (`github:Mic92/sops-nix`, follows nixpkgs)
- [ ] Add `sops-nix` to the `outputs` function argument destructuring
- [ ] Import `sops-nix.nixosModules.sops` in each host's `modules` list (hamsa, nandi, iso, usb-installer), placed before the `{ nixpkgs = nixpkgsConfig; }` block
- [ ] Run `nix flake lock` to update `flake.lock` with the new input
- [ ] Generate age key: `age-keygen -o ~/.config/sops/age/keys.txt`
- [ ] Create `.sops.yaml` at repo root with the age public key and a `creation_rules` block matching `secrets/[^/]+\.yaml$`
- [ ] Create `secrets/secrets.yaml` with sops containing: `discord-bot-token`, `opencode-server-password`, `whitelisted-user-ids`, `link-api-token`
- [ ] Add sops configuration block to `configuration.nix`: `sops.defaultSopsFile`, `sops.age.sshKeyPaths`, `sops.secrets` for `discord_bot_token` and `opencode_server_password`
- [ ] Add `sops` and `age` to `environment.systemPackages` in `configuration.nix`

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `flake.nix` — new `sops-nix` input + pass through to outputs + module import per host
- `flake.lock` — auto-updated by `nix flake lock`
- `configuration.nix` — add sops config block + sops/age packages
- `.sops.yaml` — NEW: age key + creation rules
- `secrets/secrets.yaml` — NEW: encrypted secrets (committed encrypted)

**Verification**:
- `nix flake check` passes with the new sops-nix input
- `nix eval .#nixosConfigurations.hamsa.config.sops.defaultSopsFile` resolves to `./secrets/secrets.yaml`
- `sops secrets/secrets.yaml` decrypts and re-encrypts without errors
- `.sops.yaml` is valid YAML with the correct age public key

---

### Phase 2: Python Environment Setup [COMPLETED]

**Goal**: Create a dedicated `discordBotPython` Python 3.12 environment with nextcord, aiohttp, and anyio — scoped to the bot service only, not leaking into the global system PATH.

**Tasks**:
- [ ] Add `discordBotPython` binding near the top of `configuration.nix` (after the `{ config, lib, pkgs, lectic, ... }:` module arguments, before `environment.systemPackages`): `discordBotPython = pkgs.python312.withPackages (p: with p; [ nextcord aiohttp anyio ])`
- [ ] Verify the environment builds correctly with `nix eval .#nixosConfigurations.hamsa.config.system.build.vm` or a targeted eval

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `configuration.nix` — add `discordBotPython` binding (single let-like expression at module top level)

**Verification**:
- `nix eval` on the discordBotPython path confirms nextcord, aiohttp, anyio are present
- `nix flake check` passes for all hosts
- The binding does not shadow or conflict with existing `pkgs`, `python312`, or `environment.systemPackages`

---

### Phase 3: opencode-serve Systemd Service [COMPLETED]

**Goal**: Define a persistent NixOS systemd service running `opencode serve --hostname 127.0.0.1` with the server password injected via `LoadCredential` from sops-nix.

**Tasks**:
- [ ] Add `opencode-serve` service definition to the `systemd.services` block in `configuration.nix`
- [ ] Configure: `Type = "simple"`, `Restart = "always"`, `RestartSec = "10s"`, `wantedBy = [ "multi-user.target" ]`
- [ ] Set `after` and `wants` to `network-online.target`
- [ ] Wire `LoadCredential` to `opencode_server_password` from sops-nix
- [ ] Set `Environment` to `OPENCODE_SERVER_PASSWORD=%d/opencode_server_password`
- [ ] Set `WorkingDirectory = "/home/benjamin/.dotfiles"` (where `.opencode/` config lives)
- [ ] Set `User = config.users.users.benjamin.name` and `Group = "users"`

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `configuration.nix` — add `opencode-serve` service to `systemd.services` block

**Verification**:
- `nix flake check` passes for all hosts
- `nixos-rebuild build --flake .#hamsa` succeeds (build check only, no switch required)
- Inspect generated unit: the `ExecStart` resolves to the opencode binary path, `LoadCredential` path resolves to the sops secret path
- Note: service will fail to start if secrets are not yet created, but the Nix build itself should succeed

---

### Phase 4: discord-bot Systemd Service [COMPLETED]

**Goal**: Define a NixOS systemd service running the Nextcord Discord bot that depends on `opencode-serve.service` and uses the dedicated Python environment with `PYTHONPATH` to the bot project.

**Tasks**:
- [ ] Add `discord-bot` service definition to the `systemd.services` block in `configuration.nix`
- [ ] Configure: `Type = "simple"`, `Restart = "always"`, `RestartSec = "10s"`, `wantedBy = [ "multi-user.target" ]`
- [ ] Set `after = [ "network-online.target" "opencode-serve.service" ]`, `requires = [ "opencode-serve.service" ]`
- [ ] Set `ExecStart = "${discordBotPython}/bin/python -m opencode_discord_bot.src.bot"`
- [ ] Wire `LoadCredential` for both `discord_bot_token` and `opencode_server_password` from sops-nix
- [ ] Set environment variables: `DISCORD_BOT_TOKEN`, `OPENCODE_SERVER_PASSWORD` (from credentials), `OPENCODE_SERVER_URL=http://127.0.0.1`, `WHITELISTED_USER_IDS`, `LINK_API_TOKEN`, `LOG_LEVEL=info`, `PYTHONPATH=/home/benjamin/.dotfiles/opencode-discord-bot`
- [ ] Set `WorkingDirectory = "/home/benjamin/.dotfiles"`, `User = config.users.users.benjamin.name`, `Group = "users"`

**Timing**: 1 hour

**Depends on**: 2, 3

**Files to modify**:
- `configuration.nix` — add `discord-bot` service to `systemd.services` block

**Verification**:
- `nix flake check` passes for all hosts
- `nixos-rebuild build --flake .#hamsa` succeeds
- Inspect generated unit: `ExecStart` resolves to the discordBotPython binary, `LoadCredential` paths resolve correctly
- `PYTHONPATH` env var is set in the generated unit
- Dependency ordering: generated unit shows `After=opencode-serve.service` and `Requires=opencode-serve.service`

---

### Phase 5: Verification & Build Validation [COMPLETED]

**Goal**: Run comprehensive build checks across all hosts, verify secret decryption, and confirm service definitions are correct in the generated systemd units.

**Tasks**:
- [ ] Run `nix flake check` and confirm zero errors across all hosts
- [ ] Run `nix flake show` to confirm all four `nixosConfigurations` are present with sops-nix wired in
- [ ] Build hamsa config: `nixos-rebuild build --flake .#hamsa` and verify exit code 0
- [ ] Build nandi config: `nixos-rebuild build --flake .#nandi` and verify exit code 0
- [ ] Verify sops secret decryption: `sops --decrypt secrets/secrets.yaml` shows the plaintext secrets
- [ ] Inspect generated opencode-serve unit for correct `ExecStart`, `LoadCredential`, and `Environment` values
- [ ] Inspect generated discord-bot unit for correct `ExecStart`, `PYTHONPATH`, and credential wiring
- [ ] Confirm `discordBotPython` environment includes nextcord, aiohttp, anyio: `nix eval .#nixosConfigurations.hamsa.config.system.build.vm` or a targeted derivation check
- [ ] Document any manual steps (age key backup, Discord bot token acquisition) in a summary file

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4

**Files to modify**:
- `specs/053_nixos_discord_bot_prerequisites/summaries/02_nixos-discord-bot-prerequisites-summary.md` — NEW: verification results and manual setup checklist

**Verification**:
- All hosts build successfully with `nix flake check`
- At minimum, hamsa and nandi pass `nixos-rebuild build --flake`
- Secrets are decryptable: `sops --decrypt secrets/secrets.yaml` outputs plaintext
- Both generated systemd units have correct dependency chains and credential paths
- Summary file captures any manual steps required before a live `nixos-rebuild switch`

## Testing & Validation

- [ ] `nix flake check` passes for all hosts (hamsa, nandi, iso, usb-installer)
- [ ] `nixos-rebuild build --flake .#hamsa` succeeds
- [ ] `nixos-rebuild build --flake .#nandi` succeeds
- [ ] `sops --decrypt secrets/secrets.yaml` outputs expected plaintext secrets
- [ ] `.sops.yaml` is valid YAML: `python3 -c "import yaml; yaml.safe_load(open('.sops.yaml'))"`
- [ ] `nix eval .#nixosConfigurations.hamsa.config.sops.secrets` shows both `discord_bot_token` and `opencode_server_password`
- [ ] Generated `opencode-serve` unit: `ExecStart` points to opencode binary, `LoadCredential` is wired
- [ ] Generated `discord-bot` unit: `ExecStart` uses discordBotPython, `PYTHONPATH` is set, `Requires=opencode-serve.service`
- [ ] `discordBotPython` derivation contains nextcord, aiohttp, anyio importable modules
- [ ] No regressions: existing services (disable-speaker-amp, init-power-profile, etc.) still defined and buildable

## Artifacts & Outputs

- `flake.nix` — modified: new sops-nix input, outputs arg, module import per host
- `flake.lock` — updated with sops-nix entry
- `configuration.nix` — modified: `discordBotPython` binding, sops config block, two new systemd services, sops+age packages
- `.sops.yaml` — new: age key configuration at repo root
- `secrets/secrets.yaml` — new: encrypted secrets file (committed encrypted)
- `~/.config/sops/age/keys.txt` — new (outside repo): age private key (never committed)
- `specs/053_nixos_discord_bot_prerequisites/summaries/02_nixos-discord-bot-prerequisites-summary.md` — new: verification results
- `specs/053_nixos_discord_bot_prerequisites/plans/02_nixos-discord-bot-prerequisites.md` — this file

## Rollback/Contingency

- **Revert sops-nix**: Remove the `sops-nix` input from `flake.nix`, remove module imports from each host, delete `.sops.yaml`, remove sops config block from `configuration.nix`, run `nix flake lock`. `secrets/secrets.yaml` can remain; it's inert without sops-nix.
- **Revert services**: Comment out or remove `opencode-serve` and `discord-bot` service definitions from `configuration.nix`. Remove `discordBotPython` binding if no longer needed.
- **Build failure on one host**: Temporarily comment out that host's `nixosConfigurations` entry in `flake.nix` while debugging.
- **Age key lost**: Regenerate with `age-keygen -o ~/.config/sops/age/keys.txt`, update `.sops.yaml` with the new public key, re-encrypt `secrets/secrets.yaml` with `sops --rotate`.

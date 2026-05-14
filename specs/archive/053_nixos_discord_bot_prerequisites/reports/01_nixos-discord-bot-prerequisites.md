# Research Report: NixOS Discord Bot Prerequisites

**Task**: 53 - nixos_discord_bot_prerequisites
**Started**: 2026-05-08T01:24:00Z
**Completed**: 2026-05-08T02:00:00Z
**Effort**: ~1.5 hours
**Dependencies**: None (references external nvim-task-547 research and plan)
**Sources/Inputs**:
- Codebase: `/home/benjamin/.dotfiles/configuration.nix` (existing systemd services, package list)
- Codebase: `/home/benjamin/.dotfiles/flake.nix` (flake inputs, overlays, host configs)
- Codebase: `/home/benjamin/.dotfiles/home.nix` (user systemd service patterns)
- Platform: `nix eval nixpkgs#python312Packages.nextcord.version` → "3.1.1"
- Platform: `nix eval nixpkgs#sops.version` → "3.12.2"
- Platform: `nix eval nixpkgs#age.version` → "1.3.1"
- External: sops-nix GitHub repo (`Mic92/sops-nix`, master branch, actively maintained)
- External: ~/.config/nvim/specs/547_research_mobile_agent_management/plans/01_discord-bot-neovim-setup.md (bot project structure)
- Reference: ~/.config/nvim/specs/547_research_mobile_agent_management/reports/01_mobile-agent-management-research.md
**Artifacts**:
  - specs/053_nixos_discord_bot_prerequisites/reports/01_nixos-discord-bot-prerequisites.md
**Standards**: report-format.md, return-metadata-file.md

## Executive Summary

- **Packages confirmed**: `python312Packages.nextcord` (3.1.1), `sops` (3.12.2), `age` (1.3.1), `python312Packages.aiohttp`, and `python312Packages.anyio` are all available in current nixpkgs. No custom overlays needed.
- **Dedicated Python environment**: Use `pkgs.python312.withPackages` to create a bot-specific Python environment containing nextcord, aiohttp, and anyio — keeping bot dependencies isolated from the global system Python in `home.nix`.
- **sops-nix integration**: Must be added as a flake input (`github:Mic92/sops-nix`) and imported as a NixOS module. Requires `.sops.yaml` at repo root with age key configuration. Secrets file includes `discord-bot-token`, `opencode-server-password`, and optionally `whitelisted-user-ids` and `link-api-token`.
- **Bot project structure**: Defined by the external plan `01_discord-bot-neovim-setup.md` — lives at `~/.dotfiles/opencode-discord-bot/` with `src/bot.py` as the Nextcord entry point, plus local HTTP API (`aiohttp`), session↔thread mapping store, and `/rc` slash command group.
- **opencode-serve service**: Simple systemd service running `opencode serve --hostname 127.0.0.1` with `OPENCODE_SERVER_PASSWORD` loaded from sops-nix secret.
- **discord-bot service**: Python service depending on `opencode-serve.service`. Uses the dedicated Python environment, `PYTHONPATH` pointing to the bot project, and `LoadCredential` for secrets.
- **All config changes are confined to**: `flake.nix` (sops-nix input + module import), `configuration.nix` (2 systemd services + sops config + bot Python environment), new `.sops.yaml` file, new `secrets/secrets.yaml` encrypted file.

## Context & Scope

This task configures the NixOS declarative system prerequisites for the Phase 1 Discord bot component of the mobile agent management system. It covers:

1. Installing nixpkgs packages (nextcord, sops, age)
2. Adding sops-nix flake input and NixOS module for secrets management
3. Creating the `opencode-serve` systemd service
4. Creating the `discord-bot` systemd service

Excluded by design: SSH, Mosh, firewall port rules, Raspberry Pi tooling (all deferred to later phases per the 547 research report).

## Findings

### 1. Package Availability (Verified)

All required packages are available directly in nixpkgs:

```bash
nix eval nixpkgs#python312Packages.nextcord.version  # → "3.1.1"
nix eval nixpkgs#sops.version                         # → "3.12.2"
nix eval nixpkgs#age.version                          # → "1.3.1"
```

**Package addition to `configuration.nix`:**

```nix
environment.systemPackages = with pkgs; [
  # ... existing packages ...

  # Discord Bot Prerequisites (Task 550)
  python312Packages.nextcord  # Discord bot library (3.1.1, slash-command-native, async)
  sops                        # Secrets encryption/decryption (3.12.2)
  age                         # Encryption backend for sops (age 1.3.1)
];
```

**Note**: `age` is listed explicitly for transparency. It's also a dependency of sops and typically pulled in transitively, but explicit listing ensures it's in the closure and available for `age-keygen` during key setup.

**Important**: The `nextcord` package in nixpkgs is `python3Packages.nextcord` (aliased from `python312Packages.nextcord`). Use `python312Packages.nextcord` to match the existing python312 convention in `home.nix`.

### 2. sops-nix Secrets Management

sops-nix is a NixOS module (not a standalone nixpkgs package). It must be added as a flake input and imported.

#### 2a. Flake Input Addition (`flake.nix`)

Add to the `inputs` block:

```nix
inputs = {
  # ... existing inputs ...
  sops-nix.url = "github:Mic92/sops-nix";
  sops-nix.inputs.nixpkgs.follows = "nixpkgs";
};
```

Pass through to `outputs` function arguments:

```nix
outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, lean4, niri, lectic, nix-ai-tools, utils, sops-nix, ... }@inputs:
```

#### 2b. Module Import (in each host's `modules` list)

Add `sops-nix.nixosModules.sops` to each `nixosConfigurations` host. For example, for `hamsa`:

```nix
hamsa = lib.nixosSystem {
  inherit system;
  modules = [
    ./configuration.nix
    ./hosts/hamsa/hardware-configuration.nix
    { networking.hostName = "hamsa"; }
    sops-nix.nixosModules.sops          # ← ADD THIS
    { nixpkgs = nixpkgsConfig; }
    # ... home-manager ...
  ];
};
```

Repeat for `nandi`, `iso`, and `usb-installer` hosts.

#### 2c. `.sops.yaml` (Repository Root)

Create at `/home/benjamin/.dotfiles/.sops.yaml`:

```yaml
keys:
  - &benjamin_age age180d5r...  # Replace with actual age public key

creation_rules:
  - path_regex: secrets/[^/]+\.yaml$
    key_groups:
      - age:
          - *benjamin_age
```

The age public key is generated once with:

```bash
age-keygen -o ~/.config/sops/age/keys.txt
# Outputs: Public key: age1...
```

**Key storage location**: Following the Arch Linux wiki and sops-nix conventions, the age private key should live at `~/.config/sops/age/keys.txt`. This path is used by sops and sops-nix by default. Do NOT store it in the dotfiles repo.

#### 2d. Encrypted Secrets File

Create `secrets/secrets.yaml` (encrypted with sops):

```bash
mkdir -p /home/benjamin/.dotfiles/secrets
sops secrets/secrets.yaml
```

Content (plaintext before encryption):

```yaml
discord-bot-token: "YOUR_DISCORD_BOT_TOKEN_HERE"
opencode-server-password: "YOUR_GENERATED_PASSWORD_HERE"
```

After saving, sops encrypts the file. The encrypted file is committed to git; the plaintext never touches disk unencrypted after initial creation.

#### 2e. sops-nix NixOS Configuration (`configuration.nix`)

```nix
# sops-nix secrets management (Task 550)
sops = {
  defaultSopsFile = ./secrets/secrets.yaml;
  age.sshKeyPaths = [ "/home/benjamin/.config/sops/age/keys.txt" ];

  secrets = {
    "discord_bot_token" = {
      owner = config.users.users.benjamin.name;
    };
    "opencode_server_password" = {
      owner = config.users.users.benjamin.name;
    };
  };
};
```

**Note on key names**: sops-nix converts hyphens in YAML keys to underscores in the secret path. The YAML key `discord-bot-token` becomes the sops secret path `discord_bot_token`. Systemd services reference these via `LoadCredential=discord_bot_token:...` or `EnvironmentFile=`.

### 3. opencode-serve Systemd Service

Following the existing service patterns in `configuration.nix` (e.g., `disable-speaker-amp`, which uses `wantedBy = [ "multi-user.target" ]`):

```nix
systemd.services = {
  # ... existing services ...

  # OpenCode Headless Server (Task 550)
  opencode-serve = {
    description = "OpenCode headless agent server";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.opencode}/bin/opencode serve --hostname 127.0.0.1";
      Restart = "always";
      RestartSec = "10s";

      # Inject the server password from sops-nix
      LoadCredential = "opencode_server_password:${config.sops.secrets."opencode_server_password".path}";
      Environment = "OPENCODE_SERVER_PASSWORD=%d/opencode_server_password";
      # Working directory: use the user's dotfiles path so opencode finds its .opencode/ config
      WorkingDirectory = "/home/benjamin/.dotfiles";

      User = config.users.users.benjamin.name;
      Group = "users";
    };
  };
};
```

**Key decisions**:
- `Type = "simple"` rather than "oneshot" because opencode serve is a persistent daemon, not a one-shot task.
- `Restart = "always"` ensures the server comes back if it crashes.
- `RestartSec = "10s"` provides a brief cooldown between restarts.
- `WorkingDirectory = "/home/benjamin/.dotfiles"` so OpenCode finds its `.opencode/` configuration and agent definitions.
- **IMPORTANT**: The `%d` in the Environment value is a systemd specifier for the credential directory. When `LoadCredential` is used with the path from sops-nix, systemd stores the credential at `/run/credentials/opencode-serve.service/opencode_server_password`, and `%d` expands to that directory.
- **Auth model**: OpenCode's built-in basic auth via `OPENCODE_SERVER_PASSWORD` is used. The `opencode attach` and `opencode run --attach` commands will need to pass this password.

### 4. discord-bot Systemd Service

The Python bot project lives at `~/.dotfiles/opencode-discord-bot/` with its main entry point `src/bot.py`. The plan (01_discord-bot-neovim-setup.md) defines the full project structure (see Finding 7 below). The service definition injects all secrets via `LoadCredential` and passes env vars the bot expects.

```nix
systemd.services = {
  # ... existing services ...

  discord-bot = {
    description = "Discord bot relay for OpenCode agent management";
    after = [ "network-online.target" "opencode-serve.service" ];
    wants = [ "network-online.target" ];
    requires = [ "opencode-serve.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.python312}/bin/python -m opencode_discord_bot.src.bot";
      Restart = "always";
      RestartSec = "10s";

      LoadCredential = [
        "discord_bot_token:${config.sops.secrets."discord_bot_token".path}"
        "opencode_server_password:${config.sops.secrets."opencode_server_password".path}"
      ];

      Environment = [
        "DISCORD_BOT_TOKEN=%d/discord_bot_token"
        "OPENCODE_SERVER_PASSWORD=%d/opencode_server_password"
        "OPENCODE_SERVER_URL=http://127.0.0.1"
        "WHITELISTED_USER_IDS="  # comma-separated, set in secrets.yaml
        "LINK_API_TOKEN="  # shared secret for Neovim -> bot local HTTP API
        "LOG_LEVEL=info"
      ];

      WorkingDirectory = "/home/benjamin/.dotfiles";
      User = config.users.users.benjamin.name;
      Group = "users";
    };
  };
};
```

**Key decisions**:
- `requires = [ "opencode-serve.service" ]` ensures the OpenCode server is running before the bot starts. If opencode-serve crashes, the bot also stops.
- `LoadCredential` is used for both secrets, following the same pattern as opencode-serve.
- `OPENCODE_SERVER_URL` is set to `http://127.0.0.1` since the server runs locally. The bot discovers the port via `opencode session list` or mDNS.
- `WHITELISTED_USER_IDS` and `LINK_API_TOKEN` are left as empty env vars (to be filled from secrets.yaml or configured manually). The `LINK_API_TOKEN` is a shared secret between Neovim's `:OpenCodeLinkDiscord` command and the bot's local HTTP API (`POST /link`).
- `ExecStart` uses `python -m opencode_discord_bot.src.bot` — the project root `opencode-discord-bot/` must be on Python's path. See Finding 7 for the recommended `PYTHONPATH` approach.

### 5. Additional Python Dependencies

Beyond nextcord, the bot plan calls for:

| Package | Purpose | In nixpkgs? |
|---------|---------|-------------|
| `aiohttp` | Local HTTP API server (the `POST /link` endpoint Neovim calls) | Yes, `python312Packages.aiohttp` |
| `anyio` | Structured concurrency for subprocess management | Yes, `python312Packages.anyio` |

These should be added to the system Python environment so the bot can import them. Either add them to `environment.systemPackages` via `python312.withPackages`, or create a dedicated Python environment for the bot.

**Recommended**: Create a dedicated Python environment in `configuration.nix` using a `let` binding:

```nix
discordBotPython = pkgs.python312.withPackages (p: with p; [
  nextcord
  aiohttp
  anyio
]);
```

Then use this in the service `ExecStart` and `PATH`:

```nix
ExecStart = "${discordBotPython}/bin/python -m opencode_discord_bot.src.bot";
Environment = [
  # ... other env vars ...
  "PYTHONPATH=/home/benjamin/.dotfiles/opencode-discord-bot"
];
```

This avoids polluting the global `environment.systemPackages` Python with bot-specific dependencies, while keeping the bot fully self-contained.

### 6. Secrets File Expansion

The encrypted `secrets/secrets.yaml` should include all variables the bot references:

```yaml
discord-bot-token: "YOUR_DISCORD_BOT_TOKEN_HERE"
opencode-server-password: "YOUR_GENERATED_PASSWORD_HERE"
whitelisted-user-ids: "123456789012345678"  # comma-separated Discord user IDs
link-api-token: "YOUR_RANDOM_SHARED_SECRET"   # for Neovim -> bot HTTP API auth
```

And corresponding sops secrets block entries:

```nix
sops.secrets = {
  "discord_bot_token" = { owner = config.users.users.benjamin.name; };
  "opencode_server_password" = { owner = config.users.users.benjamin.name; };
};
```

The `WHITELISTED_USER_IDS` and `LINK_API_TOKEN` can optionally be passed via systemd `LoadCredential` as well, or set directly in the `Environment` block if they're not sensitive enough to warrant encryption. The `LINK_API_TOKEN` should be encrypted (it's a shared secret); `WHITELISTED_USER_IDS` is less sensitive but encrypting everything keeps the pattern uniform.

### 7. Python Bot Project Structure (from 01_discord-bot-neovim-setup.md)

The bot lives at `~/.dotfiles/opencode-discord-bot/` with this layout:

```
opencode-discord-bot/
├── src/
│   ├── __init__.py
│   ├── bot.py              # main entry point, Nextcord client
│   ├── logging_config.py   # structured JSON logging to stdout
│   ├── auth.py             # whitelist decorator
│   ├── rate_limit.py       # in-memory sliding window rate limiter
│   ├── relay.py            # message relay: Discord thread ↔ OpenCode session
│   ├── api.py              # local HTTP API (aiohttp): POST /link, GET /health, GET /sessions
│   ├── commands/
│   │   ├── __init__.py     # cog registration
│   │   ├── session_cog.py  # /rc session join/list/leave
│   │   ├── task_cog.py     # /rc task status/create/research/plan/implement
│   │   └── system_cog.py   # /rc status, /rc refresh
│   ├── opencode/
│   │   ├── __init__.py
│   │   ├── client.py       # OpenCode CLI wrapper (session list, run --command)
│   │   └── executor.py     # async subprocess runner with timeout
│   └── state/
│       ├── __init__.py
│       └── store.py        # JSON-backed session↔thread mapping store
├── config/
│   ├── settings.py         # env var configuration loader
│   ├── example.env         # env var template (dev)
│   └── env.production      # env var template (production)
├── data/
│   └── .gitkeep            # sessions.json stored here at runtime
├── tests/                  # pytest test suite
├── systemd/
│   └── opencode-discord-bot.service  # systemd unit (for reference only)
├── requirements.txt        # pip freeze (for reference; Nix handles deps)
└── README.md               # setup and usage guide
```

**Key implications for the NixOS configuration**:

1. **Package dependencies**: The bot needs `nextcord`, `aiohttp`, and `anyio` in its Python environment.
2. **PYTHONPATH**: The service must add `opencode-discord-bot/` to `PYTHONPATH` so `import opencode_discord_bot.src.bot` resolves.
3. **Data directory**: `data/sessions.json` persists the session↔thread mapping across restarts. The `data/` directory must exist and be writable by the `benjamin` user.
4. **Port binding**: The HTTP API binds to `127.0.0.1` only (see security hardening in Phase 6 of the plan).
5. **Systemd service file in plan**: The plan defines a standalone `systemd/opencode-discord-bot.service` — the NixOS `discord-bot` service definition in `configuration.nix` supersedes this as the authoritative service configuration.

## Decisions

1. **sops-nix over agenix**: sops-nix is the recommended approach per the external research report. agenix is not in nixpkgs. sops-nix has broader community adoption and supports age natively.

2. **Dedicated Python environment**: Use `python312.withPackages` for the bot's Python deps (nextcord, aiohttp, anyio) rather than adding them to the global system Python in `home.nix`. This avoids dependency conflicts and keeps the bot self-contained.

3. **Service dependencies**: `discord-bot` uses `requires` (hard dependency) on `opencode-serve`. If the server crashes, systemd restarts both.

4. **Service user**: Both services run as `benjamin` (not root). Correct for accessing `/home/benjamin/.dotfiles/` and `opencode-discord-bot/`.

5. **Credential-based secrets**: `LoadCredential` is preferred over `EnvironmentFile` — uses systemd's credential system, stored in memory-backed tmpfs, never on disk.

6. **Bot project not Nix-packaged**: The bot source lives as a plain Python package at `~/.dotfiles/opencode-discord-bot/` (per the plan). The NixOS service sets `PYTHONPATH` to load it. This keeps the bot implementation decoupled from the NixOS configuration — the bot can be developed and tested independently.

7. **`WHITELISTED_USER_IDS` and `LINK_API_TOKEN`**: Passed as env vars. The `LINK_API_TOKEN` is sensitive (a shared secret for Neovim→bot API auth) and should come from sops; `WHITELISTED_USER_IDS` is less critical but encrypting it maintains uniform secret handling.

## Recommendations

### Implementation (to be done in a follow-up task)

1. **Add sops-nix flake input**: Add to `inputs` block, pass through to `outputs`, import module in each host, run `nix flake lock`.

2. **Generate age key**: Run `age-keygen -o ~/.config/sops/age/keys.txt`, record the public key.

3. **Create `.sops.yaml`**: At repo root with the age public key.

4. **Create encrypted secrets**: `sops secrets/secrets.yaml` with `discord-bot-token` and `opencode-server-password`.

5. **Add packages to `configuration.nix`**: Python312 nextcord, sops, age under `environment.systemPackages`.

6. **Add sops-nix config to `configuration.nix`**: `sops.defaultSopsFile`, `sops.age.sshKeyPaths`, `sops.secrets` blocks.

7. **Add systemd services to `configuration.nix`**: `opencode-serve` and `discord-bot` service definitions.

8. **Replace bot ExecStart placeholder**: Create the actual bot script (Python) and wire it into the service.

9. **Verify build**: Run `nix flake check` and `nixos-rebuild build --flake .#hamsa` before attempting a switch.

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| sops-nix module import breaks existing builds | Low | High | Add to all hosts in one pass; `nix flake check` before each host build |
| OpenCode picks random port, bot can't find it | Medium | Medium | Implementation task can add `--port 4096` if mDNS discovery proves unreliable |
| Age key lost after disk failure | Low | High | Back up age private key separately; document recovery procedure |
| Bot references non-existent Python script | High (with placeholder) | Low | Placeholder is expected to fail; implementation task replaces it before merging |

## Appendix

### A. Modified Files Summary

| File | Change Type | What Changes |
|------|-------------|--------------|
| `flake.nix` | New input, module import | Add `sops-nix` input + module import per host |
| `configuration.nix` | New `discordBotPython` binding | Dedicated Python environment (nextcord, aiohttp, anyio) |
| `configuration.nix` | New NixOS config block | Add `sops = { ... }` block |
| `configuration.nix` | New systemd service | Add `opencode-serve` service definition |
| `configuration.nix` | New systemd service | Add `discord-bot` service definition |
| `configuration.nix` | Package addition | Add `sops` and `age` to `environment.systemPackages` |
| `.sops.yaml` | New file | Age key + creation rules |
| `secrets/secrets.yaml` | New encrypted file | Bot token, server password (encrypted on disk) |
| `opencode-discord-bot/` | External project | Bot source (created by separate implementation task) |

### B. Full `configuration.nix` Additions (Consolidated)

```nix
# ==========================================================================
# Discord Bot Prerequisites (Task 53)
# ==========================================================================
# sops-nix decryption: injects bot token and OpenCode password into
# systemd services via LoadCredential (never on disk unencrypted).
# Bot project: ~/.dotfiles/opencode-discord-bot/src/bot.py (Nextcord)
# Plan: ~/.config/nvim/specs/547_research_mobile_agent_management/plans/01_discord-bot-neovim-setup.md
# See: specs/053_nixos_discord_bot_prerequisites/reports/01_nixos-discord-bot-prerequisites.md
# ==========================================================================

# --- DEDICATED BOT PYTHON ENVIRONMENT ---
# (add near top of configuration.nix, after pkgs is available)
discordBotPython = pkgs.python312.withPackages (p: with p; [
  nextcord   # Discord bot library (3.1.1, slash-command-native, async)
  aiohttp    # Local HTTP API server (POST /link endpoint for Neovim)
  anyio      # Structured concurrency for subprocess management
]);

# --- SOPS-NIX ---
sops = {
  defaultSopsFile = ./secrets/secrets.yaml;
  age.sshKeyPaths = [ "/home/benjamin/.config/sops/age/keys.txt" ];

  secrets = {
    "discord_bot_token" = {
      owner = config.users.users.benjamin.name;
    };
    "opencode_server_password" = {
      owner = config.users.users.benjamin.name;
    };
  };
};

# --- SERVICES ---
systemd.services = {
  # (existing services remain above)

  opencode-serve = {
    description = "OpenCode headless agent server";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.opencode}/bin/opencode serve --hostname 127.0.0.1";
      Restart = "always";
      RestartSec = "10s";
      LoadCredential = "opencode_server_password:${config.sops.secrets."opencode_server_password".path}";
      Environment = "OPENCODE_SERVER_PASSWORD=%d/opencode_server_password";
      WorkingDirectory = "/home/benjamin/.dotfiles";
      User = config.users.users.benjamin.name;
      Group = "users";
    };
  };

  discord-bot = {
    description = "Discord bot relay for OpenCode agent management";
    after = [ "network-online.target" "opencode-serve.service" ];
    wants = [ "network-online.target" ];
    requires = [ "opencode-serve.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${discordBotPython}/bin/python -m opencode_discord_bot.src.bot";
      Restart = "always";
      RestartSec = "10s";
      LoadCredential = [
        "discord_bot_token:${config.sops.secrets."discord_bot_token".path}"
        "opencode_server_password:${config.sops.secrets."opencode_server_password".path}"
      ];
      Environment = [
        "DISCORD_BOT_TOKEN=%d/discord_bot_token"
        "OPENCODE_SERVER_PASSWORD=%d/opencode_server_password"
        "OPENCODE_SERVER_URL=http://127.0.0.1"
        "WHITELISTED_USER_IDS="
        "LINK_API_TOKEN="
        "LOG_LEVEL=info"
        "PYTHONPATH=/home/benjamin/.dotfiles/opencode-discord-bot"
      ];
      WorkingDirectory = "/home/benjamin/.dotfiles";
      User = config.users.users.benjamin.name;
      Group = "users";
    };
  };
};
```

### C. sops-nix Flake Input (Consolidated)

```nix
# In inputs {...}:
sops-nix.url = "github:Mic92/sops-nix";
sops-nix.inputs.nixpkgs.follows = "nixpkgs";

# In outputs = { ... sops-nix, ... }@inputs:

# In each host's modules list, BEFORE the nixpkgs config:
sops-nix.nixosModules.sops
```

### D. Step-by-Step Setup Commands (Manual, Run Once)

```bash
# 1. Generate age key (one-time)
age-keygen -o ~/.config/sops/age/keys.txt
# Note the public key (starts with "age1")

# 2. Create .sops.yaml with the public key
# (use template from Finding 2c)

# 3. Create encrypted secrets file
mkdir -p /home/benjamin/.dotfiles/secrets
# Use sops to create the file; it opens $EDITOR:
sops /home/benjamin/.dotfiles/secrets/secrets.yaml
# Content:
# discord-bot-token: "YOUR_ACTUAL_TOKEN"
# opencode-server-password: "A_GENERATED_LONG_RANDOM_STRING"

# 4. Add sops-nix flake input and lock
# (edit flake.nix per Appendix C, then:)
nix flake lock

# 5. Rebuild
nixos-rebuild build --flake .#hamsa
```

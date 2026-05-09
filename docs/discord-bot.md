# Discord Bot Infrastructure

NixOS systemd services and Python environment for the OpenCode Discord bot relay — a Nextcord bot that bridges Discord to a headless OpenCode agent server.

## Architecture

```
Discord ←→ discord-bot.service ←→ opencode-serve.service ←→ OpenCode Agent
                (Nextcord)              (opencode serve)
                                         127.0.0.1 (dynamic port)
```

- **opencode-serve**: Persistent agent server bound to `127.0.0.1`, no port fixed (mDNS discovery)
- **discord-bot**: Nextcord relay connecting to opencode-serve at `OPENCODE_SERVER_URL`
- Secrets (Discord token, OpenCode password) injected via systemd `LoadCredential` from sops-nix — never touch disk unencrypted (held in tmpfs at `/run/credentials/<service>.service/`)

## Files

| File | Purpose |
|------|---------|
| `configuration.nix` | `discordBotPython` env + sops config + both systemd services |
| `flake.nix` | sops-nix flake input + module import on all 4 hosts |
| `.sops.yaml` | Age key config + creation rules for `secrets/*.yaml` |
| `secrets/secrets.yaml` | Encrypted secrets (committed encrypted) |
| `~/.config/sops/age/keys.txt` | Age private key (**never committed**) |

## Python Environment

`discordBotPython` is a dedicated `python312.withPackages` environment defined as a let-binding in `configuration.nix`. It contains:

| Package | Purpose |
|---------|---------|
| `nextcord` | Discord API library |
| `aiohttp` | HTTP client for local OpenCode API calls |
| `anyio` | Structured concurrency |

Versions are not pinned — they track whatever is in the nixpkgs flake input.

The environment is scoped to the bot service only — it does not leak into the global system PATH. The bot service runs it directly:

```nix
ExecStart = "${discordBotPython}/bin/python -m opencode_discord_bot.src.bot"
```

## Systemd Services

### opencode-serve.service

```nix
Type = "simple"
Restart = "always"
RestartSec = "10s"
After = [ "network-online.target" ]
Wants = [ "network-online.target" ]
WantedBy = [ "multi-user.target" ]
User = "benjamin"
Group = "users"
WorkingDirectory = "/home/benjamin/.dotfiles"

ExecStart = "${pkgs.opencode}/bin/opencode serve --hostname 127.0.0.1"
LoadCredential = "opencode_server_password:/run/secrets/opencode_server_password"
Environment = "OPENCODE_SERVER_PASSWORD=%d/opencode_server_password"
```

- `%d` expands to `/run/credentials/opencode-serve.service/`
- Uses the existing `packages/opencode.nix` wrapper
- Port is not fixed — OpenCode uses default mDNS-based discovery
- Service starts on boot, survives crashes (always restart with 10s backoff)

### discord-bot.service

```nix
Type = "simple"
Restart = "always"
RestartSec = "10s"
After = [ "network-online.target" "opencode-serve.service" ]
Wants = [ "network-online.target" ]
Requires = [ "opencode-serve.service" ]
WantedBy = [ "multi-user.target" ]
User = "benjamin"
Group = "users"
WorkingDirectory = "/home/benjamin/.dotfiles"

ExecStart = "${discordBotPython}/bin/python -m opencode_discord_bot.src.bot"
LoadCredential = [
  "discord_bot_token:/run/secrets/discord_bot_token"
  "opencode_server_password:/run/secrets/opencode_server_password"
]
Environment = [
  "DISCORD_BOT_TOKEN=%d/discord_bot_token"
  "OPENCODE_SERVER_PASSWORD=%d/opencode_server_password"
  "OPENCODE_SERVER_URL=http://127.0.0.1"
  "WHITELISTED_USER_IDS="
  "LINK_API_TOKEN="
  "LOG_LEVEL=info"
  "PYTHONPATH=/home/benjamin/.dotfiles/opencode-discord-bot"
]
```

- **`Requires`** (hard dependency) + **`After`** (ordering) on `opencode-serve.service`
- `PYTHONPATH` points to bot project source at `~/.dotfiles/opencode-discord-bot/`
- Bot will fail to start until the Python source code exists (external task 547)
- Both secrets injected via `LoadCredential`, each in its own credential file

## Secrets Management (sops-nix)

All secrets use **age** encryption via sops-nix (chosen over agenix for broader community adoption).

### Key Files

**`.sops.yaml`** (repo root):
```yaml
keys:
  - &benjamin_age age173cp99dekavwh2s4cdv7eurpmcvda5339n6w4t23pg72fnz4g38qzfsyzt

creation_rules:
  - path_regex: secrets/[^/]+\.yaml$
    key_groups:
      - age:
          - *benjamin_age
```

**`secrets/secrets.yaml`** (encrypted, committed):
| Key | sops-managed? | Purpose |
|-----|--------------|---------|
| `discord_bot_token` | Yes | Discord bot authentication token (decrypted to `/run/secrets/`) |
| `opencode_server_password` | Yes | Password for OpenCode headless server (decrypted to `/run/secrets/`) |
| `whitelisted_user_ids` | No | Comma-separated Discord user IDs allowed to use the bot |
| `link_api_token` | No | Token for external link shortening/API service |

> **Note**: `whitelisted_user_ids` and `link_api_token` exist in the encrypted file but are **not** declared in `sops.secrets` in `configuration.nix`. They are not decrypted to `/run/secrets/` or injected via `LoadCredential`. Instead, the discord-bot service sets these as empty-string environment variables directly. To actually use these values, either add them to `sops.secrets` + `LoadCredential`, or set them directly in the service environment.

**`~/.config/sops/age/keys.txt`** (private key — never committed, never pushed):
```
AGE-SECRET-KEY-1...
```

### sops-nix NixOS Configuration

In `configuration.nix`:
```nix
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

This creates:
- `/run/secrets/discord_bot_token` — decrypted at activation time
- `/run/secrets/opencode_server_password` — decrypted at activation time

Decryption happens before systemd starts, so services can rely on secrets being available. If decryption fails (e.g., missing age key), services will fail to start gracefully.

### Day-to-Day Operations

**Edit secrets** (opens interactive editor):
```bash
sops secrets/secrets.yaml
```

**View secrets** (read-only):
```bash
sops --decrypt secrets/secrets.yaml
```

**Rotate age key** (key lost or compromised):
```bash
age-keygen -o ~/.config/sops/age/keys.txt
# Update .sops.yaml with new public key
# Re-encrypt all secrets with new key
sops --rotate secrets/secrets.yaml
```

**Add a new secret**:
- Add the key-value to `secrets/secrets.yaml` via `sops secrets/secrets.yaml`
- Add a corresponding entry in `sops.secrets` in `configuration.nix`
- Use `LoadCredential` to inject it into the relevant service

### Secret Lifecycle

```
Write → sops encrypts → committed to git (ciphertext only)
                     → sops-nix decrypts at nixos-rebuild activation
                     → written to /run/secrets/ (tmpfs, RAM-only)
                     → systemd LoadCredential injects into service
                     → %d/ expands to /run/credentials/<service>.service/
```

Secrets never exist as plaintext on persistent storage.

## Manual Setup Checklist

Before running `nixos-rebuild switch`:

1. **Generate age key** (first time):
   ```bash
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

2. **Set real secrets**:
   ```bash
   sops secrets/secrets.yaml
   ```
   - Replace `discord_bot_token` with actual Discord token
   - Replace `opencode_server_password` with a strong random password
   - Optionally set `whitelisted_user_ids` and `link_api_token` (note: these are stored in the encrypted file but not currently wired through sops-nix — see secrets table above)

3. **Back up age key**: Store `~/.config/sops/age/keys.txt` securely (password manager, encrypted backup)

4. **Create bot project**: The bot source must exist at `~/.dotfiles/opencode-discord-bot/src/bot.py` before `discord-bot.service` can start (external task 547)

5. **Apply**:
   ```bash
   sudo nixos-rebuild switch --flake .#hamsa   # or .#nandi
   ```

## Verification

After applying the configuration:

```bash
# Check flake integrity
nix flake check

# Verify secrets are decryptable
sops --decrypt secrets/secrets.yaml

# Check service status
systemctl status opencode-serve
systemctl status discord-bot

# Inspect generated units
systemctl cat opencode-serve
systemctl cat discord-bot

# Check credential availability (as root)
sudo ls /run/credentials/opencode-serve.service/
sudo ls /run/credentials/discord-bot.service/

# Follow logs
journalctl -fu opencode-serve
journalctl -fu discord-bot
```

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `discord-bot` fails to start | Bot source missing at `~/.dotfiles/opencode-discord-bot/` | Create bot project (task 547) |
| `opencode-serve` fails to start | Missing server password | Run `sops secrets/secrets.yaml` and set password |
| Both services fail with LoadCredential errors | Age key missing at `~/.config/sops/age/keys.txt` | Generate key with `age-keygen` |
| `nixos-rebuild build --flake .#hamsa` fails | sops-nix module import issue | Verify `sops-nix.nixosModules.sops` is in hamsa's modules list |
| sops decrypt fails | Wrong key or corrupted file | Check `.sops.yaml` has correct public key; regenerate if needed |

## Rollback

To remove the Discord bot infrastructure:

```bash
# 1. Remove sops-nix flake input from flake.nix and all 4 host module imports
# 2. Remove discordBotPython binding from configuration.nix
# 3. Remove sops config block from configuration.nix
# 4. Remove both systemd services from configuration.nix
# 5. Remove sops/age from environment.systemPackages
# 6. Delete .sops.yaml (optional)
# 7. Run: nix flake lock
# 8. Rebuild: sudo nixos-rebuild switch --flake .#hamsa
```

The encrypted `secrets/secrets.yaml` is inert without sops-nix and can remain or be deleted.

## Related Documentation

- **Spec Report 1**: `specs/053_nixos_discord_bot_prerequisites/reports/01_nixos-discord-bot-prerequisites.md`
- **Spec Report 2**: `specs/053_nixos_discord_bot_prerequisites/reports/02_python-discord-bot-best-practices.md`
- **Implementation Plan**: `specs/053_nixos_discord_bot_prerequisites/plans/02_nixos-discord-bot-prerequisites.md`
- **Implementation Summary**: `specs/053_nixos_discord_bot_prerequisites/summaries/02_nixos-discord-bot-prerequisites-summary.md`
- **Bot source**: External task 547 at `~/.dotfiles/opencode-discord-bot/`

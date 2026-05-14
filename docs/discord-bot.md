# Discord Bot Infrastructure

NixOS systemd services and Python environment for the OpenCode Discord bot relay — a Nextcord bot that bridges Discord to a headless OpenCode agent server.

## Architecture

```
Neovim TUI (opencode --port)  <-->  discord-bot.service  <-->  Discord
  dynamic port per project           (Nextcord, port 8080)
                                          |
                               opencode-serve.service
                                (port 4096, fallback)
```

- **Neovim TUI**: Each `opencode --port` instance runs an embedded HTTP server on a dynamic port. The bot connects to whichever instance owns the linked session.
- **discord-bot**: Nextcord relay with a local HTTP API on port 8080 for Neovim integration. Stores a `server_url` per linked session so it routes messages to the correct OpenCode instance.
- **opencode-serve**: Persistent headless server bound to `127.0.0.1:4096`. Acts as a fallback when no TUI-specific `server_url` is stored for a session. Scoped to a single working directory (`~/.dotfiles`).
- TUI instances do **not** require authentication. The headless server uses HTTP Basic Auth (`OPENCODE_SERVER_PASSWORD`).
- Secrets (Discord token, OpenCode password, Ollama API key, link API token) injected via systemd `LoadCredential` from sops-nix — never touch disk unencrypted (held in tmpfs at `/run/credentials/<service>.service/`)

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

ExecStart = "${pkgs.bash}/bin/bash -c 'OPENCODE_SERVER_PASSWORD=$(cat %d/opencode_server_password) OLLAMA_API_KEY=$(cat %d/ollama_api_key) exec ${pkgs.opencode}/bin/opencode serve --hostname 127.0.0.1 --port 4096'"
LoadCredential = [
  "opencode_server_password:${config.sops.secrets."opencode_server_password".path}"
  "ollama_api_key:${config.sops.secrets."ollama_api_key".path}"
]
```

- **Bash wrapper**: OpenCode reads `OPENCODE_SERVER_PASSWORD` literally from the env var. Systemd's `%d` expands to the credential directory path, not the file contents. The wrapper uses `cat` to read the actual secret into the env var before `exec`-ing OpenCode. Same pattern for `OLLAMA_API_KEY`.
- The previous `Environment = "OPENCODE_SERVER_PASSWORD=%d/opencode_server_password"` line was removed — the wrapper handles it.
- `OLLAMA_API_KEY` provides LLM provider authentication (Ollama cloud API).
- Uses the existing `packages/opencode.nix` wrapper
- Port is fixed at 4096 (`--port 4096`)
- Service starts on boot, survives crashes (always restart with 10s backoff)
- This server is scoped to `WorkingDirectory = /home/benjamin/.dotfiles`. Sessions created here belong to that project only. For other projects, the bot connects to per-project TUI instances instead.

### discord-bot.service

```nix
Type = "notify"
Restart = "always"
RestartSec = "10s"
WatchdogSec = "120s"
After = [ "network-online.target" "opencode-serve.service" ]
Wants = [ "network-online.target" "opencode-serve.service" ]
WantedBy = [ "multi-user.target" ]
User = "benjamin"
Group = "users"
WorkingDirectory = "/home/benjamin/.dotfiles"

ExecStart = "${discordBotPython}/bin/python -m opencode_discord_bot.src.bot"
LoadCredential = [
  "discord_bot_token:/run/secrets/discord_bot_token"
  "opencode_server_password:/run/secrets/opencode_server_password"
  "discord_channel_id:/run/secrets/discord_channel_id"
  "link_api_token:/run/secrets/link_api_token"
]
Environment = [
  "DISCORD_BOT_TOKEN=%d/discord_bot_token"
  "OPENCODE_SERVER_PASSWORD=%d/opencode_server_password"
  "OPENCODE_SERVER_URL=http://127.0.0.1:4096"
  "DISCORD_CHANNEL_ID=%d/discord_channel_id"
  "WHITELISTED_USER_IDS="
  "LINK_API_TOKEN=%d/link_api_token"
  "LOG_LEVEL=info"
  "PYTHONPATH=/home/benjamin/.dotfiles/opencode-discord-bot"
]
```

- **`Wants`** (soft dependency) + **`After`** (ordering) on `opencode-serve.service` — the bot tolerates OpenCode restarts without being force-restarted itself
- **`Type = "notify"`** + **`WatchdogSec = "120s"`** — the bot sends `READY=1` to systemd when the Discord gateway connects, then pings `WATCHDOG=1` every 60s. If the event loop freezes (no ping for 120s), systemd kills and restarts the bot automatically
- `PYTHONPATH` points to bot project source at `~/.dotfiles/opencode-discord-bot/`
- Bot will fail to start until the Python source code exists (external task 547)
- All secrets injected via `LoadCredential`, each in its own credential file
- `LINK_API_TOKEN` enables Bearer authentication on the HTTP API (used by Neovim integration)

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
| `discord_channel_id` | Yes | Discord channel ID for thread creation (decrypted to `/run/secrets/`) |
| `link_api_token` | Yes | Bearer token for the bot HTTP API, used by Neovim integration (decrypted to `/run/secrets/`) |
| `ollama_api_key` | Yes | API key for Ollama LLM provider, used by opencode-serve (decrypted to `/run/secrets/`) |
| `whitelisted_user_ids` | No | Comma-separated Discord user IDs allowed to use the bot |

> **Note**: `whitelisted_user_ids` exists in the encrypted file but is **not** declared in `sops.secrets` in `configuration.nix`. It is set as an empty-string environment variable directly in the service. To use it, add it to `sops.secrets` + `LoadCredential`.

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
    "discord_channel_id" = {
      owner = config.users.users.benjamin.name;
    };
    "link_api_token" = {
      owner = config.users.users.benjamin.name;
    };
    "ollama_api_key" = {
      owner = config.users.users.benjamin.name;
    };
  };
};
```

This creates:
- `/run/secrets/discord_bot_token` — decrypted at activation time
- `/run/secrets/opencode_server_password` — decrypted at activation time
- `/run/secrets/discord_channel_id` — decrypted at activation time
- `/run/secrets/link_api_token` — decrypted at activation time
- `/run/secrets/ollama_api_key` — decrypted at activation time

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
   - Set `link_api_token` to a random hex string (`openssl rand -hex 32`) — this is the Bearer token for the bot's HTTP API
   - Set `ollama_api_key` to your Ollama cloud API key (used by opencode-serve for LLM calls)
   - Optionally set `whitelisted_user_ids` (note: stored in the encrypted file but not currently wired through sops-nix — see secrets table above)

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
| `DISCORD_BOT_LINK_TOKEN not set` in Neovim | Fish shell didn't read `/run/secrets/link_api_token` | Ensure `link_api_token` is set in `secrets.yaml` and rebuild; restart fish |
| Bot returns 401 on `/link` or `/sessions` | Token mismatch between Neovim and bot | Both read from same sops secret; rebuild and restart shell |
| OpenCode health returns 401 | `OPENCODE_SERVER_PASSWORD` was set to credential file path, not contents | Use bash wrapper in ExecStart to `cat` the credential file (current config already does this) |
| Messages sent but silently ignored | `default_agent` in `config/opencode.json` references a non-existent agent | Remove `default_agent` from `config/opencode.json` or define the agent |
| LLM provider returns 401 | `OLLAMA_API_KEY` not available in opencode-serve env | Add `ollama_api_key` to sops secrets + LoadCredential in opencode-serve |
| Discord heartbeat blocked (>30s warnings) | Event loop froze (e.g., OpenCode dependency restarted mid-relay) | Systemd watchdog auto-restarts after 120s; manual: `sudo systemctl restart discord-bot` |
| `<leader>ar` shows no sessions | OpenCode TUI not running, or no session created yet | Start OpenCode TUI first and send at least one message to create a session |
| Bot HTTP API unresponsive (port 8080) | Service crashed or event loop stalled | Watchdog should auto-restart; manual: `sudo systemctl restart discord-bot` |
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

## Neovim Integration

Two Neovim plugins provide the Discord integration:
- `lua/neotex/plugins/ai/opencode/discord-link.lua` — session linking (`<leader>ar`)
- `lua/neotex/plugins/ai/opencode/discord-session-picker.lua` — session management (`<leader>as`)
- `lua/neotex/plugins/ai/opencode.lua` — TUI launcher (uses `opencode --port` for standalone instances)

### How Linking Works

1. `<leader>ar` discovers the TUI's embedded server port by scanning `ss -tlnp` for `opencode` processes matching the current working directory.
2. Queries that server's `GET /session` and `GET /session/status` endpoints to list sessions (busy/active sessions sorted first, then by most recently updated).
3. Shows a Telescope picker (capped at 20 sessions) with a preview pane displaying title, directory, status, age, and file change stats.
4. On selection, calls the bot's `POST /link` endpoint with `session_id`, `session_name`, and `server_url` (the TUI's dynamic port).
5. The bot stores the `server_url` per session so future Discord messages route to the correct TUI instance.

The `discord-link.lua` queries the OpenCode HTTP API directly (no CLI `opencode session list`). TUI instances do not require authentication.

### Environment Variables

The `DISCORD_BOT_LINK_TOKEN` env var is required by the Neovim plugins and must match the bot's `LINK_API_TOKEN`. It is set automatically in fish shell init by reading the sops-nix decrypted secret:

```fish
# In programs.fish.interactiveShellInit (configuration.nix):
if test -r /run/secrets/link_api_token
  set -gx DISCORD_BOT_LINK_TOKEN (cat /run/secrets/link_api_token)
end
```

| Variable | Source | Used by |
|----------|--------|---------|
| `DISCORD_BOT_URL` | Default `http://localhost:8080` | Neovim plugins (override if port changes) |
| `DISCORD_BOT_LINK_TOKEN` | `/run/secrets/link_api_token` via fish init | Neovim plugins (Bearer token) |
| `LINK_API_TOKEN` | `LoadCredential` via systemd | discord-bot service (validates Bearer tokens) |
| `OPENCODE_SERVER_URL` | Default `http://127.0.0.1:4096` | Neovim plugins (override for non-standard headless server port) |

### Keybindings

| Key | Command | Action |
|-----|---------|--------|
| `<leader>ar` | `:OpenCodeLinkDiscord` | Discover TUI server, pick a session, link to Discord thread |
| `<leader>as` | `:DiscordSessions` | Browse/manage linked sessions (Telescope picker: `<CR>` kills, `<C-o>` copies URL) |

### Verification

```bash
# Token is available in shell
echo $DISCORD_BOT_LINK_TOKEN

# Bot API responds
curl -s -H "Authorization: Bearer $DISCORD_BOT_LINK_TOKEN" http://localhost:8080/health | jq .

# TUI server is running (look for opencode --port processes)
ss -tlnp | grep opencode
```

## Related Documentation

- **Spec Report 1**: `specs/053_nixos_discord_bot_prerequisites/reports/01_nixos-discord-bot-prerequisites.md`
- **Spec Report 2**: `specs/053_nixos_discord_bot_prerequisites/reports/02_python-discord-bot-best-practices.md`
- **Implementation Plan**: `specs/053_nixos_discord_bot_prerequisites/plans/02_nixos-discord-bot-prerequisites.md`
- **Implementation Summary**: `specs/053_nixos_discord_bot_prerequisites/summaries/02_nixos-discord-bot-prerequisites-summary.md`
- **Bot source**: External task 547 at `~/.dotfiles/opencode-discord-bot/`

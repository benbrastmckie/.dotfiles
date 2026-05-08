# Research Report: Python Discord Bot Best Practices (2026) for Task 53

**Task**: 53 - nixos_discord_bot_prerequisites
**Started**: 2026-05-07
**Completed**: 2026-05-07
**Effort**: Research only; estimated implementation 4-6 hours
**Dependencies**: None
**Sources/Inputs**: nextcord docs, discord.py docs, sops-nix README, nixpkgs evaluation, NixOS Wiki (Python), GitHub releases, Discord Developer Platform docs
**Artifacts**: This report
**Standards**: report-format.md

## Executive Summary

This research covers the 2026 state of Python Discord bot development, with a focus on using **nextcord** (the chosen library per task requirements) within a NixOS environment. Key findings:

1. **nextcord v3.1.1** is the current latest release (August 2025) and requires Python &ge;3.12, which is met by the codebase's existing `python312` setup.
2. Both `nextcord` and `discordpy` (discord.py wrapper) are available in nixpkgs; nextcord is at **3.1.1**.
3. All required async primitives (`aiohttp` 3.13.4, `anyio` 4.13.0, `websockets` 16.0) are present and current in nixpkgs.
4. **sops-nix with age keys** is the current best practice for NixOS secret management; the codebase already has a `.sops.yaml` pattern ready for adoption.
5. The existing codebase has extensive Python environment patterns in `home.nix` using `python312.withPackages`, systemd user services in `home.nix`, and flake.nix overlay patterns that can be extended.
6. For a production bot, a **system-level NixOS systemd service** (not user-level) is recommended for reliability on boot, with sops-nix for secret injection.

## Context & Scope

### Task Description
Configure NixOS prerequisites for the Discord bot system:
- sops-nix flake input + module integration
- Dedicated Python environment (nextcord, aiohttp, anyio)
- `opencode-serve` systemd service
- `discord-bot` systemd service
- `.sops.yaml` with age key configuration
- Encrypted `secrets/secrets.yaml` for Discord token and OpenCode server password

### Constraints
- Bot project source lives at `~/.dotfiles/opencode-discord-bot/`
- The task explicitly names **nextcord** as the Discord library (not discord.py)
- Must follow existing flake.nix patterns (nixpkgs-unstable, overlays, home-manager)
- Age-based encryption preferred (lighter weight, modern, already used in nixpkgs)

## Findings

### 1. Library Comparison: nextcord vs discord.py (2026)

#### discord.py (v2.7.1)
- **The original and canonical library**: 16.1k GitHub stars, maintained by Rapptz
- Stable, mature API that closely mirrors Discord's official API design
- Extensions: `commands` (prefix+slash), `tasks` (asyncio loop helpers)
- Uses `aiohttp` for HTTP, maintains own WebSocket gateway connection
- Slower release cadence but very stable
- In nixpkgs as `python3Packages.discordpy`

#### nextcord (v3.1.1) &mdash; **RECOMMENDED for this task**
- Fork of discord.py with active community maintenance (1.3k stars)
- **Latest release**: v3.1.1 (August 2025), actively maintained with 6 releases in 2024-2025
- **Python 3.12+ required** (v3.0.0 breaking change, Dec 2024) &mdash; compatible with our python312
- Additional extensions over discord.py:
  - `nextcord.ext.application_checks` - slash command permission checks
  - Enhanced interaction/slash support with better type annotations
  - More Discord feature coverage (application emoji, new username system)
- Drop-in migration from discord.py (naming: `nextcord` instead of `discord`)
- In nixpkgs as `python3Packages.nextcord` at version **3.1.1**
- **Active development velocity is superior** to discord.py for new Discord API features

**Decision**: Use **nextcord** as specified in the task description. It is well-maintained, feature-complete, and has the Python 3.12+ baseline already met.

### 2. Discord Bot Development Best Practices (2026)

#### Architecture Patterns
- **Async-first design**: Both libraries use `asyncio`; all bot code should be async
- **Cog system**: Organize commands into `commands.Cog` subclasses for modularity
- **Slash commands are mandatory**: Prefix commands require the Message Content privileged intent (gatekeeping for verified bots &ge;100 guilds since 2025). **Slash commands are the default for all new bots.**
- **Intents**: Only enable needed intents. Typical bot needs:
  ```python
  intents = nextcord.Intents.default()
  intents.message_content = True  # if using prefix commands or reading message text
  # intents.members = True  # only if tracking joins/leaves/nickname changes
  ```

#### Gateway Intents (Post-2025 Hardening)
- Discord has significantly hardened privileged intent requirements
- **Message Content Intend**: Now gated behind bot verification for bots in &ge;100 guilds
- **Recommendation**: Build on slash commands first; avoid Message Content intent unless needed for moderation features
- **Member intent**: Only enable if tracking member events; use `Guild.fetch_member()` for one-off lookups
- `chunk_guilds_at_startup` should be `False` unless member intent is required

#### Slash Commands
```python
@bot.slash_command(name="ping", description="Check bot latency")
async def ping(interaction: nextcord.Interaction):
    await interaction.response.send_message(f"Pong! {round(bot.latency * 1000)}ms")
```
- Use `guild_ids` for instant command registration during development
- Global commands take up to 1 hour to propagate; prefer guild-scoped for testing
- Use `defer()` for operations taking >3 seconds (Discord interaction timeout)

#### Security Best Practices
- **Never hardcode tokens**: Use environment variables or sops-nix decrypted at runtime
- **`.gitignore` encrypted files** even though they're encrypted (defense in depth)
- **Rate limiting**: Use `nextcord.ext.tasks.loop` with `@tasks.loop(seconds=...)` for background tasks
- **Error handling**: Implement `on_application_command_error` for graceful user-facing errors
- **Permissions**: Use `@nextcord.slash_command(default_member_permissions=...)` for admin commands
- **Ephemeral responses**: Send sensitive command output only to the invoking user with `ephemeral=True`

### 3. Async Dependencies for Python Discord Bots

#### Core HTTP/Async Stack
| Package | Version in nixpkgs | Purpose |
|---------|-------------------|---------|
| `aiohttp` | 3.13.4 | HTTP client/server (used by nextcord internals) |
| `anyio` | 4.13.0 | Async compatibility layer (trio/asyncio) |
| `websockets` | 16.0 | WebSocket protocol (Discord gateway) |
| `yarl` | (bundled) | URL parsing for aiohttp |

These match or exceed the requirements for nextcord 3.1.x, which needs aiohttp &ge;3.9.

### 4. Nix Integration Patterns

#### Existing Codebase Patterns

The dotfiles repository already contains:

1. **`flake.nix`**: Extensive flake infrastructure with `nixpkgs-unstable`, overlays, and home-manager
   - Overlay pattern for Python packages (lines 104-118)
   - `pythonPackagesOverlay` with `packageOverrides` for custom Python packages
   - `pkgs-unstable` available via `specialArgs`

2. **`home.nix`**: Home Manager configuration with:
   - `python312.withPackages` for user-level Python env (line 342)
   - Systemd user services pattern (lines 722-813)
   - `home.activation` scripts (lines 681-721)
   - Service dependency ordering (`After` directives)

3. **`configuration.nix`**: NixOS system configuration with:
   - `systemd.services` block (lines 748-822)
   - Service timeouts and restart policies
   - System-level packages via `environment.systemPackages`

#### Recommended Python Environment Setup

For the bot, **two approaches** are viable:

**Option A: Dedicated nixpkgs Python package (Recommended for production)**
```nix
# In flake.nix overlays or separate module:
discord-bot-python = pkgs.python312.withPackages (ps: with ps; [
  nextcord
  aiohttp
  anyio
  pyyaml
]);
```
Then reference as `ExecStart = "${pkgs.discord-bot-python}/bin/python /path/to/bot.py"`

**Option B: SystemPackages with withPackages (Simpler)**
```nix
environment.systemPackages = [
  (python312.withPackages (ps: with ps; [ nextcord aiohttp anyio pyyaml ]))
];
```
Less scoped but simpler to implement.

**Recommendation**: Option A creates a self-contained Python environment and avoids leaking Discord dependencies into the system PATH.

#### Systemd Service Best Practices

For the `discord-bot` service (system-level, in `configuration.nix`):
```nix
systemd.services.discord-bot = {
  description = "Discord Bot Service";
  wantedBy = [ "multi-user.target" ];
  after = [ "network-online.target" ];
  wants = [ "network-online.target" ];
  serviceConfig = {
    Type = "simple";
    User = "discord-bot";  # dedicated user
    Group = "discord-bot";
    ExecStart = "${discord-bot-python}/bin/python ${bot-source}/main.py";
    Restart = "always";
    RestartSec = "10";
    # Security hardening
    ProtectSystem = "strict";
    ProtectHome = true;
    NoNewPrivileges = true;
    PrivateTmp = true;
    # Secret injection via EnvironmentFile or sops template
    EnvironmentFile = config.sops.templates."discord-bot.env".path;
  };
};
```

Key points:
- `after = [ "network-online.target" ]` ensures Discord gateway can connect
- `Restart = "always"` keeps bot alive through crashes
- Security hardening with `ProtectSystem` and `NoNewPrivileges`
- Secret injection via sops-nix templates (environment file or JSON config)

### 5. sops-nix Best Practices

#### Age vs GPG
- **Age (`age`) is strongly recommended** for new deployments in 2026
- Simpler key management, no daemon required, faster operations
- SSH Ed25519 key conversion via `ssh-to-age` for existing host keys
- The codebase's approach of using age aligns with sops-nix documentation recommendations

#### sops-nix Integration Plan

**Step 1: Add to flake.nix inputs**
```nix
sops-nix.url = "github:Mic92/sops-nix";
sops-nix.inputs.nixpkgs.follows = "nixpkgs";
```

**Step 2: Import module**
```nix
# In configuration.nix or flake module list:
sops-nix.nixosModules.sops
```

**Step 3: Create `.sops.yaml`**
```yaml
keys:
  - &admin age1...  # your personal age public key
creation_rules:
  - path_regex: secrets/[^/]+\.yaml$
    key_groups:
    - age:
      - *admin
      - *host  # host's age key (derived from SSH host key)
```

**Step 4: Create encrypted secrets file**
```bash
nix-shell -p sops --run "sops secrets/secrets.yaml"
```
```yaml
discord_token: "your-bot-token"
opencode_password: "your-server-password"
```

**Step 5: Configure in NixOS**
```nix
sops = {
  defaultSopsFile = ./secrets/secrets.yaml;
  age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  secrets.discord_token = {
    owner = "discord-bot";
    restartUnits = [ "discord-bot.service" ];
  };

  templates."discord-bot.env" = {
    content = ''
      DISCORD_TOKEN=${config.sops.placeholder.discord_token}
    '';
  };
};
```

#### Key Security Considerations
- Secrets are decrypted at activation time, not at evaluation time
- `/run/secrets` is on tmpfs (RAM-only), not persisted to disk
- Atomic secret directory replacement on `nixos-rebuild switch`
- `restartUnits` auto-restarts services when secrets change
- Use dedicated service users with minimal permissions per secret

### 6. Bot Architecture Recommendations

#### Recommended Directory Structure (for `~/.dotfiles/opencode-discord-bot/`)
```
opencode-discord-bot/
├── bot/
│   ├── __init__.py
│   ├── main.py           # Entry point
│   ├── core/
│   │   ├── __init__.py
│   │   └── bot.py        # Bot subclass, cog loading, error handling
│   ├── cogs/
│   │   ├── __init__.py
│   │   ├── admin.py      # Admin/slash commands
│   │   ├── opencode.py   # OpenCode server integration
│   │   └── utilities.py  # General utility commands
│   ├── utils/
│   │   ├── __init__.py
│   │   └── config.py     # Config/env loading
│   └── services/
│       ├── __init__.py
│       └── opencode.py   # OpenCode API client
├── pyproject.toml         # Project metadata
├── README.md
└── requirements.txt       # For reference only (nix manages deps)
```

#### Entry Point Pattern (`main.py`)
```python
import os
import nextcord
from nextcord.ext import commands
from bot.core.bot import Bot

def main():
    token = os.environ["DISCORD_TOKEN"]
    intents = nextcord.Intents.default()
    intents.message_content = False  # slash-commands only

    bot = Bot(command_prefix=None, intents=intents)  # No prefix; slash-only

    # Load cogs
    bot.load_extension("bot.cogs.admin")
    bot.load_extension("bot.cogs.opencode")
    bot.load_extension("bot.cogs.utilities")

    bot.run(token)

if __name__ == "__main__":
    main()
```

#### Key Patterns
- **Slash-command-first**: No prefix commands unless Message Content intent is justified
- **Cog-based organization**: One cog per feature domain
- **Error handling middleware**: `on_application_command_error` for consistent error responses
- **Graceful shutdown**: Handle `SIGTERM`/`SIGINT` for clean disconnect from Discord gateway
- **Logging**: Use `logging` module with structured logging; redirect to journald for NixOS compatibility

## Decisions

1. **Library**: **nextcord** (v3.1.1, in nixpkgs) as specified in task requirements
2. **Encryption**: **age** (via sops-nix) for secret management; lighter weight than GPG, modern standard
3. **Service type**: **System-level NixOS service** (not user-level) for boot-time reliability
4. **Python environment**: **Dedicated `python312.withPackages` scoped to the bot** (not shared with user environment)
5. **Command architecture**: **Slash commands only**, no Message Content intent (avoids verification gatekeeping)
6. **Service model**: Single bot process with cog-based modularity (not sharded &mdash; single-guild use case)
7. **Secret injection**: **sops-nix templates** generating environment files (clean separation from code)

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| nextcord API changes between releases | Pin to nixpkgs version; test before nixpkgs updates |
| Discord Gateway disconnection | `Restart=always` with 10s backoff in systemd |
| Secret leakage via git history | `.gitignore` all encrypted files; use git-crypt as additional layer if needed |
| sops-nix activation failure blocks rebuild | Test `nixos-rebuild dry-activate` first |
| Python environment bloat from withPackages | Use minimal package set; scope Python to bot service only |
| Rate limiting from Discord API | Implement cooldowns and respectful retry logic in bot code |
| opencode-serve availability dependency | `After = opencode-serve.service` in systemd unit ordering |

## Appendix

### Search Queries Used
- nixpkgs package validation: `nextcord` (3.1.1), `discordpy` (&check;), `aiohttp` (3.13.4), `anyio` (4.13.0), `websockets` (16.0), `sops` (3.12.2), `age` (1.3.1)
- Web research: nextcord docs (intents, interactions, commands), discord.py docs, sops-nix README, NixOS Wiki Python page, GitHub releases for both libraries

### References
- [nextcord Documentation](https://docs.nextcord.dev/en/stable/)
- [discord.py Documentation](https://discordpy.readthedocs.io/en/stable/)
- [sops-nix GitHub](https://github.com/Mic92/sops-nix)
- [NixOS Wiki: Python](https://wiki.nixos.org/wiki/Python)
- [Discord Developer Platform](https://discord.com/developers/docs/intro)
- [nextcord Releases](https://github.com/nextcord/nextcord/releases) - v3.1.1 (Aug 2025, latest)
- Existing codebase: `flake.nix`, `home.nix`, `configuration.nix`

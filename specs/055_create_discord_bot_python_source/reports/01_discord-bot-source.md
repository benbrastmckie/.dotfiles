# Research Report: Discord Bot Python Source Code

**Task**: 55 - create_discord_bot_python_source
**Started**: 2026-05-08T12:00:00Z
**Completed**: 2026-05-08T13:30:00Z
**Effort**: ~1.5 hours research
**Dependencies**: Task 53 (NixOS prerequisites - completed), nvim task 547 (Neovim integration - completed)
**Sources/Inputs**:
- Codebase: `/home/benjamin/.dotfiles/configuration.nix` (systemd service definitions, discordBotPython env)
- Codebase: `/home/benjamin/.dotfiles/docs/discord-bot.md` (architecture documentation)
- Codebase: `~/.config/nvim/lua/neotex/plugins/ai/opencode/discord-link.lua` (POST /link client)
- Codebase: `~/.config/nvim/lua/neotex/plugins/ai/opencode/discord-session-picker.lua` (GET /sessions, POST /kill client)
- Codebase: `specs/053_nixos_discord_bot_prerequisites/reports/01_nixos-discord-bot-prerequisites.md`
- Codebase: `specs/053_nixos_discord_bot_prerequisites/reports/02_python-discord-bot-best-practices.md`
- Codebase: `~/.config/nvim/specs/547_research_mobile_agent_management/plans/01_discord-bot-neovim-setup.md`
- Codebase: `~/.config/nvim/specs/547_research_mobile_agent_management/plans/02_discord-bot-revised.md`
- Platform: `opencode serve --help`, `opencode session list --format json`, `opencode run --help`
- External: https://opencode.ai/docs/server/ (OpenCode Server HTTP API)
- External: https://docs.nextcord.dev/en/stable/interactions.html (Nextcord slash commands)
- External: https://deepwiki.com/sst/opencode/2.2-message-and-prompt-system (OpenCode message parts)
**Artifacts**:
  - specs/055_create_discord_bot_python_source/reports/01_discord-bot-source.md
**Standards**: status-markers.md, artifact-management.md, tasks.md, report.md

## Executive Summary

- **Systemd contract fully defined**: The bot is launched as `python -m opencode_discord_bot.src.bot` with `PYTHONPATH=/home/benjamin/.dotfiles/opencode-discord-bot` and 6 environment variables. Credentials (`DISCORD_BOT_TOKEN`, `OPENCODE_SERVER_PASSWORD`) are file paths under `/run/credentials/discord-bot.service/`, not literal values.
- **HTTP API contract locked by Neovim client**: The existing `discord-link.lua` and `discord-session-picker.lua` define exact request/response contracts for `POST /link`, `GET /sessions`, `POST /kill`, and `GET /health`. The bot must serve these on `http://localhost:8080` with `Authorization: Bearer <LINK_API_TOKEN>` auth.
- **OpenCode serve exposes a full REST API**: The bot should communicate with OpenCode via its HTTP API (not CLI subprocesses), using basic auth (`opencode`/password) and SSE for streaming. Key endpoints: `GET /session` (list sessions), `POST /session/:id/message` (send message), `GET /event` (SSE stream), `POST /session/:id/abort` (kill).
- **Nextcord 3.1.1 patterns confirmed**: Slash commands use `@bot.slash_command()` decorator; cogs use `commands.Cog` subclass; thread creation via `channel.create_thread()`; `MESSAGE_CONTENT` intent required for reading thread messages. The bot's `setup_hook` is the correct place to start the aiohttp web server.
- **Project structure is predetermined**: Module path `opencode_discord_bot.src.bot` requires `opencode-discord-bot/opencode_discord_bot/src/bot.py` with proper `__init__.py` files. The `PYTHONPATH` makes `opencode_discord_bot` importable as a top-level package.
- **Two communication channels**: (1) Discord gateway (Nextcord websocket) for slash commands and thread messages, (2) Local aiohttp HTTP server on port 8080 for Neovim integration.

## Context & Scope

This research covers everything needed to implement the Discord bot Python source code at `~/.dotfiles/opencode-discord-bot/`. The bot bridges Discord to a headless OpenCode agent server, enabling mobile agent management via Discord threads.

### Constraints

- Python environment is fixed: `python312.withPackages [nextcord, aiohttp, anyio]` (no pip install)
- Module entry point is fixed: `python -m opencode_discord_bot.src.bot`
- Working directory is fixed: `/home/benjamin/.dotfiles`
- Credentials are systemd LoadCredential file paths, not literal env var values
- The Neovim client code already exists and defines the API contract (cannot be changed)
- Single-user bot (whitelist-based authorization)

## Findings

### 1. Systemd Service Contract (Exact)

From `configuration.nix` lines 892-921:

```nix
ExecStart = "${discordBotPython}/bin/python -m opencode_discord_bot.src.bot";
```

**Environment variables set by systemd**:

| Variable | Value | Notes |
|----------|-------|-------|
| `DISCORD_BOT_TOKEN` | `%d/discord_bot_token` | Expands to `/run/credentials/discord-bot.service/discord_bot_token` - a FILE PATH |
| `OPENCODE_SERVER_PASSWORD` | `%d/opencode_server_password` | Expands to `/run/credentials/discord-bot.service/opencode_server_password` - a FILE PATH |
| `OPENCODE_SERVER_URL` | `http://127.0.0.1` | No port specified (discovery needed) |
| `WHITELISTED_USER_IDS` | `` (empty) | Comma-separated Discord user IDs when set |
| `LINK_API_TOKEN` | `` (empty) | Shared secret for Neovim HTTP API auth |
| `LOG_LEVEL` | `info` | Python logging level |
| `PYTHONPATH` | `/home/benjamin/.dotfiles/opencode-discord-bot` | Makes `opencode_discord_bot` importable |

**Critical: Credential reading pattern**:
The `DISCORD_BOT_TOKEN` and `OPENCODE_SERVER_PASSWORD` env vars contain FILE PATHS, not the actual secrets. The bot must read the file contents at startup:

```python
import os

def read_credential(env_var: str) -> str:
    """Read a credential from a systemd LoadCredential file path or literal value."""
    value = os.environ.get(env_var, "")
    if not value:
        raise RuntimeError(f"{env_var} not set")
    # If the value is a file path, read the file contents
    if os.path.isfile(value):
        with open(value) as f:
            return f.read().strip()
    # Otherwise treat as literal value (for development)
    return value
```

### 2. HTTP API Contract (Defined by Neovim Client)

The Neovim client code (`discord-link.lua` and `discord-session-picker.lua`) defines the exact HTTP API the bot must serve. Both files use:

- **Base URL**: `http://localhost:8080` (from `DISCORD_BOT_URL` env var, default)
- **Auth**: `Authorization: Bearer <token>` header (from `DISCORD_BOT_LINK_TOKEN` env var)
- **Content-Type**: `application/json`
- **Timeout**: 5s connect, 10s max

#### POST /link

**Request**:
```json
{
  "session_id": "ses_abc123...",
  "session_name": "project-name"
}
```

**Success Response** (200):
```json
{
  "thread_url": "https://discord.com/channels/guild_id/thread_id"
}
```

**Already Linked Response** (409):
```json
{
  "thread_url": "https://discord.com/channels/guild_id/thread_id"
}
```

**Auth Failure**: 401

#### GET /sessions

**Request**: No body.

**Response** (200):
```json
{
  "sessions": [
    {
      "session_id": "ses_abc123...",
      "session_name": "project-name",
      "name": "project-name",
      "id": "ses_abc123...",
      "status": "active",
      "linked_at": "2026-05-08T12:00:00Z",
      "thread_url": "https://discord.com/channels/...",
      "thread_channel": "#general",
      "working_directory": "/home/benjamin/.dotfiles",
      "cwd": "/home/benjamin/.dotfiles"
    }
  ]
}
```

The Neovim picker accesses: `session.session_name`, `session.name`, `session.session_id`, `session.id`, `session.status`, `session.linked_at`, `session.thread_url`, `session.thread_channel`, `session.working_directory`, `session.cwd`. Fields should be redundantly provided (both `session_id` and `id`, both `session_name` and `name`, both `working_directory` and `cwd`).

#### POST /kill

**Request**:
```json
{
  "session_id": "ses_abc123..."
}
```

**Success Response** (200): Any JSON (client ignores body on success).

**Auth Failure**: 401

#### GET /health

Not explicitly called by the Neovim code but referenced in the architecture docs. Should return:
```json
{
  "healthy": true,
  "version": "1.0.0",
  "uptime": 3600,
  "discord_connected": true,
  "opencode_connected": true,
  "linked_sessions": 3
}
```

### 3. OpenCode Server API (for Bot-to-Server Communication)

The OpenCode `serve` command exposes a comprehensive REST API. The bot should use this HTTP API directly (via aiohttp client) rather than spawning CLI subprocesses.

**Authentication**: HTTP Basic Auth with username `opencode` and password from `OPENCODE_SERVER_PASSWORD`.

**Key endpoints the bot needs**:

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/global/health` | Health check (returns `{healthy, version}`) |
| `GET` | `/session` | List all sessions (returns array of Session objects) |
| `POST` | `/session` | Create new session (body: `{title?}`) |
| `GET` | `/session/:id` | Get session details |
| `DELETE` | `/session/:id` | Delete session |
| `POST` | `/session/:id/abort` | Abort running session |
| `GET` | `/session/:id/message` | Get messages (query: `limit?`) |
| `POST` | `/session/:id/message` | Send message and wait for response |
| `POST` | `/session/:id/prompt_async` | Send message async (returns 204, results via SSE) |
| `GET` | `/event` | SSE event stream (all server events) |

**Session object fields** (from `opencode session list --format json`):
```json
{
  "id": "ses_1fa434227ffeUj0tdhkXTzFGTc",
  "title": "Implement command specification",
  "updated": 1778257453651,
  "created": 1778212715992,
  "projectId": "eb72f4a770fffe44961bf73f14a6455c12e750e0",
  "directory": "/home/benjamin/.dotfiles"
}
```

**Message send format** (`POST /session/:id/message`):
```json
{
  "parts": [{"type": "text", "text": "user message here"}]
}
```

**Port discovery**: `OPENCODE_SERVER_URL` is set to `http://127.0.0.1` without a port. The bot needs to either:
1. Use `opencode session list --format json` CLI to discover sessions (they include the project directory)
2. Try known ports or rely on the server being started with `--port` flag
3. Use the OpenCode SSE event stream for real-time session updates

**Recommended approach**: The bot should use `opencode session list --format json` at startup to discover the server port (by checking which port the sessions are on), or the systemd service should be updated to pass a fixed port. For initial implementation, use a configurable `OPENCODE_SERVER_PORT` env var (default 0 = auto-discovery via CLI).

### 4. SSE Event Stream

The OpenCode server emits Server-Sent Events at `GET /event`:
- First event: `server.connected`
- Heartbeat every 30 seconds
- Message events: `message.created`, `message.part.updated`, `message.completed`

The bot should connect to this SSE stream to receive real-time updates about session activity, which it can then relay to Discord threads.

**Message part types**: `TextPart`, `ReasoningPart`, `FilePart`, `ToolPart`, `SubtaskPart`, `CompactionPart`, `StepStartPart`, `StepFinishPart`.

For Discord relay, the bot primarily cares about `TextPart` content from assistant messages.

### 5. Project Structure (Module Path Analysis)

The systemd service runs: `python -m opencode_discord_bot.src.bot`
With `PYTHONPATH=/home/benjamin/.dotfiles/opencode-discord-bot`

This means the directory layout must be:

```
opencode-discord-bot/           # PYTHONPATH root
  opencode_discord_bot/         # Top-level package
    __init__.py
    src/                        # Source package
      __init__.py
      bot.py                    # Entry point (__main__ equivalent)
      config.py                 # Configuration/credential loading
      logging_config.py         # Structured JSON logging
      auth.py                   # Discord user whitelist + HTTP bearer auth
      relay.py                  # Message relay: Discord thread <-> OpenCode session
      api.py                    # aiohttp HTTP server (POST /link, GET /sessions, etc.)
      store.py                  # Session-to-thread mapping (JSON-backed)
      opencode_client.py        # OpenCode server HTTP API client
      commands/                 # Nextcord cog package
        __init__.py
        session_cog.py          # /rc session join/list/leave
        task_cog.py             # /rc task status/create/research/plan/implement
        system_cog.py           # /rc status, /rc refresh
```

**Import chain**: `python -m opencode_discord_bot.src.bot` finds `opencode-discord-bot/opencode_discord_bot/src/bot.py` and executes it as `__main__`.

### 6. Nextcord Patterns (Verified)

#### Bot initialization with MESSAGE_CONTENT intent
```python
import nextcord
from nextcord.ext import commands

intents = nextcord.Intents.default()
intents.message_content = True  # Required to read thread messages for relay

bot = commands.Bot(intents=intents)
```

#### Slash command group in a cog (/rc subcommands)
```python
class SessionCog(commands.Cog):
    def __init__(self, bot):
        self.bot = bot

    @nextcord.slash_command(name="rc", description="Remote code management")
    async def rc(self, interaction: nextcord.Interaction):
        pass  # Parent command, never directly invoked

    @rc.subcommand(name="session", description="Session management")
    async def session(self, interaction: nextcord.Interaction):
        pass  # Sub-group

    @session.subcommand(name="join", description="Join an OpenCode session")
    async def session_join(self, interaction: nextcord.Interaction, session_id: str):
        await interaction.response.defer()
        # ... create thread, link session
        await interaction.followup.send(f"Session linked: {thread.jump_url}")
```

#### Thread creation
```python
# Create a public thread in a text channel
channel = bot.get_channel(CHANNEL_ID)
thread = await channel.create_thread(
    name=f"Session: {session_name}",
    type=nextcord.ChannelType.public_thread,
    auto_archive_duration=10080,  # 7 days
)
await thread.send(f"Linked to OpenCode session `{session_id}`")
```

#### Running aiohttp alongside the bot (in setup_hook)
```python
from aiohttp import web

class DiscordBot(commands.Bot):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.http_app = web.Application()
        self.http_runner = None

    async def setup_hook(self):
        # Start HTTP server in the same event loop
        self.http_app.router.add_post("/link", self.handle_link)
        self.http_app.router.add_get("/sessions", self.handle_sessions)
        self.http_app.router.add_post("/kill", self.handle_kill)
        self.http_app.router.add_get("/health", self.handle_health)

        self.http_runner = web.AppRunner(self.http_app)
        await self.http_runner.setup()
        site = web.TCPSite(self.http_runner, "127.0.0.1", 8080)
        await site.start()

    async def close(self):
        if self.http_runner:
            await self.http_runner.cleanup()
        await super().close()
```

This pattern uses `web.AppRunner` and `web.TCPSite` to manually manage the aiohttp server lifecycle within the bot's event loop, avoiding the blocking `web.run_app()`.

### 7. Credential Reading (systemd LoadCredential)

The env vars `DISCORD_BOT_TOKEN` and `OPENCODE_SERVER_PASSWORD` contain **file paths** (e.g., `/run/credentials/discord-bot.service/discord_bot_token`), not the actual secret values. The `%d` systemd specifier expands to the credentials directory at service start.

**Reading pattern**:
```python
def read_credential(env_var: str) -> str:
    """Read credential from file path or use as literal value."""
    raw = os.environ.get(env_var, "")
    if not raw:
        raise RuntimeError(f"Environment variable {env_var} is not set")
    if os.path.isfile(raw):
        with open(raw, "r") as f:
            return f.read().strip()
    return raw  # Fallback: treat as literal (dev mode)
```

The fallback to literal values enables local development without systemd.

### 8. Message Relay Architecture

The core relay flow:

```
1. User sends message in Discord thread
2. Bot's on_message handler fires (MESSAGE_CONTENT intent)
3. Bot looks up session_id from thread_id in store
4. Bot sends message to OpenCode via POST /session/:id/message
   - Auth: Basic auth (opencode / password)
   - Body: {"parts": [{"type": "text", "text": "user message"}]}
5. OpenCode processes and returns response
6. Bot extracts text parts from response
7. Bot sends response text to Discord thread
```

For long-running operations, use `POST /session/:id/prompt_async` (returns 204 immediately) and listen on the SSE stream for completion events. However, for initial implementation, the synchronous `POST /session/:id/message` is simpler and sufficient.

**Discord message length limit**: 2000 characters. Responses longer than 2000 chars must be split into multiple messages.

### 9. Session Store Design

JSON-backed persistent store at a location relative to the bot's working directory:

```python
# Store location: ~/.dotfiles/opencode-discord-bot/data/sessions.json
STORE_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
    "data", "sessions.json"
)
```

**Schema**:
```json
{
  "sessions": {
    "ses_abc123": {
      "session_id": "ses_abc123",
      "session_name": "project-name",
      "thread_id": "1234567890",
      "channel_id": "9876543210",
      "thread_url": "https://discord.com/channels/...",
      "linked_at": "2026-05-08T12:00:00Z",
      "working_directory": "/home/benjamin/.dotfiles",
      "status": "active"
    }
  }
}
```

Operations: `link()`, `unlink()`, `get_by_session()`, `get_by_thread()`, `list_all()`, `update_status()`.

Atomic writes: write to temp file, then `os.replace()` to target path.

### 10. Port Discovery for OpenCode Server

The `OPENCODE_SERVER_URL` is set to `http://127.0.0.1` (no port). OpenCode defaults to `--port 0` (random port). There are several approaches:

1. **CLI discovery**: Run `opencode session list --format json` to find active sessions, then determine which port the server is on. This is indirect since session list does not include port.

2. **Fixed port**: Update `configuration.nix` to add `--port 4096` to the `opencode serve` command. This is the simplest and most reliable approach.

3. **Health probe**: Try common ports (4096, 8080, 3000) with `GET /global/health`.

**Recommendation**: For the initial implementation, the bot should accept `OPENCODE_SERVER_URL` as the full URL including port (e.g., `http://127.0.0.1:4096`). The systemd service should be updated to include the port, or a secondary env var `OPENCODE_SERVER_PORT` should be added. The current `OPENCODE_SERVER_URL=http://127.0.0.1` value in configuration.nix needs a port appended.

## Decisions

1. **Use OpenCode HTTP API over CLI**: The bot communicates with OpenCode via its REST API (aiohttp client), not by spawning `opencode run` CLI subprocesses. The HTTP API is richer, async-native, and avoids subprocess management complexity.

2. **aiohttp server in setup_hook**: The bot's HTTP API (for Neovim) runs in the same asyncio event loop as the Discord gateway, started in `setup_hook()` using `web.AppRunner`/`web.TCPSite`.

3. **HTTP port 8080**: Matches the Neovim client's default `DISCORD_BOT_URL = http://localhost:8080`.

4. **Credential file reading with literal fallback**: Supports both systemd LoadCredential paths (production) and literal env var values (development).

5. **JSON-backed session store**: Simple file-based persistence with atomic writes. No external database dependency.

6. **Redundant API response fields**: The session listing endpoint provides both `session_id`/`id` and `session_name`/`name` and `working_directory`/`cwd` to satisfy the Neovim client's flexible field access.

7. **Synchronous message relay initially**: Use `POST /session/:id/message` (blocking) for the first implementation. SSE-based async relay can be added later.

8. **MESSAGE_CONTENT intent enabled**: Required to read user messages in threads for relay functionality. The bot is a private, single-guild bot so this does not require Discord verification.

## Recommendations

### Implementation Priority

1. **Phase 1 - Scaffolding**: Project structure, config loading, credential reading, logging, minimal bot that connects to Discord
2. **Phase 2 - HTTP API**: aiohttp server with `POST /link`, `GET /sessions`, `POST /kill`, `GET /health` endpoints and bearer token auth (this unblocks Neovim integration testing)
3. **Phase 3 - Session Store**: JSON-backed session-to-thread mapping with atomic writes
4. **Phase 4 - Thread Management**: Creating Discord threads on `POST /link`, archiving on kill
5. **Phase 5 - Message Relay**: `on_message` handler forwarding thread messages to OpenCode and relaying responses
6. **Phase 6 - Slash Commands**: `/rc session`, `/rc task`, `/rc status` cog implementations
7. **Phase 7 - Polish**: Rate limiting, error handling, health check details, graceful shutdown

### Configuration.nix Update Needed

The `OPENCODE_SERVER_URL` should include a port. Either:
- Update `opencode-serve` to use `--port 4096` and set `OPENCODE_SERVER_URL=http://127.0.0.1:4096`
- Or add `OPENCODE_SERVER_PORT` as a separate env var

### Channel Configuration

The bot needs to know which Discord channel to create threads in. Add a `DISCORD_CHANNEL_ID` environment variable (or hard-code the channel ID in config).

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| OpenCode server port unknown (random) | High | High | Pin port to 4096 in configuration.nix; document as a prerequisite |
| Discord rate limits on thread creation | Low | Medium | Cache thread lookups; reuse existing threads for same session |
| Bot and OpenCode server timing (bot starts before server) | Medium | Low | `Requires` + `After` in systemd; retry loop with backoff on startup |
| aiohttp server port 8080 conflict | Low | Low | Make port configurable via env var; 8080 is typically free on NixOS desktop |
| Long OpenCode responses exceed Discord 2000 char limit | High | Medium | Split responses into multiple messages at newline boundaries |
| Session store corruption on crash | Low | Medium | Atomic writes via temp file + os.replace(); store is reconstructable |

## Appendix

### A. Complete Environment Variable Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DISCORD_BOT_TOKEN` | Yes | - | File path or literal Discord bot token |
| `OPENCODE_SERVER_PASSWORD` | Yes | - | File path or literal OpenCode server password |
| `OPENCODE_SERVER_URL` | Yes | `http://127.0.0.1` | OpenCode server base URL (needs port) |
| `WHITELISTED_USER_IDS` | No | `` | Comma-separated Discord user IDs |
| `LINK_API_TOKEN` | No | `` | Bearer token for HTTP API auth |
| `LOG_LEVEL` | No | `info` | Python logging level |
| `DISCORD_CHANNEL_ID` | Needed | - | Discord channel for thread creation (not in systemd yet) |
| `BOT_HTTP_PORT` | No | `8080` | Port for the local HTTP API |

### B. Neovim Client Source Locations

- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/opencode/discord-link.lua` - POST /link client
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/opencode/discord-session-picker.lua` - GET /sessions, POST /kill client

### C. OpenCode Server API Reference

Full API documentation: https://opencode.ai/docs/server/
OpenAPI spec available at: `http://localhost:<port>/doc`

### D. Prior Research References

- `specs/053_nixos_discord_bot_prerequisites/reports/01_nixos-discord-bot-prerequisites.md`
- `specs/053_nixos_discord_bot_prerequisites/reports/02_python-discord-bot-best-practices.md`
- `~/.config/nvim/specs/547_research_mobile_agent_management/reports/01_mobile-agent-management-research.md`
- `~/.config/nvim/specs/547_research_mobile_agent_management/plans/01_discord-bot-neovim-setup.md` (original plan)
- `~/.config/nvim/specs/547_research_mobile_agent_management/plans/02_discord-bot-revised.md` (revised plan)

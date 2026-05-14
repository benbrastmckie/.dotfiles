# Implementation Plan: Discord Bot Python Source

- **Task**: 55 - create_discord_bot_python_source
- **Status**: [COMPLETED]
- **Effort**: 7 hours
- **Dependencies**: Task 53 (NixOS prerequisites - completed)
- **Research Inputs**: specs/055_create_discord_bot_python_source/reports/01_discord-bot-source.md
- **Artifacts**: plans/01_discord-bot-source.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: python
- **Lean Intent**: false

## Overview

Create the Discord bot Python source code at `~/.dotfiles/opencode-discord-bot/`. The bot is a Nextcord application that bridges Discord to a headless OpenCode agent server, enabling mobile agent management via Discord threads. It must serve an HTTP API on port 8080 for Neovim integration (POST /link, GET /sessions, POST /kill, GET /health), relay messages between Discord threads and OpenCode sessions via the OpenCode REST API, and read credentials from systemd LoadCredential file paths. The bot runs as `python -m opencode_discord_bot.src.bot` with dependencies provided by the `discordBotPython` Nix derivation (nextcord, aiohttp, anyio). Definition of done: bot connects to Discord, serves all four HTTP endpoints matching the existing Neovim client contract, and can relay messages between a Discord thread and an OpenCode session.

### Research Integration

Research report `reports/01_discord-bot-source.md` provided:
- Exact systemd contract: `ExecStart`, environment variables, `LoadCredential` paths
- HTTP API contract locked by existing Neovim client code (`discord-link.lua`, `discord-session-picker.lua`)
- OpenCode serve REST API endpoints and authentication (Basic auth, SSE events)
- Nextcord patterns: slash commands via cogs, thread creation, `setup_hook` for aiohttp cohosting
- Project directory layout: `opencode_discord_bot/src/bot.py` with `PYTHONPATH` root
- Credential reading pattern: file-path env vars with literal fallback for dev mode
- Session store schema: JSON-backed with atomic writes

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Create the complete Python package structure importable as `opencode_discord_bot.src.bot`
- Implement configuration module that reads systemd LoadCredential file paths with dev-mode literal fallback
- Implement Nextcord bot with MESSAGE_CONTENT intent that connects to Discord
- Implement aiohttp HTTP API server (POST /link, GET /sessions, POST /kill, GET /health) matching the Neovim client contract exactly
- Implement JSON-backed session store with atomic writes mapping sessions to Discord threads
- Implement message relay between Discord threads and OpenCode sessions via the OpenCode REST API
- Implement structured logging with configurable log level

**Non-Goals**:
- Slash command cogs (/rc session, /rc task, /rc status) -- deferred to a follow-up task
- SSE-based async message streaming from OpenCode (use synchronous POST /session/:id/message initially)
- Rate limiting or advanced error recovery (polish phase deferred)
- Modifying configuration.nix (task 53 already completed the NixOS setup)
- Fixing the OPENCODE_SERVER_URL port issue (document as a known prerequisite; the env var should include the port)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| OpenCode server port unknown (OPENCODE_SERVER_URL lacks port) | H | H | Bot treats OPENCODE_SERVER_URL as full URL including port; document that systemd env must be updated to include port before deployment |
| Discord 2000-char message limit truncates long OpenCode responses | M | H | Split responses at newline boundaries into multiple messages |
| Bot starts before OpenCode server is ready | L | M | systemd `Requires`+`After` ordering already set; add retry loop with backoff in OpenCode client health check |
| aiohttp server port 8080 conflicts with another service | L | L | Make port configurable via BOT_HTTP_PORT env var (default 8080) |
| Thread-to-session mapping lost on crash | M | L | JSON store with atomic writes via temp file + os.replace(); store is reconstructable from Discord thread history |
| Nextcord API changes between versions | L | L | Use stable nextcord 3.x patterns confirmed in research; no version pinning needed since Nix controls the version |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

REDACTED_DISCORD_TOKEN

---

### Phase 1: Project Scaffolding and Configuration [COMPLETED]

**Goal**: Create the Python package directory structure and the configuration/credential loading module so all subsequent phases have a working import base.

**Tasks**:
- [ ] Create directory structure: `opencode-discord-bot/opencode_discord_bot/__init__.py`, `opencode-discord-bot/opencode_discord_bot/src/__init__.py`
- [ ] Create `opencode_discord_bot/src/config.py` with:
  - `read_credential(env_var)` function: reads file path from env var, returns file contents; falls back to literal value for dev mode
  - `Config` dataclass or class loading all env vars: `DISCORD_BOT_TOKEN`, `OPENCODE_SERVER_PASSWORD`, `OPENCODE_SERVER_URL`, `WHITELISTED_USER_IDS`, `LINK_API_TOKEN`, `LOG_LEVEL`, `DISCORD_CHANNEL_ID`, `BOT_HTTP_PORT`
  - Validation: raise on missing required vars (DISCORD_BOT_TOKEN, OPENCODE_SERVER_PASSWORD, OPENCODE_SERVER_URL)
- [ ] Create `opencode_discord_bot/src/logging_config.py` with:
  - `setup_logging(level)` function configuring Python logging with structured JSON-like format
  - Module-level logger factory
- [ ] Create minimal `opencode_discord_bot/src/bot.py` entry point that:
  - Loads config
  - Sets up logging
  - Creates a Nextcord `commands.Bot` with `MESSAGE_CONTENT` intent
  - Logs "Bot starting" and calls `bot.run(token)`
- [ ] Verify: `python -c "from opencode_discord_bot.src import config; print('OK')"` succeeds from the `opencode-discord-bot/` directory

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `opencode-discord-bot/opencode_discord_bot/__init__.py` - create (empty package init)
- `opencode-discord-bot/opencode_discord_bot/src/__init__.py` - create (empty package init)
- `opencode-discord-bot/opencode_discord_bot/src/config.py` - create (configuration loading)
- `opencode-discord-bot/opencode_discord_bot/src/logging_config.py` - create (logging setup)
- `opencode-discord-bot/opencode_discord_bot/src/bot.py` - create (minimal entry point)

**Verification**:
- Package imports work: `PYTHONPATH=opencode-discord-bot python -c "from opencode_discord_bot.src.config import Config"`
- Config raises on missing required env vars
- Logging produces structured output

---

### Phase 2: Session Store and OpenCode Client [COMPLETED]

**Goal**: Implement the JSON-backed session store and the async HTTP client for communicating with the OpenCode server, providing the data and communication layers needed by the HTTP API and message relay.

**Tasks**:
- [ ] Create `opencode_discord_bot/src/store.py` with:
  - `SessionStore` class with configurable file path (default: `data/sessions.json` relative to project root)
  - Session data model: `session_id`, `session_name`, `thread_id`, `channel_id`, `thread_url`, `linked_at`, `working_directory`, `status`
  - Methods: `link(session_id, session_name, thread_id, channel_id, thread_url, working_directory)`, `unlink(session_id)`, `get_by_session(session_id)`, `get_by_thread(thread_id)`, `list_all()`, `update_status(session_id, status)`
  - Atomic writes: write to temp file, then `os.replace()` to target path
  - Auto-create data directory on first write
  - Thread-safe with `asyncio.Lock`
- [ ] Create `opencode_discord_bot/src/opencode_client.py` with:
  - `OpenCodeClient` class wrapping `aiohttp.ClientSession` with Basic auth (`opencode`/password)
  - Methods: `health()` -> bool, `list_sessions()` -> list, `get_session(id)` -> dict, `send_message(session_id, text)` -> dict, `abort_session(session_id)` -> bool, `delete_session(session_id)` -> bool
  - Base URL from config's `OPENCODE_SERVER_URL`
  - Retry logic for `health()` with exponential backoff (3 attempts)
  - Message send format: `{"parts": [{"type": "text", "text": "..."}]}`
  - Proper `close()` method and async context manager support
- [ ] Create `opencode-discord-bot/data/` directory with `.gitkeep`

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `opencode-discord-bot/opencode_discord_bot/src/store.py` - create (session store)
- `opencode-discord-bot/opencode_discord_bot/src/opencode_client.py` - create (OpenCode API client)
- `opencode-discord-bot/data/.gitkeep` - create (data directory placeholder)

**Verification**:
- SessionStore can link, unlink, list, and look up sessions
- SessionStore writes are atomic (temp file + replace)
- OpenCodeClient constructs correct URLs and auth headers
- OpenCodeClient.send_message formats parts correctly

---

### Phase 3: HTTP API Server (Neovim Integration) [COMPLETED]

**Goal**: Implement the aiohttp HTTP API server that serves POST /link, GET /sessions, POST /kill, and GET /health -- matching the exact contract defined by the existing Neovim client code.

**Tasks**:
- [ ] Create `opencode_discord_bot/src/auth.py` with:
  - `check_bearer_token(request, expected_token)` middleware/helper that validates `Authorization: Bearer <token>` header
  - Return 401 JSON response on auth failure
  - Skip auth check if `LINK_API_TOKEN` is empty (dev mode)
- [ ] Create `opencode_discord_bot/src/api.py` with:
  - `setup_api(app, bot_instance)` function that registers routes on the aiohttp app
  - `POST /link` handler:
    - Validate request body has `session_id` and `session_name`
    - Check if session already linked (return 409 with existing `thread_url`)
    - Create Discord thread in configured channel via bot instance
    - Store link in session store
    - Return 200 with `{"thread_url": "https://discord.com/channels/..."}`
  - `GET /sessions` handler:
    - List all linked sessions from store
    - Enrich with redundant fields: both `session_id`/`id`, `session_name`/`name`, `working_directory`/`cwd`
    - Return 200 with `{"sessions": [...]}`
  - `POST /kill` handler:
    - Validate request body has `session_id`
    - Call `opencode_client.abort_session(session_id)`
    - Unlink from store
    - Return 200 with `{"status": "killed"}`
  - `GET /health` handler:
    - Check Discord gateway connection (`bot.is_ready()`)
    - Check OpenCode server health (`opencode_client.health()`)
    - Return 200 with health status object
  - All endpoints wrapped with bearer token auth middleware

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `opencode-discord-bot/opencode_discord_bot/src/auth.py` - create (authentication helpers)
- `opencode-discord-bot/opencode_discord_bot/src/api.py` - create (HTTP API server routes)

**Verification**:
- Auth middleware rejects requests without valid Bearer token (returns 401)
- Auth middleware passes requests when LINK_API_TOKEN is empty
- POST /link returns 200 with thread_url on success, 409 on duplicate
- GET /sessions returns all sessions with redundant field names
- POST /kill aborts session and returns 200
- GET /health returns correct connection status

---

### Phase 4: Bot Integration and Thread Management [COMPLETED]

**Goal**: Wire the HTTP API server and session store into the Nextcord bot lifecycle, implement thread creation, and add the on_message handler for relaying Discord messages to OpenCode.

**Tasks**:
- [ ] Update `opencode_discord_bot/src/bot.py` to use custom `DiscordBot(commands.Bot)` subclass:
  - In `__init__`: initialize `config`, `session_store`, `opencode_client`, and `aiohttp.web.Application`
  - In `setup_hook`: register API routes via `setup_api()`, start aiohttp server on `127.0.0.1:BOT_HTTP_PORT` using `web.AppRunner`/`web.TCPSite`
  - In `on_ready` event: log bot username, guild count, and HTTP API port
  - In `close()` override: clean up aiohttp runner and opencode client session
- [ ] Create `opencode_discord_bot/src/relay.py` with:
  - `create_session_thread(bot, channel_id, session_id, session_name)` function:
    - Get channel by ID
    - Create public thread with name `"Session: {session_name}"` and 7-day auto-archive
    - Send initial message: `"Linked to OpenCode session \`{session_id}\`"`
    - Return thread object and thread URL
  - `relay_to_opencode(opencode_client, session_id, message_text)` function:
    - Send message via opencode_client.send_message()
    - Extract text parts from response
    - Return response text
  - `split_discord_message(text, limit=2000)` function:
    - Split long text at newline boundaries respecting the 2000-char limit
    - Return list of message chunks
  - `relay_response_to_thread(thread, response_text)` function:
    - Split response and send each chunk as a separate message
- [ ] Add `on_message` handler to `DiscordBot`:
  - Ignore bot's own messages
  - Check if message is in a thread that maps to a linked session (via store.get_by_thread)
  - Check if message author is whitelisted (if whitelist is configured)
  - Call relay_to_opencode with message content
  - Call relay_response_to_thread with the response
  - Handle errors gracefully (send error message to thread, log exception)
- [ ] Wire `POST /link` in api.py to call `create_session_thread()` from relay.py

**Timing**: 1.5 hours

**Depends on**: 2, 3

**Files to modify**:
- `opencode-discord-bot/opencode_discord_bot/src/bot.py` - update (full bot class with lifecycle management)
- `opencode-discord-bot/opencode_discord_bot/src/relay.py` - create (thread creation and message relay)
- `opencode-discord-bot/opencode_discord_bot/src/api.py` - update (wire POST /link to thread creation)

**Verification**:
- Bot connects to Discord and logs ready status
- aiohttp server starts on configured port during setup_hook
- Thread creation works in configured channel
- on_message handler relays messages to OpenCode and posts responses
- Long responses are split correctly at 2000-char boundaries
- Bot ignores its own messages
- Graceful shutdown cleans up aiohttp runner and HTTP sessions

---

### Phase 5: Error Handling, Shutdown, and Smoke Test [COMPLETED]

**Goal**: Add robust error handling, graceful shutdown via signal handlers, and perform an end-to-end smoke test to verify the complete bot works as an integrated system.

**Tasks**:
- [ ] Add signal handling to `bot.py`:
  - Register SIGTERM and SIGINT handlers for graceful shutdown
  - Ensure aiohttp server, opencode client session, and Discord gateway all close cleanly
  - Log shutdown reason
- [ ] Add error handling to `on_message` relay:
  - Catch `aiohttp.ClientError` when OpenCode server is unreachable (send "OpenCode server unavailable" to thread)
  - Catch generic exceptions (log traceback, send generic error to thread)
  - Handle case where session was deleted on OpenCode side but still linked in store
- [ ] Add error handling to API endpoints:
  - Return 500 with JSON error body on unexpected exceptions
  - Return 400 on malformed request bodies
  - Log all errors with request context
- [ ] Add startup health check:
  - On bot ready, attempt OpenCode server health check
  - Log warning if server unreachable (do not crash -- server may start later)
- [ ] Verify module entry point: `python -m opencode_discord_bot.src.bot` invokes correctly from PYTHONPATH root
- [ ] Add `.gitignore` in `opencode-discord-bot/` to exclude `data/sessions.json` and `__pycache__/`
- [ ] Smoke test: manually verify bot starts, connects to Discord, and HTTP endpoints respond with correct format

**Timing**: 1 hour

**Depends on**: 4

**Files to modify**:
- `opencode-discord-bot/opencode_discord_bot/src/bot.py` - update (signal handling, startup health check)
- `opencode-discord-bot/opencode_discord_bot/src/relay.py` - update (error handling in relay functions)
- `opencode-discord-bot/opencode_discord_bot/src/api.py` - update (error handling in endpoints)
- `opencode-discord-bot/.gitignore` - create (exclude data files and pycache)

**Verification**:
- Bot handles SIGTERM gracefully (no orphaned connections)
- Relay errors produce user-friendly messages in Discord thread
- API endpoints return proper error JSON on bad requests
- Bot starts and logs warning if OpenCode server is not yet available
- `python -m opencode_discord_bot.src.bot` runs from correct PYTHONPATH
- All four HTTP endpoints respond with correct status codes and JSON format

## Testing & Validation

- [ ] Package imports: `PYTHONPATH=opencode-discord-bot python -c "from opencode_discord_bot.src.bot import DiscordBot; print('OK')"`
- [ ] Config loading: verify Config raises on missing DISCORD_BOT_TOKEN
- [ ] Credential reading: test `read_credential()` with both file path and literal value
- [ ] Session store: create, link, list, unlink, verify atomic write (temp file exists during write)
- [ ] OpenCode client: verify URL construction, auth headers, message part format
- [ ] HTTP API: curl POST /link, GET /sessions, POST /kill, GET /health with and without auth token
- [ ] Message splitting: verify `split_discord_message()` handles edge cases (empty, exactly 2000, >2000)
- [ ] Entry point: `cd opencode-discord-bot && PYTHONPATH=. python -m opencode_discord_bot.src.bot` starts without import errors
- [ ] Graceful shutdown: send SIGTERM to running bot, verify clean exit

## Artifacts & Outputs

- `opencode-discord-bot/opencode_discord_bot/__init__.py` - package init
- `opencode-discord-bot/opencode_discord_bot/src/__init__.py` - source package init
- `opencode-discord-bot/opencode_discord_bot/src/bot.py` - main entry point with DiscordBot class
- `opencode-discord-bot/opencode_discord_bot/src/config.py` - configuration and credential loading
- `opencode-discord-bot/opencode_discord_bot/src/logging_config.py` - logging setup
- `opencode-discord-bot/opencode_discord_bot/src/auth.py` - authentication helpers
- `opencode-discord-bot/opencode_discord_bot/src/api.py` - HTTP API server routes
- `opencode-discord-bot/opencode_discord_bot/src/store.py` - JSON-backed session store
- `opencode-discord-bot/opencode_discord_bot/src/opencode_client.py` - OpenCode server API client
- `opencode-discord-bot/opencode_discord_bot/src/relay.py` - thread creation and message relay
- `opencode-discord-bot/data/.gitkeep` - data directory placeholder
- `opencode-discord-bot/.gitignore` - git ignore for data files and pycache

## Rollback/Contingency

To revert, delete the `opencode-discord-bot/` directory entirely. No existing files are modified by this task -- all changes are new file creation within the new project directory. The systemd service (`discord-bot.service`) from task 53 will simply fail to start if the source directory is removed, which is the expected behavior documented in the troubleshooting section of `docs/discord-bot.md`.

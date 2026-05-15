# Research Report: Task #56

**Task**: 56 - Bidirectional Discord-OpenCode Relay
**Started**: 2026-05-14T19:40:00Z
**Completed**: 2026-05-14T20:15:00Z
**Effort**: 35 minutes
**Dependencies**: None
**Sources/Inputs**:
- `/home/benjamin/.dotfiles/opencode-discord-bot/opencode_discord_bot/src/bot.py` - Nextcord bot main loop
- `/home/benjamin/.dotfiles/opencode-discord-bot/opencode_discord_bot/src/opencode_client.py` - OpenCode REST client
- `/home/benjamin/.dotfiles/opencode-discord-bot/opencode_discord_bot/src/relay.py` - Discord relay utilities
- `/home/benjamin/.dotfiles/opencode-discord-bot/opencode_discord_bot/src/api.py` - HTTP API routes (POST /link, GET /sessions, etc.)
- `/home/benjamin/.dotfiles/opencode-discord-bot/opencode_discord_bot/src/store.py` - Session store (sessions.json)
- `/home/benjamin/.dotfiles/opencode-discord-bot/opencode_discord_bot/src/config.py` - Bot configuration
- `/home/benjamin/.dotfiles/opencode-discord-bot/data/sessions.json` - Live session state
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/opencode/discord-link.lua` - Neovim link plugin
- `/home/benjamin/.dotfiles/configuration.nix` - NixOS systemd service + discordBotPython env
- `/home/benjamin/.config/nvim/.opencode/node_modules/@opencode-ai/sdk/dist/gen/types.gen.d.ts` - OpenCode API types
- `/home/benjamin/.config/nvim/.opencode/node_modules/@opencode-ai/sdk/dist/gen/sdk.gen.d.ts` - OpenCode SDK methods
- Live server inspection: `curl http://127.0.0.1:{TUI_PORT}/event`, `/session`, `/session/{id}/message`
- WebSearch: aiohttp SSE client implementation patterns (2025/2026)
**Artifacts**:
- `specs/056_implement_bidirectional_discord_opencode_relay/reports/01_discord-opencode-relay.md` (this file)
**Standards**: report-format.md, artifact-management.md, tasks.md

---

## Executive Summary

- The Discord->OpenCode relay is fully implemented and operational; the missing direction is OpenCode TUI->Discord, where assistant responses generated from within the TUI never appear in the linked Discord thread
- Each linked session stores a `server_url` (e.g., `http://127.0.0.1:42285`) pointing to the TUI's embedded HTTP server; this server exposes a live SSE endpoint at `GET /event` with no authentication required
- The SSE event stream emits `message.part.updated` (streaming text deltas), `message.updated` (role=assistant, includes completion metadata), and `session.idle`/`session.status` events; the `session.idle` event is the clean signal that a TUI response is complete
- The implementation approach is a new `TuiSseSubscriber` class that the bot starts when each session is linked and tears down when it is unlinked; it reads the SSE stream with pure aiohttp (no new dependencies needed), filters for assistant message completion, collects the full text from `message.updated` + parts, and posts to the Discord thread via `relay_response_to_thread`
- The primary complexity is deduplication: both the Discord->OpenCode path (user in Discord sends message) and the TUI->Discord path (user in TUI sends message) will be active simultaneously; responses from Discord-sourced prompts must not be re-posted (since `relay_to_opencode` already posts the response)
- The `aiohttp-sse-client` package is available in nixpkgs but is not required; pure aiohttp `response.content` async iteration is sufficient and keeps the dependency footprint unchanged

---

## Context & Scope

**What was researched**: The complete existing Discord bot codebase, OpenCode SSE event API (types, endpoints, data shapes), live server behavior on the running system, and implementation patterns for asyncio SSE consumption in Python.

**Scope**: Implement the reverse relay: when a user types in the OpenCode TUI and receives an assistant response, that exchange (or just the response) should automatically appear in the corresponding linked Discord thread. This affects only the bot process at `/home/benjamin/.dotfiles/opencode-discord-bot/`.

**Constraints**:
- The NixOS `discordBotPython` environment contains only `nextcord`, `aiohttp`, and `anyio`; adding new dependencies requires a `configuration.nix` change and `nixos-rebuild`
- TUI servers use no authentication; the headless server at port 4096 uses HTTP Basic auth
- TUI ports are dynamic and change when the user restarts Neovim; the `/link` endpoint (and `update_server_url`) already handles port rotation
- The bot runs as a single asyncio event loop (nextcord + aiohttp web server sharing one loop)

---

## Findings

### Current Architecture (Discord -> OpenCode Only)

```
Discord message in linked thread
    -> bot.on_message() -> asyncio.create_task(_relay_and_respond())
    -> relay_to_opencode(client, session_id, text)  [runs in ThreadPoolExecutor]
    -> POST /session/{id}/message  [blocks thread, waits for response]
    -> relay_response_to_thread(thread, response_text)
    -> Discord thread receives assistant response
```

What is missing:

```
User types in OpenCode TUI
    -> TUI generates assistant response
    -> SSE event: message.updated (role=assistant)
    [nothing currently consuming this event]
    [Discord thread sees nothing]
```

### OpenCode SSE Event API

**Endpoint**: `GET /event` on the TUI's embedded server (no auth required).
- Response: `Content-Type: text/event-stream`, `Transfer-Encoding: chunked`, `Cache-Control: no-cache`
- Format: standard SSE, each event is `data: {JSON}\n\n`
- First event on connect: `{"type":"server.connected","properties":{}}`

**Event types relevant to assistant responses** (from `types.gen.d.ts`):

| Event type | Properties | Purpose |
|---|---|---|
| `message.part.updated` | `{part: Part, delta?: string}` | Streaming text chunk; `part.type == "text"` for text content; `delta` is the incremental text |
| `message.updated` | `{info: Message}` | Called when message state changes; when `info.role == "assistant"` and `info.time.completed` is set, the response is complete |
| `session.idle` | `{sessionID: string}` | Emitted when session returns to idle state after a response; clean completion signal |
| `session.status` | `{sessionID: string, status: SessionStatus}` | Status transitions; `status.type == "idle"` is equivalent to `session.idle` |

**Key observation**: The `message.updated` event includes `info.id` (messageID) which can be used for deduplication. Text content lives in `message.part.updated` events. The complete text for a finished assistant response is available via `GET /session/{id}/message` (fetches all messages with parts), but for real-time streaming it's better to accumulate `message.part.updated` deltas.

**Verified live behavior**: Connecting to `http://127.0.0.1:{TUI_PORT}/event` with `Accept: text/event-stream` returns a `server.connected` event immediately, then streams subsequent events as they occur. The stream stays open indefinitely (event-driven).

### Session-to-TUI Mapping

The `SessionStore` already tracks `server_url` per session in `data/sessions.json`:

```json
"ses_1d8140184ffe3tZb9Hc5h10Pd5": {
    "server_url": "http://127.0.0.1:42285",
    "session_id": "ses_1d8140184ffe3tZb9Hc5h10Pd5",
    "thread_id": "1504563648327057518",
    ...
}
```

A session without `server_url` (empty string) is linked to the headless `opencode-serve` at port 4096. The headless server requires HTTP Basic auth and is always available via `self.opencode_client`.

**TUI event subscription scope**: Each TUI server hosts all sessions opened in that Neovim instance (same `directory`). The `/event` endpoint emits events for ALL sessions on that TUI, not just one. The event payload includes `sessionID` in its properties for filtering.

### Deduplication Challenge

When the bot relays a Discord message to OpenCode (via `_relay_and_respond`), it calls `POST /session/{id}/message` which triggers the same SSE events that the TUI subscriber would see. Without deduplication, the assistant's response would be posted to Discord twice:
1. Once by `relay_to_opencode` (already implemented, waits for POST to return)
2. Once by the SSE subscriber (new code)

**Solution**: Track in-flight Discord-sourced message IDs. When `relay_to_opencode` is called, record the session_id as "discord-sourced-relay-in-progress". The SSE subscriber skips posting when a relay is in progress for that session. After `relay_to_opencode` completes, clear the flag. A `asyncio.Event` or a set of session IDs is sufficient.

**Alternative solution**: The bot could switch the Discord->OpenCode path to use `POST /session/{id}/prompt_async` (returns 204 immediately) and rely exclusively on the SSE subscriber for all responses (both TUI-typed and Discord-typed). This is architecturally cleaner but is a more invasive refactor.

### SSE Client Implementation (No New Dependencies)

Pure aiohttp can consume the SSE stream:

```python
async with aiohttp.ClientSession() as session:
    async with session.get(
        f"{server_url}/event",
        headers={"Accept": "text/event-stream"},
        timeout=aiohttp.ClientTimeout(total=None, sock_read=None),  # no timeout
    ) as resp:
        buffer = ""
        async for chunk in resp.content:
            buffer += chunk.decode("utf-8", errors="replace")
            while "\n" in buffer:
                line, buffer = buffer.split("\n", 1)
                line = line.strip()
                if line.startswith("data: "):
                    yield json.loads(line[6:])
```

This uses only the existing `aiohttp` dependency. The `aiohttp-sse-client` package in nixpkgs (`p.aiohttp-sse-client`) provides a cleaner API but adds a dependency.

### Connection Management

Each TUI server is ephemeral (dies when the user closes Neovim). The SSE subscriber must:
1. Handle `aiohttp.ClientConnectionError` / `asyncio.TimeoutError` gracefully (log and stop, not crash the bot)
2. Be started when `/link` registers a session with a `server_url`
3. Be stopped when `/kill` unlinks a session
4. Be re-started when `update_server_url` is called (port rotation on re-link)
5. Be started on bot startup for all already-linked sessions in `sessions.json`

**Reconnection**: The TUI server shuts down when Neovim closes. There is no benefit to reconnecting after connection loss (the old TUI is gone). The user will re-link with the new port via `<leader>ar`, which triggers `update_server_url`. So: no automatic reconnect; just log and exit the subscriber task.

### Architecture for Implementation

**New class**: `TuiSseSubscriber` in a new file `opencode_discord_bot/src/sse_subscriber.py`:

```
TuiSseSubscriber(
    server_url: str,
    session_id: str,
    thread: nextcord.Thread,
    in_progress_sessions: set[str],  # shared set of discord-relay-in-progress session IDs
)
```

**Bot changes** (`bot.py`):
- Add `self._sse_subscribers: dict[str, asyncio.Task] = {}` (keyed by session_id)
- Add `self._discord_relay_sessions: set[str] = set()` (dedup guard)
- In `_relay_and_respond()`: add/remove session_id to/from `_discord_relay_sessions` around the relay call
- In `on_ready()`: start SSE subscribers for all sessions with `server_url` in `session_store`
- New method `start_sse_subscriber(session)`: resolve thread by ID, create `TuiSseSubscriber`, wrap in `asyncio.create_task`
- New method `stop_sse_subscriber(session_id)`: cancel and remove the task

**API changes** (`api.py`):
- In `_handle_link()`: after `session_store.link()`, call `bot.start_sse_subscriber(session)`
- In `_handle_kill()`: call `bot.stop_sse_subscriber(session_id)` before `session_store.unlink()`
- In `_handle_link()` update path (when `server_url` changes): stop old subscriber, start new one

**NixOS change** (`configuration.nix`):
- No change needed if using pure aiohttp SSE parsing
- Add `p.aiohttp-sse-client` to `discordBotPython` if the cleaner API is preferred

---

## Decisions

- **Use pure aiohttp SSE parsing** (no new dependency). The existing `aiohttp` already provides `response.content` async iteration which is sufficient. This avoids a `configuration.nix` change and NixOS rebuild.
- **Accumulate on `session.idle`**: Collect `message.part.updated` text deltas into a buffer per (session_id, message_id). On `session.idle`, if there is accumulated text and the session is NOT in `_discord_relay_sessions`, post the full text to Discord. This avoids partial-message spam.
- **Dedup by `_discord_relay_sessions` set** (not `promptAsync` refactor): Less invasive, preserves existing Discord->OpenCode path which is tested and working.
- **No reconnect**: When the SSE connection drops, log and stop. The user re-links via `<leader>ar`, which calls `update_server_url`, which triggers a fresh subscriber.
- **Session filtering in SSE stream**: Since each TUI may serve multiple sessions, the subscriber must filter events by `properties.sessionID` (where present). Session-less events (like `server.connected`) are ignored.

---

## Recommendations

### Implementation Priority

1. **Create `sse_subscriber.py`** with `TuiSseSubscriber` class:
   - `start()` coroutine: connects, reads event loop, buffers text parts, posts on session.idle
   - `stop()`: cancels the asyncio task
   - Text accumulation: `dict[message_id, str]` buffer per subscriber instance
   - Dedup check: `if session_id in in_progress_sessions: continue` before posting

2. **Update `bot.py`**:
   - Add `_sse_subscribers`, `_discord_relay_sessions`
   - Wrap `_relay_and_respond` with dedup guard
   - Start subscribers on `on_ready` for pre-existing sessions
   - Expose `start_sse_subscriber` / `stop_sse_subscriber` methods

3. **Update `api.py`**:
   - Call `bot.start_sse_subscriber()` in `_handle_link()` (new link + server_url update)
   - Call `bot.stop_sse_subscriber()` in `_handle_kill()`

4. **Update `configuration.nix`** (optional, if `aiohttp-sse-client` preferred):
   - Add `p.aiohttp-sse-client` to `discordBotPython` packages

### Event Handling Strategy

Post to Discord on `session.idle` (not on each `message.part.updated`) to avoid flooding the thread with partial text. Buffer all text parts for the current message_id, then send one consolidated message when idle is received. Use `relay_response_to_thread()` (already handles chunking for 2000-char limit).

If `session.idle` never arrives (e.g., error condition), also post on `message.updated` with `info.time.completed` set and `info.role == "assistant"`.

### Error Handling

- `aiohttp.ClientConnectorError`: TUI closed; log info (not error), stop subscriber cleanly
- `asyncio.CancelledError`: Normal stop via `stop_sse_subscriber()`; re-raise to exit task
- `json.JSONDecodeError`: Skip malformed events; log debug
- Discord send failures in SSE subscriber: log error; do not crash the subscriber task
- Thread not found in bot cache: fetch from Discord API with `bot.get_or_fetch_channel(thread_id)`

### Testing Strategy

1. Start a TUI session, link it to Discord
2. Type a message in the TUI (not in Discord)
3. Verify the response appears in Discord thread (within ~30s for typical responses)
4. Type a message in Discord
5. Verify the response appears in Discord thread exactly once (not twice - dedup check)
6. Close Neovim (TUI dies), type in Discord -> verify graceful error message in thread
7. Re-open Neovim, run `<leader>ar` to re-link -> verify new SSE subscriber starts

---

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|
| Duplicate posts if dedup window is too narrow | High | Medium | Track dedup by both session_id and a brief time window (e.g., 120s); clear flag only after `relay_response_to_thread` completes |
| Long assistant responses before `session.idle` never received (crash/timeout) | Medium | Low | Also trigger on `message.updated` with `time.completed` set as a fallback |
| Multiple concurrent messages in same TUI session interleave | Medium | Low | Key buffer by `message_id` not just `session_id`; each assistant message has a unique ID |
| TUI port changes mid-subscriber (session migrated) | Low | Low | `_handle_link` update path stops old subscriber and starts new one |
| SSE subscriber task crashes and leaks | Medium | Low | Wrap `start()` in try/except; always remove from `_sse_subscribers` on exit (finally block) |
| Bot startup re-subscribing to dead TUI URLs | Low | High | Health-check `server_url` before subscribing; if unreachable, skip gracefully (not an error) |

---

## Context Extension Recommendations

- **Topic**: OpenCode SSE event types and subscription patterns
- **Gap**: No existing context file documents the OpenCode `/event` SSE endpoint, event type taxonomy, or how to consume them from Python
- **Recommendation**: Create `.claude/context/project/neovim/domain/opencode-sse-events.md` with the event types table and Python consumption pattern

---

## Appendix

### OpenCode SSE Endpoint Summary

- URL: `http://{TUI_HOST}:{TUI_PORT}/event`
- Auth: none (TUI instances), HTTP Basic (headless server at port 4096)
- Protocol: SSE (text/event-stream), standard format `data: {JSON}\n\n`
- First event: `{"type":"server.connected","properties":{}}`
- Session-scoped events include `sessionID` in `properties`
- All events on TUI are for all sessions hosted by that TUI instance

### Key Event Types for Assistant Relay

```
message.part.updated
  properties.part.type == "text"
  properties.part.sessionID  -> for session filtering
  properties.part.messageID  -> for message accumulation
  properties.delta           -> incremental text (may be undefined; fall back to part.text)

message.updated
  properties.info.role == "assistant"
  properties.info.time.completed (set when done)
  properties.info.id         -> messageID

session.idle
  properties.sessionID       -> clean completion signal
```

### Global Event Endpoint

`GET /event` on the headless server (port 4096, auth required) wraps events as:
```json
{"payload": {"type": "...", "properties": {...}}}
```
(not `{"type": "..."}` directly - note the extra `payload` wrapper).

The TUI `/event` endpoint uses the flat format: `{"type": "...", "properties": {...}}`.

### Files to Modify

```
~/.dotfiles/opencode-discord-bot/
├── opencode_discord_bot/src/
│   ├── bot.py              -- add subscriber management, dedup guard
│   ├── api.py              -- start/stop subscriber on link/kill
│   └── sse_subscriber.py   -- NEW: TuiSseSubscriber class
~/.dotfiles/configuration.nix  -- optional: add aiohttp-sse-client to discordBotPython
```

### aiohttp SSE Parsing Pattern (Minimal)

```python
async def _stream_events(server_url: str) -> AsyncIterator[dict]:
    headers = {"Accept": "text/event-stream", "Cache-Control": "no-cache"}
    timeout = aiohttp.ClientTimeout(total=None, sock_read=None)
    async with aiohttp.ClientSession() as session:
        async with session.get(f"{server_url}/event", headers=headers, timeout=timeout) as resp:
            buf = ""
            async for chunk in resp.content:
                buf += chunk.decode("utf-8", errors="replace")
                while "\n" in buf:
                    line, buf = buf.split("\n", 1)
                    line = line.strip()
                    if line.startswith("data: ") and line != "data: ":
                        try:
                            yield json.loads(line[6:])
                        except json.JSONDecodeError:
                            pass
```

### References

- OpenCode SDK types: `/home/benjamin/.config/nvim/.opencode/node_modules/@opencode-ai/sdk/dist/gen/types.gen.d.ts`
- aiohttp SSE server library: https://github.com/aio-libs/aiohttp-sse
- aiohttp SSE client library: https://pypi.org/project/aiohttp-sse-client/
- Bot source: `/home/benjamin/.dotfiles/opencode-discord-bot/`
- Task 571 research (prior architecture findings): `/home/benjamin/.config/nvim/specs/571_create_guide_discord_opencode_agents_neovim/reports/01_discord-opencode-guide.md`

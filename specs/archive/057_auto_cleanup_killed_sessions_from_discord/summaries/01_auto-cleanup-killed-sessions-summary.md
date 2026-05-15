# Task 57 Summary: Auto Cleanup Killed Sessions from Discord

**Completed**: 2026-05-15
**Session**: sess_1778805139_ef9fa6
**Plan**: [plans/01_auto-cleanup-killed-sessions.md](plans/01_auto-cleanup-killed-sessions.md)

---

## What Was Implemented

Added Discord thread cleanup to all session kill scenarios in the OpenCode Discord bot across three distinct paths:

### 1. Explicit Kill Path (api.py)

Updated `POST /kill` handler (`_handle_kill()`) to clean up the Discord thread **before** unlinking the session from the store. The `thread_id` is resolved from the session store entry prior to cleanup. Cleanup is non-blocking: if it fails, the kill flow continues and the session is still unlinked.

### 2. Implicit Kill Path (sse_subscriber.py)

Added two new event handlers to `TuiSseSubscriber._process_stream()`:

- **`session.deleted`**: Always triggers cleanup. This event is emitted when the session is explicitly deleted in the TUI.
- **`session.error`**: Triggers cleanup only when the `sessionID` in the error payload matches the subscriber's session. This avoids cleaning up on unrelated global errors.

Both handlers call a new `_handle_session_death()` method that:
1. Sets `_running = False` to stop reconnection loops
2. Cancels any pending embed timer
3. Looks up `thread_id` from the session store
4. Calls `bot._cleanup_discord_thread(thread_id)`
5. Unlinks the session from the store
6. Removes itself from the bot's tracking dicts

### 3. Health-Check Polling Loop (bot.py)

Added a periodic background task that polls the headless OpenCode server (`list_sessions()`) every 5 minutes (configurable). For each linked headless session (sessions without a custom TUI `server_url`), it checks whether the session ID still exists on the server. If not found, the loop triggers cleanup: stops the SSE subscriber, archives/deletes the thread, and unlinks from the store.

The health-check loop:
- Starts in `on_ready()` when `OPENCODE_HEALTH_CHECK_ENABLED` is true
- Is cancelled cleanly in `close()` on bot shutdown
- Skips cycles gracefully when the headless server is unreachable

### Configuration

Three new environment variables were added to `config.py`:

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENCODE_DISCORD_CLEANUP_MODE` | `archive` | `archive` (archive+lock thread) or `delete` (permanently delete) |
| `OPENCODE_HEALTH_CHECK_ENABLED` | `true` | Enable/disable the periodic health-check loop |
| `OPENCODE_HEALTH_CHECK_INTERVAL` | `300` | Polling interval in seconds |

### Cleanup Helper (bot.py)

Added `_cleanup_discord_thread(thread_id: str)` to `DiscordBot` that:
- Resolves the thread via `get_channel()` / `fetch_channel()`
- Archives and locks (`archived=True, locked=True`) when `cleanup_mode == "archive"`
- Deletes when `cleanup_mode == "delete"`
- Handles `nextcord.NotFound` (thread already gone) gracefully
- Handles `nextcord.Forbidden` (missing permissions) with a warning
- Catches generic exceptions to avoid failing the kill flow

---

## Files Modified

- `opencode-discord-bot/opencode_discord_bot/src/config.py` — new env vars and validation
- `opencode-discord-bot/opencode_discord_bot/src/bot.py` — `_cleanup_discord_thread()`, `_run_session_health_check()`, health-check lifecycle
- `opencode-discord-bot/opencode_discord_bot/src/api.py` — `_handle_kill()` thread cleanup
- `opencode-discord-bot/opencode_discord_bot/src/sse_subscriber.py` — `session.deleted` and `session.error` handlers

---

## Validation

All modified files passed Python syntax checks (`python3 -m py_compile`).

---

## Rollback

If cleanup causes issues, set `OPENCODE_DISCORD_CLEANUP_MODE=archive` (the safe default) or `OPENCODE_HEALTH_CHECK_ENABLED=false` without redeploying. If SSE event handlers cause problems, they can be individually commented out in `sse_subscriber.py` while retaining the explicit kill path.

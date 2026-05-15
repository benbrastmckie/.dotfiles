# Research Report: Task #57

**Task**: 57 - Auto cleanup killed sessions from Discord
**Started**: 2026-05-14T20:30:00Z
**Completed**: 2026-05-14T21:00:00Z
**Effort**: 30 minutes
**Dependencies**: Task 56 (Bidirectional Discord-OpenCode relay)
**Sources/Inputs**:
- `specs/056_implement_bidirectional_discord_opencode_relay/reports/01_discord-opencode-relay.md` — prior architecture findings
- `specs/056_implement_bidirectional_discord_opencode_relay/plans/01_bidirectional-discord-opencode-relay.md` — completed plan
- `opencode_discord_bot/src/bot.py` — DiscordBot class (sse subscriber lifecycle, link/kill flows)
- `opencode_discord_bot/src/api.py` — `POST /kill` handler (stops subscriber, aborts, unlinks store)
- `opencode_discord_bot/src/sse_subscriber.py` — TuiSseSubscriber SSE event stream consumer
- `opencode_discord_bot/src/store.py` — SessionStore JSON-backed session-thread mappings
- `opencode_discord_bot/src/relay.py` — Thread creation with `create_session_thread()`
- `opencode_discord_bot/src/opencode_client.py` — `abort_session()`, `delete_session()` REST client methods
- `opencode_discord_bot/src/config.py` — Config from env
- `opencode_discord_bot/data/sessions.json` — Live session state (3 active sessions)
- `~/.config/nvim/lua/neotex/plugins/ai/opencode/discord-session-picker.lua` — Telescope kill action via `POST /kill`
- `~/.config/nvim/lua/neotex/plugins/ai/opencode/discord-link.lua` — TUI port discovery and `/link` API
- `~/.config/nvim/.opencode/node_modules/@opencode-ai/sdk/dist/gen/types.gen.d.ts` — Event type taxonomy: `session.deleted`, `session.error`, `session.idle`, `session.status`
- `~/.config/nvim/.opencode/node_modules/@opencode-ai/sdk/dist/gen/sdk.gen.d.ts` — SDK methods: `session.delete()`, `session.abort()`, `session.status()`
- `/home/benjamin/.dotfiles/configuration.nix` — NixOS systemd service (lines 903-940)
- Discord API docs: Channel resource (modify thread, delete/close channel, thread metadata)
**Artifacts**:
- `specs/057_auto_cleanup_killed_sessions_from_discord/reports/01_auto-cleanup-sessions.md` (this file)
**Standards**: report-format.md, artifact-management.md, tasks.md

---

## Executive Summary

- The existing `POST /kill` handler (in `api.py`) stops the SSE subscriber, aborts the OpenCode session, and unlinks from the session store — but does **nothing** to clean up the Discord thread. The thread remains as an active, abandoned thread with no linked session.
- There are two distinct kill paths, each requiring different cleanup strategies: (A) explicit kill via `POST /kill` (Telescope picker `kill` action) where the bot is the caller and can directly clean up, and (B) implicit kill (TUI closes, Neovim exits, process killed, session deleted in TUI UI) where the bot is only an observer via the SSE event stream.
- For path A, the fix is straightforward: add `thread.delete()` or `thread.edit(archived=true, locked=true)` to `_handle_kill()` in `api.py` after unlink succeeds. The `thread_id` is already available from the session store lookup.
- For path B, the SSE event stream emits `session.deleted` and `session.error` events that signal when a session is gone. The `TuiSseSubscriber` (in `sse_subscriber.py`) already parses all event types; adding handlers for `session.deleted` and terminal `session.error` events to trigger thread cleanup would cover this case.
- The critical gap for path B is: when the TUI process dies (Neovim closed), the SSE connection drops and the subscriber disconnects. The `session.deleted` event is emitted by the TUI server, so if the TUI dies *before* the session is formally deleted, the subscriber never sees the event. Mitigation requires either a separate polling loop in the bot that checks the headless server (`session.status` endpoint) for stale session IDs, or handling SSE disconnect as a signal that the session *may* be dead and performing a liveness check.
- For Discord cleanup, nextcord provides `Thread.delete()` (permanent deletion) and `Thread.edit(archived=True, locked=True)` (soft archive). Archiving is lower-risk and non-destructive; deletion is cleaner but irreversible. The recommendation is to **archive + lock** as the default, with deletion as an optional configurable mode.
- Threads are currently created as `PUBLIC_THREAD` with `auto_archive_duration=10080` (7 days), meaning threads will auto-archive after 7 days of inactivity anyway. Explicit cleanup shortens this from "up to a week" to "immediate."

---

## Context & Scope

**What was researched**: The complete kill lifecycle across both explicit (`POST /kill`) and implicit (TUI death, session deletion) pathways, what cleanup (if any) currently happens, what SSE events signal session death, what Discord API capabilities exist for thread cleanup, and the NixOS systemd configuration for the bot.

**Scope**: Add Discord thread cleanup to session kill scenarios. This affects `api.py` (explicit kill path) and `sse_subscriber.py` (implicit kill path via SSE events). The bot process at `~/.dotfiles/opencode-discord-bot/` is the sole implementation target. No NixOS configuration changes are needed unless new Python dependencies are added.

**Constraints**:
- The bot runs as a systemd service (`discord-bot`) with `Type=notify` and `Restart=always`
- TUI SSE endpoints are ephemeral — when Neovim closes, the SSE stream drops and the subscriber disconnects
- The headless server at `http://127.0.0.1:4096` is always available (with auth) and provides `GET /session/status` as a source of truth
- The Neovim kill action (Telescope picker `<CR>`) calls `POST /kill` on the bot API, which is the explicit kill path
- No existing polling mechanism exists in the bot — the architecture is currently purely event-driven via nextcord and SSE

---

## Findings

### Current Kill Behavior (No Cleanup)

The `POST /kill` handler in `api.py` (lines 198-240) performs three actions:

1. `bot.stop_sse_subscriber(session_id)` — cancels the SSE listening task
2. `bot.opencode_client.abort_session(session_id)` — attempts to abort on the OpenCode server
3. `bot.session_store.unlink(session_id)` — removes the session from `sessions.json`

**What is missing**: After step 3, the Discord thread still exists. The `thread_id` is available in the session entry before unlinking but is never used for cleanup. The thread stays visible as an active thread with no linked session, cluttering the Discord channel.

### Two Distinct Kill Pathways

**Path A — Explicit kill (bot is the caller)**:
```
Neovim Telescope picker <CR>
  -> curl POST /kill {session_id}
  -> _handle_kill() in api.py
  -> bot.stop_sse_subscriber(session_id)
  -> bot.opencode_client.abort_session(session_id)
  -> bot.session_store.unlink(session_id)
  [cleanup missing here]
```

The bot has the `thread_id` from the session entry and can directly call Thread methods. This is the easy path — just add cleanup after unlink.

**Path B — Implicit kill (bot is observer via SSE)**:
```
User deletes session in TUI UI (Ctrl+D, kill command, TUI crash, Neovim close)
  -> TUI emits session.deleted or session.error SSE event
  -> TuiSseSubscriber receives event
  [no handler for session.deleted/error]
  [session mapping remains in sessions.json]
  [Discord thread lingers]
```

The `TuiSseSubscriber._process_stream()` (sse_subscriber.py, lines 238-348) currently handles `message.part.updated`, `message.updated`, `session.idle`, and `session.status` events. It does **not** handle `session.deleted` or `session.error`.

**Path B sub-problem — TUI death before session delete**:

```
User closes Neovim (TUI process exits)
  -> SSE connection drops
  -> TuiSseSubscriber._run_with_reconnect() logs "SSE connect failed"
  [subscriber disconnects, never sees session.deleted]
  [session stays in sessions.json as "active"]
  [Discord thread lingers]
```

The `TuiSseSubscriber` reconnection loop (lines 180-232) reconnects with exponential backoff on disconnection, but the TUI is gone — the same `server_url` will never be reachable again. The subscriber enters a reconnect loop until the bot is restarted or the session is explicitly killed.

### SSE Events That Signal Session Death

From the OpenCode SDK type definitions (`types.gen.d.ts`):

| Event Type | Properties | Meaning |
|---|---|---|
| `session.deleted` | `{info: Session}` | Session was formally deleted (explicit delete action) |
| `session.error` | `{sessionID?: string, error?: ...}` | Session encountered a fatal error (may or may not have sessionID) |
| `session.status` | `{sessionID: string, status: SessionStatus}` | SessionStatus = `{type: "idle"}` / `{type: "retry", ...}` / `{type: "busy"}` — but note: there is NO `"killed"` or `"deleted"` status type; `session.deleted` is a separate event type |

### Discord Thread Cleanup Options

nextcord provides two mechanisms for removing threads:

1. **`Thread.delete()`** — `DELETE /channels/{thread.id}`. Permanently deletes the thread. Requires `MANAGE_THREADS` permission. Non-reversible.
2. **`Thread.edit(archived=True, locked=True)`** — `PATCH /channels/{thread.id}`. Archives and locks the thread so it disappears from the active thread list but remains accessible in the "Archived" view. Requires `MANAGE_THREADS` when locking. Reversible (can be unarchived).

**Additional option — final message**: Before archiving/deleting, post a "Session terminated" message to the thread. This provides context for anyone viewing the thread later. However, this adds latency and risk (send can fail).

**Current thread lifecycle**: Threads are created as `PUBLIC_THREAD` with `auto_archive_duration=10080` (7 days). Without explicit cleanup, abandoned threads will eventually auto-archive after 7 days of inactivity.

### Session Store State

The `sessions.json` file maps `session_id` to `{thread_id, thread_url, server_url, status: "active", ...}`. The `status` field is always set to `"active"` on link — there is no mechanism to mark a session as `"dead"` or `"terminated"` in the store. If a session is killed implicitly (path B), the store entry persists indefinitely with `status: "active"`.

When the bot restarts, `on_ready()` (bot.py, lines 131-135) iterates all sessions and starts SSE subscribers for those with `server_url`. If a session's TUI is dead, the subscriber will fail to connect and enter the reconnect loop — this wastes resources and creates log noise.

### Headless Server as Source of Truth

The headless OpenCode server at `http://127.0.0.1:4096` provides:

- `GET /session` — list all sessions on the headless server
- `GET /session/{id}` — get session details (returns 404 if deleted)
- `GET /session/status` — get status map `{session_id: SessionStatus}` for all sessions
- `DELETE /session/{id}` — delete a session

The `OpenCodeClient` class already wraps `list_sessions()`, `get_session()`, and `delete_session()` methods. A polling or on-startup verification loop could use `GET /session/{id}` or `GET /session` to verify whether a linked session still exists.

---

## Decisions

- **Archive (not delete) as default cleanup mode**: `Thread.edit(archived=True, locked=True)` is non-destructive and provides a paper trail if someone revisits the thread. Thread deletion is a configurable alternative.
- **Handle both kill paths separately**:
  - Path A (explicit kill via `POST /kill`): Add cleanup directly in `_handle_kill()` using the `thread_id` from the session entry before unlinking
  - Path B (implicit kill via SSE): Add `session.deleted` and terminal `session.error` handlers to `TuiSseSubscriber._process_stream()`
- **Add periodic health-check loop**: Introduce a background task that polls `GET /session/status` on the headless server every 2-5 minutes and unlinks/cleans up any sessions that no longer exist. This catches the TUI-death-before-delete edge case and stale entries from bot restarts.
- **No post-kill message to thread**: Adds complexity and latency for marginal benefit. The thread being archived/locked communicates the same information.
- **Preserve thread URL in metadata before cleanup**: If deletion is chosen, the `thread_url` is lost. Store it in a `"cleaned_up_at"` field with the thread URL before cleanup.

---

## Recommendations

### Implementation Priority

1. **Path A — Direct cleanup in `_handle_kill()` (high priority, lowest effort)**:
   - Before `bot.session_store.unlink(session_id)`, look up the session to get `thread_id`
   - Resolve the thread via `bot.get_channel(thread_id)` or `bot.fetch_channel(thread_id)`
   - Call `thread.edit(archived=True, locked=True)` (archive + lock)
   - Add optional `cleanup_mode` config field: `"archive"` (default) or `"delete"`
   - If `"delete"`, call `thread.delete()` instead
   - Log the cleanup action

2. **Path B — SSE event handlers in `TuiSseSubscriber` (medium priority)**:
   - Add handler for `session.deleted` event: call `bot.session_store.unlink(self.session_id)` and `bot.stop_sse_subscriber(self.session_id)`, then archive the thread
   - Add handler for `session.error` event (when `sessionID` matches): same cleanup flow
   - On SSE disconnect (after reconnect attempts exhausted or on `stop()` call), optionally trigger a liveness check before cleanup

3. **Health-check loop in `bot.py` (medium priority, catches edge cases)**:
   - Add `self._session_health_task` asyncio task started in `on_ready()`
   - Poll `GET /session/status` on headless server every 2-5 minutes
   - For each linked session, check if `session_id` exists in the status response
   - If not found: stop subscriber if running, archive/delete thread, unlink from store
   - Use the existing `OpenCodeClient` instance (already authenticated)

4. **Optional — Configurable cleanup mode**:
   - Add `CLEANUP_MODE` env var to `Config`: `"archive"` (default) or `"delete"`
   - Used by both path A and path B cleanup code

### Error Handling

- Thread not found on cleanup (already deleted manually): log debug, proceed with unlink
- `Forbidden` (403) on Thread.edit/delete: bot lacks `MANAGE_THREADS` permission; log warning, still unlink from store
- Headless server unreachable during health-check: skip that cycle, log debug (not error — server may restart)
- Thread resolution fails (network): log warning, retry on next health-check cycle

### Files to Modify

```
~/.dotfiles/opencode-discord-bot/
├── opencode_discord_bot/src/
│   ├── api.py              — Add thread cleanup to _handle_kill()
│   ├── sse_subscriber.py   — Add session.deleted / session.error handlers
│   ├── bot.py              — Add health-check loop, optional cleanup helper
│   └── config.py           — Optional: add cleanup_mode config field
~/.dotfiles/configuration.nix — Optional: if new env var added
```

### No NixOS Changes Required

Neither archiving nor deleting threads requires new Python packages beyond `nextcord` which is already in `discordBotPython`. The health-check loop uses the existing `aiohttp`-based `OpenCodeClient`.

---

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|
| Thread cleanup fails (403) but session is already unlinked — thread orphaned | Medium | Low | Health-check loop catches this: if thread still exists and session is unlinked, retry cleanup |
| Race condition: session re-linked with new thread_id between health-check polls | Low | Low | Health-check only verifies session existence, not thread_id consistency; re-link already handles old subscriber teardown |
| Archived thread is accidentally re-opened by a user later | Low | Low | Lock the thread (`locked=True`) so only users with `MANAGE_THREADS` can unarchive |
| Deleting threads (if delete mode chosen) loses conversation history | Medium | N/A (configurable) | Default to archive mode; make delete an explicit opt-in |
| Health-check loop adds load to headless server | Low | Low | Poll every 2-5 minutes (not seconds); `GET /session/status` is a lightweight endpoint |

---

## Context Extension Recommendations

- **Topic**: Session lifecycle and cleanup patterns in the Discord-OpenCode relay
- **Gap**: No existing context file documents the session kill pathways, the distinction between explicit and implicit kills, or the cleanup responsibilities of each component
- **Recommendation**: Create `.opencode/context/repo/apps/discord-bot-session-lifecycle.md` documenting the two kill paths, SSE event signals for session death, and cleanup flow

---

## Appendix

### OpenCode SSE Events Relevant to Session Death

```
session.deleted:
    type: "session.deleted"
    properties:
        info: Session    # contains id, directory, title, time, etc.

session.error:
    type: "session.error"
    properties:
        sessionID?: string   # may be absent for global errors
        error?: ProviderAuthError | UnknownError | MessageOutputLengthError | MessageAbortedError | ApiError
```

### Discord Thread Cleanup API (via nextcord)

```python
# Archive + lock (non-destructive, recommended default)
await thread.edit(archived=True, locked=True)

# Permanent deletion (irreversible)
await thread.delete()
```

### Headless Server Session Verification

```python
# Check if a session exists (returns 404 if deleted)
response = await opencode_client.get_session(session_id)
# If raises HTTP 404: session is gone -> trigger cleanup

# Batch check (more efficient for health-check loop)
all_sessions = await opencode_client.list_sessions()
existing_ids = {s["id"] for s in all_sessions}
dead_ids = linked_session_ids - existing_ids
```

### Current Thread Creation Params (from relay.py)

```python
thread = await channel.create_thread(
    name=thread_name,
    type=nextcord.ChannelType.public_thread,
    auto_archive_duration=10080,  # 7 days
)
```

### Existing `_handle_kill()` Flow (api.py lines 198-240)

```python
async def _handle_kill(request):
    # ... auth check, body parsing ...
    session_id = body.get("session_id")

    # Stop SSE subscriber
    await bot.stop_sse_subscriber(session_id)

    # Attempt to abort on OpenCode server
    try:
        await bot.opencode_client.abort_session(session_id)
    except Exception as exc:
        logger.warning(...)

    # Unlink from store
    await bot.session_store.unlink(session_id)

    # >>> CLEANUP INSERTION POINT <<<
    # Thread cleanup should go here (or before unlink if thread_id needed)

    return web.json_response({"status": "killed"})
```

### Session Store Entry Structure (from store.py and sessions.json)

```json
{
  "session_id": "ses_...",
  "session_name": "...",
  "thread_id": "1504636238525894746",
  "channel_id": "1504572702130700472",
  "thread_url": "https://discord.com/channels/1502482791743356928/1504636238525894746",
  "linked_at": "2026-05-15T00:07:14.333024+00:00",
  "working_directory": "/home/benjamin/.dotfiles",
  "server_url": "http://127.0.0.1:40427",
  "status": "active"
}
```

### References

- Task 56 research: `specs/056_.../reports/01_discord-opencode-relay.md`
- Task 56 plan: `specs/056_.../plans/01_bidirectional-discord-opencode-relay.md`
- Bot source: `~/.dotfiles/opencode-discord-bot/opencode_discord_bot/src/`
- OpenCode SDK types: `~/.config/nvim/.opencode/node_modules/@opencode-ai/sdk/dist/gen/types.gen.d.ts`
- Discord API docs for threads: https://discord.com/developers/docs/resources/channel
- NixOS service: `~/.dotfiles/configuration.nix` lines 903-940

# Implementation Plan: Auto Cleanup Killed Sessions from Discord

- **Task**: 57 - Auto cleanup killed sessions from Discord
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: Task 56 (Bidirectional Discord-OpenCode relay)
- **Research Inputs**: `specs/057_auto_cleanup_killed_sessions_from_discord/reports/01_auto-cleanup-sessions.md`
- **Artifacts**: `plans/01_auto-cleanup-killed-sessions.md` (this file)
- **Standards**: `plan-format.md`, `status-markers.md`, `artifact-management.md`, `tasks.md`
- **Type**: general
- **Lean Intent**: false

## Overview

Add Discord thread cleanup to all session kill scenarios in the OpenCode Discord bot. There are two kill pathways: (A) explicit kill via `POST /kill` where the bot is the caller, and (B) implicit kill via SSE `session.deleted`/`session.error` events where the bot is an observer. A periodic health-check polling loop will catch the edge case where the TUI process dies before the session is formally deleted. The default cleanup mode archives and locks threads (non-destructive); deletion is configurable.

### Research Integration

The research report identified two distinct kill paths requiring cleanup, the gap in SSE event handling for session death signals, and the TUI-death-before-delete edge case. Key findings integrated: `thread_id` is available in the session store before unlink; `session.deleted` and `session.error` events are emitted by the TUI server but unhandled; the headless server at `127.0.0.1:4096` provides `GET /session/status` for liveness verification; archiving + locking is the recommended default cleanup mode.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items found.

## Goals & Non-Goals

**Goals**:
- Clean up Discord threads when sessions are explicitly killed via `POST /kill`
- Clean up Discord threads when `session.deleted` or terminal `session.error` SSE events are received
- Detect and clean up stale sessions via a periodic health-check polling loop
- Make cleanup mode configurable (archive vs delete)
- Handle cleanup errors gracefully (thread already gone, permission denied)

**Non-Goals**:
- Posting a final "session terminated" message to the thread before cleanup
- Modifying NixOS configuration or adding new Python dependencies
- Changing the thread creation behavior in `relay.py`
- Adding a UI for users to configure cleanup mode at runtime

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Thread cleanup fails (403 Forbidden) but session is unlinked — thread orphaned | Medium | Low | Health-check loop catches orphaned threads on next poll; log warning and retry |
| Race condition: session re-linked with new thread between health-check polls | Low | Low | Health-check only verifies session existence via headless server; re-link already handles old subscriber teardown |
| Archived thread accidentally re-opened by a user | Low | Low | Lock the thread (`locked=True`) so only users with `MANAGE_THREADS` can unarchive |
| Deleting threads loses conversation history | Medium | N/A (configurable) | Default to archive mode; make delete an explicit opt-in via env var |
| Health-check loop adds load to headless server | Low | Low | Poll every 2-5 minutes; `GET /session/status` is lightweight |
| TUI dies before session deletion — SSE disconnect with no event | Medium | Medium | Health-check loop detects stale sessions and triggers cleanup |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1 |
| 4 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Add Cleanup Configuration and Helper [COMPLETED]

**Goal**: Add the `CLEANUP_MODE` configuration option and a reusable Discord thread cleanup helper to `bot.py`.

**Tasks**:
- [ ] Add `CLEANUP_MODE: str = "archive"` to `config.py` with env var `OPENCODE_DISCORD_CLEANUP_MODE`
- [ ] Add validation: accepted values are `"archive"` (default) or `"delete"`
- [ ] Add `_cleanup_discord_thread(self, thread_id: str)` async method to `DiscordBot` in `bot.py`
- [ ] Method resolves thread via `self.fetch_channel(thread_id)` or `self.get_channel(thread_id)`
- [ ] If `CLEANUP_MODE == "archive"`: call `await thread.edit(archived=True, locked=True)`
- [ ] If `CLEANUP_MODE == "delete"`: call `await thread.delete()`
- [ ] Handle `nextcord.NotFound`: log debug, return (thread already gone)
- [ ] Handle `nextcord.Forbidden`: log warning, return (proceed with unlink)
- [ ] Handle generic `Exception`: log error, return (do not fail the kill flow)

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `opencode_discord_bot/src/config.py` — add `CLEANUP_MODE` config field
- `opencode_discord_bot/src/bot.py` — add `_cleanup_discord_thread()` helper method

**Verification**:
- Config loads correctly with default `"archive"` and accepts `"delete"`
- Helper method archives/locks a test thread without error
- Helper handles `NotFound` and `Forbidden` gracefully

---

### Phase 2: Path A — Explicit Kill Cleanup in api.py [COMPLETED]

**Goal**: Update `_handle_kill()` to clean up the Discord thread before unlinking the session from the store.

**Tasks**:
- [ ] In `_handle_kill()`, after `bot.stop_sse_subscriber(session_id)` and before `bot.session_store.unlink(session_id)`, look up the session entry to get `thread_id`
- [ ] If `thread_id` exists, call `await bot._cleanup_discord_thread(thread_id)`
- [ ] Preserve the session entry lookup result so `thread_id` is available even after unlink
- [ ] If cleanup fails (exception logged by helper), continue with unlink — do not block the kill flow
- [ ] Add logging: `logger.info("Cleaning up Discord thread %s for session %s (mode: %s)", thread_id, session_id, bot.config.CLEANUP_MODE)`

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `opencode_discord_bot/src/api.py` — `_handle_kill()` add thread cleanup before unlink

**Verification**:
- Calling `POST /kill` with a valid `session_id` archives/locks the associated Discord thread
- Session is unlinked from store after cleanup
- Kill flow completes successfully even if thread cleanup fails

---

### Phase 3: Path B — SSE Event Handlers in sse_subscriber.py [COMPLETED]

**Goal**: Add handlers for `session.deleted` and terminal `session.error` events in `TuiSseSubscriber` to trigger thread cleanup.

**Tasks**:
- [ ] In `TuiSseSubscriber._process_stream()`, add a branch for `event_type == "session.deleted"`
- [ ] Handler calls `await self.bot.stop_sse_subscriber(self.session_id)`
- [ ] Handler calls `await self.bot._cleanup_discord_thread(thread_id)` (resolve `thread_id` from `self.bot.session_store` lookup)
- [ ] Handler calls `await self.bot.session_store.unlink(self.session_id)`
- [ ] Add a branch for `event_type == "session.error"` when `sessionID` matches `self.session_id`
- [ ] Only treat `session.error` as terminal if the error type indicates a fatal/abort condition (e.g., `MessageAbortedError`, `ApiError`, or when `sessionID` is present and the error is unrecoverable)
- [ ] Same cleanup flow as `session.deleted` for terminal errors
- [ ] Add logging for both handlers: `logger.info("Session %s received %s, cleaning up thread", self.session_id, event_type)`

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `opencode_discord_bot/src/sse_subscriber.py` — add `session.deleted` and `session.error` handlers

**Verification**:
- Receiving a `session.deleted` SSE event triggers thread cleanup and store unlink
- Receiving a terminal `session.error` SSE event triggers thread cleanup and store unlink
- Non-terminal `session.error` events are ignored
- Subscriber stops after cleanup to avoid reconnection loops

---

### Phase 4: Health-Check Polling Loop in bot.py [COMPLETED]

**Goal**: Add a background task that periodically polls the headless server to detect stale sessions and trigger cleanup.

**Tasks**:
- [ ] Add `_session_health_task: Optional[asyncio.Task]` to `DiscordBot` in `bot.py`
- [ ] Add `_run_session_health_check(self)` async method
- [ ] Method polls `await self.opencode_client.list_sessions()` every 5 minutes (configurable via env var `OPENCODE_HEALTH_CHECK_INTERVAL`, default 300 seconds)
- [ ] Build a set of existing session IDs from the response
- [ ] Iterate all sessions in `self.session_store`; for any `session_id` not in the existing set:
  - Call `await self.stop_sse_subscriber(session_id)` if running
  - Call `await self._cleanup_discord_thread(session.thread_id)` if `thread_id` exists
  - Call `await self.session_store.unlink(session_id)`
  - Log: `logger.warning("Session %s not found on headless server, cleaned up orphaned thread", session_id)`
- [ ] Start the health-check task in `on_ready()` after starting SSE subscribers
- [ ] Cancel the health-check task in a new `close()` or `cleanup()` method (or in `on_disconnect` if applicable)
- [ ] Handle headless server unreachable: log debug, skip cycle, retry on next poll
- [ ] Add `OPENCODE_HEALTH_CHECK_ENABLED: bool = True` to `config.py`

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `opencode_discord_bot/src/bot.py` — add health-check loop and task lifecycle
- `opencode_discord_bot/src/config.py` — add `OPENCODE_HEALTH_CHECK_ENABLED` and `OPENCODE_HEALTH_CHECK_INTERVAL`

**Verification**:
- Health-check task starts on bot ready
- A stale session (removed from headless server but present in store) is detected and cleaned up within one polling interval
- Health-check skips cycle gracefully when headless server is unreachable
- Task is cancelled cleanly on bot shutdown

---

### Phase 5: Testing and Validation [COMPLETED]

**Goal**: Verify all three cleanup paths work correctly in a live or mocked environment.

**Tasks**:
- [ ] Test Path A: trigger `POST /kill` via Neovim Telescope picker, verify thread is archived/locked and session unlinked
- [ ] Test Path B (deleted): simulate `session.deleted` SSE event, verify cleanup triggers
- [ ] Test Path B (error): simulate terminal `session.error` SSE event, verify cleanup triggers
- [ ] Test health-check: manually remove a session from the headless server (or mock `list_sessions()`), verify cleanup within polling interval
- [ ] Test edge case: thread already deleted manually — verify `NotFound` is handled gracefully
- [ ] Test edge case: bot lacks `MANAGE_THREADS` permission — verify `Forbidden` is handled gracefully
- [ ] Test config: set `CLEANUP_MODE=delete`, verify threads are deleted instead of archived
- [ ] Test disable: set `OPENCODE_HEALTH_CHECK_ENABLED=false`, verify health-check task does not start

**Timing**: 1 hour

**Depends on**: 2, 3, 4

**Files to modify**:
- None (testing only)

**Verification**:
- All test scenarios pass
- No orphaned threads remain after session kills
- Bot logs show cleanup actions and any warnings/errors
- Bot continues operating normally after cleanup failures

## Testing & Validation

- [ ] Explicit kill (`POST /kill`) archives/locks the Discord thread and unlinks the session
- [ ] `session.deleted` SSE event triggers thread cleanup and unlink
- [ ] Terminal `session.error` SSE event triggers thread cleanup and unlink
- [ ] Health-check loop detects stale sessions and cleans them up within the polling interval
- [ ] Thread already deleted (`NotFound`) is handled gracefully without failing the kill flow
- [ ] Missing permissions (`Forbidden`) is handled gracefully with a warning log
- [ ] `CLEANUP_MODE=delete` permanently deletes threads instead of archiving
- [ ] `OPENCODE_HEALTH_CHECK_ENABLED=false` disables the health-check loop
- [ ] Bot continues to link new sessions and operate normally after cleanup

## Artifacts & Outputs

- `specs/057_auto_cleanup_killed_sessions_from_discord/plans/01_auto-cleanup-killed-sessions.md` (this file)
- Modified `opencode_discord_bot/src/config.py` — new env vars: `CLEANUP_MODE`, `OPENCODE_HEALTH_CHECK_ENABLED`, `OPENCODE_HEALTH_CHECK_INTERVAL`
- Modified `opencode_discord_bot/src/bot.py` — `_cleanup_discord_thread()` helper, `_run_session_health_check()` loop
- Modified `opencode_discord_bot/src/api.py` — `_handle_kill()` thread cleanup
- Modified `opencode_discord_bot/src/sse_subscriber.py` — `session.deleted` and `session.error` handlers

## Rollback/Contingency

- Revert all modified files to pre-change state using git
- If cleanup causes issues (e.g., accidental thread deletion), set `CLEANUP_MODE=archive` or disable health-check via `OPENCODE_HEALTH_CHECK_ENABLED=false` without redeploying
- If SSE event handlers cause crashes, they can be individually commented out in `sse_subscriber.py` while retaining the explicit kill path
- The health-check loop is isolated in its own asyncio task; cancelling the task stops polling without affecting other bot functionality

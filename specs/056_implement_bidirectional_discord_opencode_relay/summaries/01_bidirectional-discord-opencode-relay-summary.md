# Implementation Summary: Bidirectional Discord-OpenCode Relay

- **Task**: 56 - bidirectional_discord_opencode_relay
- **Status**: [COMPLETED]
- **Started**: 2026-05-14T12:00:00Z
- **Completed**: 2026-05-14T12:00:00Z
- **Artifacts**: plans/01_bidirectional-discord-opencode-relay.md

## Overview

Implemented the reverse relay for the Discord-OpenCode bot, enabling assistant responses typed in the OpenCode TUI to automatically appear in the corresponding linked Discord thread. The existing Discord→OpenCode relay remains fully operational; this adds the missing TUI→Discord direction via an SSE subscriber.

## What Changed

- **Created `opencode_discord_bot/src/sse_subscriber.py`** — New `TuiSseSubscriber` class that:
  - Connects to the TUI SSE endpoint (`GET /event`) using pure `aiohttp`
  - Parses SSE `data:` lines and filters events by `session_id`
  - Accumulates text deltas from `message.part.updated` events keyed by `message_id`
  - Posts accumulated text to Discord on `session.idle` (primary trigger)
  - Falls back to `message.updated` with `time.completed` and `role == "assistant"`
  - Skips posting when a Discord→OpenCode relay is in progress (`_discord_relay_sessions` dedup guard)
  - Handles `ClientConnectorError` (logs info, exits cleanly), `CancelledError` (re-raises), `JSONDecodeError` (skips event), and Discord send failures (logs error, continues loop)

- **Updated `opencode_discord_bot/src/bot.py`** — Added:
  - `self._sse_subscribers: dict[str, asyncio.Task] = {}` and `self._discord_relay_sessions: set[str] = set()`
  - `_relay_and_respond()` wrapped with dedup guard (add `session_id` before relay, remove after `relay_response_to_thread`)
  - `start_sse_subscriber(session)` — health-checks the TUI server before subscribing, skips gracefully if unreachable
  - `stop_sse_subscriber(session_id)` — cancels task, removes from dict, cleans up dead tasks
  - `on_ready()` iterates existing linked sessions and starts SSE subscribers for those with a non-empty `server_url`
  - `close()` cancels and awaits all SSE subscriber tasks on shutdown

- **Updated `opencode_discord_bot/src/api.py`** — Wired lifecycle hooks:
  - `_handle_link()` new link path: calls `bot.start_sse_subscriber(session)` after linking
  - `_handle_link()` update path (server_url changes): stops old subscriber, updates URL, starts new subscriber
  - `_handle_kill()`: calls `bot.stop_sse_subscriber(session_id)` before unlinking

## Decisions

- Used pure `aiohttp` (no new dependencies) for SSE streaming, matching the existing codebase patterns.
- Stored `asyncio.Task` objects in `_sse_subscribers` rather than subscriber instances, keeping the dict lightweight and allowing direct task cancellation.
- Added dead-task cleanup in `start_sse_subscriber()` to prevent crashed/completed tasks from blocking restarts.
- Chose `session.idle` as the primary posting trigger with `message.updated` fallback, as recommended by the research report.

## Impacts

- Discord threads now receive assistant responses from both Discord-typed and TUI-typed messages.
- Dedup guard prevents duplicate posts when both relay paths are active for the same session.
- Bot startup automatically resumes SSE subscriptions for previously linked sessions with TUI URLs.
- Port rotation (server_url update) cleanly stops the old subscriber and starts a new one.
- No new Python package dependencies or NixOS configuration changes required.

## Follow-ups

- **Manual end-to-end testing** required in a live environment: link a session, type in TUI, verify response appears in Discord thread; type in Discord thread, verify exactly one response.
- **Long-running stability test** recommended to validate dedup behavior under race conditions between SSE events and relay completion.
- Consider adding message-level dedup (e.g., tracking posted `message_id`s) if session-level guard proves insufficient in practice.

## References

- `specs/056_implement_bidirectional_discord_opencode_relay/plans/01_bidirectional-discord-opencode-relay.md`
- `opencode-discord-bot/opencode_discord_bot/src/sse_subscriber.py` (new)
- `opencode-discord-bot/opencode_discord_bot/src/bot.py` (modified)
- `opencode-discord-bot/opencode_discord_bot/src/api.py` (modified)

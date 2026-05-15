# Implementation Plan: Discord Permission Approval Flow

- **Task**: 58 - discord_permission_approval_flow
- **Status**: [NOT STARTED]
- **Effort**: 3.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/058_discord_permission_approval_flow/reports/01_permission-approval-research.md
- **Artifacts**: plans/01_permission-approval-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

Implement a Discord-based permission approval flow for the OpenCode Discord bot. When OpenCode sessions emit `permission.asked` SSE events, the bot will post an embed with approve/deny buttons in the linked Discord thread. Users can approve (once or always) or reject permission requests directly from Discord, resolving the headless permission hang problem (OpenCode issue #14473). The feature is done when permission requests appear as interactive embeds and button clicks successfully resolve the permission via the OpenCode REST API.

### Research Integration

Key findings from the research report:
- OpenCode emits `permission.asked` SSE events with a `Request` object containing `id`, `sessionID`, `permission` type, `patterns`, `metadata`, and `always` fields
- Permission replies go to `POST /permission/:requestID/reply` with body `{reply: "once"|"always"|"reject", message?: string}`
- Pending permissions can be listed via `GET /permission` for SSE reconnect recovery
- Nextcord persistent views with `timeout=None` and `custom_id` encoding survive bot restarts
- The existing `_process_stream()` method in `sse_subscriber.py` has a clear extension point for new event types
- `_get_client_for_url()` pattern in `bot.py` enables routing replies to the correct TUI server

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No relevant ROADMAP.md items (roadmap is empty).

## Goals & Non-Goals

**Goals**:
- Surface OpenCode permission requests as Discord embeds with interactive buttons in the linked thread
- Support all three reply types: "Approve Once", "Approve Always", "Reject"
- Handle edge cases: stale permissions, session death, bot restarts, SSE reconnection gaps
- Enforce whitelist authorization on button interactions
- Update the Discord message after resolution to show outcome

**Non-Goals**:
- Configurable auto-approve patterns (future enhancement)
- Custom reject messages from Discord UI (simplify to fixed reject)
- Permission audit log or history
- Web dashboard for permissions

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Bot offline causes session hang | H | M | Document that headless sessions should configure permissions as "allow"; bot is supplementary |
| Stale button clicks after session death | M | M | Handle gracefully with "permission expired" feedback on interaction |
| SSE reconnect misses permission events | M | L | Call GET /permission on reconnect to fetch pending permissions |
| Multiple users clicking same buttons | L | L | First click wins; subsequent clicks show "already resolved" |
| Bot restart loses view state | M | L | Use persistent views with custom_id encoding; re-register on startup |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Extend OpenCode Client with Permission API Methods [NOT STARTED]

**Goal**: Add `reply_permission()` and `list_permissions()` methods to the `OpenCodeClient` class so downstream code can interact with the permission endpoints.

**Tasks**:
- [ ] Add `reply_permission(request_id: str, reply: str, message: str = "") -> bool` method to `OpenCodeClient`
- [ ] Add `list_permissions() -> list[dict]` method to `OpenCodeClient`
- [ ] Handle error cases (connection errors, non-200 responses) with logging
- [ ] Verify methods work against the OpenCode permission API schema

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `opencode-discord-bot/opencode_discord_bot/src/opencode_client.py` - Add two new API methods

**Verification**:
- Methods are syntactically correct and follow existing patterns (aiohttp session usage, timeout, raise_for_status)
- Error handling is consistent with existing methods (try/except with logging)

---

### Phase 2: Create Permission Approval View (Discord UI Component) [NOT STARTED]

**Goal**: Create a `PermissionApprovalView` class with persistent buttons that calls the OpenCode permission reply API when clicked.

**Tasks**:
- [ ] Create new module `opencode-discord-bot/opencode_discord_bot/src/permission_view.py`
- [ ] Implement `PermissionApprovalView(nextcord.ui.View)` with three buttons: Approve Once (green), Approve Always (blurple), Reject (red)
- [ ] Encode `request_id` into button `custom_id` to support multiple concurrent permission requests
- [ ] Implement `_reply_permission()` helper that calls the OpenCode API and updates the Discord message
- [ ] Disable all buttons after any click and edit the message to show outcome
- [ ] Handle stale interactions gracefully (API returns 200 for non-existent IDs, show "permission may have expired")
- [ ] Enforce whitelist check on button interactions (compare interaction.user.id against config)
- [ ] Create helper function `make_permission_embed()` that formats the permission request details (type, patterns, session info) into a rich embed

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `opencode-discord-bot/opencode_discord_bot/src/permission_view.py` - New file: view class and embed builder

**Verification**:
- View class uses `timeout=None` for persistence
- Custom IDs include the request_id for uniqueness
- Buttons disable after interaction
- Embed shows permission type, patterns, and session context

---

### Phase 3: Wire Permission Event into SSE Subscriber [NOT STARTED]

**Goal**: Add `permission.asked` event handling to `_process_stream()` so permission requests are detected and routed to the Discord thread.

**Tasks**:
- [ ] Add `elif event_type == "permission.asked":` branch in `_process_stream()` after existing event handlers
- [ ] Extract permission fields: `id`, `sessionID`, `permission`, `patterns`, `metadata`, `always` from `properties`
- [ ] Filter by session ID (only handle permissions for this subscriber's session)
- [ ] Resolve the Discord thread via `_resolve_thread()`
- [ ] Import and instantiate `PermissionApprovalView` with the request details
- [ ] Call `make_permission_embed()` and send embed + view to the thread
- [ ] Add `permission.replied` event handling to update/remove permission messages when resolved externally

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `opencode-discord-bot/opencode_discord_bot/src/sse_subscriber.py` - Add permission event branches

**Verification**:
- Permission events are detected and filtered by session ID
- Embed with buttons appears in the correct Discord thread
- External resolution (permission.replied) updates the message

---

### Phase 4: Bot Startup Integration and Reconnect Recovery [NOT STARTED]

**Goal**: Register persistent views on bot startup and recover missed permissions on SSE reconnect.

**Tasks**:
- [ ] In `bot.py` `on_ready()`, register the persistent view class with `self.add_view(PermissionApprovalView(...))` pattern for view persistence across restarts
- [ ] Add a method `_recover_pending_permissions(session: dict)` that calls `list_permissions()` on reconnect and posts embeds for any pending permissions matching the session
- [ ] Call `_recover_pending_permissions()` in `_run_with_reconnect()` after successful SSE connection (after `backoff = RECONNECT_BASE` reset)
- [ ] Pass necessary context (bot config, server URL) to the view so it can access the OpenCode client for replies
- [ ] Import `PermissionApprovalView` in bot.py

**Timing**: 45 minutes

**Depends on**: 2, 3

**Files to modify**:
- `opencode-discord-bot/opencode_discord_bot/src/bot.py` - Add persistent view registration and recovery method
- `opencode-discord-bot/opencode_discord_bot/src/sse_subscriber.py` - Add reconnect permission recovery call

**Verification**:
- Bot startup registers persistent views (buttons work after bot restart)
- SSE reconnect fetches and displays any missed pending permissions
- No duplicate permission messages (check if already posted for same request_id)

---

## Testing & Validation

- [ ] Bot starts without errors with the new permission_view module imported
- [ ] Sending a test `permission.asked` SSE event results in an embed appearing in the Discord thread
- [ ] Clicking "Approve Once" calls POST /permission/:id/reply with `{reply: "once"}` and disables buttons
- [ ] Clicking "Approve Always" calls POST /permission/:id/reply with `{reply: "always"}` and disables buttons
- [ ] Clicking "Reject" calls POST /permission/:id/reply with `{reply: "reject"}` and disables buttons
- [ ] Non-whitelisted users see an ephemeral "not authorized" message when clicking buttons
- [ ] Stale permission clicks (after session death) show appropriate feedback
- [ ] Multiple permission requests result in separate embeds with independent button sets
- [ ] SSE reconnect posts embeds for any pending permissions that were missed

## Artifacts & Outputs

- `opencode-discord-bot/opencode_discord_bot/src/permission_view.py` - New module with PermissionApprovalView class
- `opencode-discord-bot/opencode_discord_bot/src/opencode_client.py` - Extended with permission API methods
- `opencode-discord-bot/opencode_discord_bot/src/sse_subscriber.py` - Extended with permission event handling
- `opencode-discord-bot/opencode_discord_bot/src/bot.py` - Extended with persistent view registration

## Rollback/Contingency

All changes are additive (new module, new methods, new event branches). Rollback by:
1. Removing the `permission_view.py` module
2. Reverting the added methods in `opencode_client.py`
3. Removing the `permission.asked` / `permission.replied` branches in `sse_subscriber.py`
4. Removing the persistent view registration in `bot.py`

No existing functionality is modified, so rollback carries no risk of regression.

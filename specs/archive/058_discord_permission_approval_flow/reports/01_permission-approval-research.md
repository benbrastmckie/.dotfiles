# Research Report: Discord Permission Approval Flow

- **Task**: 58 - discord_permission_approval_flow
- **Started**: 2026-05-14T16:45:00Z
- **Completed**: 2026-05-14T17:10:00Z
- **Effort**: ~25 minutes
- **Dependencies**: None
- **Sources/Inputs**:
  - Codebase: `/home/benjamin/.dotfiles/opencode-discord-bot/` (full bot source)
  - OpenCode source: `github.com/sst/opencode` (permission module, server handlers, API groups)
  - OpenCode docs: https://opencode.ai/docs/permissions/, https://opencode.ai/docs/server/
  - GitHub issues: #14473, #15386, #11616, #11885, #10564
  - DeepWiki: Permission System, Permission and Question System
- **Artifacts**: 
  - `specs/058_discord_permission_approval_flow/reports/01_permission-approval-research.md`
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

## Executive Summary

- OpenCode emits `permission.asked` SSE events with a `Request` object containing `id`, `sessionID`, `permission` type, `patterns`, `metadata`, `always` patterns, and optional `tool` context
- Permission requests are resolved via `POST /permission/:requestID/reply` with body `{reply: "once"|"always"|"reject", message?: string}`
- Pending permissions can be listed via `GET /permission` (returns array of `Permission.Request` objects)
- The existing SSE subscriber in the Discord bot already processes SSE events and can be extended to handle `permission.asked` events
- Nextcord supports persistent Views with buttons and custom_ids, enabling approve/deny buttons that work even after bot restart
- The implementation should add a new event handler branch in `_process_stream` and a corresponding `PermissionApprovalView` class

## Context & Scope

This research investigates how to implement a Discord-based permission approval flow for OpenCode sessions linked to the Discord bot. When OpenCode requests a permission (e.g., running a bash command, accessing an external directory, editing a file), the user should be notified in Discord and be able to approve or deny directly from a Discord message with buttons.

### Current State

The existing Discord bot:
- Links OpenCode sessions to Discord threads via POST /link
- Subscribes to SSE event streams from OpenCode TUI servers
- Handles events: `message.part.updated`, `message.updated`, `session.idle`, `session.status`, `session.deleted`, `session.error`
- Does NOT currently handle `permission.asked` events

### Problem Context

In headless/server mode, OpenCode permission checks configured as `"ask"` hang indefinitely (issue #14473) because there is no UI to surface the permission prompt. The web UI had a bug where tool-triggered permissions were not displayed (issue #11885). This feature would solve the headless permission problem by routing permission requests to Discord.

## Findings

### 1. OpenCode Permission Request Structure

From the source code at `packages/opencode/src/permission/index.ts`:

```typescript
export class Request extends Schema.Class<Request>("PermissionRequest")({
  id: PermissionID,              // String starting with "per" (e.g., "per_abc123...")
  sessionID: SessionID,          // The session that triggered the permission
  permission: Schema.String,     // Type: "bash", "read", "edit", "external_directory", etc.
  patterns: Schema.Array(Schema.String),  // The specific patterns being requested
  metadata: Schema.Record(Schema.String, Schema.Unknown),  // Additional context
  always: Schema.Array(Schema.String),    // Patterns that "always" would approve
  tool: Schema.optional(Schema.Struct({   // Optional tool context
    messageID: MessageID,
    callID: Schema.String,
  })),
}) {}
```

### 2. Permission Reply API

**Endpoint**: `POST /permission/:requestID/reply`

**Request body**:
```json
{
  "reply": "once" | "always" | "reject",
  "message": "optional feedback string"
}
```

**Reply semantics**:
- `"once"` - Approve this specific request only
- `"always"` - Approve and remember the pattern for the session (persisted to SQLite)
- `"reject"` - Deny the request (optionally with feedback message)

**Response**: `true` (boolean) on success

**List endpoint**: `GET /permission` returns `Permission.Request[]` of all pending permissions.

### 3. SSE Event Format

The `permission.asked` event arrives in the SSE stream as:

```json
{
  "id": "evt_...",
  "type": "permission.asked",
  "properties": {
    "id": "per_...",
    "sessionID": "ses_...",
    "permission": "bash",
    "patterns": ["rm -rf /tmp/test"],
    "metadata": {},
    "always": ["rm *"],
    "tool": {
      "messageID": "msg_...",
      "callID": "call_..."
    }
  }
}
```

A `permission.replied` event is also broadcast after a reply:
```json
{
  "type": "permission.replied",
  "properties": {
    "sessionID": "ses_...",
    "requestID": "per_...",
    "reply": "once"
  }
}
```

### 4. Current Bot Architecture (Extension Points)

The SSE subscriber in `sse_subscriber.py` processes events in `_process_stream()`. The relevant extension points:

1. **Event detection**: Add a new `elif event_type == "permission.asked":` branch after existing handlers
2. **Session matching**: Use `event_session_id` from `properties.get("sessionID", "")` to match to correct thread
3. **Thread resolution**: Reuse `_resolve_thread()` to get the Discord thread
4. **API call**: Use the existing `OpenCodeClient` with a new method for permission reply

### 5. Nextcord Button Pattern for Approve/Deny

Nextcord (discord.py fork) supports interactive buttons via `nextcord.ui.View`:

```python
import nextcord
from nextcord.ui import View, Button, button

class PermissionApprovalView(View):
    def __init__(self, request_id: str, session_id: str, server_url: str):
        super().__init__(timeout=None)  # Persistent view (no timeout)
        self.request_id = request_id
        self.session_id = session_id
        self.server_url = server_url

    @button(label="Approve Once", style=nextcord.ButtonStyle.green, custom_id="perm_approve_once")
    async def approve_once(self, btn: Button, interaction: nextcord.Interaction):
        await self._reply_permission(interaction, "once")

    @button(label="Approve Always", style=nextcord.ButtonStyle.blurple, custom_id="perm_approve_always")
    async def approve_always(self, btn: Button, interaction: nextcord.Interaction):
        await self._reply_permission(interaction, "always")

    @button(label="Reject", style=nextcord.ButtonStyle.red, custom_id="perm_reject")
    async def reject(self, btn: Button, interaction: nextcord.Interaction):
        await self._reply_permission(interaction, "reject")

    async def _reply_permission(self, interaction, reply_type):
        # Send reply to OpenCode API
        # Update the Discord message to show result
        # Disable buttons after response
        pass
```

**Key considerations for persistent views**:
- `timeout=None` means the view never expires
- `custom_id` must be unique per button instance (should encode the `request_id`)
- The bot must re-register persistent views on startup via `bot.add_view()`
- Views survive bot restarts if custom_ids are used

### 6. OpenCode Client Extension

The `OpenCodeClient` class needs a new method:

```python
async def reply_permission(
    self, request_id: str, reply: str, message: str = ""
) -> bool:
    """Reply to a permission request.
    
    Parameters
    ----------
    request_id: Permission request ID (starts with "per")
    reply: One of "once", "always", "reject"
    message: Optional feedback message (used with reject)
    """
    session = self._get_session()
    url = f"{self._base_url}/permission/{request_id}/reply"
    payload = {"reply": reply}
    if message:
        payload["message"] = message
    
    async with session.post(url, json=payload, timeout=...) as resp:
        resp.raise_for_status()
        return await resp.json()
```

Also a method to list pending permissions:
```python
async def list_permissions(self) -> list[dict]:
    """List all pending permission requests."""
    session = self._get_session()
    url = f"{self._base_url}/permission"
    async with session.get(url, timeout=...) as resp:
        resp.raise_for_status()
        return await resp.json()
```

### 7. Complete Event Flow

```
1. OpenCode agent attempts tool use (e.g., bash "rm file")
2. Permission system evaluates rule -> result is "ask"
3. Server creates Deferred promise, stores in pending map
4. Server publishes "permission.asked" event on bus
5. SSE stream delivers event to connected bot subscriber
6. Bot detects "permission.asked" event in _process_stream()
7. Bot posts Discord embed with approve/deny buttons to linked thread
8. User clicks a button in Discord
9. Button callback fires: bot calls POST /permission/:requestID/reply
10. OpenCode server resolves the Deferred promise
11. Tool execution proceeds (or is rejected with feedback)
12. Bot updates Discord message to show result (approved/rejected)
```

### 8. Edge Cases and Considerations

- **Multiple pending permissions**: OpenCode may queue multiple permission requests for the same session. Each should get its own Discord message with buttons.
- **Timeout handling**: If the OpenCode session is killed while a permission is pending, the buttons become stale. The bot should handle this gracefully.
- **Stale permission IDs**: Issue #15386 notes that `POST /permission/:requestID/reply` returns 200 even for non-existent IDs. The bot should handle this gracefully (log warning, update message).
- **Rejecting cascades**: When a permission is rejected, OpenCode rejects ALL pending permissions for that session (see source: reply handler cascades reject to same-session pending items).
- **"Always" cascades**: When "always" is selected, OpenCode auto-approves other pending permissions matching the same pattern (same session).
- **Session filtering**: The SSE event includes `sessionID` in properties; the subscriber should only show permissions for its matched session.
- **Server URL routing**: Permission replies must go to the correct server URL (TUI instance vs headless), matching the existing `_get_client_for_url()` pattern.
- **Whitelist enforcement**: Only whitelisted Discord users should be able to approve/deny permissions.

## Decisions

- Use `nextcord.ui.View` with persistent buttons (custom_id + timeout=None) for the approval UI
- Encode the `request_id` into the button `custom_id` to handle multiple concurrent permission requests
- Add `permission.asked` handling as a new branch in `TuiSseSubscriber._process_stream()`
- Extend `OpenCodeClient` with `reply_permission()` and `list_permissions()` methods
- Use an embed for the permission request message (consistent with existing status embeds)
- Support all three reply types: "once", "always", "reject"

## Recommendations

1. **Phase 1: Core implementation**
   - Add `reply_permission()` to `OpenCodeClient`
   - Create `PermissionApprovalView` class with buttons
   - Add `permission.asked` event handling in `TuiSseSubscriber._process_stream()`
   - Post embed with view to Discord thread when permission is asked

2. **Phase 2: Robustness**
   - Handle `permission.replied` event to update messages when permissions are resolved externally (e.g., from web UI)
   - Add timeout/cleanup for stale permission messages
   - Handle session death while permissions are pending
   - Register persistent views on bot startup for surviving restarts

3. **Phase 3: Polish**
   - Add `list_permissions()` to fetch pending permissions on SSE reconnect (handles missed events)
   - Add configurable auto-approve patterns (optional, via env var)
   - Format permission details nicely in the embed (show command, file path, etc.)

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Permission hangs if bot is offline | Session freezes permanently | Document that permissions default to "allow" in headless; bot is supplementary |
| Stale button interactions (session already dead) | User confusion | Handle gracefully - show "permission expired" message |
| Multiple users clicking buttons | Race condition | First click wins (OpenCode deletes pending entry); subsequent clicks show "already resolved" |
| SSE reconnection misses events | Permissions not shown | Call GET /permission on reconnect to fetch pending |
| Bot restart loses view state | Buttons stop working | Use persistent views with custom_id encoding request_id |
| Rate limiting on Discord embed edits | Errors in logs | Already handled by existing PROGRESS_EDIT_INTERVAL pattern |

## Appendix

### Search Queries Used
- "opencode.ai headless server API permission approval endpoint"
- "opencode github source code permission consent SSE event headless"
- "opencode SDK typescript permission list reply client"
- "nextcord discord.py buttons components View interaction callback"

### Key References
- OpenCode Permission Source: `github.com/sst/opencode/packages/opencode/src/permission/index.ts`
- API Route Definition: `github.com/sst/opencode/packages/opencode/src/server/routes/instance/httpapi/groups/permission.ts`
- Route Handler: `github.com/sst/opencode/packages/opencode/src/server/routes/instance/httpapi/handlers/permission.ts`
- SSE Event Stream: `github.com/sst/opencode/packages/opencode/src/server/routes/instance/httpapi/handlers/event.ts`
- Issue #14473: Permission ask hangs in headless mode
- Issue #15386: POST /permission returns 200 for non-existent IDs
- Issue #11616: Web interface client interaction architecture
- Issue #11885: Web UI skips permission prompt with tool field
- Issue #10564: TUI should show pending permissions on attach

### Permission Types Reference
| Permission | Description | Default |
|-----------|-------------|---------|
| `bash` | Shell command execution | allow |
| `read` | File read access | allow |
| `edit` | File write/edit/patch | allow |
| `glob` | File pattern matching | allow |
| `grep` | Content searching | allow |
| `external_directory` | Paths outside project | ask |
| `doom_loop` | Repeated failing calls | ask |
| `task` | Launching subagents | allow |
| `webfetch` | URL fetching | allow |
| `websearch` | Web search queries | allow |

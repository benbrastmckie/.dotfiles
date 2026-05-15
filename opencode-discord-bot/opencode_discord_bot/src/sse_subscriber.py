"""SSE subscriber that listens to the OpenCode TUI event stream.

Connects to the TUI's ``GET /event`` endpoint and forwards assistant
responses back to the corresponding Discord thread.  For long-running
tasks (>10s), shows a status embed that updates in-place.  Short
exchanges get the response posted directly with no embed.

Reconnects automatically with exponential backoff when the SSE
connection drops.
"""

from __future__ import annotations

import asyncio
import json
import logging
import time

import aiohttp
import nextcord

from opencode_discord_bot.src.permission_view import (
    PermissionApprovalView,
    make_permission_embed,
)
from opencode_discord_bot.src.relay import relay_response_to_thread

logger = logging.getLogger(__name__)

COLOUR_WORKING = 0xFFC107  # yellow/amber
COLOUR_DONE = 0x4CAF50  # green
COLOUR_ERROR = 0xF44336  # red
PROGRESS_EDIT_INTERVAL = 15  # seconds between embed edits
EMBED_DELAY = 10  # seconds before showing a status embed
RECONNECT_BASE = 2  # seconds, doubled each retry
RECONNECT_MAX = 60  # cap on backoff


class TuiSseSubscriber:
    """Subscribes to a TUI SSE event stream and relays assistant responses
    to the linked Discord thread.
    """

    def __init__(
        self,
        bot: object,
        session_id: str,
        server_url: str,
        thread_id: str,
    ) -> None:
        self.bot = bot
        self.session_id = session_id
        self.server_url = server_url.rstrip("/") if server_url else ""
        self.thread_id = thread_id
        self._running = False
        self._task: asyncio.Task | None = None

        self._status_msg: nextcord.Message | None = None
        self._last_edit_time: float = 0
        self._started_at: int = 0
        self._embed_timer: asyncio.Task | None = None
        self._pending_embed_thread: nextcord.Thread | None = None
        # Track posted permission messages by request_id for external resolution updates
        self._permission_messages: dict[str, nextcord.Message] = {}

    async def start(self) -> None:
        """Start the SSE subscription as a background task."""
        if self._running:
            return
        self._running = True
        self._task = asyncio.create_task(self._run_with_reconnect())

    async def stop(self) -> None:
        """Stop the SSE subscription."""
        self._running = False
        self._cancel_embed_timer()
        if self._task and not self._task.done():
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        self._task = None

    # ------------------------------------------------------------------
    # Thread resolution
    # ------------------------------------------------------------------

    async def _resolve_thread(self) -> nextcord.Thread | None:
        thread = self.bot.get_channel(int(self.thread_id))
        if thread is None:
            try:
                thread = await self.bot.fetch_channel(int(self.thread_id))
            except Exception as exc:
                logger.error(
                    "Failed to resolve thread %s for session %s: %s",
                    self.thread_id, self.session_id, exc,
                )
                return None
        return thread

    # ------------------------------------------------------------------
    # Status embed (only for long-running tasks)
    # ------------------------------------------------------------------

    def _make_embed(
        self, status: str, snippet: str = "", colour: int = COLOUR_WORKING
    ) -> nextcord.Embed:
        embed = nextcord.Embed(colour=colour)
        embed.add_field(name="Status", value=status, inline=True)
        if self._started_at:
            embed.add_field(
                name="Started", value=f"<t:{self._started_at}:R>", inline=True
            )
        if snippet:
            if len(snippet) > 300:
                snippet = snippet[-300:]
            embed.add_field(
                name="Latest activity",
                value=f"```\n{snippet}\n```",
                inline=False,
            )
        embed.set_footer(text=f"Session {self.session_id[:12]}")
        return embed

    def _cancel_embed_timer(self) -> None:
        if self._embed_timer and not self._embed_timer.done():
            self._embed_timer.cancel()
        self._embed_timer = None

    def _schedule_embed(self, thread: nextcord.Thread) -> None:
        """Schedule an embed to appear after EMBED_DELAY seconds."""
        self._cancel_embed_timer()
        self._started_at = int(time.time())
        self._pending_embed_thread = thread
        self._embed_timer = asyncio.create_task(self._delayed_embed())

    async def _delayed_embed(self) -> None:
        """Wait, then post the status embed if the response hasn't arrived."""
        try:
            await asyncio.sleep(EMBED_DELAY)
        except asyncio.CancelledError:
            return
        thread = self._pending_embed_thread
        if thread is None:
            return
        try:
            embed = self._make_embed("Processing...")
            self._status_msg = await thread.send(embed=embed)
            self._last_edit_time = time.time()
        except Exception as exc:
            logger.debug("Failed to post delayed status embed: %s", exc)

    async def _update_progress(self, snippet: str) -> None:
        """Edit the status embed with a progress snippet, throttled."""
        if not self._status_msg:
            return
        now = time.time()
        if now - self._last_edit_time < PROGRESS_EDIT_INTERVAL:
            return
        try:
            embed = self._make_embed("Processing...", snippet)
            await self._status_msg.edit(embed=embed)
            self._last_edit_time = now
        except Exception as exc:
            logger.debug("Failed to edit progress embed: %s", exc)

    async def _finalize_embed(self, success: bool = True) -> None:
        """Final edit of the status embed, or cancel if it hasn't appeared."""
        self._cancel_embed_timer()
        if not self._status_msg:
            return
        try:
            colour = COLOUR_DONE if success else COLOUR_ERROR
            status = "Completed" if success else "Error"
            embed = self._make_embed(status, colour=colour)
            await self._status_msg.edit(embed=embed)
        except Exception as exc:
            logger.debug("Failed to finalize status embed: %s", exc)
        self._status_msg = None

    # ------------------------------------------------------------------
    # SSE connection with reconnect
    # ------------------------------------------------------------------

    async def _run_with_reconnect(self) -> None:
        """Outer loop: reconnect on failure with exponential backoff."""
        if not self.server_url:
            return

        url = f"{self.server_url}/event"
        backoff = RECONNECT_BASE

        while self._running:
            logger.info(
                "SSE connecting for session %s at %s", self.session_id, url
            )
            try:
                async with aiohttp.ClientSession() as session:
                    async with session.get(url) as response:
                        if response.status != 200:
                            logger.warning(
                                "SSE endpoint returned %d for session %s",
                                response.status, self.session_id,
                            )
                            await asyncio.sleep(backoff)
                            backoff = min(backoff * 2, RECONNECT_MAX)
                            continue

                        backoff = RECONNECT_BASE  # reset on successful connect
                        await self._process_stream(response.content)

            except aiohttp.ClientConnectorError as exc:
                logger.info(
                    "SSE connect failed for session %s: %s",
                    self.session_id, exc,
                )
            except asyncio.CancelledError:
                raise
            except Exception:
                logger.exception(
                    "SSE subscriber for %s crashed", self.session_id
                )

            if not self._running:
                break

            logger.info(
                "SSE reconnecting for session %s in %ds",
                self.session_id, backoff,
            )
            try:
                await asyncio.sleep(backoff)
            except asyncio.CancelledError:
                break
            backoff = min(backoff * 2, RECONNECT_MAX)

        self._running = False

    # ------------------------------------------------------------------
    # Stream processing
    # ------------------------------------------------------------------

    async def _process_stream(self, content) -> None:
        """Parse SSE events from the response stream and handle them."""
        text_buffer: dict[str, str] = {}
        pending_message_id: str | None = None

        while self._running:
            try:
                line = await content.readline()
            except asyncio.CancelledError:
                raise
            except Exception:
                logger.exception(
                    "Error reading SSE stream for session %s", self.session_id
                )
                break

            if not line:
                break

            try:
                line_str = line.decode("utf-8").strip()
            except UnicodeDecodeError:
                continue

            if not line_str.startswith("data:"):
                continue

            data_str = line_str[5:].strip()
            if not data_str:
                continue

            try:
                event = json.loads(data_str)
            except json.JSONDecodeError:
                continue

            event_type = event.get("type", "")
            properties = event.get("properties", {})

            event_session_id = ""
            if event_type == "message.part.updated":
                event_session_id = properties.get("part", {}).get("sessionID", "")
            elif event_type == "message.updated":
                event_session_id = properties.get("info", {}).get("sessionID", "")
            elif event_type == "session.idle":
                event_session_id = properties.get("sessionID", "")
            elif event_type == "session.status":
                event_session_id = properties.get("sessionID", "")
            elif event_type in ("permission.asked", "permission.replied"):
                event_session_id = properties.get("sessionID", "")

            if event_session_id and event_session_id != self.session_id:
                continue

            if event_type == "message.part.updated":
                part = properties.get("part", {})
                message_id = part.get("messageID", "")

                if part.get("type") == "text" and message_id:
                    delta = properties.get("delta")
                    if delta is not None:
                        text_buffer[message_id] = (
                            text_buffer.get(message_id, "") + str(delta)
                        )
                    else:
                        text = part.get("text", "")
                        if text:
                            text_buffer[message_id] = text
                    pending_message_id = message_id

                    # Start delayed embed on first chunk (if not already started)
                    if not self._embed_timer or self._embed_timer.done():
                        if not self._status_msg:
                            thread = await self._resolve_thread()
                            if thread:
                                self._schedule_embed(thread)

                    snippet = text_buffer.get(message_id, "")
                    await self._update_progress(snippet)

            elif event_type == "message.updated":
                info = properties.get("info", {})
                message_id = info.get("id", "")
                role = info.get("role", "")
                time_completed = info.get("time", {}).get("completed")

                if role == "assistant" and message_id and time_completed:
                    full_text = text_buffer.get(message_id, "")
                    if full_text:
                        await self._finalize_embed(success=True)
                        await self._post_response(full_text, message_id)
                        text_buffer.pop(message_id, None)
                        if pending_message_id == message_id:
                            pending_message_id = None

            elif event_type in ("session.idle", "session.status"):
                if event_type == "session.status":
                    status = properties.get("status", {})
                    if status.get("type") != "idle":
                        continue

                if pending_message_id and pending_message_id in text_buffer:
                    full_text = text_buffer[pending_message_id]
                    await self._finalize_embed(success=True)
                    await self._post_response(full_text, pending_message_id)
                    text_buffer.pop(pending_message_id, None)
                    pending_message_id = None
                elif text_buffer:
                    await self._finalize_embed(success=True)
                    for msg_id, full_text in list(text_buffer.items()):
                        await self._post_response(full_text, msg_id)
                    text_buffer.clear()
                    pending_message_id = None

            elif event_type == "session.deleted":
                logger.info(
                    "Session %s received session.deleted, cleaning up thread",
                    self.session_id,
                )
                await self._handle_session_death()
                break

            elif event_type == "session.error":
                error_session_id = properties.get("sessionID", "")
                if error_session_id and error_session_id == self.session_id:
                    logger.info(
                        "Session %s received terminal session.error, cleaning up thread",
                        self.session_id,
                    )
                    await self._handle_session_death()
                    break

            elif event_type == "permission.asked":
                await self._handle_permission_asked(properties)

            elif event_type == "permission.replied":
                await self._handle_permission_replied(properties)

    async def _handle_session_death(self) -> None:
        """Clean up Discord thread and unlink session when the session dies."""
        self._running = False
        self._cancel_embed_timer()

        # Look up thread_id from session store before unlinking
        session_entry = self.bot.session_store.get_by_session(self.session_id)
        thread_id = session_entry.get("thread_id", "") if session_entry else ""

        if thread_id:
            await self.bot._cleanup_discord_thread(thread_id)

        await self.bot.session_store.unlink(self.session_id)

        # Remove from bot tracking without awaiting our own task
        self.bot._sse_subscriber_instances.pop(self.session_id, None)
        self.bot._sse_subscribers.pop(self.session_id, None)

    async def _post_response(self, text: str, message_id: str) -> None:
        """Post the assistant response to Discord."""
        if not text:
            return

        thread = await self._resolve_thread()
        if thread is None:
            return

        try:
            await relay_response_to_thread(thread, text)
            logger.info(
                "Relayed response for session %s message %s",
                self.session_id, message_id,
            )
        except Exception as exc:
            logger.error(
                "Failed to send response to thread %s: %s",
                self.thread_id, exc, exc_info=True,
            )

    # ------------------------------------------------------------------
    # Permission event handlers
    # ------------------------------------------------------------------

    async def _handle_permission_asked(self, properties: dict) -> None:
        """Handle a permission.asked event by posting an approval embed."""
        request_id = properties.get("id", "")
        permission_type = properties.get("permission", "")
        patterns = properties.get("patterns", [])
        metadata = properties.get("metadata", {})
        always_patterns = properties.get("always", [])

        if not request_id:
            logger.warning("Received permission.asked with no id, skipping")
            return

        # Skip if we already posted for this request_id (e.g. reconnect recovery)
        if request_id in self._permission_messages:
            return

        thread = await self._resolve_thread()
        if thread is None:
            return

        # Build embed and view
        embed = make_permission_embed(
            request_id=request_id,
            permission_type=permission_type,
            patterns=patterns,
            session_id=self.session_id,
            metadata=metadata,
            always_patterns=always_patterns,
        )

        # Get whitelist from bot config
        whitelisted = getattr(self.bot, "config", None)
        whitelisted_ids = whitelisted.whitelisted_user_ids if whitelisted else []

        view = PermissionApprovalView(
            request_id=request_id,
            server_url=self.server_url,
            whitelisted_user_ids=whitelisted_ids,
        )

        try:
            msg = await thread.send(embed=embed, view=view)
            self._permission_messages[request_id] = msg
            logger.info(
                "Posted permission request %s for session %s in thread %s",
                request_id, self.session_id, self.thread_id,
            )
        except Exception as exc:
            logger.error(
                "Failed to post permission embed for %s: %s",
                request_id, exc, exc_info=True,
            )

    async def _handle_permission_replied(self, properties: dict) -> None:
        """Handle a permission.replied event by updating the posted message."""
        request_id = properties.get("requestID", "")
        reply_type = properties.get("reply", "")

        if not request_id:
            return

        msg = self._permission_messages.pop(request_id, None)
        if msg is None:
            # We didn't post this permission (or it was already resolved)
            return

        action_label = {
            "once": "Approved (once)",
            "always": "Approved (always)",
            "reject": "Rejected",
        }.get(reply_type, reply_type)

        colour = 0x4CAF50 if reply_type != "reject" else 0xF44336

        embed = nextcord.Embed(
            title=f"Permission {action_label}",
            description="Resolved externally (not via Discord buttons).",
            colour=colour,
        )
        embed.set_footer(text=f"Request {request_id[:16]}")

        try:
            # Edit message to show resolved state with no buttons
            await msg.edit(embed=embed, view=None)
            logger.info(
                "Updated permission message %s as externally resolved (%s)",
                request_id, reply_type,
            )
        except Exception as exc:
            logger.debug(
                "Failed to update permission message %s: %s", request_id, exc
            )

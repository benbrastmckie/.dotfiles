"""SSE subscriber that listens to the OpenCode TUI event stream.

Connects to the TUI's ``GET /event`` endpoint and forwards assistant
responses back to the corresponding Discord thread.
"""

from __future__ import annotations

import asyncio
import json
import logging

import aiohttp

from opencode_discord_bot.src.relay import relay_response_to_thread

logger = logging.getLogger(__name__)


class TuiSseSubscriber:
    """Subscribes to a TUI SSE event stream and relays assistant responses
    to the linked Discord thread.

    Parameters
    ----------
    bot:
        The DiscordBot instance (provides ``get_channel``, ``fetch_channel``,
        and ``_discord_relay_sessions``).
    session_id:
        The OpenCode session ID to filter events for.
    server_url:
        Base URL of the TUI server (e.g. ``http://127.0.0.1:4096``).
    thread_id:
        Discord thread ID to post responses to.
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

    async def start(self) -> None:
        """Start the SSE subscription as a background task."""
        if self._running:
            logger.warning("SSE subscriber for %s already running", self.session_id)
            return
        self._running = True
        self._task = asyncio.create_task(self._run())

    async def stop(self) -> None:
        """Stop the SSE subscription."""
        self._running = False
        if self._task and not self._task.done():
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        self._task = None
        logger.info("SSE subscriber for %s stopped", self.session_id)

    async def _run(self) -> None:
        """Main loop: connect to SSE endpoint and process events."""
        if not self.server_url:
            logger.info(
                "No server_url for session %s, skipping SSE subscription",
                self.session_id,
            )
            return

        url = f"{self.server_url}/event"
        logger.info(
            "Starting SSE subscriber for session %s at %s",
            self.session_id,
            url,
        )

        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(url) as response:
                    if response.status != 200:
                        logger.warning(
                            "SSE endpoint returned %d for session %s",
                            response.status,
                            self.session_id,
                        )
                        return

                    await self._process_stream(response.content)
        except aiohttp.ClientConnectorError as exc:
            logger.info(
                "Could not connect to SSE endpoint for session %s: %s",
                self.session_id,
                exc,
            )
        except asyncio.CancelledError:
            logger.info("SSE subscriber for %s cancelled", self.session_id)
            raise
        except Exception:
            logger.exception("SSE subscriber for %s crashed", self.session_id)
        finally:
            self._running = False

    async def _process_stream(self, content) -> None:
        """Parse SSE events from the response stream and handle them."""
        text_buffer: dict[str, str] = {}  # message_id -> accumulated text
        pending_message_id: str | None = None

        while self._running:
            try:
                line = await content.readline()
            except asyncio.CancelledError:
                raise
            except Exception:
                logger.exception(
                    "Error reading SSE stream for session %s",
                    self.session_id,
                )
                break

            if not line:
                break  # Connection closed

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
                logger.debug(
                    "Skipping invalid JSON in SSE stream: %s",
                    data_str[:200],
                )
                continue

            event_type = event.get("type", "")
            properties = event.get("properties", {})

            # Extract session ID from properties (event-type specific)
            event_session_id = ""
            if event_type == "message.part.updated":
                event_session_id = properties.get("part", {}).get("sessionID", "")
            elif event_type == "message.updated":
                event_session_id = properties.get("info", {}).get("sessionID", "")
            elif event_type == "session.idle":
                event_session_id = properties.get("sessionID", "")
            elif event_type == "session.status":
                event_session_id = properties.get("sessionID", "")

            # Only process events for our session
            if event_session_id and event_session_id != self.session_id:
                continue

            if event_type == "message.part.updated":
                part = properties.get("part", {})
                message_id = part.get("messageID", "")

                if part.get("type") == "text" and message_id:
                    # Prefer incremental delta; fall back to part.text
                    delta = properties.get("delta")
                    if delta is not None:
                        text_buffer[message_id] = text_buffer.get(message_id, "") + str(delta)
                    else:
                        text = part.get("text", "")
                        if text:
                            text_buffer[message_id] = text
                    pending_message_id = message_id

            elif event_type == "message.updated":
                info = properties.get("info", {})
                message_id = info.get("id", "")
                role = info.get("role", "")
                time_completed = info.get("time", {}).get("completed")

                if role == "assistant" and message_id and time_completed:
                    full_text = text_buffer.get(message_id, "")
                    if full_text:
                        await self._post_response(full_text, message_id)
                        text_buffer.pop(message_id, None)
                        if pending_message_id == message_id:
                            pending_message_id = None

            elif event_type in ("session.idle", "session.status"):
                # For session.status, only trigger on idle status
                if event_type == "session.status":
                    status = properties.get("status", {})
                    if status.get("type") != "idle":
                        continue

                # Primary trigger: post any pending text
                if pending_message_id and pending_message_id in text_buffer:
                    full_text = text_buffer[pending_message_id]
                    await self._post_response(full_text, pending_message_id)
                    text_buffer.pop(pending_message_id, None)
                    pending_message_id = None
                elif text_buffer:
                    # Post everything remaining
                    for msg_id, full_text in list(text_buffer.items()):
                        await self._post_response(full_text, msg_id)
                    text_buffer.clear()
                    pending_message_id = None

    async def _post_response(self, text: str, message_id: str) -> None:
        """Post the assistant response to Discord, with deduplication."""
        if not text:
            return

        # Check dedup guard: if a Discord->OpenCode relay is in progress
        # for this session, skip to avoid duplicate posts.
        if self.session_id in self.bot._discord_relay_sessions:
            logger.debug(
                "Skipping SSE relay for session %s message %s (relay in progress)",
                self.session_id,
                message_id,
            )
            return

        # Resolve Discord thread
        thread = self.bot.get_channel(int(self.thread_id))
        if thread is None:
            try:
                thread = await self.bot.fetch_channel(int(self.thread_id))
            except Exception as exc:
                logger.error(
                    "Failed to resolve thread %s for session %s: %s",
                    self.thread_id,
                    self.session_id,
                    exc,
                )
                return

        try:
            await relay_response_to_thread(thread, text)
            logger.info(
                "Relayed SSE response for session %s message %s to thread %s",
                self.session_id,
                message_id,
                self.thread_id,
            )
        except Exception as exc:
            logger.error(
                "Failed to send SSE response to thread %s: %s",
                self.thread_id,
                exc,
                exc_info=True,
            )

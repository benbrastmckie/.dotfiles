"""Async HTTP client for the OpenCode server REST API.

Communicates with the headless OpenCode agent server using HTTP Basic
authentication (username ``opencode``, password from config). Wraps
aiohttp.ClientSession with typed methods for each endpoint.

The message endpoint is fire-and-forget -- OpenCode processes messages
asynchronously. To get the assistant response, we subscribe to the SSE
event stream at ``GET /event`` and collect ``message.part.updated``
events until the session becomes idle (``session.updated`` with no
active prompt).
"""

from __future__ import annotations

import asyncio
import json
import logging

import aiohttp

logger = logging.getLogger(__name__)

RESPONSE_TIMEOUT = 300  # 5 min max wait for assistant response


class OpenCodeClient:
    """HTTP client for the OpenCode server API.

    Parameters
    ----------
    base_url:
        Base URL of the OpenCode server (e.g. ``http://127.0.0.1:4096``).
    password:
        Server password for HTTP Basic authentication.
    """

    def __init__(self, base_url: str, password: str) -> None:
        self._base_url = base_url.rstrip("/")
        self._auth = aiohttp.BasicAuth(login="opencode", password=password)
        self._session: aiohttp.ClientSession | None = None

    def _get_session(self) -> aiohttp.ClientSession:
        """Lazily create the aiohttp session."""
        if self._session is None or self._session.closed:
            self._session = aiohttp.ClientSession(auth=self._auth)
        return self._session

    async def close(self) -> None:
        """Close the underlying HTTP session."""
        if self._session and not self._session.closed:
            await self._session.close()
            self._session = None

    async def __aenter__(self) -> OpenCodeClient:
        return self

    async def __aexit__(self, *args: object) -> None:
        await self.close()

    # ------------------------------------------------------------------
    # API methods
    # ------------------------------------------------------------------

    async def health(self, retries: int = 3, backoff: float = 1.0) -> bool:
        """Check if the OpenCode server is healthy.

        Retries with exponential backoff on connection errors.
        """
        session = self._get_session()
        url = f"{self._base_url}/global/health"

        for attempt in range(retries):
            try:
                async with session.get(url, timeout=aiohttp.ClientTimeout(total=5)) as resp:
                    if resp.status == 200:
                        return True
                    logger.warning(
                        "Health check returned status %d (attempt %d/%d)",
                        resp.status,
                        attempt + 1,
                        retries,
                    )
            except (aiohttp.ClientError, asyncio.TimeoutError) as exc:
                logger.debug(
                    "Health check attempt %d/%d failed: %s",
                    attempt + 1,
                    retries,
                    exc,
                )
            if attempt < retries - 1:
                await asyncio.sleep(backoff * (2 ** attempt))

        return False

    async def list_sessions(self) -> list[dict]:
        """List all OpenCode sessions."""
        session = self._get_session()
        url = f"{self._base_url}/session"

        async with session.get(url, timeout=aiohttp.ClientTimeout(total=10)) as resp:
            resp.raise_for_status()
            data = await resp.json()
            if isinstance(data, list):
                return data
            return data.get("sessions", data.get("data", []))

    async def get_session(self, session_id: str) -> dict:
        """Get details for a specific session."""
        session = self._get_session()
        url = f"{self._base_url}/session/{session_id}"

        async with session.get(url, timeout=aiohttp.ClientTimeout(total=10)) as resp:
            resp.raise_for_status()
            return await resp.json()

    async def send_message(self, session_id: str, text: str) -> None:
        """Send a message to an OpenCode session (fire-and-forget).

        The message endpoint returns an empty body. Use
        ``send_message_and_wait`` to get the assistant's response.
        """
        session = self._get_session()
        url = f"{self._base_url}/session/{session_id}/message"
        payload = {"parts": [{"type": "text", "text": text}]}

        async with session.post(
            url,
            json=payload,
            timeout=aiohttp.ClientTimeout(total=30),
        ) as resp:
            resp.raise_for_status()

    async def send_message_and_wait(self, session_id: str, text: str) -> str:
        """Send a message and wait for the assistant response via SSE.

        Opens an SSE connection to ``GET /event``, sends the message,
        then collects text parts from the assistant's response until
        the session goes idle.

        Returns the assembled assistant response text, or a fallback
        message if no text was received.
        """
        session = self._get_session()
        event_url = f"{self._base_url}/event"

        collected_text: dict[str, str] = {}
        got_response = asyncio.Event()
        assistant_msg_ids: set[str] = set()

        async def listen_sse() -> None:
            try:
                async with session.get(
                    event_url,
                    headers={"Accept": "text/event-stream"},
                    timeout=aiohttp.ClientTimeout(
                        total=RESPONSE_TIMEOUT,
                        sock_read=RESPONSE_TIMEOUT,
                    ),
                ) as resp:
                    buffer = ""
                    async for chunk in resp.content.iter_any():
                        buffer += chunk.decode("utf-8", errors="replace")
                        while "\n\n" in buffer:
                            raw_event, buffer = buffer.split("\n\n", 1)
                            data_line = ""
                            for line in raw_event.split("\n"):
                                if line.startswith("data: "):
                                    data_line += line[6:]
                                elif line.startswith("data:"):
                                    data_line += line[5:]
                            if not data_line:
                                continue
                            try:
                                event = json.loads(data_line)
                            except json.JSONDecodeError:
                                continue

                            ev_type = event.get("type", "")
                            props = event.get("properties", {})

                            if ev_type == "message.updated":
                                info = props.get("info", props)
                                if (
                                    info.get("sessionID") == session_id
                                    and info.get("role") == "assistant"
                                ):
                                    msg_id = info.get("id", "")
                                    if msg_id:
                                        assistant_msg_ids.add(msg_id)

                            elif ev_type == "message.part.updated":
                                part = props.get("part", {})
                                msg_id = part.get("messageID", "")
                                if (
                                    part.get("sessionID") == session_id
                                    and part.get("type") == "text"
                                    and msg_id in assistant_msg_ids
                                ):
                                    part_id = part.get("id", "default")
                                    collected_text[part_id] = part.get("text", "")

                            elif ev_type in ("session.idle", "session.status"):
                                sid = props.get("sessionID", "")
                                if sid == session_id:
                                    status = props.get("status", {})
                                    if (
                                        ev_type == "session.idle"
                                        or status.get("type") == "idle"
                                    ):
                                        if assistant_msg_ids:
                                            got_response.set()
                                            return

                            elif ev_type == "session.error":
                                if props.get("sessionID") == session_id:
                                    error = props.get("error", {})
                                    if isinstance(error, dict):
                                        error_msg = error.get("message", str(error))
                                    else:
                                        error_msg = str(error)
                                    collected_text["error"] = f"OpenCode error: {error_msg}"
                                    got_response.set()
                                    return

            except (aiohttp.ClientError, asyncio.TimeoutError) as exc:
                logger.warning("SSE connection ended: %s", exc)
                if not got_response.is_set():
                    got_response.set()

        sse_task = asyncio.create_task(listen_sse())

        # Small delay to let the SSE connection establish
        await asyncio.sleep(0.5)

        try:
            await self.send_message(session_id, text)
        except Exception:
            sse_task.cancel()
            raise

        try:
            await asyncio.wait_for(got_response.wait(), timeout=RESPONSE_TIMEOUT)
        except asyncio.TimeoutError:
            logger.warning(
                "Timed out waiting for response from session %s", session_id
            )

        sse_task.cancel()
        try:
            await sse_task
        except asyncio.CancelledError:
            pass

        if collected_text:
            return "\n".join(collected_text.values())
        return "(No text response from OpenCode)"

    async def get_messages(self, session_id: str) -> list[dict]:
        """Get all messages for a session."""
        session = self._get_session()
        url = f"{self._base_url}/session/{session_id}/message"

        async with session.get(url, timeout=aiohttp.ClientTimeout(total=10)) as resp:
            if resp.content_type != "application/json":
                return []
            resp.raise_for_status()
            data = await resp.json()
            if isinstance(data, list):
                return data
            return data.get("messages", data.get("data", []))

    async def abort_session(self, session_id: str) -> bool:
        """Abort a running OpenCode session."""
        session = self._get_session()
        url = f"{self._base_url}/session/{session_id}/abort"

        try:
            async with session.post(
                url, timeout=aiohttp.ClientTimeout(total=10)
            ) as resp:
                return resp.status in (200, 204)
        except aiohttp.ClientError as exc:
            logger.error("Failed to abort session %s: %s", session_id, exc)
            return False

    async def delete_session(self, session_id: str) -> bool:
        """Delete an OpenCode session."""
        session = self._get_session()
        url = f"{self._base_url}/session/{session_id}"

        try:
            async with session.delete(
                url, timeout=aiohttp.ClientTimeout(total=10)
            ) as resp:
                return resp.status in (200, 204)
        except aiohttp.ClientError as exc:
            logger.error("Failed to delete session %s: %s", session_id, exc)
            return False

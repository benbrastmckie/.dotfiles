"""Async HTTP client for the OpenCode server REST API.

Communicates with the headless OpenCode agent server using HTTP Basic
authentication (username ``opencode``, password from config). Wraps
aiohttp.ClientSession with typed methods for each endpoint.
"""

from __future__ import annotations

import asyncio
import logging

import aiohttp

logger = logging.getLogger(__name__)


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

        Returns
        -------
        bool
            True if the server responds with a healthy status.
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
        """List all OpenCode sessions.

        Returns
        -------
        list[dict]
            Array of session objects from the server.
        """
        session = self._get_session()
        url = f"{self._base_url}/session"

        async with session.get(url, timeout=aiohttp.ClientTimeout(total=10)) as resp:
            resp.raise_for_status()
            data = await resp.json()
            # The API may return a list directly or wrapped in an object
            if isinstance(data, list):
                return data
            return data.get("sessions", data.get("data", []))

    async def get_session(self, session_id: str) -> dict:
        """Get details for a specific session.

        Returns
        -------
        dict
            Session object from the server.
        """
        session = self._get_session()
        url = f"{self._base_url}/session/{session_id}"

        async with session.get(url, timeout=aiohttp.ClientTimeout(total=10)) as resp:
            resp.raise_for_status()
            return await resp.json()

    async def send_message(self, session_id: str, text: str) -> dict:
        """Send a message to an OpenCode session and wait for the response.

        Parameters
        ----------
        session_id:
            The OpenCode session ID.
        text:
            The message text to send.

        Returns
        -------
        dict
            The response from the server (contains message parts).
        """
        session = self._get_session()
        url = f"{self._base_url}/session/{session_id}/message"

        payload = {
            "parts": [{"type": "text", "text": text}],
        }

        async with session.post(
            url,
            json=payload,
            timeout=aiohttp.ClientTimeout(total=300),  # 5 min for long operations
        ) as resp:
            resp.raise_for_status()
            return await resp.json()

    async def abort_session(self, session_id: str) -> bool:
        """Abort a running OpenCode session.

        Returns
        -------
        bool
            True if the abort was successful.
        """
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
        """Delete an OpenCode session.

        Returns
        -------
        bool
            True if the deletion was successful.
        """
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

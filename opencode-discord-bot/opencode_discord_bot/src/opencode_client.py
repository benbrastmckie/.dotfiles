"""Async HTTP client for the OpenCode server REST API.

Communicates with the headless OpenCode agent server using HTTP Basic
authentication (username ``opencode``, password from config). Wraps
aiohttp.ClientSession with typed methods for each endpoint.
"""

from __future__ import annotations

import asyncio
import json
import logging
from concurrent.futures import ThreadPoolExecutor
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError
import base64

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

    def __init__(self, base_url: str, password: str = "") -> None:
        self._base_url = base_url.rstrip("/")
        self._auth = aiohttp.BasicAuth(login="opencode", password=password) if password else None
        self._session: aiohttp.ClientSession | None = None
        self._executor = ThreadPoolExecutor(max_workers=4)

    def _get_session(self) -> aiohttp.ClientSession:
        """Lazily create the aiohttp session."""
        if self._session is None or self._session.closed:
            kwargs = {}
            if self._auth:
                kwargs["auth"] = self._auth
            self._session = aiohttp.ClientSession(**kwargs)
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

    async def send_message(self, session_id: str, text: str) -> dict:
        """Send a message and wait for the assistant response.

        Runs the blocking HTTP call in a thread pool so it never starves
        the asyncio event loop (OpenCode can take minutes for long tasks).
        """
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(
            self._executor, self._send_message_sync, session_id, text
        )

    def _send_message_sync(self, session_id: str, text: str) -> dict:
        """Synchronous HTTP POST that blocks until the response arrives."""
        url = f"{self._base_url}/session/{session_id}/message"
        payload = json.dumps({"parts": [{"type": "text", "text": text}]}).encode()

        req = Request(url, data=payload, method="POST")
        req.add_header("Content-Type", "application/json")
        if self._auth:
            cred = base64.b64encode(
                f"{self._auth.login}:{self._auth.password}".encode()
            ).decode()
            req.add_header("Authorization", f"Basic {cred}")

        try:
            with urlopen(req, timeout=600) as resp:
                body = resp.read()
                if not body:
                    return {}
                return json.loads(body)
        except HTTPError as exc:
            logger.error("OpenCode API error %d: %s", exc.code, exc.reason)
            raise
        except URLError as exc:
            logger.error("OpenCode connection error: %s", exc.reason)
            raise

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

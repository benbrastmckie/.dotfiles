"""JSON-backed session store mapping OpenCode sessions to Discord threads.

Provides persistent storage for session-to-thread links with atomic writes
(temp file + os.replace) and asyncio lock for thread safety.
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import tempfile
from datetime import datetime, timezone

logger = logging.getLogger(__name__)

# Default store path relative to the opencode-discord-bot/ project root
_DEFAULT_STORE_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "data",
)
_DEFAULT_STORE_PATH = os.path.join(_DEFAULT_STORE_DIR, "sessions.json")


class SessionStore:
    """Persistent JSON store for session-to-thread mappings.

    Parameters
    ----------
    path:
        Path to the JSON file. Defaults to ``data/sessions.json`` relative
        to the ``opencode-discord-bot/`` project root.
    """

    def __init__(self, path: str | None = None) -> None:
        self._path = path or _DEFAULT_STORE_PATH
        self._lock = asyncio.Lock()
        self._data: dict[str, dict] = {}
        self._load()

    # ------------------------------------------------------------------
    # Persistence
    # ------------------------------------------------------------------

    def _load(self) -> None:
        """Load sessions from disk."""
        if not os.path.isfile(self._path):
            self._data = {}
            return
        try:
            with open(self._path, "r") as f:
                raw = json.load(f)
            self._data = raw.get("sessions", {})
            logger.info("Loaded %d sessions from %s", len(self._data), self._path)
        except (json.JSONDecodeError, OSError) as exc:
            logger.warning("Failed to load session store: %s", exc)
            self._data = {}

    def _save(self) -> None:
        """Persist sessions to disk with atomic write."""
        store_dir = os.path.dirname(self._path)
        os.makedirs(store_dir, exist_ok=True)

        payload = json.dumps(
            {"sessions": self._data},
            indent=2,
            sort_keys=True,
        )

        # Atomic write: temp file in same directory, then os.replace
        fd, tmp_path = tempfile.mkstemp(
            dir=store_dir, prefix=".sessions_", suffix=".tmp"
        )
        try:
            with os.fdopen(fd, "w") as f:
                f.write(payload)
                f.write("\n")
            os.replace(tmp_path, self._path)
        except Exception:
            # Clean up temp file on failure
            try:
                os.unlink(tmp_path)
            except OSError:
                pass
            raise

    # ------------------------------------------------------------------
    # Public API (all async for caller convenience)
    # ------------------------------------------------------------------

    async def link(
        self,
        session_id: str,
        session_name: str,
        thread_id: str,
        channel_id: str,
        thread_url: str,
        working_directory: str = "",
        server_url: str = "",
    ) -> dict:
        """Link an OpenCode session to a Discord thread.

        Returns the created session entry.
        """
        async with self._lock:
            entry = {
                "session_id": session_id,
                "session_name": session_name,
                "thread_id": thread_id,
                "channel_id": channel_id,
                "thread_url": thread_url,
                "linked_at": datetime.now(timezone.utc).isoformat(),
                "working_directory": working_directory,
                "server_url": server_url,
                "status": "active",
            }
            self._data[session_id] = entry
            self._save()
            logger.info("Linked session %s to thread %s", session_id, thread_id)
            return entry

    async def unlink(self, session_id: str) -> bool:
        """Remove a session link. Returns True if the session existed."""
        async with self._lock:
            if session_id not in self._data:
                return False
            del self._data[session_id]
            self._save()
            logger.info("Unlinked session %s", session_id)
            return True

    def get_by_session(self, session_id: str) -> dict | None:
        """Look up a session by its OpenCode session ID."""
        return self._data.get(session_id)

    def get_by_thread(self, thread_id: str) -> dict | None:
        """Look up a session by its Discord thread ID."""
        for entry in self._data.values():
            if entry.get("thread_id") == thread_id:
                return entry
        return None

    def list_all(self) -> list[dict]:
        """Return all linked sessions."""
        return list(self._data.values())

    async def update_status(self, session_id: str, status: str) -> bool:
        """Update the status of a linked session. Returns True if found."""
        async with self._lock:
            if session_id not in self._data:
                return False
            self._data[session_id]["status"] = status
            self._save()
            return True

    async def update_session_name(self, session_id: str, session_name: str) -> bool:
        """Update the session name for a linked session (title change)."""
        async with self._lock:
            if session_id not in self._data:
                return False
            self._data[session_id]["session_name"] = session_name
            self._save()
            logger.info("Updated session_name for %s to %r", session_id, session_name)
            return True

    async def update_working_directory(self, session_id: str, directory: str) -> bool:
        """Update the working directory for a linked session."""
        async with self._lock:
            if session_id not in self._data:
                return False
            self._data[session_id]["working_directory"] = directory
            self._save()
            logger.info("Updated working_directory for %s to %r", session_id, directory)
            return True

    async def update_server_url(self, session_id: str, server_url: str) -> bool:
        """Update the server URL for a linked session (port rotation)."""
        async with self._lock:
            if session_id not in self._data:
                return False
            self._data[session_id]["server_url"] = server_url
            self._save()
            logger.info("Updated server_url for %s to %s", session_id, server_url)
            return True

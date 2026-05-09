"""Bearer token authentication for the HTTP API.

Validates ``Authorization: Bearer <token>`` headers against the configured
LINK_API_TOKEN. When the token is empty or unset, authentication is skipped
(dev mode).
"""

from __future__ import annotations

import logging

from aiohttp import web

logger = logging.getLogger(__name__)


def check_bearer_token(request: web.Request, expected_token: str) -> web.Response | None:
    """Validate the Bearer token in the request.

    Parameters
    ----------
    request:
        The incoming aiohttp request.
    expected_token:
        The expected token value. If empty, auth is skipped.

    Returns
    -------
    web.Response | None
        A 401 response if auth fails, or None if auth succeeds (or is skipped).
    """
    if not expected_token:
        # No token configured -- skip auth (dev mode)
        return None

    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        logger.warning("Missing or malformed Authorization header from %s", request.remote)
        return web.json_response(
            {"error": "Missing or malformed Authorization header"},
            status=401,
        )

    provided_token = auth_header[len("Bearer "):]
    if provided_token != expected_token:
        logger.warning("Invalid bearer token from %s", request.remote)
        return web.json_response(
            {"error": "Invalid bearer token"},
            status=401,
        )

    return None

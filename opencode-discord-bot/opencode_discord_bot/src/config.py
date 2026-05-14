"""Configuration and credential loading for the Discord bot.

Reads environment variables set by the systemd service unit. Credentials
(DISCORD_BOT_TOKEN, OPENCODE_SERVER_PASSWORD) are file paths injected via
systemd LoadCredential -- the bot reads the file contents at startup. For
local development, literal values are accepted as a fallback when the env
var value is not a valid file path.
"""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass, field

logger = logging.getLogger(__name__)


def read_credential(env_var: str) -> str:
    """Read a credential from a systemd LoadCredential file path or literal value.

    Parameters
    ----------
    env_var:
        Name of the environment variable containing either a file path
        (production, via systemd %d specifier) or a literal secret value
        (development).

    Returns
    -------
    str
        The credential value with leading/trailing whitespace stripped.

    Raises
    ------
    RuntimeError
        If the environment variable is not set or empty.
    """
    raw = os.environ.get(env_var, "")
    if not raw:
        raise RuntimeError(f"Environment variable {env_var} is not set")
    if os.path.isfile(raw):
        with open(raw, "r") as f:
            return f.read().strip()
    # Fallback: treat as literal value (dev mode)
    return raw


@dataclass
class Config:
    """Bot configuration loaded from environment variables.

    Required variables (will raise on missing):
        DISCORD_BOT_TOKEN          - Discord bot token (file path or literal)
        OPENCODE_SERVER_PASSWORD   - OpenCode server password (file path or literal)
        OPENCODE_SERVER_URL        - OpenCode server base URL (should include port)

    Optional variables:
        WHITELISTED_USER_IDS       - Comma-separated Discord user IDs (empty = no filter)
        LINK_API_TOKEN             - Bearer token for the HTTP API (empty = no auth)
        LOG_LEVEL                  - Python logging level (default: info)
        DISCORD_CHANNEL_ID         - Discord channel for thread creation
        BOT_HTTP_PORT              - Port for the local HTTP API (default: 8080)
    """

    discord_bot_token: str = ""
    opencode_server_password: str = ""
    opencode_server_url: str = ""
    whitelisted_user_ids: list[str] = field(default_factory=list)
    link_api_token: str = ""
    log_level: str = "INFO"
    discord_channel_id: int = 0
    bot_http_port: int = 8080

    @classmethod
    def from_env(cls) -> Config:
        """Load configuration from environment variables.

        Returns
        -------
        Config
            Populated configuration instance.

        Raises
        ------
        RuntimeError
            If any required environment variable is missing.
        """
        discord_bot_token = read_credential("DISCORD_BOT_TOKEN")
        opencode_server_password = read_credential("OPENCODE_SERVER_PASSWORD")

        opencode_server_url = os.environ.get("OPENCODE_SERVER_URL", "")
        if not opencode_server_url:
            raise RuntimeError("Environment variable OPENCODE_SERVER_URL is not set")

        whitelist_raw = os.environ.get("WHITELISTED_USER_IDS", "")
        whitelisted_user_ids = [
            uid.strip()
            for uid in whitelist_raw.split(",")
            if uid.strip()
        ]

        try:
            link_api_token = read_credential("LINK_API_TOKEN")
        except RuntimeError:
            link_api_token = ""
        log_level = os.environ.get("LOG_LEVEL", "info").upper()

        try:
            channel_id_raw = read_credential("DISCORD_CHANNEL_ID")
        except RuntimeError:
            channel_id_raw = "0"
        try:
            discord_channel_id = int(channel_id_raw)
        except ValueError:
            logger.warning(
                "DISCORD_CHANNEL_ID=%r is not a valid integer, defaulting to 0",
                channel_id_raw,
            )
            discord_channel_id = 0

        port_raw = os.environ.get("BOT_HTTP_PORT", "8080")
        try:
            bot_http_port = int(port_raw)
        except ValueError:
            logger.warning(
                "BOT_HTTP_PORT=%r is not a valid integer, defaulting to 8080",
                port_raw,
            )
            bot_http_port = 8080

        return cls(
            discord_bot_token=discord_bot_token,
            opencode_server_password=opencode_server_password,
            opencode_server_url=opencode_server_url,
            whitelisted_user_ids=whitelisted_user_ids,
            link_api_token=link_api_token,
            log_level=log_level,
            discord_channel_id=discord_channel_id,
            bot_http_port=bot_http_port,
        )

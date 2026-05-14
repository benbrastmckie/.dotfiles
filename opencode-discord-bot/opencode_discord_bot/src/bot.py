"""Discord bot entry point.

Run with: python -m opencode_discord_bot.src.bot
Requires PYTHONPATH to include the opencode-discord-bot/ directory.

This module creates the DiscordBot instance, wires up the HTTP API server
and message relay, then starts the bot.
"""

from __future__ import annotations

import asyncio
import logging
import signal
import time

import nextcord
from aiohttp import web
from nextcord.ext import commands

from opencode_discord_bot.src.api import setup_api
from opencode_discord_bot.src.config import Config
from opencode_discord_bot.src.logging_config import setup_logging
from opencode_discord_bot.src.opencode_client import OpenCodeClient
from opencode_discord_bot.src.relay import (
    relay_response_to_thread,
    relay_to_opencode,
)
from opencode_discord_bot.src.store import SessionStore

logger = logging.getLogger(__name__)


class DiscordBot(commands.Bot):
    """Nextcord bot with integrated aiohttp HTTP API server.

    Bridges Discord threads to OpenCode sessions. Serves a local HTTP API
    for Neovim integration (POST /link, GET /sessions, POST /kill, GET /health).
    """

    def __init__(self, config: Config) -> None:
        intents = nextcord.Intents.default()
        intents.message_content = True
        super().__init__(intents=intents)

        self.config = config
        self.session_store = SessionStore()
        self.opencode_client = OpenCodeClient(
            base_url=config.opencode_server_url,
            password=config.opencode_server_password,
        )
        self._extra_clients: dict[str, OpenCodeClient] = {}
        self.http_app = web.Application()
        self.http_runner: web.AppRunner | None = None
        self.start_time = time.time()

    async def start(self, token: str, **kwargs) -> None:
        """Start the HTTP API server, then connect to Discord.

        Overrides Client.start() because this version of nextcord does not
        call setup_hook(), so HTTP server startup must happen here instead.
        """
        setup_api(self.http_app, self)

        self.http_runner = web.AppRunner(self.http_app)
        await self.http_runner.setup()
        site = web.TCPSite(self.http_runner, "127.0.0.1", self.config.bot_http_port)
        await site.start()
        logger.info(
            "HTTP API server started on http://127.0.0.1:%d",
            self.config.bot_http_port,
        )

        await super().start(token, **kwargs)

    async def on_ready(self) -> None:
        """Called when the bot has connected to Discord."""
        logger.info(
            "Bot connected as %s (guilds: %d, HTTP API: port %d)",
            self.user,
            len(self.guilds),
            self.config.bot_http_port,
        )
        # Non-blocking health check of OpenCode server
        try:
            healthy = await self.opencode_client.health()
            if healthy:
                logger.info("OpenCode server health check passed")
            else:
                logger.warning(
                    "OpenCode server health check failed -- "
                    "server may not be ready yet"
                )
        except Exception:
            logger.warning(
                "Could not reach OpenCode server at %s -- "
                "server may start later",
                self.config.opencode_server_url,
                exc_info=True,
            )

    async def on_message(self, message: nextcord.Message) -> None:
        """Handle messages in linked Discord threads.

        Relays user messages from linked threads to the corresponding
        OpenCode session and posts the response back to the thread.
        """
        # Ignore bot's own messages
        if message.author == self.user:
            return

        # Only handle messages in threads
        if not isinstance(message.channel, nextcord.Thread):
            return

        # Check if this thread is linked to a session
        session = self.session_store.get_by_thread(str(message.channel.id))
        if session is None:
            return

        # Check whitelist if configured
        if self.config.whitelisted_user_ids:
            if str(message.author.id) not in self.config.whitelisted_user_ids:
                logger.debug(
                    "Ignoring message from non-whitelisted user %s",
                    message.author.id,
                )
                return

        session_id = session["session_id"]
        server_url = session.get("server_url", "")
        logger.info(
            "Relaying message from thread %s to session %s (server=%s): %s",
            message.channel.id,
            session_id,
            server_url or "default",
            message.content[:100],
        )

        asyncio.create_task(
            self._relay_and_respond(message.channel, session_id, message.content, server_url)
        )

    def _get_client_for_url(self, server_url: str) -> OpenCodeClient:
        """Get or create an OpenCodeClient for a given server URL."""
        if not server_url:
            return self.opencode_client
        if server_url not in self._extra_clients:
            # TUI instances don't use auth
            self._extra_clients[server_url] = OpenCodeClient(base_url=server_url)
        return self._extra_clients[server_url]

    async def _relay_and_respond(
        self,
        thread: nextcord.Thread,
        session_id: str,
        text: str,
        server_url: str = "",
    ) -> None:
        """Background task: relay message to OpenCode and post response."""
        try:
            client = self._get_client_for_url(server_url)
            response_text = await relay_to_opencode(
                client, session_id, text
            )
            await relay_response_to_thread(thread, response_text)
        except Exception as exc:
            logger.error(
                "Error relaying message to session %s: %s",
                session_id,
                exc,
                exc_info=True,
            )
            try:
                error_msg = str(exc)
                if "ClientError" in type(exc).__name__ or "ConnectionError" in type(exc).__name__:
                    error_msg = "OpenCode server unavailable -- is the service running?"
                await thread.send(
                    f"Error communicating with OpenCode: {error_msg}"
                )
            except Exception:
                logger.error("Failed to send error message to thread", exc_info=True)

    async def close(self) -> None:
        """Clean up resources on shutdown."""
        logger.info("Shutting down bot...")
        if self.http_runner:
            await self.http_runner.cleanup()
            logger.info("HTTP API server stopped")
        await self.opencode_client.close()
        for client in self._extra_clients.values():
            await client.close()
        self._extra_clients.clear()
        logger.info("OpenCode client(s) closed")
        await super().close()
        logger.info("Discord gateway closed")


def _handle_signal(bot: DiscordBot, sig: signal.Signals) -> None:
    """Handle termination signals for graceful shutdown."""
    logger.info("Received signal %s, initiating graceful shutdown...", sig.name)
    asyncio.get_event_loop().create_task(bot.close())


def main() -> None:
    """Entry point for the Discord bot."""
    config = Config.from_env()
    setup_logging(config.log_level)

    logger.info("Starting Discord bot...")
    logger.info("OpenCode server URL: %s", config.opencode_server_url)
    logger.info("HTTP API port: %d", config.bot_http_port)
    if config.discord_channel_id:
        logger.info("Discord channel ID: %d", config.discord_channel_id)
    if config.whitelisted_user_ids:
        logger.info(
            "Whitelisted user IDs: %s",
            ", ".join(config.whitelisted_user_ids),
        )

    bot = DiscordBot(config)

    # Register signal handlers for graceful shutdown
    loop = asyncio.new_event_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, _handle_signal, bot, sig)

    try:
        loop.run_until_complete(bot.start(config.discord_bot_token))
    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received")
    finally:
        if not bot.is_closed():
            loop.run_until_complete(bot.close())
        loop.close()
        logger.info("Bot shutdown complete")


if __name__ == "__main__":
    main()

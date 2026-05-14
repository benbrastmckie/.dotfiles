"""HTTP API server routes for Neovim integration.

Serves four endpoints on the local aiohttp web server:
- POST /link     -- Link an OpenCode session to a Discord thread
- GET  /sessions -- List all linked sessions
- POST /kill     -- Abort and unlink a session
- GET  /health   -- Health check
"""

from __future__ import annotations

import logging
import time

from aiohttp import web

from opencode_discord_bot.src.auth import check_bearer_token
from opencode_discord_bot.src.relay import _build_thread_name, create_session_thread

logger = logging.getLogger(__name__)


def setup_api(app: web.Application, bot: object) -> None:
    """Register HTTP API routes on the aiohttp application.

    Parameters
    ----------
    app:
        The aiohttp web application.
    bot:
        The DiscordBot instance (provides config, session_store,
        opencode_client, and Discord channel access).
    """
    app["bot"] = bot
    app.router.add_post("/link", _handle_link)
    app.router.add_get("/sessions", _handle_sessions)
    app.router.add_post("/kill", _handle_kill)
    app.router.add_get("/health", _handle_health)


async def _handle_link(request: web.Request) -> web.Response:
    """POST /link -- Link an OpenCode session to a new Discord thread.

    Request body:
        {"session_id": "ses_...", "session_name": "project-name"}

    Success response (200):
        {"thread_url": "https://discord.com/channels/..."}

    Already linked (409):
        {"thread_url": "https://discord.com/channels/..."}
    """
    bot = request.app["bot"]
    auth_err = check_bearer_token(request, bot.config.link_api_token)
    if auth_err:
        return auth_err

    try:
        body = await request.json()
    except Exception:
        return web.json_response(
            {"error": "Invalid JSON body"},
            status=400,
        )

    session_id = body.get("session_id")
    session_name = body.get("session_name", "")
    server_url = body.get("server_url", "")
    directory = body.get("directory", "")

    if not session_id:
        return web.json_response(
            {"error": "Missing required field: session_id"},
            status=400,
        )

    # Check if already linked — update server_url / thread name if changed
    existing = bot.session_store.get_by_session(session_id)
    if existing:
        updated = False

        # Update server_url on port rotation
        old_url = existing.get("server_url", "")
        if server_url and server_url != old_url:
            await bot.session_store.update_server_url(session_id, server_url)
            logger.info(
                "Updated server_url for session %s: %s -> %s",
                session_id, old_url, server_url,
            )
            updated = True

        # Update thread name if title, directory, or format changed
        old_name = existing.get("session_name", "")
        old_dir = existing.get("working_directory", "")
        new_thread_name = _build_thread_name(
            session_name or old_name, session_id, directory or old_dir,
        )
        try:
            thread = bot.get_channel(int(existing["thread_id"]))
            if thread and thread.name != new_thread_name:
                await thread.edit(name=new_thread_name)
                logger.info(
                    "Renamed thread %s: %r -> %r",
                    existing["thread_id"], thread.name, new_thread_name,
                )
                updated = True
        except Exception as exc:
            logger.warning("Failed to rename thread for session %s: %s", session_id, exc)

        if session_name and session_name != old_name:
            await bot.session_store.update_session_name(session_id, session_name)
            updated = True
        if directory and directory != old_dir:
            await bot.session_store.update_working_directory(session_id, directory)
            updated = True

        if updated:
            return web.json_response(
                {"thread_url": existing["thread_url"], "updated": True},
                status=200,
            )
        logger.info("Session %s already linked to thread %s", session_id, existing["thread_id"])
        return web.json_response(
            {"thread_url": existing["thread_url"]},
            status=409,
        )

    # Create Discord thread and link
    try:
        thread, thread_url = await create_session_thread(
            bot,
            bot.config.discord_channel_id,
            session_id,
            session_name,
            directory,
        )

        await bot.session_store.link(
            session_id=session_id,
            session_name=session_name,
            thread_id=str(thread.id),
            channel_id=str(bot.config.discord_channel_id),
            thread_url=thread_url,
            working_directory=directory,
            server_url=server_url,
        )

        logger.info("Linked session %s to thread %s", session_id, thread_url)
        return web.json_response({"thread_url": thread_url})

    except ValueError as exc:
        return web.json_response(
            {"error": str(exc)},
            status=400,
        )
    except Exception as exc:
        logger.error("Failed to create thread for session %s: %s", session_id, exc, exc_info=True)
        return web.json_response(
            {"error": f"Failed to create Discord thread: {exc}"},
            status=500,
        )


async def _handle_sessions(request: web.Request) -> web.Response:
    """GET /sessions -- List all linked sessions.

    Response (200):
        {"sessions": [{session_id, session_name, name, id, status, ...}, ...]}
    """
    bot = request.app["bot"]
    auth_err = check_bearer_token(request, bot.config.link_api_token)
    if auth_err:
        return auth_err

    sessions = bot.session_store.list_all()

    # Provide redundant fields to satisfy the Neovim client
    enriched = []
    for s in sessions:
        entry = dict(s)
        # Redundant field aliases expected by the Neovim picker
        entry.setdefault("id", entry.get("session_id", ""))
        entry.setdefault("name", entry.get("session_name", ""))
        entry.setdefault("cwd", entry.get("working_directory", ""))
        entry.setdefault("thread_channel", "")
        enriched.append(entry)

    return web.json_response({"sessions": enriched})


async def _handle_kill(request: web.Request) -> web.Response:
    """POST /kill -- Abort and unlink a session.

    Request body:
        {"session_id": "ses_..."}

    Success response (200):
        {"status": "killed"}
    """
    bot = request.app["bot"]
    auth_err = check_bearer_token(request, bot.config.link_api_token)
    if auth_err:
        return auth_err

    try:
        body = await request.json()
    except Exception:
        return web.json_response(
            {"error": "Invalid JSON body"},
            status=400,
        )

    session_id = body.get("session_id")
    if not session_id:
        return web.json_response(
            {"error": "Missing required field: session_id"},
            status=400,
        )

    # Attempt to abort the session on the OpenCode server
    try:
        await bot.opencode_client.abort_session(session_id)
    except Exception as exc:
        logger.warning("Failed to abort session %s on OpenCode server: %s", session_id, exc)

    # Unlink from store regardless
    await bot.session_store.unlink(session_id)

    logger.info("Killed and unlinked session %s", session_id)
    return web.json_response({"status": "killed"})


async def _handle_health(request: web.Request) -> web.Response:
    """GET /health -- Health check endpoint.

    Response (200):
        {"healthy": true, "version": "1.0.0", "uptime": 3600,
         "discord_connected": true, "opencode_connected": true,
         "linked_sessions": 3}
    """
    bot = request.app["bot"]

    discord_connected = bot.is_ready()

    try:
        opencode_connected = await bot.opencode_client.health(retries=1, backoff=0.5)
    except Exception:
        opencode_connected = False

    uptime = int(time.time() - bot.start_time)
    linked_sessions = len(bot.session_store.list_all())

    return web.json_response({
        "healthy": discord_connected and opencode_connected,
        "version": "1.0.0",
        "uptime": uptime,
        "discord_connected": discord_connected,
        "opencode_connected": opencode_connected,
        "linked_sessions": linked_sessions,
    })

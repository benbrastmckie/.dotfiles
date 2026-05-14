"""Thread creation and message relay between Discord and OpenCode.

Handles creating Discord threads for linked sessions and relaying
messages between threads and OpenCode sessions.
"""

from __future__ import annotations

import logging
import os
import re

import aiohttp
import nextcord

logger = logging.getLogger(__name__)


def _build_thread_name(session_name: str, session_id: str, directory: str) -> str:
    """Build a Discord thread name from session metadata.

    Format: ``{dir} #{task}: {label}`` when a task number is found in the
    session name, otherwise ``{dir}: {session_name}``, falling back to
    ``{session_id[:12]}`` when no name is provided.  Discord truncates
    thread names to 100 characters.
    """
    dir_label = os.path.basename(directory.rstrip("/")) if directory else ""
    label = session_name or session_id[:12]

    task_match = re.search(r"task\s+(\d+)", label, re.IGNORECASE)
    if dir_label and task_match:
        task_num = task_match.group(1)
        name = f"{dir_label} #{task_num}: {label}"
    elif dir_label:
        name = f"{dir_label}: {label}"
    else:
        name = label

    return name[:100]


async def create_session_thread(
    bot: object,
    channel_id: int,
    session_id: str,
    session_name: str,
    directory: str = "",
) -> tuple[nextcord.Thread, str]:
    """Create a Discord thread linked to an OpenCode session.

    Parameters
    ----------
    bot:
        The DiscordBot instance.
    channel_id:
        The Discord channel ID to create the thread in.
    session_id:
        The OpenCode session ID.
    session_name:
        A human-readable name for the session.
    directory:
        Working directory of the OpenCode session.

    Returns
    -------
    tuple[nextcord.Thread, str]
        The created thread and its URL.

    Raises
    ------
    ValueError
        If the channel_id is not set or the channel cannot be found.
    """
    if not channel_id:
        raise ValueError(
            "DISCORD_CHANNEL_ID is not configured -- "
            "set the environment variable to the target channel ID"
        )

    channel = bot.get_channel(channel_id)
    if channel is None:
        raise ValueError(
            f"Could not find Discord channel {channel_id} -- "
            "ensure the bot has access to the channel"
        )

    thread_name = _build_thread_name(session_name, session_id, directory)

    thread = await channel.create_thread(
        name=thread_name,
        type=nextcord.ChannelType.public_thread,
        auto_archive_duration=10080,  # 7 days
    )

    await thread.send(f"Linked to OpenCode session `{session_id}`")

    # Build the thread URL
    guild_id = channel.guild.id if hasattr(channel, "guild") else 0
    thread_url = f"https://discord.com/channels/{guild_id}/{thread.id}"

    logger.info(
        "Created thread %s (%s) for session %s",
        thread.name,
        thread_url,
        session_id,
    )

    return thread, thread_url


async def relay_to_opencode(
    opencode_client: object,
    session_id: str,
    message_text: str,
) -> str:
    """Send a message to an OpenCode session and return the response text."""
    response = await opencode_client.send_message(session_id, message_text)
    if not response:
        return "(No response from OpenCode)"

    text_parts = []
    for part in response.get("parts", []):
        if isinstance(part, dict) and part.get("type") == "text":
            text_parts.append(part.get("text", ""))

    if text_parts:
        return "\n".join(text_parts)

    return "(No text response from OpenCode)"


def split_discord_message(text: str, limit: int = 2000) -> list[str]:
    """Split a long text into chunks that fit Discord's message limit.

    Splits at newline boundaries when possible, falling back to hard
    splits at the character limit.

    Parameters
    ----------
    text:
        The text to split.
    limit:
        Maximum characters per chunk (default: 2000, Discord's limit).

    Returns
    -------
    list[str]
        List of message chunks, each within the limit.
    """
    if not text:
        return ["(empty response)"]

    if len(text) <= limit:
        return [text]

    chunks = []
    remaining = text

    while remaining:
        if len(remaining) <= limit:
            chunks.append(remaining)
            break

        # Try to split at a newline boundary
        split_pos = remaining.rfind("\n", 0, limit)
        if split_pos <= 0:
            # No good newline break -- hard split
            split_pos = limit

        chunk = remaining[:split_pos]
        remaining = remaining[split_pos:].lstrip("\n")
        chunks.append(chunk)

    return chunks


async def relay_response_to_thread(
    thread: nextcord.Thread,
    response_text: str,
) -> None:
    """Send a response to a Discord thread, splitting if necessary.

    Parameters
    ----------
    thread:
        The Discord thread to send to.
    response_text:
        The response text from OpenCode.
    """
    chunks = split_discord_message(response_text)
    for chunk in chunks:
        await thread.send(chunk)

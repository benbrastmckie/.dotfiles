"""Discord UI components for OpenCode permission approval.

Provides a persistent View with Approve Once / Approve Always / Reject
buttons that call the OpenCode permission reply API when clicked.  Also
includes an embed builder for formatting permission request details.
"""

from __future__ import annotations

import logging

import nextcord
from nextcord.ui import Button, View, button

from opencode_discord_bot.src.opencode_client import OpenCodeClient

logger = logging.getLogger(__name__)

# Embed colours
COLOUR_PERMISSION = 0xFF9800  # orange — attention-grabbing
COLOUR_APPROVED = 0x4CAF50  # green
COLOUR_REJECTED = 0xF44336  # red

# Permission type display names
PERMISSION_LABELS = {
    "bash": "Shell Command",
    "read": "File Read",
    "edit": "File Edit",
    "glob": "File Glob",
    "grep": "Content Search",
    "external_directory": "External Directory",
    "doom_loop": "Doom Loop Detection",
    "task": "Subagent Launch",
    "webfetch": "Web Fetch",
    "websearch": "Web Search",
}


def make_permission_embed(
    request_id: str,
    permission_type: str,
    patterns: list[str],
    session_id: str,
    metadata: dict | None = None,
    always_patterns: list[str] | None = None,
) -> nextcord.Embed:
    """Build a rich embed for a permission request.

    Parameters
    ----------
    request_id:
        The permission request ID.
    permission_type:
        Permission type string (e.g. "bash", "read", "edit").
    patterns:
        The specific patterns/commands being requested.
    session_id:
        The session that triggered the permission.
    metadata:
        Additional context from the permission request.
    always_patterns:
        Patterns that "Approve Always" would cover.
    """
    label = PERMISSION_LABELS.get(permission_type, permission_type.title())
    embed = nextcord.Embed(
        title=f"Permission Required: {label}",
        colour=COLOUR_PERMISSION,
    )

    # Show the requested patterns (commands, file paths, etc.)
    if patterns:
        pattern_text = "\n".join(f"`{p}`" for p in patterns[:10])
        if len(patterns) > 10:
            pattern_text += f"\n... and {len(patterns) - 10} more"
        embed.add_field(name="Requested", value=pattern_text, inline=False)

    # Show what "Always" would approve
    if always_patterns:
        always_text = "\n".join(f"`{p}`" for p in always_patterns[:5])
        embed.add_field(
            name="Always would approve",
            value=always_text,
            inline=False,
        )

    embed.add_field(name="Type", value=f"`{permission_type}`", inline=True)
    embed.set_footer(text=f"Request {request_id[:16]} | Session {session_id[:12]}")

    return embed


class PermissionApprovalView(View):
    """Persistent view with approve/deny buttons for permission requests.

    Parameters
    ----------
    request_id:
        The permission request ID (used in custom_id for persistence).
    server_url:
        The OpenCode server URL to send the reply to.
    whitelisted_user_ids:
        List of Discord user IDs allowed to interact with buttons.
        Empty list means no restriction.
    """

    def __init__(
        self,
        request_id: str,
        server_url: str,
        whitelisted_user_ids: list[str] | None = None,
    ) -> None:
        # Persistent view: timeout=None, custom_ids encode request_id
        super().__init__(timeout=None)
        self.request_id = request_id
        self.server_url = server_url
        self.whitelisted_user_ids = whitelisted_user_ids or []

        # Dynamically add buttons with unique custom_ids
        approve_once_btn = Button(
            label="Approve Once",
            style=nextcord.ButtonStyle.green,
            custom_id=f"perm_once:{request_id}",
        )
        approve_once_btn.callback = self._approve_once_callback
        self.add_item(approve_once_btn)

        approve_always_btn = Button(
            label="Approve Always",
            style=nextcord.ButtonStyle.blurple,
            custom_id=f"perm_always:{request_id}",
        )
        approve_always_btn.callback = self._approve_always_callback
        self.add_item(approve_always_btn)

        reject_btn = Button(
            label="Reject",
            style=nextcord.ButtonStyle.red,
            custom_id=f"perm_reject:{request_id}",
        )
        reject_btn.callback = self._reject_callback
        self.add_item(reject_btn)

    def _is_authorized(self, user_id: str) -> bool:
        """Check if the user is authorized to interact with this view."""
        if not self.whitelisted_user_ids:
            return True
        return user_id in self.whitelisted_user_ids

    async def _approve_once_callback(self, interaction: nextcord.Interaction) -> None:
        await self._reply_permission(interaction, "once")

    async def _approve_always_callback(self, interaction: nextcord.Interaction) -> None:
        await self._reply_permission(interaction, "always")

    async def _reject_callback(self, interaction: nextcord.Interaction) -> None:
        await self._reply_permission(interaction, "reject")

    async def _reply_permission(
        self, interaction: nextcord.Interaction, reply_type: str
    ) -> None:
        """Send permission reply to OpenCode and update the Discord message."""
        # Check authorization
        if not self._is_authorized(str(interaction.user.id)):
            await interaction.response.send_message(
                "You are not authorized to respond to permission requests.",
                ephemeral=True,
            )
            return

        # Defer to avoid timeout while we call the API
        await interaction.response.defer(ephemeral=False)

        # Call OpenCode permission reply API
        client = OpenCodeClient(base_url=self.server_url)
        try:
            success = await client.reply_permission(self.request_id, reply_type)
        except Exception as exc:
            logger.error(
                "Failed to reply to permission %s: %s",
                self.request_id, exc, exc_info=True,
            )
            success = False
        finally:
            await client.close()

        # Update the message to reflect the outcome
        if success:
            action_label = {
                "once": "Approved (once)",
                "always": "Approved (always)",
                "reject": "Rejected",
            }.get(reply_type, reply_type)

            colour = COLOUR_APPROVED if reply_type != "reject" else COLOUR_REJECTED

            embed = nextcord.Embed(
                title=f"Permission {action_label}",
                colour=colour,
            )
            embed.add_field(
                name="Resolved by",
                value=interaction.user.mention,
                inline=True,
            )
            embed.set_footer(text=f"Request {self.request_id[:16]}")

            # Disable all buttons
            for item in self.children:
                if isinstance(item, Button):
                    item.disabled = True

            await interaction.edit_original_message(embed=embed, view=self)
        else:
            # Permission may have expired or session died
            embed = nextcord.Embed(
                title="Permission Expired",
                description="This permission request may have already been resolved or the session has ended.",
                colour=COLOUR_REJECTED,
            )
            embed.set_footer(text=f"Request {self.request_id[:16]}")

            for item in self.children:
                if isinstance(item, Button):
                    item.disabled = True

            await interaction.edit_original_message(embed=embed, view=self)

        self.stop()

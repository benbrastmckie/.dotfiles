"""Allow running the bot source package as a module.

This enables: python -m opencode_discord_bot.src
However, the primary entry point is: python -m opencode_discord_bot.src.bot
which runs bot.py directly (bot.py has its own if __name__ == '__main__' block).
"""

from opencode_discord_bot.src.bot import main

main()

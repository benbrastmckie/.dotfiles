"""Structured logging setup for the Discord bot.

Configures Python logging with a structured format suitable for systemd
journal output (timestamp, level, logger name, message).
"""

from __future__ import annotations

import logging
import sys


def setup_logging(level: str = "INFO") -> None:
    """Configure the root logger with structured output.

    Parameters
    ----------
    level:
        Logging level string (DEBUG, INFO, WARNING, ERROR, CRITICAL).
    """
    numeric_level = getattr(logging, level.upper(), logging.INFO)

    formatter = logging.Formatter(
        fmt="%(asctime)s [%(levelname)-8s] %(name)s: %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S",
    )

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(formatter)

    root = logging.getLogger()
    root.setLevel(numeric_level)
    # Remove any existing handlers to avoid duplicate output
    root.handlers.clear()
    root.addHandler(handler)

    # Silence noisy libraries at INFO level
    logging.getLogger("nextcord").setLevel(max(numeric_level, logging.WARNING))
    logging.getLogger("aiohttp").setLevel(max(numeric_level, logging.WARNING))

"""
Structured Logging System for Cognify AI Backend.
Provides colored console output + file logging with rotation.
"""

import logging
import sys
from pathlib import Path
from logging.handlers import RotatingFileHandler
import re

# Log directory
LOG_DIR = Path("logs")
LOG_DIR.mkdir(exist_ok=True)

class SafeFilter(logging.Filter):
    """Prevents sensitive data (like therapy messages and API keys) from being logged."""
    def filter(self, record):
        msg = str(record.msg)
        # Redact therapy or specific keywords
        if "user_message" in msg or "therapy_messages" in msg.lower():
            record.msg = "[REDACTED SENSITIVE CHAT DATA]"
        elif re.search(r"(ey[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+)", msg):
            record.msg = re.sub(r"(ey[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+)", "[REDACTED JWT]", msg)
        return True


class ColorFormatter(logging.Formatter):
    """Custom formatter with color-coded log levels for console output."""

    COLORS = {
        "DEBUG": "\033[36m",     # Cyan
        "INFO": "\033[32m",      # Green
        "WARNING": "\033[33m",   # Yellow
        "ERROR": "\033[31m",     # Red
        "CRITICAL": "\033[35m",  # Magenta
    }
    RESET = "\033[0m"

    def format(self, record):
        color = self.COLORS.get(record.levelname, self.RESET)
        record.levelname = f"{color}{record.levelname}{self.RESET}"
        return super().format(record)


def setup_logging(debug: bool = False) -> logging.Logger:
    """
    Initialize the application-wide logging system.

    - Console: colored output with INFO+ level
    - File: rotating log file (5MB max, 3 backups) with DEBUG level
    """
    logger = logging.getLogger("cognify")
    logger.setLevel(logging.DEBUG if debug else logging.INFO)

    # Prevent duplicate handlers on reload
    if logger.handlers:
        return logger

    # ── Console Handler ──
    console = logging.StreamHandler(sys.stdout)
    console.setLevel(logging.DEBUG if debug else logging.INFO)
    console.setFormatter(ColorFormatter(
        fmt="%(asctime)s │ %(levelname)-18s │ %(name)s │ %(message)s",
        datefmt="%H:%M:%S",
    ))
    logger.addHandler(console)

    # ── File Handler (rotating) ──
    file_handler = RotatingFileHandler(
        LOG_DIR / "cognify.log",
        maxBytes=5 * 1024 * 1024,  # 5 MB
        backupCount=3,
        encoding="utf-8",
    )
    file_handler.addFilter(SafeFilter())
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(logging.Formatter(
        fmt="%(asctime)s | %(levelname)-8s | %(name)s | %(funcName)s:%(lineno)d | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    ))
    logger.addHandler(file_handler)

    logger.info("Logging system initialized ✅")
    return logger


def get_logger(name: str) -> logging.Logger:
    """Get a child logger for a specific module."""
    return logging.getLogger(f"cognify.{name}")

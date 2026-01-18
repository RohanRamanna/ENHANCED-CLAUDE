#!/usr/bin/env python3
"""
Shared logging utility for Claude Code hooks.

Usage:
    from hook_logger import HookLogger
    logger = HookLogger("hook-name")
    logger.info("Processing started")
    logger.error("Something went wrong", exc_info=True)
"""

import os
import json
import traceback
from datetime import datetime
from pathlib import Path

# Log directory
LOG_DIR = Path(os.path.expanduser("~/.claude/hooks/logs"))

# Max log file size (1MB)
MAX_LOG_SIZE = 1_000_000

# Max log files to keep per hook
MAX_LOG_FILES = 3


class HookLogger:
    def __init__(self, hook_name: str):
        self.hook_name = hook_name
        self.log_dir = LOG_DIR
        self.log_dir.mkdir(parents=True, exist_ok=True)
        self.log_file = self.log_dir / f"{hook_name}.log"
        self._rotate_if_needed()

    def _rotate_if_needed(self):
        """Rotate log file if it exceeds max size."""
        if self.log_file.exists() and self.log_file.stat().st_size > MAX_LOG_SIZE:
            # Rotate existing logs
            for i in range(MAX_LOG_FILES - 1, 0, -1):
                old_file = self.log_dir / f"{self.hook_name}.{i}.log"
                new_file = self.log_dir / f"{self.hook_name}.{i + 1}.log"
                if old_file.exists():
                    if i + 1 >= MAX_LOG_FILES:
                        old_file.unlink()  # Delete oldest
                    else:
                        old_file.rename(new_file)

            # Rotate current to .1
            backup = self.log_dir / f"{self.hook_name}.1.log"
            self.log_file.rename(backup)

    def _write(self, level: str, message: str, **kwargs):
        """Write a log entry."""
        timestamp = datetime.now().isoformat()

        entry = {
            "timestamp": timestamp,
            "level": level,
            "hook": self.hook_name,
            "message": message
        }

        # Add any extra data
        if kwargs.get("exc_info"):
            entry["traceback"] = traceback.format_exc()

        if kwargs.get("data"):
            entry["data"] = kwargs["data"]

        try:
            with open(self.log_file, "a") as f:
                f.write(json.dumps(entry) + "\n")
        except Exception:
            pass  # Don't let logging errors break the hook

    def debug(self, message: str, **kwargs):
        self._write("DEBUG", message, **kwargs)

    def info(self, message: str, **kwargs):
        self._write("INFO", message, **kwargs)

    def warning(self, message: str, **kwargs):
        self._write("WARNING", message, **kwargs)

    def error(self, message: str, **kwargs):
        self._write("ERROR", message, **kwargs)

    def log_input(self, hook_input: dict):
        """Log the hook input (sanitized)."""
        sanitized = {
            "prompt_length": len(hook_input.get("prompt", "")),
            "prompt_preview": hook_input.get("prompt", "")[:100],
            "cwd": hook_input.get("cwd", ""),
            "has_transcript": bool(hook_input.get("transcript_path")),
        }
        self.debug("Hook input received", data=sanitized)

    def log_output(self, output: dict):
        """Log the hook output."""
        self.debug("Hook output", data=output)

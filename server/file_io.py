"""
File-based I/O implementation for Balatro MCP Server.
Handles communication with the Balatro mod through JSON files.
"""

import json
import asyncio
import os
from pathlib import Path
from typing import Optional
from datetime import datetime, timezone
import logging
import re

from .interfaces import IFileIO
from .schemas import (
    GameState,
    GameAction,
    ActionResult,
    CommunicationMessage,
    MessageType,
)


logger = logging.getLogger(__name__)


class BalatroFileIO(IFileIO):
    """File-based I/O implementation for communicating with Balatro mod."""

    # Allowed file extensions for communication files
    ALLOWED_EXTENSIONS = {".json", ".tmp"}

    # Maximum path length to prevent excessively long paths
    MAX_PATH_LENGTH = 260

    # Blocked path patterns (case-insensitive)
    BLOCKED_PATTERNS = [
        r"\.\.[\\/]",  # Directory traversal patterns
        r"[\\/]\.\.[\\/]",  # Directory traversal in middle of path
        r"[\\/]\.\.$",  # Directory traversal at end
        r"^\.\.[\\/]",  # Directory traversal at start
        r"^\.\.?$",  # Just .. or .
        r"[\x00-\x1f\x7f-\x9f]",  # Control characters
        r'[<>"|?*]',  # Windows reserved characters (excluding colon for drive letters)
        r"(?:^|[\\/])(?:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?$",  # Windows reserved names
    ]

    def __init__(self, base_path: str = "shared"):
        """Initialize file I/O with base path for communication files."""
        validated_path = self._validate_and_sanitize_path(base_path)
        self.base_path = Path(validated_path)
        self.base_path.mkdir(exist_ok=True)

        # Communication file paths
        self.game_state_file = self.base_path / "game_state.json"
        self.actions_file = self.base_path / "actions.json"
        self.action_results_file = self.base_path / "action_results.json"

        # Sequence tracking
        self._sequence_id = 0
        self._last_read_sequence = {}

        logger.info(f"BalatroFileIO initialized with base path: {self.base_path}")

    def _validate_and_sanitize_path(self, path: str) -> str:
        """
        Validate and sanitize file paths to prevent directory traversal attacks.

        Args:
            path: The path to validate and sanitize

        Returns:
            The sanitized path

        Raises:
            ValueError: If the path is invalid or potentially malicious
        """
        if not path or not isinstance(path, str):
            raise ValueError("Path must be a non-empty string")

        # Check path length
        if len(path) > self.MAX_PATH_LENGTH:
            logger.warning(f"Path too long: {len(path)} characters")
            raise ValueError(
                f"Path exceeds maximum length of {self.MAX_PATH_LENGTH} characters"
            )

        # Check for blocked patterns
        for pattern in self.BLOCKED_PATTERNS:
            if re.search(pattern, path, re.IGNORECASE):
                logger.warning(f"Blocked path pattern detected: {path}")
                raise ValueError(
                    "Path contains invalid or potentially dangerous characters/patterns"
                )

        # Convert to Path object for normalization
        try:
            path_obj = Path(path)
        except (ValueError, OSError) as e:
            logger.warning(f"Invalid path format: {path} - {e}")
            raise ValueError(f"Invalid path format: {e}")

        # Check for directory traversal in the original path before resolution
        if ".." in path_obj.parts:
            logger.warning(f"Directory traversal attempt in path: {path}")
            raise ValueError("Directory traversal not allowed")

        # For relative paths, keep them relative for normal operation
        # For absolute paths, validate they're in safe locations
        if path_obj.is_absolute():
            try:
                resolved_path = path_obj.resolve()
                resolved_str = str(resolved_path)

                # Get the current working directory for safety checks
                cwd = Path.cwd().resolve()
                cwd_str = str(cwd)

                # Allow if it's a child of cwd or temp/test directory
                is_child_of_cwd = resolved_str.startswith(cwd_str)
                is_temp_or_test = any(
                    marker in resolved_str.lower()
                    for marker in ["tmp", "temp", "test", "pytest"]
                )

                if not (is_child_of_cwd or is_temp_or_test):
                    logger.warning(
                        f"Absolute path outside allowed directories: {resolved_str}"
                    )
                    raise ValueError("Absolute path is outside allowed directories")

                logger.debug(f"Absolute path validated: {path} -> {resolved_str}")
                return str(resolved_path)

            except (OSError, RuntimeError) as e:
                logger.warning(f"Path resolution failed: {path} - {e}")
                raise ValueError(f"Path resolution failed: {e}")
        else:
            # For relative paths, validate they don't try to escape upwards
            # but preserve them as relative paths for normal operation
            try:
                # Normalize the path to check for hidden traversal
                normalized = path_obj.resolve()
                cwd = Path.cwd().resolve()

                # If resolving a relative path takes us outside cwd, it's suspicious
                if not str(normalized).startswith(str(cwd)):
                    # Unless it's clearly a temp/test directory
                    if not any(
                        marker in str(normalized).lower()
                        for marker in ["tmp", "temp", "test", "pytest"]
                    ):
                        logger.warning(
                            f"Relative path resolves outside working directory: {path}"
                        )
                        raise ValueError(
                            "Relative path attempts to escape working directory"
                        )

                logger.debug(f"Relative path validated: {path}")
                return path  # Return original relative path

            except (OSError, RuntimeError) as e:
                logger.warning(f"Path validation failed: {path} - {e}")
                raise ValueError(f"Path validation failed: {e}")

    def _validate_file_operation(self, file_path: Path) -> None:
        """
        Validate that a file operation is safe to perform.

        Args:
            file_path: The file path to validate

        Raises:
            ValueError: If the file operation is not safe
        """
        try:
            resolved_path = file_path.resolve()
            base_resolved = self.base_path.resolve()

            # Ensure the file is within the base directory
            if not str(resolved_path).startswith(str(base_resolved)):
                logger.warning(
                    f"File operation outside base directory: {resolved_path}"
                )
                raise ValueError("File operation outside allowed base directory")

            # Check file extension if it has one
            if (
                file_path.suffix
                and file_path.suffix.lower() not in self.ALLOWED_EXTENSIONS
            ):
                logger.warning(
                    f"File operation with disallowed extension: {file_path.suffix}"
                )
                raise ValueError(f"File extension '{file_path.suffix}' not allowed")

            # Check for symbolic links
            if resolved_path.is_symlink():
                logger.warning(f"Symbolic link detected: {resolved_path}")
                raise ValueError("Symbolic links are not allowed")

        except (OSError, RuntimeError) as e:
            logger.error(f"File validation error: {e}")
            raise ValueError(f"File validation failed: {e}")

    def get_next_sequence_id(self) -> int:
        """Get the next sequence ID for communication."""
        self._sequence_id += 1
        return self._sequence_id

    async def read_game_state(self) -> Optional[GameState]:
        """Read the current game state from file."""
        try:
            # Validate file operation before proceeding
            self._validate_file_operation(self.game_state_file)

            if not self.game_state_file.exists():
                return None

            with open(self.game_state_file, "r", encoding="utf-8") as f:
                data = json.load(f)

            # Check if this is a new message
            sequence_id = data.get("sequence_id", 0)
            last_read = self._last_read_sequence.get("game_state", 0)

            if sequence_id <= last_read:
                return None  # Already processed

            self._last_read_sequence["game_state"] = sequence_id

            # Validate message structure
            if data.get("message_type") != MessageType.GAME_STATE.value:
                logger.warning(
                    f"Invalid message type in game state file: {data.get('message_type')}"
                )
                return None

            # Parse game state
            game_state_data = data.get("data")
            if not game_state_data:
                logger.warning("No data field in game state message")
                return None

            game_state = GameState(**game_state_data)

            logger.debug(
                f"Read game state: session_id={game_state.session_id}, phase={game_state.current_phase}"
            )
            return game_state

        except (
            json.JSONDecodeError,
            FileNotFoundError,
            KeyError,
            TypeError,
            OSError,
        ) as e:
            logger.error(f"Error reading game state: {e}")
            return None

    async def write_action(self, action: GameAction) -> bool:
        """Write an action command to file."""
        try:
            # Validate file operations before proceeding
            self._validate_file_operation(self.actions_file)
            temp_file = self.actions_file.with_suffix(".tmp")
            self._validate_file_operation(temp_file)

            # Create action command message
            message_data = {
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "sequence_id": self.get_next_sequence_id(),
                "message_type": MessageType.ACTION_COMMAND.value,
                "data": action.model_dump(),
            }

            # Write atomically using temporary file
            with open(temp_file, "w", encoding="utf-8") as f:
                json.dump(message_data, f, indent=2)

            # Atomic move
            temp_file.replace(self.actions_file)

            logger.debug(f"Wrote action: {action.action_type}")
            return True

        except (IOError, TypeError) as e:
            logger.error(f"Error writing action: {e}")
            return False

    async def read_action_result(self) -> Optional[ActionResult]:
        """Read action execution result from file."""
        try:
            # Validate file operation before proceeding
            self._validate_file_operation(self.action_results_file)

            if not self.action_results_file.exists():
                return None

            with open(self.action_results_file, "r", encoding="utf-8") as f:
                data = json.load(f)

            # Check if this is a new message
            sequence_id = data.get("sequence_id", 0)
            last_read = self._last_read_sequence.get("action_result", 0)

            if sequence_id <= last_read:
                return None  # Already processed

            self._last_read_sequence["action_result"] = sequence_id

            # Validate message structure
            if data.get("message_type") != MessageType.ACTION_RESULT.value:
                logger.warning(
                    f"Invalid message type in action result file: {data.get('message_type')}"
                )
                return None

            # Parse action result
            result_data = data.get("data", {})
            action_result = ActionResult(**result_data)

            # Clean up the file after reading
            try:
                self.action_results_file.unlink()
            except FileNotFoundError:
                pass  # File already removed

            logger.debug(f"Read action result: success={action_result.success}")
            return action_result

        except (json.JSONDecodeError, FileNotFoundError, KeyError, TypeError) as e:
            logger.error(f"Error reading action result: {e}")
            return None

    async def cleanup_old_files(self, max_age_seconds: int = 300) -> None:
        """Clean up old communication files to prevent accumulation."""
        try:
            current_time = datetime.now(timezone.utc).timestamp()

            for file_path in [
                self.game_state_file,
                self.actions_file,
                self.action_results_file,
            ]:
                # Validate file operation before cleanup
                try:
                    self._validate_file_operation(file_path)
                except ValueError as e:
                    logger.warning(
                        f"Skipping cleanup of invalid file path: {file_path} - {e}"
                    )
                    continue

                if file_path.exists():
                    file_age = current_time - file_path.stat().st_mtime
                    if file_age > max_age_seconds:
                        file_path.unlink()
                        logger.debug(f"Cleaned up old file: {file_path}")

        except Exception as e:
            logger.error(f"Error during cleanup: {e}")

    async def wait_for_action_result(
        self, timeout_seconds: int = 10
    ) -> Optional[ActionResult]:
        """Wait for an action result with timeout."""
        start_time = asyncio.get_event_loop().time()

        while (asyncio.get_event_loop().time() - start_time) < timeout_seconds:
            result = await self.read_action_result()
            if result is not None:
                return result

            await asyncio.sleep(0.1)  # Poll every 100ms

        logger.warning("Timeout waiting for action result")
        return None

    async def ensure_directories(self) -> None:
        """Ensure all required directories exist."""
        self.base_path.mkdir(parents=True, exist_ok=True)
        logger.debug(f"Ensured directory exists: {self.base_path}")

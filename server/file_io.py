"""
File-based I/O implementation for Balatro MCP Server.
Handles communication with the Balatro mod through JSON files.
"""

import json
import asyncio
from pathlib import Path
from typing import Optional
from datetime import datetime, timezone
import logging

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

    def __init__(self, base_path: str = "shared"):
        """Initialize file I/O with base path for communication files."""
        self.base_path = Path(base_path)
        self.base_path.mkdir(exist_ok=True)

        # Communication file paths
        self.game_state_file = self.base_path / "game_state.json"
        self.actions_file = self.base_path / "actions.json"
        self.action_results_file = self.base_path / "action_results.json"

        # Sequence tracking
        self._sequence_id = 0
        self._last_read_sequence = {}

        logger.info(f"BalatroFileIO initialized with base path: {self.base_path}")

    def get_next_sequence_id(self) -> int:
        """Get the next sequence ID for communication."""
        self._sequence_id += 1
        return self._sequence_id

    async def read_game_state(self) -> Optional[GameState]:
        """Read the current game state from file."""
        try:
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

        except (json.JSONDecodeError, FileNotFoundError, KeyError, TypeError, OSError) as e:
            logger.error(f"Error reading game state: {e}")
            return None

    async def write_action(self, action: GameAction) -> bool:
        """Write an action command to file."""
        try:
            # Create action command message
            message_data = {
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "sequence_id": self.get_next_sequence_id(),
                "message_type": MessageType.ACTION_COMMAND.value,
                "data": action.model_dump(),
            }

            # Write atomically using temporary file
            temp_file = self.actions_file.with_suffix(".tmp")
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

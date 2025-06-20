"""
State management for the Balatro MCP Server.
Handles game state tracking and updates.
"""

import asyncio
import logging
from typing import Optional
from datetime import datetime, timezone

from .interfaces import IStateManager, IFileIO
from .schemas import GameState


logger = logging.getLogger(__name__)


class BalatroStateManager(IStateManager):
    """Manages game state for the Balatro MCP Server."""

    def __init__(self, file_io: IFileIO):
        """Initialize state manager with file I/O dependency."""
        self.file_io = file_io
        self._current_state: Optional[GameState] = None
        self._last_update_time: Optional[datetime] = None
        self._state_changed = False

        logger.info("BalatroStateManager initialized")

    async def get_current_state(self) -> Optional[GameState]:
        """Get the current game state."""
        await self._update_from_file()
        return self._current_state

    async def update_state(self, new_state: GameState) -> None:
        """Update the current game state."""
        if not self._states_equal(self._current_state, new_state):
            self._current_state = new_state
            self._last_update_time = datetime.now(timezone.utc)
            self._state_changed = True

            logger.info(
                f"State updated: session_id={new_state.session_id}, "
                f"phase={new_state.current_phase}, ante={new_state.ante}"
            )

    async def is_state_changed(self) -> bool:
        """Check if the game state has changed since last check."""
        await self._update_from_file()

        if self._state_changed:
            self._state_changed = False  # Reset flag
            return True
        return False

    async def _update_from_file(self) -> None:
        """Update internal state from file I/O."""
        try:
            new_state = await self.file_io.read_game_state()
            if new_state is not None:
                await self.update_state(new_state)
        except Exception as e:
            logger.error(f"Error updating state from file: {e}")

    def _states_equal(
        self, state1: Optional[GameState], state2: Optional[GameState]
    ) -> bool:
        """Compare two game states for equality."""
        if state1 is None and state2 is None:
            return True
        if state1 is None or state2 is None:
            return False

        # Compare key state attributes that indicate meaningful changes
        return (
            state1.session_id == state2.session_id
            and state1.current_phase == state2.current_phase
            and state1.ante == state2.ante
            and state1.money == state2.money
            and state1.hands_remaining == state2.hands_remaining
            and state1.discards_remaining == state2.discards_remaining
            and len(state1.hand_cards) == len(state2.hand_cards)
            and len(state1.jokers) == len(state2.jokers)
            and state1.post_hand_joker_reorder_available
            == state2.post_hand_joker_reorder_available
        )

    async def wait_for_state_change(self, timeout_seconds: int = 30) -> bool:
        """Wait for the game state to change."""
        start_time = asyncio.get_event_loop().time()

        while (asyncio.get_event_loop().time() - start_time) < timeout_seconds:
            if await self.is_state_changed():
                return True
            await asyncio.sleep(0.1)  # Poll every 100ms

        logger.warning(f"Timeout waiting for state change after {timeout_seconds}s")
        return False

    async def get_state_summary(self) -> dict:
        """Get a summary of the current state for logging/debugging."""
        state = await self.get_current_state()
        if state is None:
            return {"status": "no_state"}

        return {
            "session_id": state.session_id,
            "phase": state.current_phase.value,
            "ante": state.ante,
            "money": state.money,
            "hands_remaining": state.hands_remaining,
            "discards_remaining": state.discards_remaining,
            "hand_size": len(state.hand_cards),
            "joker_count": len(state.jokers),
            "consumable_count": len(state.consumables),
            "reorder_available": state.post_hand_joker_reorder_available,
            "last_update": (
                self._last_update_time.isoformat() if self._last_update_time else None
            ),
        }


class StateValidator:
    """Validates game state integrity and transitions."""

    @staticmethod
    def validate_state_transition(
        old_state: Optional[GameState], new_state: GameState
    ) -> bool:
        """Validate that a state transition is valid."""
        if old_state is None:
            return True  # First state is always valid

        # Basic validation rules
        validations = [
            StateValidator._validate_session_consistency(old_state, new_state),
            StateValidator._validate_ante_progression(old_state, new_state),
            StateValidator._validate_phase_transition(old_state, new_state),
        ]

        return all(validations)

    @staticmethod
    def _validate_session_consistency(
        old_state: GameState, new_state: GameState
    ) -> bool:
        """Validate session ID consistency."""
        return old_state.session_id == new_state.session_id

    @staticmethod
    def _validate_ante_progression(old_state: GameState, new_state: GameState) -> bool:
        """Validate ante can only stay same or increase."""
        return new_state.ante >= old_state.ante

    @staticmethod
    def _validate_phase_transition(old_state: GameState, new_state: GameState) -> bool:
        """Validate phase transitions are logical."""
        # This could be expanded with more complex phase transition rules
        return True  # For now, allow all phase transitions

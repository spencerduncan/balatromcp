"""
Unit tests for state_manager module.
Tests game state management and change detection.
"""

import pytest
from unittest.mock import Mock, AsyncMock, patch
from datetime import datetime, timezone

from server.state_manager import BalatroStateManager, StateValidator
from server.interfaces import IFileIO
from server.schemas import (
    GameState,
    GamePhase,
    Card,
    Joker,
    Consumable,
    Blind,
    ShopItem,
    BlindType,
)


@pytest.fixture
def mock_file_io():
    """Create a mock file I/O interface."""
    mock = Mock(spec=IFileIO)
    mock.read_game_state = AsyncMock()
    return mock


@pytest.fixture
def state_manager(mock_file_io):
    """Create a BalatroStateManager instance for testing."""
    return BalatroStateManager(mock_file_io)


@pytest.fixture
def sample_game_state():
    """Create a sample game state for testing."""
    return GameState(
        session_id="test_session",
        current_phase=GamePhase.HAND_SELECTION,
        ante=1,
        money=100,
        hands_remaining=4,
        discards_remaining=3,
        hand_cards=[Card(id="c1", rank="A", suit="hearts")],
        jokers=[Joker(id="j1", name="Test Joker", position=0)],
        consumables=[],
        current_blind=None,
        shop_contents=[],
        available_actions=["play_hand", "discard_cards"],
        post_hand_joker_reorder_available=False,
    )


@pytest.fixture
def different_game_state():
    """Create a different game state for testing state changes."""
    return GameState(
        session_id="test_session",
        current_phase=GamePhase.SHOP,  # Different phase
        ante=1,
        money=150,  # Different money
        hands_remaining=3,  # Different hands
        discards_remaining=3,
        hand_cards=[],  # Different hand cards
        jokers=[Joker(id="j1", name="Test Joker", position=0)],
        consumables=[],
        current_blind=None,
        shop_contents=[],
        available_actions=["buy_item"],
        post_hand_joker_reorder_available=True,  # Different reorder availability
    )


class TestBalatroStateManagerInitialization:
    """Test BalatroStateManager initialization."""

    def test_initialization(self, mock_file_io):
        """Test state manager initialization."""
        manager = BalatroStateManager(mock_file_io)

        assert manager.file_io == mock_file_io
        assert manager._current_state is None
        assert manager._last_update_time is None
        assert manager._state_changed is False

    def test_initialization_with_file_io_dependency(self):
        """Test that file_io dependency is required."""
        with pytest.raises(TypeError):
            BalatroStateManager()  # Missing required argument


class TestGetCurrentState:
    """Test getting current game state."""

    @pytest.mark.asyncio
    async def test_get_current_state_first_time(
        self, state_manager, mock_file_io, sample_game_state
    ):
        """Test getting current state for the first time."""
        mock_file_io.read_game_state.return_value = sample_game_state

        result = await state_manager.get_current_state()

        assert result == sample_game_state
        assert state_manager._current_state == sample_game_state
        mock_file_io.read_game_state.assert_called_once()

    @pytest.mark.asyncio
    async def test_get_current_state_no_new_data(self, state_manager, mock_file_io):
        """Test getting current state when no new data is available."""
        mock_file_io.read_game_state.return_value = None

        result = await state_manager.get_current_state()

        assert result is None
        assert state_manager._current_state is None

    @pytest.mark.asyncio
    async def test_get_current_state_cached_when_no_update(
        self, state_manager, mock_file_io, sample_game_state
    ):
        """Test that current state is returned from cache when no file update."""
        # Set initial state
        state_manager._current_state = sample_game_state
        mock_file_io.read_game_state.return_value = None  # No new data

        result = await state_manager.get_current_state()

        assert result == sample_game_state
        mock_file_io.read_game_state.assert_called_once()

    @pytest.mark.asyncio
    async def test_get_current_state_updates_from_file(
        self, state_manager, mock_file_io, sample_game_state, different_game_state
    ):
        """Test that current state is updated from file when new data available."""
        # Set initial state
        state_manager._current_state = sample_game_state
        mock_file_io.read_game_state.return_value = different_game_state

        result = await state_manager.get_current_state()

        assert result == different_game_state
        assert state_manager._current_state == different_game_state

    @pytest.mark.asyncio
    async def test_get_current_state_file_io_error(self, state_manager, mock_file_io):
        """Test handling of file I/O errors."""
        mock_file_io.read_game_state.side_effect = Exception("File error")

        result = await state_manager.get_current_state()

        # Should return current state (None) and not crash
        assert result is None


class TestUpdateState:
    """Test state update functionality."""

    @pytest.mark.asyncio
    async def test_update_state_new_state(self, state_manager, sample_game_state):
        """Test updating to a new state."""
        await state_manager.update_state(sample_game_state)

        assert state_manager._current_state == sample_game_state
        assert state_manager._last_update_time is not None
        assert state_manager._state_changed is True

    @pytest.mark.asyncio
    async def test_update_state_same_state(self, state_manager, sample_game_state):
        """Test updating with the same state doesn't trigger change."""
        # Set initial state
        state_manager._current_state = sample_game_state
        state_manager._state_changed = False

        # Update with same state
        await state_manager.update_state(sample_game_state)

        # State change flag should remain False
        assert state_manager._state_changed is False

    @pytest.mark.asyncio
    async def test_update_state_different_state(
        self, state_manager, sample_game_state, different_game_state
    ):
        """Test updating with a different state triggers change."""
        # Set initial state
        state_manager._current_state = sample_game_state
        state_manager._state_changed = False

        # Update with different state
        await state_manager.update_state(different_game_state)

        assert state_manager._current_state == different_game_state
        assert state_manager._state_changed is True
        assert state_manager._last_update_time is not None

    @pytest.mark.asyncio
    async def test_update_state_tracks_update_time(
        self, state_manager, sample_game_state
    ):
        """Test that update time is tracked."""
        before_update = datetime.now(timezone.utc)
        await state_manager.update_state(sample_game_state)
        after_update = datetime.now(timezone.utc)

        assert before_update <= state_manager._last_update_time <= after_update


class TestIsStateChanged:
    """Test state change detection."""

    @pytest.mark.asyncio
    async def test_is_state_changed_no_change(self, state_manager, mock_file_io):
        """Test is_state_changed when no change occurred."""
        mock_file_io.read_game_state.return_value = None
        state_manager._state_changed = False

        result = await state_manager.is_state_changed()

        assert result is False

    @pytest.mark.asyncio
    async def test_is_state_changed_with_change(
        self, state_manager, mock_file_io, sample_game_state
    ):
        """Test is_state_changed when change occurred."""
        mock_file_io.read_game_state.return_value = sample_game_state

        result = await state_manager.is_state_changed()

        assert result is True

    @pytest.mark.asyncio
    async def test_is_state_changed_resets_flag(self, state_manager, mock_file_io):
        """Test that is_state_changed resets the change flag."""
        mock_file_io.read_game_state.return_value = None
        state_manager._state_changed = True

        result = await state_manager.is_state_changed()

        assert result is True
        assert state_manager._state_changed is False  # Flag should be reset

    @pytest.mark.asyncio
    async def test_is_state_changed_multiple_calls(self, state_manager, mock_file_io):
        """Test multiple calls to is_state_changed."""
        mock_file_io.read_game_state.return_value = None
        state_manager._state_changed = True

        # First call should return True and reset flag
        result1 = await state_manager.is_state_changed()
        assert result1 is True

        # Second call should return False
        result2 = await state_manager.is_state_changed()
        assert result2 is False


class TestStatesEqual:
    """Test state equality comparison."""

    def test_states_equal_both_none(self, state_manager):
        """Test equality when both states are None."""
        result = state_manager._states_equal(None, None)
        assert result is True

    def test_states_equal_one_none(self, state_manager, sample_game_state):
        """Test equality when one state is None."""
        result1 = state_manager._states_equal(None, sample_game_state)
        result2 = state_manager._states_equal(sample_game_state, None)

        assert result1 is False
        assert result2 is False

    def test_states_equal_identical(self, state_manager, sample_game_state):
        """Test equality with identical states."""
        result = state_manager._states_equal(sample_game_state, sample_game_state)
        assert result is True

    def test_states_equal_different_session_id(self, state_manager, sample_game_state):
        """Test inequality with different session ID."""
        different_state = sample_game_state.model_copy()
        different_state.session_id = "different_session"

        result = state_manager._states_equal(sample_game_state, different_state)
        assert result is False

    def test_states_equal_different_phase(self, state_manager, sample_game_state):
        """Test inequality with different phase."""
        different_state = sample_game_state.model_copy()
        different_state.current_phase = GamePhase.SHOP

        result = state_manager._states_equal(sample_game_state, different_state)
        assert result is False

    def test_states_equal_different_ante(self, state_manager, sample_game_state):
        """Test inequality with different ante."""
        different_state = sample_game_state.model_copy()
        different_state.ante = 2

        result = state_manager._states_equal(sample_game_state, different_state)
        assert result is False

    def test_states_equal_different_money(self, state_manager, sample_game_state):
        """Test inequality with different money."""
        different_state = sample_game_state.model_copy()
        different_state.money = 200

        result = state_manager._states_equal(sample_game_state, different_state)
        assert result is False

    def test_states_equal_different_hands_remaining(
        self, state_manager, sample_game_state
    ):
        """Test inequality with different hands remaining."""
        different_state = sample_game_state.model_copy()
        different_state.hands_remaining = 3

        result = state_manager._states_equal(sample_game_state, different_state)
        assert result is False

    def test_states_equal_different_hand_size(self, state_manager, sample_game_state):
        """Test inequality with different hand card count."""
        different_state = sample_game_state.model_copy()
        different_state.hand_cards = []  # Different size

        result = state_manager._states_equal(sample_game_state, different_state)
        assert result is False

    def test_states_equal_different_joker_count(self, state_manager, sample_game_state):
        """Test inequality with different joker count."""
        different_state = sample_game_state.model_copy()
        different_state.jokers = []  # Different size

        result = state_manager._states_equal(sample_game_state, different_state)
        assert result is False

    def test_states_equal_different_reorder_availability(
        self, state_manager, sample_game_state
    ):
        """Test inequality with different joker reorder availability."""
        different_state = sample_game_state.model_copy()
        different_state.post_hand_joker_reorder_available = True

        result = state_manager._states_equal(sample_game_state, different_state)
        assert result is False


class TestWaitForStateChange:
    """Test waiting for state change with timeout."""

    @pytest.mark.asyncio
    async def test_wait_for_state_change_immediate(
        self, state_manager, mock_file_io, sample_game_state
    ):
        """Test waiting when state change is immediate."""
        mock_file_io.read_game_state.return_value = sample_game_state

        result = await state_manager.wait_for_state_change(timeout_seconds=1)

        assert result is True

    @pytest.mark.asyncio
    async def test_wait_for_state_change_timeout(self, state_manager, mock_file_io):
        """Test waiting with timeout when no state change occurs."""
        mock_file_io.read_game_state.return_value = None

        result = await state_manager.wait_for_state_change(timeout_seconds=0.1)

        assert result is False

    @pytest.mark.asyncio
    async def test_wait_for_state_change_delayed(
        self, state_manager, mock_file_io, sample_game_state
    ):
        """Test waiting when state change occurs after delay."""
        call_count = 0

        def mock_read_state():
            nonlocal call_count
            call_count += 1
            if call_count > 2:
                return sample_game_state
            return None

        mock_file_io.read_game_state.side_effect = mock_read_state

        result = await state_manager.wait_for_state_change(timeout_seconds=1)

        assert result is True


class TestGetStateSummary:
    """Test state summary generation."""

    @pytest.mark.asyncio
    async def test_get_state_summary_no_state(self, state_manager, mock_file_io):
        """Test state summary when no state is available."""
        mock_file_io.read_game_state.return_value = None

        summary = await state_manager.get_state_summary()

        assert summary == {"status": "no_state"}

    @pytest.mark.asyncio
    async def test_get_state_summary_with_state(
        self, state_manager, mock_file_io, sample_game_state
    ):
        """Test state summary generation with valid state."""
        mock_file_io.read_game_state.return_value = sample_game_state

        summary = await state_manager.get_state_summary()

        expected_keys = {
            "session_id",
            "phase",
            "ante",
            "money",
            "hands_remaining",
            "discards_remaining",
            "hand_size",
            "joker_count",
            "consumable_count",
            "reorder_available",
            "last_update",
        }
        assert set(summary.keys()) == expected_keys
        assert summary["session_id"] == "test_session"
        assert summary["phase"] == "hand_selection"
        assert summary["ante"] == 1
        assert summary["money"] == 100

    @pytest.mark.asyncio
    async def test_get_state_summary_with_update_time(
        self, state_manager, sample_game_state
    ):
        """Test state summary includes update time when available."""
        state_manager._current_state = sample_game_state
        state_manager._last_update_time = datetime.now(timezone.utc)

        with patch.object(state_manager, "_update_from_file"):
            summary = await state_manager.get_state_summary()

        assert summary["last_update"] is not None
        assert isinstance(summary["last_update"], str)


class TestStateValidator:
    """Test StateValidator utility class."""

    def test_validate_state_transition_first_state(self, sample_game_state):
        """Test validation when old_state is None (first state)."""
        result = StateValidator.validate_state_transition(None, sample_game_state)
        assert result is True

    def test_validate_state_transition_valid(
        self, sample_game_state, different_game_state
    ):
        """Test validation of valid state transition."""
        result = StateValidator.validate_state_transition(
            sample_game_state, different_game_state
        )
        assert result is True

    def test_validate_session_consistency_valid(
        self, sample_game_state, different_game_state
    ):
        """Test session consistency validation with same session."""
        result = StateValidator._validate_session_consistency(
            sample_game_state, different_game_state
        )
        assert result is True

    def test_validate_session_consistency_invalid(self, sample_game_state):
        """Test session consistency validation with different session."""
        different_session_state = sample_game_state.model_copy()
        different_session_state.session_id = "different_session"

        result = StateValidator._validate_session_consistency(
            sample_game_state, different_session_state
        )
        assert result is False

    def test_validate_ante_progression_valid_same(self, sample_game_state):
        """Test ante progression validation with same ante."""
        result = StateValidator._validate_ante_progression(
            sample_game_state, sample_game_state
        )
        assert result is True

    def test_validate_ante_progression_valid_increase(self, sample_game_state):
        """Test ante progression validation with increased ante."""
        increased_ante_state = sample_game_state.model_copy()
        increased_ante_state.ante = 2

        result = StateValidator._validate_ante_progression(
            sample_game_state, increased_ante_state
        )
        assert result is True

    def test_validate_ante_progression_invalid_decrease(self, sample_game_state):
        """Test ante progression validation with decreased ante."""
        decreased_ante_state = sample_game_state.model_copy()
        decreased_ante_state.ante = 0

        result = StateValidator._validate_ante_progression(
            sample_game_state, decreased_ante_state
        )
        assert result is False

    def test_validate_phase_transition_always_valid(
        self, sample_game_state, different_game_state
    ):
        """Test phase transition validation (currently always returns True)."""
        result = StateValidator._validate_phase_transition(
            sample_game_state, different_game_state
        )
        assert result is True


class TestPrivateUpdateFromFile:
    """Test private _update_from_file method."""

    @pytest.mark.asyncio
    async def test_update_from_file_success(
        self, state_manager, mock_file_io, sample_game_state
    ):
        """Test successful update from file."""
        mock_file_io.read_game_state.return_value = sample_game_state

        await state_manager._update_from_file()

        assert state_manager._current_state == sample_game_state
        assert state_manager._state_changed is True

    @pytest.mark.asyncio
    async def test_update_from_file_no_new_data(self, state_manager, mock_file_io):
        """Test update from file when no new data."""
        mock_file_io.read_game_state.return_value = None
        initial_state = state_manager._current_state

        await state_manager._update_from_file()

        # State should remain unchanged
        assert state_manager._current_state == initial_state

    @pytest.mark.asyncio
    async def test_update_from_file_exception_handling(
        self, state_manager, mock_file_io
    ):
        """Test update from file handles exceptions gracefully."""
        mock_file_io.read_game_state.side_effect = Exception("File error")

        # Should not raise exception
        await state_manager._update_from_file()

        # State should remain None
        assert state_manager._current_state is None

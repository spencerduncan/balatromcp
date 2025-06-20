"""
Unit tests for file_io module.
Tests file-based communication operations.
"""

import pytest
import json
import asyncio
from pathlib import Path
from unittest.mock import Mock, patch, mock_open, AsyncMock
from datetime import datetime, timezone

from server.file_io import BalatroFileIO
from server.schemas import (
    GameState,
    GamePhase,
    PlayHandAction,
    ActionResult,
    MessageType,
    Card,
    Joker,
    Consumable,
    Blind,
    ShopItem,
    BlindType,
)


@pytest.fixture
def temp_path(tmp_path):
    """Provide a temporary path for testing."""
    return str(tmp_path)


@pytest.fixture
def file_io(temp_path):
    """Create BalatroFileIO instance for testing."""
    return BalatroFileIO(temp_path)


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
    )


@pytest.fixture
def sample_action():
    """Create a sample action for testing."""
    return PlayHandAction(card_indices=[0, 1])


@pytest.fixture
def sample_action_result():
    """Create a sample action result for testing."""
    return ActionResult(success=True, error_message=None)


class TestBalatroFileIOInitialization:
    """Test BalatroFileIO initialization."""

    def test_initialization_default_path(self):
        """Test initialization with default path."""
        file_io = BalatroFileIO()
        assert file_io.base_path == Path("shared")
        assert file_io._sequence_id == 0
        assert file_io._last_read_sequence == {}

    def test_initialization_custom_path(self, temp_path):
        """Test initialization with custom path."""
        file_io = BalatroFileIO(temp_path)
        assert file_io.base_path == Path(temp_path)
        
        # Check file paths are set correctly
        assert file_io.game_state_file == Path(temp_path) / "game_state.json"
        assert file_io.actions_file == Path(temp_path) / "actions.json"
        assert file_io.action_results_file == Path(temp_path) / "action_results.json"

    @patch('pathlib.Path.mkdir')
    def test_directory_creation(self, mock_mkdir, temp_path):
        """Test that directory is created during initialization."""
        BalatroFileIO(temp_path)
        mock_mkdir.assert_called_once_with(exist_ok=True)


class TestSequenceIdManagement:
    """Test sequence ID management."""

    def test_get_next_sequence_id(self, file_io):
        """Test sequence ID incrementing."""
        assert file_io.get_next_sequence_id() == 1
        assert file_io.get_next_sequence_id() == 2
        assert file_io.get_next_sequence_id() == 3

    def test_sequence_id_state(self, file_io):
        """Test sequence ID internal state."""
        initial_id = file_io._sequence_id
        next_id = file_io.get_next_sequence_id()
        assert next_id == initial_id + 1
        assert file_io._sequence_id == next_id


class TestReadGameState:
    """Test reading game state from file."""

    @pytest.mark.asyncio
    async def test_read_game_state_success(self, file_io, sample_game_state):
        """Test successful game state reading."""
        message_data = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "sequence_id": 1,
            "message_type": MessageType.GAME_STATE.value,
            "data": sample_game_state.model_dump(),
        }

        with patch("pathlib.Path.exists", return_value=True):
            with patch("builtins.open", mock_open(read_data=json.dumps(message_data))):
                result = await file_io.read_game_state()
                
        assert result is not None
        assert result.session_id == "test_session"
        assert result.current_phase == GamePhase.HAND_SELECTION
        assert result.ante == 1

    @pytest.mark.asyncio
    async def test_read_game_state_file_not_exists(self, file_io):
        """Test reading when file doesn't exist."""
        with patch("pathlib.Path.exists", return_value=False):
            result = await file_io.read_game_state()
            assert result is None

    @pytest.mark.asyncio
    async def test_read_game_state_invalid_json(self, file_io):
        """Test reading with invalid JSON."""
        with patch("pathlib.Path.exists", return_value=True):
            with patch("builtins.open", mock_open(read_data="invalid json")):
                result = await file_io.read_game_state()
                assert result is None

    @pytest.mark.asyncio
    async def test_read_game_state_wrong_message_type(self, file_io):
        """Test reading with wrong message type."""
        message_data = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "sequence_id": 1,
            "message_type": "wrong_type",
            "data": {},
        }

        with patch("pathlib.Path.exists", return_value=True):
            with patch("builtins.open", mock_open(read_data=json.dumps(message_data))):
                result = await file_io.read_game_state()
                assert result is None

    @pytest.mark.asyncio
    async def test_read_game_state_sequence_tracking(self, file_io, sample_game_state):
        """Test sequence ID tracking prevents duplicate reads."""
        message_data = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "sequence_id": 1,
            "message_type": MessageType.GAME_STATE.value,
            "data": sample_game_state.model_dump(),
        }

        with patch("pathlib.Path.exists", return_value=True):
            with patch("builtins.open", mock_open(read_data=json.dumps(message_data))):
                # First read should succeed
                result1 = await file_io.read_game_state()
                assert result1 is not None
                
                # Second read with same sequence should return None
                result2 = await file_io.read_game_state()
                assert result2 is None

    @pytest.mark.asyncio
    async def test_read_game_state_missing_data(self, file_io):
        """Test reading with missing data field."""
        message_data = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "sequence_id": 1,
            "message_type": MessageType.GAME_STATE.value,
            # Missing data field
        }

        with patch("pathlib.Path.exists", return_value=True):
            with patch("builtins.open", mock_open(read_data=json.dumps(message_data))):
                result = await file_io.read_game_state()
                assert result is None


class TestWriteAction:
    """Test writing actions to file."""

    @pytest.mark.asyncio
    async def test_write_action_success(self, file_io, sample_action):
        """Test successful action writing."""
        mock_file = mock_open()
        
        with patch("builtins.open", mock_file):
            with patch("pathlib.Path.replace") as mock_replace:
                result = await file_io.write_action(sample_action)
                
        assert result is True
        mock_file.assert_called()
        mock_replace.assert_called_once()

    @pytest.mark.asyncio
    async def test_write_action_creates_message_structure(self, file_io, sample_action):
        """Test that write_action creates proper message structure."""
        mock_file = mock_open()
        
        with patch("builtins.open", mock_file):
            with patch("pathlib.Path.replace"):
                await file_io.write_action(sample_action)
                
        # Get the written data from the mock - join all write calls
        mock_file.assert_called()
        handle = mock_file.return_value.__enter__.return_value
        write_calls = handle.write.call_args_list
        
        # Join all written chunks to get complete JSON
        written_data = ''.join(call[0][0] for call in write_calls)
        message_data = json.loads(written_data)
        
        assert "timestamp" in message_data
        assert "sequence_id" in message_data
        assert message_data["message_type"] == MessageType.ACTION_COMMAND.value
        assert "data" in message_data
        assert message_data["data"]["action_type"] == "play_hand"

    @pytest.mark.asyncio
    async def test_write_action_atomic_operation(self, file_io, sample_action):
        """Test that write_action uses atomic file operations."""
        with patch("builtins.open", mock_open()):
            with patch("pathlib.Path.replace") as mock_replace:
                await file_io.write_action(sample_action)
                
        # Verify atomic operation (temp file -> final file)
        mock_replace.assert_called_once()

    @pytest.mark.asyncio
    async def test_write_action_io_error(self, file_io, sample_action):
        """Test write_action with I/O error."""
        with patch("builtins.open", side_effect=IOError("File error")):
            result = await file_io.write_action(sample_action)
            assert result is False

    @pytest.mark.asyncio
    async def test_write_action_sequence_increment(self, file_io, sample_action):
        """Test that write_action increments sequence ID."""
        initial_seq = file_io._sequence_id
        
        with patch("builtins.open", mock_open()):
            with patch("pathlib.Path.replace"):
                await file_io.write_action(sample_action)
                
        assert file_io._sequence_id == initial_seq + 1


class TestReadActionResult:
    """Test reading action results from file."""

    @pytest.mark.asyncio
    async def test_read_action_result_success(self, file_io, sample_action_result):
        """Test successful action result reading."""
        message_data = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "sequence_id": 1,
            "message_type": MessageType.ACTION_RESULT.value,
            "data": sample_action_result.model_dump(),
        }

        with patch("pathlib.Path.exists", return_value=True):
            with patch("builtins.open", mock_open(read_data=json.dumps(message_data))):
                with patch("pathlib.Path.unlink") as mock_unlink:
                    result = await file_io.read_action_result()
                    
        assert result is not None
        assert result.success is True
        mock_unlink.assert_called_once()

    @pytest.mark.asyncio
    async def test_read_action_result_file_not_exists(self, file_io):
        """Test reading when result file doesn't exist."""
        with patch("pathlib.Path.exists", return_value=False):
            result = await file_io.read_action_result()
            assert result is None

    @pytest.mark.asyncio
    async def test_read_action_result_cleanup_on_read(self, file_io, sample_action_result):
        """Test that action result file is cleaned up after reading."""
        message_data = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "sequence_id": 1,
            "message_type": MessageType.ACTION_RESULT.value,
            "data": sample_action_result.model_dump(),
        }

        with patch("pathlib.Path.exists", return_value=True):
            with patch("builtins.open", mock_open(read_data=json.dumps(message_data))):
                with patch("pathlib.Path.unlink") as mock_unlink:
                    await file_io.read_action_result()
                    mock_unlink.assert_called_once()

    @pytest.mark.asyncio
    async def test_read_action_result_cleanup_error_ignored(self, file_io, sample_action_result):
        """Test that cleanup errors are ignored."""
        message_data = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "sequence_id": 1,
            "message_type": MessageType.ACTION_RESULT.value,
            "data": sample_action_result.model_dump(),
        }

        with patch("pathlib.Path.exists", return_value=True):
            with patch("builtins.open", mock_open(read_data=json.dumps(message_data))):
                with patch("pathlib.Path.unlink", side_effect=FileNotFoundError()):
                    result = await file_io.read_action_result()
                    # Should still return result despite cleanup error
                    assert result is not None

    @pytest.mark.asyncio
    async def test_read_action_result_sequence_tracking(self, file_io, sample_action_result):
        """Test sequence tracking for action results."""
        message_data = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "sequence_id": 1,
            "message_type": MessageType.ACTION_RESULT.value,
            "data": sample_action_result.model_dump(),
        }

        with patch("pathlib.Path.exists", return_value=True):
            with patch("builtins.open", mock_open(read_data=json.dumps(message_data))):
                with patch("pathlib.Path.unlink"):
                    # First read should succeed
                    result1 = await file_io.read_action_result()
                    assert result1 is not None
                    
                    # Second read with same sequence should return None
                    result2 = await file_io.read_action_result()
                    assert result2 is None


class TestWaitForActionResult:
    """Test waiting for action results with timeout."""

    @pytest.mark.asyncio
    async def test_wait_for_action_result_success(self, file_io, sample_action_result):
        """Test successful wait for action result."""
        message_data = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "sequence_id": 1,
            "message_type": MessageType.ACTION_RESULT.value,
            "data": sample_action_result.model_dump(),
        }

        with patch("pathlib.Path.exists", return_value=True):
            with patch("builtins.open", mock_open(read_data=json.dumps(message_data))):
                with patch("pathlib.Path.unlink"):
                    result = await file_io.wait_for_action_result(timeout_seconds=1)
                    
        assert result is not None
        assert result.success is True

    @pytest.mark.asyncio
    async def test_wait_for_action_result_timeout(self, file_io):
        """Test timeout when waiting for action result."""
        with patch("pathlib.Path.exists", return_value=False):
            result = await file_io.wait_for_action_result(timeout_seconds=0.1)
            assert result is None

    @pytest.mark.asyncio
    async def test_wait_for_action_result_delayed_appearance(self, file_io, sample_action_result):
        """Test waiting when result appears after delay."""
        message_data = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "sequence_id": 1,
            "message_type": MessageType.ACTION_RESULT.value,
            "data": sample_action_result.model_dump(),
        }

        call_count = 0
        def mock_exists():
            nonlocal call_count
            call_count += 1
            return call_count > 2  # Return True after a few calls

        with patch("pathlib.Path.exists", side_effect=mock_exists):
            with patch("builtins.open", mock_open(read_data=json.dumps(message_data))):
                with patch("pathlib.Path.unlink"):
                    result = await file_io.wait_for_action_result(timeout_seconds=1)
                    
        assert result is not None


class TestCleanupOperations:
    """Test file cleanup operations."""

    @pytest.mark.asyncio
    async def test_cleanup_old_files(self, file_io):
        """Test cleanup of old files."""
        mock_stat = Mock()
        mock_stat.st_mtime = 0  # Very old timestamp
        
        with patch("pathlib.Path.exists", return_value=True):
            with patch("pathlib.Path.stat", return_value=mock_stat):
                with patch("pathlib.Path.unlink") as mock_unlink:
                    with patch("datetime.datetime") as mock_datetime:
                        mock_datetime.now.return_value.timestamp.return_value = 1000
                        
                        await file_io.cleanup_old_files(max_age_seconds=300)
                        
        # Should clean up all 3 files (game_state, actions, action_results)
        assert mock_unlink.call_count == 3

    @pytest.mark.asyncio
    async def test_cleanup_recent_files_not_removed(self, file_io):
        """Test that recent files are not cleaned up."""
        mock_stat = Mock()
        mock_stat.st_mtime = 999  # Recent timestamp
        
        with patch("pathlib.Path.exists", return_value=True):
            with patch("pathlib.Path.stat", return_value=mock_stat):
                with patch("pathlib.Path.unlink") as mock_unlink:
                    # Mock the datetime.now().timestamp() call correctly
                    with patch("server.file_io.datetime") as mock_datetime:
                        mock_datetime.now.return_value.timestamp.return_value = 1000
                        
                        await file_io.cleanup_old_files(max_age_seconds=300)
                        
        # Should not clean up any files (file age = 1000 - 999 = 1 second, less than 300)
        mock_unlink.assert_not_called()

    @pytest.mark.asyncio
    async def test_cleanup_error_handling(self, file_io):
        """Test that cleanup errors are handled gracefully."""
        with patch("pathlib.Path.exists", side_effect=Exception("Test error")):
            # Should not raise exception
            await file_io.cleanup_old_files()

    @pytest.mark.asyncio
    async def test_ensure_directories(self, file_io):
        """Test directory creation."""
        with patch("pathlib.Path.mkdir") as mock_mkdir:
            await file_io.ensure_directories()
            mock_mkdir.assert_called_once_with(parents=True, exist_ok=True)


class TestErrorHandling:
    """Test error handling in various scenarios."""

    @pytest.mark.asyncio
    async def test_read_game_state_file_error(self, file_io):
        """Test handling of file read errors."""
        with patch("pathlib.Path.exists", return_value=True):
            with patch("builtins.open", side_effect=IOError("Read error")):
                result = await file_io.read_game_state()
                assert result is None

    @pytest.mark.asyncio
    async def test_read_action_result_json_error(self, file_io):
        """Test handling of JSON decode errors in action results."""
        with patch("pathlib.Path.exists", return_value=True):
            with patch("builtins.open", mock_open(read_data="invalid json")):
                result = await file_io.read_action_result()
                assert result is None

    @pytest.mark.asyncio
    async def test_write_action_type_error(self, file_io):
        """Test handling of type errors during action writing."""
        # Create an action with non-serializable data
        action = Mock()
        action.model_dump.side_effect = TypeError("Not serializable")
        
        result = await file_io.write_action(action)
        assert result is False
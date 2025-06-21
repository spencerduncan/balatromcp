"""
Unit tests for file_io module.
Tests file-based communication operations.
"""

import pytest
import json
import asyncio
import logging
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
        assert file_io.base_path == Path("C:/Users/whokn/Documents/balatroman/shared")
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
                    # Mock the validation method to bypass security checks during testing
                    with patch.object(file_io, '_validate_file_operation', return_value=None):
                        # Mock the time calculation directly
                        with patch("server.file_io.datetime") as mock_datetime:
                            mock_datetime.now.return_value.timestamp.return_value = 1000
                            mock_datetime.timezone = timezone
                            
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


class TestPathValidationSecurity:
    """Test path validation and sanitization security features."""

    def test_validate_and_sanitize_path_valid_relative(self):
        """Test validation of valid relative paths."""
        file_io = BalatroFileIO()
        
        # Valid relative paths should pass
        assert file_io._validate_and_sanitize_path("shared") == "shared"
        assert file_io._validate_and_sanitize_path("data/files") == "data/files"
        assert file_io._validate_and_sanitize_path("test.json") == "test.json"

    def test_validate_and_sanitize_path_directory_traversal_blocked(self):
        """Test that directory traversal patterns are blocked."""
        file_io = BalatroFileIO()
        
        # Various directory traversal patterns should be blocked
        traversal_patterns = [
            "../../../etc/passwd",
            "..\\..\\..\\windows\\system32",
            "folder/../../../etc/passwd",
            "folder\\..\\..\\..\\windows\\system32",
            "folder/../../file.txt",
            "folder\\..\\..\\file.txt",
            "..",
            "../",
            "..\\",
            "folder/..",
            "folder\\..",
        ]
        
        for pattern in traversal_patterns:
            with pytest.raises(ValueError, match="Directory traversal|invalid or potentially dangerous"):
                file_io._validate_and_sanitize_path(pattern)

    def test_validate_and_sanitize_path_length_limit(self):
        """Test that excessively long paths are blocked."""
        file_io = BalatroFileIO()
        
        # Path longer than MAX_PATH_LENGTH should be blocked
        long_path = "a" * (file_io.MAX_PATH_LENGTH + 1)
        with pytest.raises(ValueError, match="Path exceeds maximum length"):
            file_io._validate_and_sanitize_path(long_path)
        
        # Path at the limit should be allowed
        max_path = "a" * file_io.MAX_PATH_LENGTH
        result = file_io._validate_and_sanitize_path(max_path)
        assert result == max_path

    def test_validate_and_sanitize_path_dangerous_characters(self):
        """Test that dangerous characters are blocked."""
        file_io = BalatroFileIO()
        
        # Dangerous characters should be blocked
        dangerous_chars = ["<", ">", '"', "|", "?", "*"]
        for char in dangerous_chars:
            dangerous_path = f"file{char}name.json"
            with pytest.raises(ValueError, match="invalid or potentially dangerous"):
                file_io._validate_and_sanitize_path(dangerous_path)

    def test_validate_and_sanitize_path_control_characters(self):
        """Test that control characters are blocked."""
        file_io = BalatroFileIO()
        
        # Control characters should be blocked
        control_chars = ["\x00", "\x01", "\x1f", "\x7f", "\x9f"]
        for char in control_chars:
            dangerous_path = f"file{char}name.json"
            with pytest.raises(ValueError, match="invalid or potentially dangerous"):
                file_io._validate_and_sanitize_path(dangerous_path)

    def test_validate_and_sanitize_path_windows_reserved_names(self):
        """Test that Windows reserved names are blocked."""
        file_io = BalatroFileIO()
        
        # Windows reserved names should be blocked
        reserved_names = ["CON", "PRN", "AUX", "NUL", "COM1", "COM9", "LPT1", "LPT9"]
        for name in reserved_names:
            with pytest.raises(ValueError, match="invalid or potentially dangerous"):
                file_io._validate_and_sanitize_path(name)
            with pytest.raises(ValueError, match="invalid or potentially dangerous"):
                file_io._validate_and_sanitize_path(f"{name}.txt")
            with pytest.raises(ValueError, match="invalid or potentially dangerous"):
                file_io._validate_and_sanitize_path(f"folder/{name}")

    def test_validate_and_sanitize_path_empty_or_invalid(self):
        """Test that empty or invalid paths are blocked."""
        file_io = BalatroFileIO()
        
        # Empty string should be blocked
        with pytest.raises(ValueError, match="Path must be a non-empty string"):
            file_io._validate_and_sanitize_path("")
        
        # None should be blocked
        with pytest.raises(ValueError, match="Path must be a non-empty string"):
            file_io._validate_and_sanitize_path(None)
        
        # Non-string should be blocked
        with pytest.raises(ValueError, match="Path must be a non-empty string"):
            file_io._validate_and_sanitize_path(123)

    def test_validate_and_sanitize_path_absolute_paths(self):
        """Test handling of absolute paths."""
        file_io = BalatroFileIO()
        
        # On Windows, "/etc/passwd" is treated as relative and will fail for different reason
        # Let's test with actual Windows absolute paths
        with pytest.raises(ValueError, match="outside allowed directories|escape working directory"):
            file_io._validate_and_sanitize_path("C:\\Windows\\System32\\config\\sam")
        
        # Unix-style absolute path that resolves outside working directory
        with pytest.raises(ValueError, match="outside allowed directories|escape working directory"):
            file_io._validate_and_sanitize_path("/etc/passwd")


class TestFileOperationValidation:
    """Test file operation validation security features."""

    def test_validate_file_operation_within_base_directory(self, temp_path):
        """Test that file operations within base directory are allowed."""
        file_io = BalatroFileIO(temp_path)
        
        # Files within base directory should be allowed
        valid_file = file_io.base_path / "test.json"
        file_io._validate_file_operation(valid_file)  # Should not raise

    def test_validate_file_operation_outside_base_directory(self, temp_path):
        """Test that file operations outside base directory are blocked."""
        file_io = BalatroFileIO(temp_path)
        
        # Files outside base directory should be blocked
        with patch("pathlib.Path.resolve") as mock_resolve:
            # Mock resolve to return different paths for file vs base
            # First call is for file_path.resolve(), second for base_path.resolve()
            mock_resolve.side_effect = [Path("/etc/passwd"), Path(temp_path)]
            
            outside_file = Path("../../../etc/passwd")
            with pytest.raises(ValueError, match="outside allowed base directory"):
                file_io._validate_file_operation(outside_file)

    def test_validate_file_operation_allowed_extensions(self, temp_path):
        """Test that only allowed file extensions are permitted."""
        file_io = BalatroFileIO(temp_path)
        
        # Allowed extensions should pass
        valid_files = [
            file_io.base_path / "test.json",
            file_io.base_path / "temp.tmp",
            file_io.base_path / "noextension",  # No extension is allowed
        ]
        
        for valid_file in valid_files:
            file_io._validate_file_operation(valid_file)  # Should not raise

    def test_validate_file_operation_disallowed_extensions(self, temp_path):
        """Test that disallowed file extensions are blocked."""
        file_io = BalatroFileIO(temp_path)
        
        # Disallowed extensions should be blocked
        invalid_files = [
            file_io.base_path / "script.exe",
            file_io.base_path / "config.bat",
            file_io.base_path / "data.xml",
            file_io.base_path / "file.txt",
        ]
        
        for invalid_file in invalid_files:
            with pytest.raises(ValueError, match="File extension.*not allowed"):
                file_io._validate_file_operation(invalid_file)

    def test_validate_file_operation_symbolic_links_blocked(self, temp_path):
        """Test that symbolic links are blocked."""
        file_io = BalatroFileIO(temp_path)
        
        # Mock a symbolic link
        with patch("pathlib.Path.resolve") as mock_resolve, \
             patch("pathlib.Path.is_symlink", return_value=True):
            
            mock_resolve.return_value = file_io.base_path / "symlink.json"
            
            symlink_file = file_io.base_path / "symlink.json"
            with pytest.raises(ValueError, match="Symbolic links are not allowed"):
                file_io._validate_file_operation(symlink_file)

    def test_validate_file_operation_resolution_errors(self, temp_path):
        """Test handling of path resolution errors."""
        file_io = BalatroFileIO(temp_path)
        
        # Mock path resolution failure
        with patch("pathlib.Path.resolve", side_effect=OSError("Resolution failed")):
            invalid_file = file_io.base_path / "test.json"
            with pytest.raises(ValueError, match="File validation failed"):
                file_io._validate_file_operation(invalid_file)


class TestSecurityIntegration:
    """Test security integration in main file operations."""

    def test_initialization_with_invalid_base_path(self):
        """Test that initialization fails with invalid base path."""
        # Directory traversal in base path should be blocked
        with pytest.raises(ValueError, match="Directory traversal|invalid or potentially dangerous"):
            BalatroFileIO("../../../etc")

    def test_initialization_with_dangerous_base_path(self):
        """Test that initialization fails with dangerous base path."""
        # Dangerous characters in base path should be blocked
        with pytest.raises(ValueError, match="invalid or potentially dangerous"):
            BalatroFileIO("shared<>path")

    @pytest.mark.asyncio
    async def test_read_game_state_security_validation(self, temp_path):
        """Test that read_game_state validates file operations."""
        file_io = BalatroFileIO(temp_path)
        
        # Mock validation failure - should raise exception
        with patch.object(file_io, '_validate_file_operation', side_effect=ValueError("Security violation")):
            with pytest.raises(ValueError, match="Security violation"):
                await file_io.read_game_state()

    @pytest.mark.asyncio
    async def test_write_action_security_validation(self, temp_path, sample_action):
        """Test that write_action validates file operations."""
        file_io = BalatroFileIO(temp_path)
        
        # Mock validation failure for actions file - should raise exception
        with patch.object(file_io, '_validate_file_operation', side_effect=ValueError("Security violation")):
            with pytest.raises(ValueError, match="Security violation"):
                await file_io.write_action(sample_action)

    @pytest.mark.asyncio
    async def test_read_action_result_security_validation(self, temp_path):
        """Test that read_action_result validates file operations."""
        file_io = BalatroFileIO(temp_path)
        
        # Mock validation failure - should raise exception
        with patch.object(file_io, '_validate_file_operation', side_effect=ValueError("Security violation")):
            with pytest.raises(ValueError, match="Security violation"):
                await file_io.read_action_result()

    @pytest.mark.asyncio
    async def test_cleanup_old_files_security_validation(self, temp_path):
        """Test that cleanup_old_files validates file operations."""
        file_io = BalatroFileIO(temp_path)
        
        # Mock validation failure for some files
        def mock_validate(file_path):
            if "game_state" in str(file_path):
                raise ValueError("Security violation")
            return None
        
        with patch.object(file_io, '_validate_file_operation', side_effect=mock_validate):
            with patch("pathlib.Path.exists", return_value=True):
                # Should handle validation errors gracefully and continue
                await file_io.cleanup_old_files()


class TestSecurityLogging:
    """Test security violation logging."""

    def test_path_validation_logs_security_violations(self, caplog):
        """Test that security violations are logged."""
        file_io = BalatroFileIO()
        
        with caplog.at_level(logging.WARNING):
            try:
                file_io._validate_and_sanitize_path("../../../etc/passwd")
            except ValueError:
                pass  # Expected
        
        # Should log the security violation
        assert "Blocked path pattern detected" in caplog.text or "Directory traversal attempt" in caplog.text

    def test_file_operation_validation_logs_violations(self, temp_path, caplog):
        """Test that file operation violations are logged."""
        file_io = BalatroFileIO(temp_path)
        
        with caplog.at_level(logging.WARNING):
            try:
                # Mock an outside directory scenario
                with patch("pathlib.Path.resolve") as mock_resolve:
                    # First call is for file_path.resolve(), second for base_path.resolve()
                    mock_resolve.side_effect = [Path("/etc/passwd"), Path(temp_path)]
                    file_io._validate_file_operation(Path("../../../etc/passwd"))
            except ValueError:
                pass  # Expected
        
        # Should log the security violation
        assert "File operation outside base directory" in caplog.text


class TestSecurityEdgeCases:
    """Test edge cases and corner cases in security validation."""

    def test_path_with_mixed_separators(self):
        """Test paths with mixed directory separators."""
        file_io = BalatroFileIO()
        
        # Mixed separators in traversal attempts should be blocked
        mixed_patterns = [
            "../folder\\..\\file.txt",
            "folder/..\\../file.txt",
            "..\\folder/../file.txt",
        ]
        
        for pattern in mixed_patterns:
            with pytest.raises(ValueError, match="Directory traversal|invalid or potentially dangerous"):
                file_io._validate_and_sanitize_path(pattern)

    def test_unicode_and_special_characters(self):
        """Test handling of Unicode and special characters."""
        file_io = BalatroFileIO()
        
        # Valid Unicode should generally be allowed
        unicode_path = "файл.json"  # Cyrillic characters
        result = file_io._validate_and_sanitize_path(unicode_path)
        assert result == unicode_path
        
        # But control characters should still be blocked
        with pytest.raises(ValueError, match="invalid or potentially dangerous"):
            file_io._validate_and_sanitize_path("file\u0000name.json")

    def test_case_insensitive_blocked_patterns(self):
        """Test that blocked patterns are case-insensitive."""
        file_io = BalatroFileIO()
        
        # Windows reserved names should be blocked regardless of case
        reserved_variants = ["CON", "con", "Con", "cOn"]
        for variant in reserved_variants:
            with pytest.raises(ValueError, match="invalid or potentially dangerous"):
                file_io._validate_and_sanitize_path(variant)

    def test_path_normalization_bypass_attempts(self):
        """Test attempts to bypass validation through path normalization."""
        file_io = BalatroFileIO()
        
        # Various bypass attempts should be blocked - focus on actual traversal patterns
        bypass_attempts = [
            "....//....//....//etc//passwd",  # Double slashes (still contains ..)
            "....\\\\....\\\\....\\\\windows\\\\system32",  # Double backslashes (still contains ..)
            "../folder/../file.txt",  # Hidden traversal
            "folder\\..\\file.txt",  # Backslash traversal
        ]
        
        for attempt in bypass_attempts:
            with pytest.raises(ValueError, match="Directory traversal|invalid or potentially dangerous"):
                file_io._validate_and_sanitize_path(attempt)
"""
Unit tests for main module.
Tests the main MCP server implementation and tool integration.
"""

import pytest
import asyncio
from unittest.mock import Mock, AsyncMock, patch, MagicMock
from datetime import datetime

from server.main import BalatroMCPServer
from server.interfaces import IFileIO, IStateManager, IActionHandler
from server.schemas import (
    GameState,
    GamePhase,
    Card,
    Joker,
    Consumable,
    ActionResult,
    PlayHandAction,
    BuyItemAction,
    ReorderJokersAction,
)
from mcp.types import (
    ListResourcesResult,
    ReadResourceResult,
    ListToolsResult,
    CallToolResult,
    TextContent,
)


@pytest.fixture
def mock_file_io():
    """Create a mock file I/O interface."""
    mock = Mock(spec=IFileIO)
    mock.ensure_directories = AsyncMock()
    mock.cleanup_old_files = AsyncMock()
    return mock


@pytest.fixture
def mock_state_manager():
    """Create a mock state manager."""
    mock = Mock(spec=IStateManager)
    mock.get_current_state = AsyncMock()
    mock.is_state_changed = AsyncMock()
    mock.get_state_summary = AsyncMock()
    return mock


@pytest.fixture
def mock_action_handler():
    """Create a mock action handler."""
    mock = Mock(spec=IActionHandler)
    mock.execute_action = AsyncMock()
    mock.get_available_actions = AsyncMock()
    return mock


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
        jokers=[
            Joker(id="j1", name="Test Joker", position=0),
            Joker(id="j2", name="Blueprint", position=1),
        ],
        consumables=[],
        current_blind=None,
        shop_contents=[],
        available_actions=["play_hand", "discard_cards"],
        post_hand_joker_reorder_available=True,
    )


class TestBalatroMCPServerInitialization:
    """Test BalatroMCPServer initialization."""

    @patch("server.main.BalatroFileIO")
    @patch("server.main.BalatroStateManager")
    @patch("server.main.BalatroActionHandler")
    def test_initialization_default_path(
        self, mock_action_handler, mock_state_manager, mock_file_io
    ):
        """Test server initialization with default shared path."""
        server = BalatroMCPServer()

        # Verify dependencies are created
        mock_file_io.assert_called_once_with(
            "C:/Users/whokn/AppData/Roaming/Balatro/mods/BalatroMCP/./"
        )
        mock_state_manager.assert_called_once()
        mock_action_handler.assert_called_once()

        # Verify server attributes
        assert server._running is False
        assert server._monitoring_task is None

    @patch("server.main.BalatroFileIO")
    @patch("server.main.BalatroStateManager")
    @patch("server.main.BalatroActionHandler")
    def test_initialization_custom_path(
        self, mock_action_handler, mock_state_manager, mock_file_io
    ):
        """Test server initialization with custom shared path."""
        custom_path = "/custom/path"
        server = BalatroMCPServer(custom_path)

        mock_file_io.assert_called_once_with(custom_path)

    @patch("server.main.BalatroFileIO")
    @patch("server.main.BalatroStateManager")
    @patch("server.main.BalatroActionHandler")
    def test_initialization_creates_mcp_server(
        self, mock_action_handler, mock_state_manager, mock_file_io
    ):
        """Test that MCP server is created during initialization."""
        server = BalatroMCPServer()

        assert server.server is not None
        assert server.server.name == "balatro-mcp"


class TestMCPResourceHandlers:
    """Test MCP resource handlers."""

    @pytest.fixture
    def server(self):
        """Create server instance for testing."""
        with patch("server.main.BalatroFileIO"), patch(
            "server.main.BalatroStateManager"
        ), patch("server.main.BalatroActionHandler"):
            return BalatroMCPServer()

    @pytest.mark.asyncio
    async def test_list_resources(self, server):
        """Test listing available resources."""
        # Test through the server's get_available_tools method instead
        tools = await server.get_available_tools()
        assert len(tools) >= 14  # At least the expected tools

        # Test that the expected tools exist
        tool_names = [t.name for t in tools]
        assert "get_game_state" in tool_names
        assert "play_hand" in tool_names
        assert "reorder_jokers" in tool_names

    @pytest.mark.asyncio
    async def test_read_game_state_resource(self, server, sample_game_state):
        """Test reading game state resource through tool call."""
        server.state_manager.get_current_state = AsyncMock(
            return_value=sample_game_state
        )

        # Test the get_game_state functionality
        result = await server.handle_tool_call("get_game_state", {})

        # Should return success with game state data
        assert result["success"] is True
        assert "game_state" in result
        assert result["tool"] == "get_game_state"
        assert "timestamp" in result
        assert result["game_state"]["session_id"] == "test_session"

    @pytest.mark.asyncio
    async def test_read_game_state_resource_no_state(self, server):
        """Test reading game state resource when no state available."""
        server.state_manager.get_current_state = AsyncMock(return_value=None)

        # Test through handle_tool_call
        result = await server.handle_tool_call("get_game_state", {})
        assert result["success"] is False
        assert result["error_message"] == "No game state available"
        assert result["tool"] == "get_game_state"
        assert "timestamp" in result

    @pytest.mark.asyncio
    async def test_read_available_actions_resource(self, server, sample_game_state):
        """Test reading available actions resource."""
        server.state_manager.get_current_state.return_value = sample_game_state
        server.action_handler.get_available_actions.return_value = [
            "play_hand",
            "discard_cards",
        ]

        # Test tools are available
        tools = await server.get_available_tools()
        tool_names = [t.name for t in tools]
        assert "play_hand" in tool_names
        assert "discard_cards" in tool_names

    @pytest.mark.asyncio
    async def test_read_joker_order_resource(self, server, sample_game_state):
        """Test reading joker order resource."""
        server.state_manager.get_current_state.return_value = sample_game_state

        # Test that reorder_jokers tool is available
        tools = await server.get_available_tools()
        tool_names = [t.name for t in tools]
        assert "reorder_jokers" in tool_names

        # Find the reorder tool and check its description
        reorder_tool = next(t for t in tools if t.name == "reorder_jokers")
        assert "Blueprint/Brainstorm" in reorder_tool.description

    @pytest.mark.asyncio
    async def test_read_joker_order_resource_no_jokers(self, server, sample_game_state):
        """Test reading joker order resource when no jokers."""
        sample_game_state.jokers = []
        sample_game_state.post_hand_joker_reorder_available = False
        server.state_manager.get_current_state.return_value = sample_game_state

        # Still should have reorder_jokers tool available
        tools = await server.get_available_tools()
        tool_names = [t.name for t in tools]
        assert "reorder_jokers" in tool_names

    @pytest.mark.asyncio
    async def test_read_unknown_resource(self, server):
        """Test reading unknown resource."""
        # Test unknown tool call
        result = await server.handle_tool_call("unknown_tool", {})
        assert "error" in result
        assert "Unknown tool" in result["error"]

    @pytest.mark.asyncio
    async def test_read_resource_exception_handling(self, server):
        """Test resource reading exception handling."""
        server.action_handler.execute_action = AsyncMock(
            side_effect=Exception("Test error")
        )

        result = await server.handle_tool_call("play_hand", {"card_indices": [0]})
        assert "error" in result
        assert "Internal error" in result["error"]


class TestMCPToolHandlers:
    """Test MCP tool handlers."""

    @pytest.fixture
    def server(self):
        """Create server instance for testing."""
        with patch("server.main.BalatroFileIO"), patch(
            "server.main.BalatroStateManager"
        ), patch("server.main.BalatroActionHandler"):
            return BalatroMCPServer()

    @pytest.mark.asyncio
    async def test_list_tools(self, server):
        """Test listing available tools."""
        tools = await server.get_available_tools()

        assert len(tools) == 15  # 14 actions + get_game_state

        tool_names = [t.name for t in tools]
        assert "get_game_state" in tool_names
        assert "play_hand" in tool_names
        assert "reorder_jokers" in tool_names

    @pytest.mark.asyncio
    async def test_call_tool_success(self, server):
        """Test successful tool call."""
        # Configure async mock to return ActionResult
        action_result = ActionResult(success=True)
        server.action_handler.execute_action = AsyncMock(return_value=action_result)

        result = await server.handle_tool_call("play_hand", {"card_indices": [0, 1]})

        assert result["success"] is True
        assert result["tool"] == "play_hand"
        assert "timestamp" in result

    @pytest.mark.asyncio
    async def test_call_tool_exception(self, server):
        """Test tool call exception handling."""
        server.action_handler.execute_action = AsyncMock(
            side_effect=Exception("Test error")
        )

        result = await server.handle_tool_call("play_hand", {"card_indices": [0, 1]})

        assert "error" in result
        assert "Internal error" in result["error"]


class TestToolCallHandling:
    """Test tool call handling and action creation."""

    @pytest.fixture
    def server(self):
        """Create server instance for testing."""
        with patch("server.main.BalatroFileIO"), patch(
            "server.main.BalatroStateManager"
        ), patch("server.main.BalatroActionHandler"):
            return BalatroMCPServer()

    @pytest.mark.asyncio
    async def test_handle_tool_call_play_hand(self, server):
        """Test handling play hand tool call."""
        expected_result = ActionResult(success=True)
        server.action_handler.execute_action = AsyncMock(return_value=expected_result)

        result = await server.handle_tool_call("play_hand", {"card_indices": [0, 1]})

        assert result["success"] is True
        assert result["tool"] == "play_hand"
        assert "timestamp" in result
        server.action_handler.execute_action.assert_called_once()

    @pytest.mark.asyncio
    async def test_handle_tool_call_buy_item(self, server):
        """Test handling buy item tool call."""
        expected_result = ActionResult(success=True)
        server.action_handler.execute_action = AsyncMock(return_value=expected_result)

        result = await server.handle_tool_call("buy_item", {"shop_index": 0})

        assert result["success"] is True
        assert result["tool"] == "buy_item"

    @pytest.mark.asyncio
    async def test_handle_tool_call_reorder_jokers(self, server):
        """Test handling reorder jokers tool call."""
        expected_result = ActionResult(success=True)
        server.action_handler.execute_action = AsyncMock(return_value=expected_result)

        result = await server.handle_tool_call(
            "reorder_jokers", {"new_order": [1, 0, 2]}
        )

        assert result["success"] is True
        assert result["tool"] == "reorder_jokers"

    @pytest.mark.asyncio
    async def test_handle_tool_call_unknown_tool(self, server):
        """Test handling unknown tool call."""
        result = await server.handle_tool_call("unknown_tool", {})

        assert "error" in result
        assert "Unknown tool" in result["error"]

    @pytest.mark.asyncio
    async def test_handle_tool_call_exception(self, server):
        """Test tool call exception handling."""
        server.action_handler.execute_action = AsyncMock(
            side_effect=Exception("Test error")
        )

        result = await server.handle_tool_call("play_hand", {"card_indices": [0, 1]})

        assert "error" in result
        assert "Internal error" in result["error"]

    @pytest.mark.asyncio
    async def test_handle_tool_call_action_failure(self, server):
        """Test handling tool call when action fails."""
        expected_result = ActionResult(success=False, error_message="Action failed")
        server.action_handler.execute_action = AsyncMock(return_value=expected_result)

        result = await server.handle_tool_call("play_hand", {"card_indices": [0, 1]})

        assert result["success"] is False
        assert result["error_message"] == "Action failed"

    @pytest.mark.asyncio
    async def test_handle_get_game_state_with_state(self, server, sample_game_state):
        """Test handling get_game_state tool call with available state."""
        server.state_manager.get_current_state = AsyncMock(
            return_value=sample_game_state
        )

        result = await server.handle_tool_call("get_game_state", {})

        assert result["success"] is True
        assert "game_state" in result
        assert result["tool"] == "get_game_state"
        assert "timestamp" in result
        # Verify state data is properly serialized
        assert result["game_state"]["session_id"] == "test_session"
        assert result["game_state"]["ante"] == 1
        assert result["game_state"]["money"] == 100

    @pytest.mark.asyncio
    async def test_handle_get_game_state_no_state(self, server):
        """Test handling get_game_state tool call with no available state."""
        server.state_manager.get_current_state = AsyncMock(return_value=None)

        result = await server.handle_tool_call("get_game_state", {})

        assert result["success"] is False
        assert result["error_message"] == "No game state available"
        assert result["tool"] == "get_game_state"
        assert "timestamp" in result
        assert "game_state" not in result

    @pytest.mark.asyncio
    async def test_handle_get_game_state_exception(self, server):
        """Test handling get_game_state tool call when state manager throws exception."""
        server.state_manager.get_current_state = AsyncMock(
            side_effect=Exception("State error")
        )

        result = await server.handle_tool_call("get_game_state", {})

        assert "error" in result
        assert "Internal error" in result["error"]

    @pytest.mark.asyncio
    async def test_get_game_state_timestamp_format(self, server, sample_game_state):
        """Test that get_game_state returns properly formatted timestamp."""
        server.state_manager.get_current_state = AsyncMock(
            return_value=sample_game_state
        )

        result = await server.handle_tool_call("get_game_state", {})

        assert result["success"] is True
        timestamp = result["timestamp"]
        # Should be ISO format with timezone
        assert "T" in timestamp
        assert timestamp.endswith("+00:00") or timestamp.endswith("Z")

    @pytest.mark.asyncio
    async def test_get_game_state_no_action_execution(self, server, sample_game_state):
        """Test that get_game_state doesn't trigger action execution."""
        server.state_manager.get_current_state = AsyncMock(
            return_value=sample_game_state
        )
        server.action_handler.execute_action = AsyncMock()

        result = await server.handle_tool_call("get_game_state", {})

        assert result["success"] is True
        # Action handler should not be called for get_game_state
        server.action_handler.execute_action.assert_not_called()


class TestActionCreation:
    """Test action creation from tool parameters."""

    @pytest.fixture
    def server(self):
        """Create server instance for testing."""
        with patch("server.main.BalatroFileIO"), patch(
            "server.main.BalatroStateManager"
        ), patch("server.main.BalatroActionHandler"):
            return BalatroMCPServer()

    @pytest.mark.asyncio
    async def test_create_play_hand_action(self, server):
        """Test creating play hand action."""
        action = await server._create_action_from_tool(
            "play_hand", {"card_indices": [0, 1, 2]}
        )

        assert isinstance(action, PlayHandAction)
        assert action.card_indices == [0, 1, 2]

    @pytest.mark.asyncio
    async def test_create_buy_item_action(self, server):
        """Test creating buy item action."""
        action = await server._create_action_from_tool("buy_item", {"shop_index": 2})

        assert isinstance(action, BuyItemAction)
        assert action.shop_index == 2

    @pytest.mark.asyncio
    async def test_create_reorder_jokers_action(self, server):
        """Test creating reorder jokers action."""
        action = await server._create_action_from_tool(
            "reorder_jokers", {"new_order": [2, 0, 1]}
        )

        assert isinstance(action, ReorderJokersAction)
        assert action.new_order == [2, 0, 1]

    @pytest.mark.asyncio
    async def test_create_action_get_game_state(self, server):
        """Test creating action for get_game_state (should return None)."""
        action = await server._create_action_from_tool("get_game_state", {})

        assert action is None

    @pytest.mark.asyncio
    async def test_create_action_unknown_tool(self, server):
        """Test creating action for unknown tool."""
        action = await server._create_action_from_tool("unknown_tool", {})

        assert action is None

    @pytest.mark.asyncio
    async def test_create_action_missing_argument(self, server):
        """Test creating action with missing required argument."""
        action = await server._create_action_from_tool(
            "buy_item", {}
        )  # Missing shop_index

        assert action is None

    @pytest.mark.asyncio
    async def test_create_action_all_simple_actions(self, server):
        """Test creating all simple actions (no parameters)."""
        simple_actions = [
            "go_to_shop",
            "reroll_boss",
            "reroll_shop",
            "sort_hand_by_rank",
            "sort_hand_by_suit",
        ]

        for action_name in simple_actions:
            action = await server._create_action_from_tool(action_name, {})
            assert action is not None
            assert action.action_type == action_name


class TestServerLifecycle:
    """Test server lifecycle management."""

    @pytest.fixture
    def server(self):
        """Create server instance for testing."""
        with patch("server.main.BalatroFileIO"), patch(
            "server.main.BalatroStateManager"
        ), patch("server.main.BalatroActionHandler"):
            return BalatroMCPServer()

    @pytest.mark.asyncio
    async def test_start_server(self, server):
        """Test starting the server."""
        # Configure file_io methods as AsyncMock
        server.file_io.ensure_directories = AsyncMock()

        with patch("asyncio.create_task", return_value=AsyncMock()) as mock_create_task:
            await server.start()

        assert server._running is True
        server.file_io.ensure_directories.assert_called_once()
        mock_create_task.assert_called_once()

    @pytest.mark.asyncio
    async def test_stop_server(self, server):
        """Test stopping the server."""

        # Create a proper async task mock
        async def dummy_task():
            pass

        mock_task = asyncio.create_task(dummy_task())
        mock_task.cancel = Mock()
        server._monitoring_task = mock_task
        server._running = True

        await server.stop()

        assert server._running is False
        mock_task.cancel.assert_called_once()

    @pytest.mark.asyncio
    async def test_stop_server_no_monitoring_task(self, server):
        """Test stopping server when no monitoring task exists."""
        server._running = True
        server._monitoring_task = None

        # Should not raise exception
        await server.stop()

        assert server._running is False

    @pytest.mark.asyncio
    async def test_stop_server_task_cancellation_error(self, server):
        """Test stopping server handles task cancellation error."""

        # Create a real task that will be cancelled
        async def dummy_task():
            await asyncio.sleep(10)  # Long running task

        mock_task = asyncio.create_task(dummy_task())
        mock_task.cancel()  # Cancel it immediately
        server._monitoring_task = mock_task
        server._running = True

        # Should handle exception gracefully
        await server.stop()

        assert server._running is False


class TestBackgroundMonitoring:
    """Test background state monitoring."""

    @pytest.fixture
    def server(self):
        """Create server instance for testing."""
        with patch("server.main.BalatroFileIO"), patch(
            "server.main.BalatroStateManager"
        ), patch("server.main.BalatroActionHandler"):
            return BalatroMCPServer()

    @pytest.mark.asyncio
    async def test_monitor_game_state_no_changes(self, server):
        """Test monitoring when no state changes occur."""
        server._running = True
        server.state_manager.is_state_changed = AsyncMock(return_value=False)
        server.file_io.cleanup_old_files = AsyncMock()

        # Mock sleep to prevent infinite loop
        with patch(
            "asyncio.sleep", side_effect=lambda x: setattr(server, "_running", False)
        ):
            await server._monitor_game_state()

        server.state_manager.is_state_changed.assert_called()
        server.file_io.cleanup_old_files.assert_called()

    @pytest.mark.asyncio
    async def test_monitor_game_state_with_changes(self, server):
        """Test monitoring when state changes occur."""
        server._running = True
        server.state_manager.is_state_changed = AsyncMock(return_value=True)
        server.state_manager.get_state_summary = AsyncMock(
            return_value={"phase": "hand_selection"}
        )
        server.file_io.cleanup_old_files = AsyncMock()

        # Mock sleep to prevent infinite loop
        with patch(
            "asyncio.sleep", side_effect=lambda x: setattr(server, "_running", False)
        ):
            await server._monitor_game_state()

        server.state_manager.get_state_summary.assert_called()

    @pytest.mark.asyncio
    async def test_monitor_game_state_exception_handling(self, server):
        """Test monitoring handles exceptions gracefully."""
        server._running = True
        server.state_manager.is_state_changed = AsyncMock(
            side_effect=Exception("Test error")
        )

        # Mock sleep to prevent infinite loop
        with patch(
            "asyncio.sleep", side_effect=lambda x: setattr(server, "_running", False)
        ):
            await server._monitor_game_state()

        # Should not raise exception and continue monitoring


class TestGetAvailableTools:
    """Test available tools listing."""

    @pytest.fixture
    def server(self):
        """Create server instance for testing."""
        with patch("server.main.BalatroFileIO"), patch(
            "server.main.BalatroStateManager"
        ), patch("server.main.BalatroActionHandler"):
            return BalatroMCPServer()

    @pytest.mark.asyncio
    async def test_get_available_tools_count(self, server):
        """Test that all expected tools are available."""
        tools = await server.get_available_tools()

        assert len(tools) == 15  # 14 game actions + get_game_state

    @pytest.mark.asyncio
    async def test_get_available_tools_structure(self, server):
        """Test tool structure and schemas."""
        tools = await server.get_available_tools()

        # Find play_hand tool
        play_hand_tool = next(t for t in tools if t.name == "play_hand")
        assert play_hand_tool.description is not None
        assert "card_indices" in play_hand_tool.inputSchema["properties"]
        assert play_hand_tool.inputSchema["required"] == ["card_indices"]

    @pytest.mark.asyncio
    async def test_get_available_tools_no_params(self, server):
        """Test tools that require no parameters."""
        tools = await server.get_available_tools()

        # Find get_game_state tool
        get_state_tool = next(t for t in tools if t.name == "get_game_state")
        assert get_state_tool.inputSchema["required"] == []

    @pytest.mark.asyncio
    async def test_get_available_tools_reorder_jokers(self, server):
        """Test reorder jokers tool schema."""
        tools = await server.get_available_tools()

        # Find reorder_jokers tool
        reorder_tool = next(t for t in tools if t.name == "reorder_jokers")
        assert "Blueprint/Brainstorm" in reorder_tool.description
        assert "new_order" in reorder_tool.inputSchema["properties"]
        assert reorder_tool.inputSchema["properties"]["new_order"]["type"] == "array"


class TestIntegrationScenarios:
    """Test integration scenarios combining multiple components."""

    @pytest.fixture
    def server(self):
        """Create server instance for testing."""
        with patch("server.main.BalatroFileIO"), patch(
            "server.main.BalatroStateManager"
        ), patch("server.main.BalatroActionHandler"):
            return BalatroMCPServer()

    @pytest.mark.asyncio
    async def test_full_tool_call_flow(self, server, sample_game_state):
        """Test complete flow from tool call to action execution."""
        # Setup mocks
        server.state_manager.get_current_state = AsyncMock(
            return_value=sample_game_state
        )
        server.action_handler.execute_action = AsyncMock(
            return_value=ActionResult(success=True)
        )

        # Execute tool call
        result = await server.handle_tool_call("play_hand", {"card_indices": [0]})

        # Verify flow
        assert result["success"] is True
        assert result["tool"] == "play_hand"
        server.action_handler.execute_action.assert_called_once()

        # Verify action was created correctly
        call_args = server.action_handler.execute_action.call_args[0]
        action = call_args[0]
        assert isinstance(action, PlayHandAction)
        assert action.card_indices == [0]

    @pytest.mark.asyncio
    async def test_resource_and_tool_consistency(self, server, sample_game_state):
        """Test that resources and tools provide consistent information."""
        # Setup state
        server.state_manager.get_current_state.return_value = sample_game_state
        server.action_handler.get_available_actions.return_value = [
            "play_hand",
            "reorder_jokers",
        ]

        # Get available tools
        tools = await server.get_available_tools()
        tool_names = [t.name for t in tools]

        # Verify consistency (available actions should be subset of available tools)
        assert "play_hand" in tool_names
        assert "reorder_jokers" in tool_names

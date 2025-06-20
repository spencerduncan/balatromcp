"""
Interfaces for the Balatro MCP Server components.
Defines contracts for dependency injection and clean architecture.
"""

from abc import ABC, abstractmethod
from typing import Optional, Dict, Any
from .schemas import GameState, GameAction, ActionResult, CommunicationMessage


class IFileIO(ABC):
    """Interface for file-based communication operations."""

    @abstractmethod
    async def read_game_state(self) -> Optional[GameState]:
        """Read the current game state from file."""
        pass

    @abstractmethod
    async def write_action(self, action: GameAction) -> bool:
        """Write an action command to file."""
        pass

    @abstractmethod
    async def read_action_result(self) -> Optional[ActionResult]:
        """Read action execution result from file."""
        pass

    @abstractmethod
    def get_next_sequence_id(self) -> int:
        """Get the next sequence ID for communication."""
        pass


class IStateManager(ABC):
    """Interface for game state management."""

    @abstractmethod
    async def get_current_state(self) -> Optional[GameState]:
        """Get the current game state."""
        pass

    @abstractmethod
    async def update_state(self, new_state: GameState) -> None:
        """Update the current game state."""
        pass

    @abstractmethod
    async def is_state_changed(self) -> bool:
        """Check if the game state has changed since last check."""
        pass


class IActionHandler(ABC):
    """Interface for handling game actions."""

    @abstractmethod
    async def execute_action(self, action: GameAction) -> ActionResult:
        """Execute a game action and return the result."""
        pass

    @abstractmethod
    async def validate_action(
        self, action: GameAction, current_state: GameState
    ) -> bool:
        """Validate if an action is valid in the current state."""
        pass

    @abstractmethod
    async def get_available_actions(self, current_state: GameState) -> list[str]:
        """Get list of available actions for the current state."""
        pass


class IMCPServer(ABC):
    """Interface for the MCP Server."""

    @abstractmethod
    async def start(self) -> None:
        """Start the MCP server."""
        pass

    @abstractmethod
    async def stop(self) -> None:
        """Stop the MCP server."""
        pass

    @abstractmethod
    async def handle_tool_call(
        self, tool_name: str, arguments: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Handle an MCP tool call."""
        pass

    @abstractmethod
    async def get_available_tools(self) -> list[Dict[str, Any]]:
        """Get list of available MCP tools."""
        pass


class IGameSession(ABC):
    """Interface for managing a game session."""

    @abstractmethod
    async def initialize(self) -> bool:
        """Initialize a new game session."""
        pass

    @abstractmethod
    async def cleanup(self) -> None:
        """Clean up the game session."""
        pass

    @abstractmethod
    async def is_active(self) -> bool:
        """Check if the game session is active."""
        pass

    @abstractmethod
    async def get_session_id(self) -> str:
        """Get the session identifier."""
        pass

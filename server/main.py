"""
Main MCP Server implementation for Balatro.
Provides the standardized MCP interface for AI agents.
"""

import asyncio
import logging
from typing import Dict, Any, List, Optional
from datetime import datetime, timezone

from mcp.server import Server
from mcp.server.models import InitializationOptions
from mcp.server.stdio import stdio_server
from mcp.types import (
    Resource,
    Tool,
    TextContent,
    ImageContent,
    EmbeddedResource,
    CallToolResult,
    ListResourcesResult,
    ListToolsResult,
    ReadResourceResult,
)

from .interfaces import IMCPServer, IFileIO, IStateManager, IActionHandler
from .file_io import BalatroFileIO
from .state_manager import BalatroStateManager
from .action_handler import BalatroActionHandler
from .schemas import (
    GameAction,
    PlayHandAction,
    DiscardCardsAction,
    GoToShopAction,
    BuyItemAction,
    SellJokerAction,
    SellConsumableAction,
    ReorderJokersAction,
    SelectBlindAction,
    SelectPackOfferAction,
    RerollBossAction,
    RerollShopAction,
    SortHandByRankAction,
    SortHandBySuitAction,
    UseConsumableAction,
)


# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class BalatroMCPServer(IMCPServer):
    """Main MCP Server implementation for Balatro."""

    def __init__(
        self,
        shared_path: str = "C:/Users/whokn/AppData/Roaming/Balatro/mods/BalatroMCP/./",
    ):
        """Initialize the MCP server with dependency injection."""
        # Initialize dependencies
        self.file_io: IFileIO = BalatroFileIO(shared_path)
        self.state_manager: IStateManager = BalatroStateManager(self.file_io)
        self.action_handler: IActionHandler = BalatroActionHandler(
            self.file_io, self.state_manager
        )

        # Initialize MCP server
        self.server = Server("balatro-mcp")
        self._setup_handlers()

        # Server state
        self._running = False
        self._monitoring_task: Optional[asyncio.Task] = None

        logger.info("BalatroMCPServer initialized")

    def _setup_handlers(self) -> None:
        """Setup MCP server handlers."""

        @self.server.list_resources()
        async def handle_list_resources() -> ListResourcesResult:
            """List available MCP resources."""
            return ListResourcesResult(
                resources=[
                    Resource(
                        uri="balatro://game-state",
                        name="Current Game State",
                        description="The current state of the Balatro game",
                        mimeType="application/json",
                    ),
                    Resource(
                        uri="balatro://available-actions",
                        name="Available Actions",
                        description="List of actions available in the current game state",
                        mimeType="application/json",
                    ),
                    Resource(
                        uri="balatro://joker-order",
                        name="Joker Order",
                        description="Current joker arrangement for strategic ordering",
                        mimeType="application/json",
                    ),
                ]
            )

        @self.server.read_resource()
        async def handle_read_resource(uri: str) -> ReadResourceResult:
            """Read a specific resource."""
            try:
                if uri == "balatro://game-state":
                    state = await self.state_manager.get_current_state()
                    if state is None:
                        content = {"error": "No game state available"}
                    else:
                        content = state.model_dump()

                    return ReadResourceResult(
                        contents=[TextContent(type="text", text=str(content))]
                    )

                elif uri == "balatro://available-actions":
                    state = await self.state_manager.get_current_state()
                    if state is None:
                        actions = []
                    else:
                        actions = await self.action_handler.get_available_actions(state)

                    return ReadResourceResult(
                        contents=[
                            TextContent(
                                type="text", text=str({"available_actions": actions})
                            )
                        ]
                    )

                elif uri == "balatro://joker-order":
                    state = await self.state_manager.get_current_state()
                    if state is None or not state.jokers:
                        joker_info = {"jokers": [], "reorder_available": False}
                    else:
                        joker_info = {
                            "jokers": [
                                {"position": j.position, "name": j.name}
                                for j in state.jokers
                            ],
                            "reorder_available": state.post_hand_joker_reorder_available,
                        }

                    return ReadResourceResult(
                        contents=[TextContent(type="text", text=str(joker_info))]
                    )

                else:
                    return ReadResourceResult(
                        contents=[
                            TextContent(type="text", text=f"Unknown resource: {uri}")
                        ]
                    )

            except Exception as e:
                logger.error(f"Error reading resource {uri}: {e}")
                return ReadResourceResult(
                    contents=[TextContent(type="text", text=f"Error: {str(e)}")]
                )

        @self.server.list_tools()
        async def handle_list_tools() -> ListToolsResult:
            """List available MCP tools."""
            return ListToolsResult(tools=await self.get_available_tools())

        @self.server.call_tool()
        async def handle_call_tool(
            name: str, arguments: Dict[str, Any]
        ) -> CallToolResult:
            """Handle tool calls."""
            try:
                result = await self.handle_tool_call(name, arguments)
                return CallToolResult(
                    content=[TextContent(type="text", text=str(result))]
                )
            except Exception as e:
                logger.error(f"Error calling tool {name}: {e}")
                return CallToolResult(
                    content=[TextContent(type="text", text=f"Error: {str(e)}")],
                    isError=True,
                )

    async def start(self) -> None:
        """Start the MCP server."""
        self._running = True

        # Ensure file directories exist
        await self.file_io.ensure_directories()

        # Start background monitoring
        self._monitoring_task = asyncio.create_task(self._monitor_game_state())

        logger.info("BalatroMCPServer started")

    async def stop(self) -> None:
        """Stop the MCP server."""
        self._running = False

        if self._monitoring_task:
            self._monitoring_task.cancel()
            try:
                await self._monitoring_task
            except asyncio.CancelledError:
                pass

        logger.info("BalatroMCPServer stopped")

    async def handle_tool_call(
        self, tool_name: str, arguments: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Handle an MCP tool call."""
        try:
            # Special handling for get_game_state tool
            if tool_name == "get_game_state":
                state = await self.state_manager.get_current_state()
                if state is None:
                    return {
                        "success": False,
                        "error_message": "No game state available",
                        "tool": tool_name,
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                    }
                else:
                    return {
                        "success": True,
                        "game_state": state.model_dump(),
                        "tool": tool_name,
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                    }

            # Map tool names to action creation
            action = await self._create_action_from_tool(tool_name, arguments)
            if action is None:
                return {"error": f"Unknown tool: {tool_name}"}

            # Execute the action
            result = await self.action_handler.execute_action(action)

            return {
                "success": result.success,
                "error_message": result.error_message,
                "tool": tool_name,
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }

        except Exception as e:
            logger.error(f"Error handling tool call {tool_name}: {e}")
            return {"error": f"Internal error: {str(e)}"}

    async def get_available_tools(self) -> List[Tool]:
        """Get list of available MCP tools."""
        return [
            Tool(
                name="get_game_state",
                description="Retrieve the current game state",
                inputSchema={"type": "object", "properties": {}, "required": []},
            ),
            Tool(
                name="play_hand",
                description="Play selected cards from hand",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "card_indices": {
                            "type": "array",
                            "items": {"type": "integer"},
                            "description": "Indices of cards to play",
                        }
                    },
                    "required": ["card_indices"],
                },
            ),
            Tool(
                name="discard_cards",
                description="Discard selected cards from hand",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "card_indices": {
                            "type": "array",
                            "items": {"type": "integer"},
                            "description": "Indices of cards to discard",
                        }
                    },
                    "required": ["card_indices"],
                },
            ),
            Tool(
                name="go_to_shop",
                description="Navigate to the shop phase",
                inputSchema={"type": "object", "properties": {}, "required": []},
            ),
            Tool(
                name="buy_item",
                description="Purchase an item from the shop",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "shop_index": {
                            "type": "integer",
                            "description": "Index of shop item to purchase",
                        }
                    },
                    "required": ["shop_index"],
                },
            ),
            Tool(
                name="sell_joker",
                description="Sell a joker from collection",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "joker_index": {
                            "type": "integer",
                            "description": "Index of joker to sell",
                        }
                    },
                    "required": ["joker_index"],
                },
            ),
            Tool(
                name="sell_consumable",
                description="Sell a consumable card",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "consumable_index": {
                            "type": "integer",
                            "description": "Index of consumable to sell",
                        }
                    },
                    "required": ["consumable_index"],
                },
            ),
            Tool(
                name="reorder_jokers",
                description="Reorder jokers for Blueprint/Brainstorm strategy",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "new_order": {
                            "type": "array",
                            "items": {"type": "integer"},
                            "description": "New joker order (indices)",
                        }
                    },
                    "required": ["new_order"],
                },
            ),
            Tool(
                name="select_blind",
                description="Select blind type",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "blind_type": {
                            "type": "string",
                            "description": "Type of blind to select",
                        }
                    },
                    "required": ["blind_type"],
                },
            ),
            Tool(
                name="select_pack_offer",
                description="Select from pack offers",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "pack_index": {
                            "type": "integer",
                            "description": "Index of pack to select",
                        }
                    },
                    "required": ["pack_index"],
                },
            ),
            Tool(
                name="reroll_boss",
                description="Reroll boss blind options",
                inputSchema={"type": "object", "properties": {}, "required": []},
            ),
            Tool(
                name="reroll_shop",
                description="Reroll shop contents",
                inputSchema={"type": "object", "properties": {}, "required": []},
            ),
            Tool(
                name="sort_hand_by_rank",
                description="Sort hand cards by rank",
                inputSchema={"type": "object", "properties": {}, "required": []},
            ),
            Tool(
                name="sort_hand_by_suit",
                description="Sort hand cards by suit",
                inputSchema={"type": "object", "properties": {}, "required": []},
            ),
            Tool(
                name="use_consumable",
                description="Use a consumable card",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "item_id": {
                            "type": "string",
                            "description": "ID of consumable to use",
                        }
                    },
                    "required": ["item_id"],
                },
            ),
        ]

    async def _create_action_from_tool(
        self, tool_name: str, arguments: Dict[str, Any]
    ) -> Optional[GameAction]:
        """Create a GameAction from tool call parameters."""
        try:
            if tool_name == "get_game_state":
                # This is handled directly, not as an action
                return None
            elif tool_name == "play_hand":
                return PlayHandAction(card_indices=arguments["card_indices"])
            elif tool_name == "discard_cards":
                return DiscardCardsAction(card_indices=arguments["card_indices"])
            elif tool_name == "go_to_shop":
                return GoToShopAction()
            elif tool_name == "buy_item":
                return BuyItemAction(shop_index=arguments["shop_index"])
            elif tool_name == "sell_joker":
                return SellJokerAction(joker_index=arguments["joker_index"])
            elif tool_name == "sell_consumable":
                return SellConsumableAction(
                    consumable_index=arguments["consumable_index"]
                )
            elif tool_name == "reorder_jokers":
                return ReorderJokersAction(new_order=arguments["new_order"])
            elif tool_name == "select_blind":
                return SelectBlindAction(blind_type=arguments["blind_type"])
            elif tool_name == "select_pack_offer":
                return SelectPackOfferAction(pack_index=arguments["pack_index"])
            elif tool_name == "reroll_boss":
                return RerollBossAction()
            elif tool_name == "reroll_shop":
                return RerollShopAction()
            elif tool_name == "sort_hand_by_rank":
                return SortHandByRankAction()
            elif tool_name == "sort_hand_by_suit":
                return SortHandBySuitAction()
            elif tool_name == "use_consumable":
                return UseConsumableAction(item_id=arguments["item_id"])
            else:
                return None
        except KeyError as e:
            logger.error(f"Missing required argument for {tool_name}: {e}")
            return None

    async def _monitor_game_state(self) -> None:
        """Background task to monitor game state changes."""
        while self._running:
            try:
                # Check for state changes
                if await self.state_manager.is_state_changed():
                    summary = await self.state_manager.get_state_summary()
                    logger.info(f"Game state changed: {summary}")

                # Clean up old files periodically
                await self.file_io.cleanup_old_files()

            except Exception as e:
                logger.error(f"Error in state monitoring: {e}")

            await asyncio.sleep(1.0)  # Monitor every second


async def main():
    """Main entry point for the MCP server."""
    server = BalatroMCPServer()

    # Setup graceful shutdown
    import signal

    def signal_handler(signum, frame):
        logger.info("Received shutdown signal")
        asyncio.create_task(server.stop())

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    try:
        await server.start()

        # Run the MCP server using stdio
        async with stdio_server() as (read_stream, write_stream):
            await server.server.run(
                read_stream,
                write_stream,
                InitializationOptions(
                    server_name="balatro-mcp", server_version="1.0.0", capabilities={}
                ),
            )

    except KeyboardInterrupt:
        logger.info("Shutting down...")
    finally:
        await server.stop()


if __name__ == "__main__":
    asyncio.run(main())

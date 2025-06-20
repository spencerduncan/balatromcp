"""
Action handling for the Balatro MCP Server.
Handles validation and execution of game actions.
"""

import asyncio
import logging
from typing import Dict, Any, List
from datetime import datetime

from .interfaces import IActionHandler, IFileIO, IStateManager
from .schemas import (
    GameAction,
    ActionResult,
    GameState,
    GamePhase,
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


logger = logging.getLogger(__name__)


class BalatroActionHandler(IActionHandler):
    """Handles game action validation and execution."""

    def __init__(self, file_io: IFileIO, state_manager: IStateManager):
        """Initialize action handler with dependencies."""
        self.file_io = file_io
        self.state_manager = state_manager

        # Action validation rules
        self.action_validators = {
            "play_hand": self._validate_play_hand,
            "discard_cards": self._validate_discard_cards,
            "go_to_shop": self._validate_go_to_shop,
            "buy_item": self._validate_buy_item,
            "sell_joker": self._validate_sell_joker,
            "sell_consumable": self._validate_sell_consumable,
            "reorder_jokers": self._validate_reorder_jokers,
            "select_blind": self._validate_select_blind,
            "select_pack_offer": self._validate_select_pack_offer,
            "reroll_boss": self._validate_reroll_boss,
            "reroll_shop": self._validate_reroll_shop,
            "sort_hand_by_rank": self._validate_sort_hand,
            "sort_hand_by_suit": self._validate_sort_hand,
            "use_consumable": self._validate_use_consumable,
        }

        logger.info("BalatroActionHandler initialized")

    async def execute_action(self, action: GameAction) -> ActionResult:
        """Execute a game action and return the result."""
        try:
            # Get current state for validation
            current_state = await self.state_manager.get_current_state()
            if current_state is None:
                return ActionResult(
                    success=False, error_message="No game state available"
                )

            # Validate action
            if not await self.validate_action(action, current_state):
                return ActionResult(
                    success=False,
                    error_message=f"Action {action.action_type} is not valid in current state",
                )

            # Write action to file for mod to execute
            success = await self.file_io.write_action(action)
            if not success:
                return ActionResult(
                    success=False, error_message="Failed to write action to file"
                )

            # Wait for action result from mod
            result = await self.file_io.wait_for_action_result(timeout_seconds=10)
            if result is None:
                return ActionResult(
                    success=False, error_message="Timeout waiting for action result"
                )

            logger.info(
                f"Action {action.action_type} executed: success={result.success}"
            )
            return result

        except Exception as e:
            logger.error(f"Error executing action {action.action_type}: {e}")
            return ActionResult(
                success=False, error_message=f"Internal error: {str(e)}"
            )

    async def validate_action(
        self, action: GameAction, current_state: GameState
    ) -> bool:
        """Validate if an action is valid in the current state."""
        try:
            action_type = action.action_type

            # Check if action is available in current state
            if action_type not in current_state.available_actions:
                logger.debug(
                    f"Action {action_type} not in available actions: {current_state.available_actions}"
                )
                return False

            # Use specific validator if available
            validator = self.action_validators.get(action_type)
            if validator:
                return await validator(action, current_state)

            # Default validation - action is in available actions
            return True

        except Exception as e:
            logger.error(f"Error validating action {action.action_type}: {e}")
            return False

    async def get_available_actions(self, current_state: GameState) -> List[str]:
        """Get list of available actions for the current state."""
        return current_state.available_actions.copy()

    # Action-specific validators

    async def _validate_play_hand(
        self, action: PlayHandAction, state: GameState
    ) -> bool:
        """Validate play hand action."""
        if state.current_phase != GamePhase.HAND_SELECTION:
            return False

        if state.hands_remaining <= 0:
            return False

        # Check card indices are valid
        hand_size = len(state.hand_cards)
        if not all(0 <= idx < hand_size for idx in action.card_indices):
            return False

        # Check at least one card is selected
        if not action.card_indices:
            return False

        return True

    async def _validate_discard_cards(
        self, action: DiscardCardsAction, state: GameState
    ) -> bool:
        """Validate discard cards action."""
        if state.current_phase != GamePhase.HAND_SELECTION:
            return False

        if state.discards_remaining <= 0:
            return False

        # Check card indices are valid
        hand_size = len(state.hand_cards)
        if not all(0 <= idx < hand_size for idx in action.card_indices):
            return False

        # Check at least one card is selected
        if not action.card_indices:
            return False

        return True

    async def _validate_go_to_shop(
        self, action: GoToShopAction, state: GameState
    ) -> bool:
        """Validate go to shop action."""
        # Can usually go to shop from hand selection phase
        return state.current_phase == GamePhase.HAND_SELECTION

    async def _validate_buy_item(self, action: BuyItemAction, state: GameState) -> bool:
        """Validate buy item action."""
        if state.current_phase != GamePhase.SHOP:
            return False

        # Check shop index is valid
        if not (0 <= action.shop_index < len(state.shop_contents)):
            return False

        # Check player has enough money
        item = state.shop_contents[action.shop_index]
        if state.money < item.cost:
            return False

        return True

    async def _validate_sell_joker(
        self, action: SellJokerAction, state: GameState
    ) -> bool:
        """Validate sell joker action."""
        if state.current_phase != GamePhase.SHOP:
            return False

        # Check joker index is valid
        if not (0 <= action.joker_index < len(state.jokers)):
            return False

        return True

    async def _validate_sell_consumable(
        self, action: SellConsumableAction, state: GameState
    ) -> bool:
        """Validate sell consumable action."""
        if state.current_phase != GamePhase.SHOP:
            return False

        # Check consumable index is valid
        if not (0 <= action.consumable_index < len(state.consumables)):
            return False

        return True

    async def _validate_reorder_jokers(
        self, action: ReorderJokersAction, state: GameState
    ) -> bool:
        """Validate reorder jokers action - critical for Blueprint/Brainstorm strategy."""
        # Can only reorder during specific timing window
        if not state.post_hand_joker_reorder_available:
            return False

        # Check new order is valid permutation of current jokers
        joker_count = len(state.jokers)
        if len(action.new_order) != joker_count:
            return False

        # Check all indices are valid and unique
        if set(action.new_order) != set(range(joker_count)):
            return False

        return True

    async def _validate_select_blind(
        self, action: SelectBlindAction, state: GameState
    ) -> bool:
        """Validate select blind action."""
        return state.current_phase == GamePhase.BLIND_SELECTION

    async def _validate_select_pack_offer(
        self, action: SelectPackOfferAction, state: GameState
    ) -> bool:
        """Validate select pack offer action."""
        # This would need specific game state information about available packs
        return True  # Basic validation for now

    async def _validate_reroll_boss(
        self, action: RerollBossAction, state: GameState
    ) -> bool:
        """Validate reroll boss action."""
        return state.current_phase == GamePhase.BLIND_SELECTION

    async def _validate_reroll_shop(
        self, action: RerollShopAction, state: GameState
    ) -> bool:
        """Validate reroll shop action."""
        if state.current_phase != GamePhase.SHOP:
            return False

        # Check player has enough money for reroll (typically costs money)
        # This would need specific game rules about reroll cost
        return True

    async def _validate_sort_hand(self, action: GameAction, state: GameState) -> bool:
        """Validate hand sorting actions."""
        return state.current_phase == GamePhase.HAND_SELECTION

    async def _validate_use_consumable(
        self, action: UseConsumableAction, state: GameState
    ) -> bool:
        """Validate use consumable action."""
        # Check consumable exists
        consumable_ids = [c.id for c in state.consumables]
        if action.item_id not in consumable_ids:
            return False

        return True


class ActionResultProcessor:
    """Processes action results and updates game state accordingly."""

    def __init__(self, state_manager: IStateManager):
        """Initialize with state manager dependency."""
        self.state_manager = state_manager

    async def process_result(self, action: GameAction, result: ActionResult) -> None:
        """Process an action result and update state if needed."""
        if result.success and result.new_state:
            await self.state_manager.update_state(result.new_state)
            logger.debug(f"State updated after successful {action.action_type}")

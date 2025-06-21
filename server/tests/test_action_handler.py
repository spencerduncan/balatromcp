"""
Unit tests for action_handler module.
Tests action validation and execution logic.
"""

import pytest
from unittest.mock import Mock, AsyncMock, patch

from server.action_handler import BalatroActionHandler, ActionResultProcessor
from server.interfaces import IFileIO, IStateManager
from server.schemas import (
    GameState,
    GamePhase,
    Card,
    Joker,
    Consumable,
    Blind,
    ShopItem,
    BlindType,
    ActionResult,
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


@pytest.fixture
def mock_file_io():
    """Create a mock file I/O interface."""
    mock = Mock(spec=IFileIO)
    mock.write_action = AsyncMock()
    mock.wait_for_action_result = AsyncMock()
    return mock


@pytest.fixture
def mock_state_manager():
    """Create a mock state manager."""
    mock = Mock(spec=IStateManager)
    mock.get_current_state = AsyncMock()
    mock.update_state = AsyncMock()
    return mock


@pytest.fixture
def action_handler(mock_file_io, mock_state_manager):
    """Create a BalatroActionHandler instance for testing."""
    return BalatroActionHandler(mock_file_io, mock_state_manager)


@pytest.fixture
def hand_selection_state():
    """Create a game state in hand selection phase."""
    return GameState(
        session_id="test_session",
        current_phase=GamePhase.HAND_SELECTION,
        ante=1,
        money=100,
        hands_remaining=4,
        discards_remaining=3,
        hand_cards=[
            Card(id="c1", rank="A", suit="hearts"),
            Card(id="c2", rank="K", suit="spades"),
            Card(id="c3", rank="Q", suit="diamonds"),
        ],
        jokers=[Joker(id="j1", name="Test Joker", position=0)],
        consumables=[Consumable(id="cons1", name="Tarot", card_type="tarot")],
        current_blind=None,
        shop_contents=[],
        available_actions=["play_hand", "discard_cards", "go_to_shop"],
        post_hand_joker_reorder_available=False,
    )


@pytest.fixture
def shop_state():
    """Create a game state in shop phase."""
    return GameState(
        session_id="test_session",
        current_phase=GamePhase.SHOP,
        ante=1,
        money=100,
        hands_remaining=4,
        discards_remaining=3,
        hand_cards=[],
        jokers=[Joker(id="j1", name="Test Joker", position=0)],
        consumables=[],
        current_blind=None,
        shop_contents=[
            ShopItem(index=0, item_type="joker", name="Shop Joker", cost=50),
            ShopItem(index=1, item_type="consumable", name="Shop Tarot", cost=30),
        ],
        available_actions=["buy_item", "sell_joker", "reroll_shop"],
        post_hand_joker_reorder_available=False,
    )


@pytest.fixture
def blind_selection_state():
    """Create a game state in blind selection phase."""
    return GameState(
        session_id="test_session",
        current_phase=GamePhase.BLIND_SELECTION,
        ante=1,
        money=100,
        hands_remaining=4,
        discards_remaining=3,
        hand_cards=[],
        jokers=[],
        consumables=[],
        current_blind=None,
        shop_contents=[],
        available_actions=["select_blind", "reroll_boss"],
        post_hand_joker_reorder_available=False,
    )


@pytest.fixture
def reorder_available_state():
    """Create a game state with joker reorder available."""
    return GameState(
        session_id="test_session",
        current_phase=GamePhase.HAND_SELECTION,
        ante=1,
        money=100,
        hands_remaining=4,
        discards_remaining=3,
        hand_cards=[],
        jokers=[
            Joker(id="j1", name="Joker 1", position=0),
            Joker(id="j2", name="Joker 2", position=1),
            Joker(id="j3", name="Joker 3", position=2),
        ],
        consumables=[],
        current_blind=None,
        shop_contents=[],
        available_actions=["reorder_jokers"],
        post_hand_joker_reorder_available=True,
    )


class TestExecuteAction:
    """Test action execution."""

    @pytest.mark.asyncio
    async def test_execute_action_success(
        self, action_handler, mock_file_io, mock_state_manager, hand_selection_state
    ):
        """Test successful action execution."""
        action = PlayHandAction(card_indices=[0, 1])
        expected_result = ActionResult(success=True)

        mock_state_manager.get_current_state.return_value = hand_selection_state
        mock_file_io.write_action.return_value = True
        mock_file_io.wait_for_action_result.return_value = expected_result

        result = await action_handler.execute_action(action)

        assert result.success is True
        mock_state_manager.get_current_state.assert_called_once()
        mock_file_io.write_action.assert_called_once_with(action)
        mock_file_io.wait_for_action_result.assert_called_once()

    @pytest.mark.asyncio
    async def test_execute_action_no_game_state(
        self, action_handler, mock_state_manager
    ):
        """Test action execution when no game state is available."""
        action = PlayHandAction(card_indices=[0, 1])
        mock_state_manager.get_current_state.return_value = None

        result = await action_handler.execute_action(action)

        assert result.success is False
        assert result.error_message == "No game state available"

    @pytest.mark.asyncio
    async def test_execute_action_invalid_action(
        self, action_handler, mock_state_manager, hand_selection_state
    ):
        """Test action execution with invalid action."""
        action = PlayHandAction(card_indices=[10, 11])  # Invalid indices
        mock_state_manager.get_current_state.return_value = hand_selection_state

        result = await action_handler.execute_action(action)

        assert result.success is False
        assert "not valid in current state" in result.error_message

    @pytest.mark.asyncio
    async def test_execute_action_write_failure(
        self, action_handler, mock_file_io, mock_state_manager, hand_selection_state
    ):
        """Test action execution when write fails."""
        action = PlayHandAction(card_indices=[0, 1])
        mock_state_manager.get_current_state.return_value = hand_selection_state
        mock_file_io.write_action.return_value = False

        result = await action_handler.execute_action(action)

        assert result.success is False
        assert result.error_message == "Failed to write action to file"

    @pytest.mark.asyncio
    async def test_execute_action_timeout(
        self, action_handler, mock_file_io, mock_state_manager, hand_selection_state
    ):
        """Test action execution timeout."""
        action = PlayHandAction(card_indices=[0, 1])
        mock_state_manager.get_current_state.return_value = hand_selection_state
        mock_file_io.write_action.return_value = True
        mock_file_io.wait_for_action_result.return_value = None  # Timeout

        result = await action_handler.execute_action(action)

        assert result.success is False
        assert "Timeout waiting for action result" in result.error_message

    @pytest.mark.asyncio
    async def test_execute_action_exception_handling(
        self, action_handler, mock_state_manager
    ):
        """Test action execution exception handling."""
        action = PlayHandAction(card_indices=[0, 1])
        mock_state_manager.get_current_state.side_effect = Exception("Test error")

        result = await action_handler.execute_action(action)

        assert result.success is False
        assert "Internal error" in result.error_message


class TestValidateAction:
    """Test action validation."""

    @pytest.mark.asyncio
    async def test_validate_action_not_available(
        self, action_handler, hand_selection_state
    ):
        """Test validation when action is not in available actions."""
        action = BuyItemAction(shop_index=0)  # Not available in HAND_SELECTION

        result = await action_handler.validate_action(action, hand_selection_state)

        assert result is False

    @pytest.mark.asyncio
    async def test_validate_action_available_no_validator(
        self, action_handler, hand_selection_state
    ):
        """Test validation when action is available but has no specific validator."""
        # Modify available actions to include an action without specific validator
        hand_selection_state.available_actions = ["unknown_action"]
        action = Mock()
        action.action_type = "unknown_action"

        result = await action_handler.validate_action(action, hand_selection_state)

        assert result is True  # Default validation passes

    @pytest.mark.asyncio
    async def test_validate_action_with_specific_validator(
        self, action_handler, hand_selection_state
    ):
        """Test validation with specific validator."""
        action = PlayHandAction(card_indices=[0, 1])

        result = await action_handler.validate_action(action, hand_selection_state)

        assert result is True

    @pytest.mark.asyncio
    async def test_validate_action_exception_handling(
        self, action_handler, hand_selection_state
    ):
        """Test validation exception handling."""
        action = Mock()
        action.action_type = "play_hand"
        action.card_indices = None  # Will cause AttributeError in validator

        result = await action_handler.validate_action(action, hand_selection_state)

        assert result is False


class TestGetAvailableActions:
    """Test getting available actions."""

    @pytest.mark.asyncio
    async def test_get_available_actions(self, action_handler, hand_selection_state):
        """Test getting available actions."""
        result = await action_handler.get_available_actions(hand_selection_state)

        assert result == ["play_hand", "discard_cards", "go_to_shop"]
        # Ensure it's a copy, not the original list
        assert result is not hand_selection_state.available_actions


class TestPlayHandValidation:
    """Test play hand action validation."""

    @pytest.mark.asyncio
    async def test_validate_play_hand_valid(self, action_handler, hand_selection_state):
        """Test valid play hand action."""
        action = PlayHandAction(card_indices=[0, 1])

        result = await action_handler._validate_play_hand(action, hand_selection_state)

        assert result is True

    @pytest.mark.asyncio
    async def test_validate_play_hand_wrong_phase(self, action_handler, shop_state):
        """Test play hand validation in wrong phase."""
        action = PlayHandAction(card_indices=[0, 1])

        result = await action_handler._validate_play_hand(action, shop_state)

        assert result is False

    @pytest.mark.asyncio
    async def test_validate_play_hand_no_hands_remaining(
        self, action_handler, hand_selection_state
    ):
        """Test play hand validation with no hands remaining."""
        hand_selection_state.hands_remaining = 0
        action = PlayHandAction(card_indices=[0, 1])

        result = await action_handler._validate_play_hand(action, hand_selection_state)

        assert result is False

    @pytest.mark.asyncio
    async def test_validate_play_hand_invalid_indices(
        self, action_handler, hand_selection_state
    ):
        """Test play hand validation with invalid card indices."""
        action = PlayHandAction(card_indices=[10, 11])  # Out of range

        result = await action_handler._validate_play_hand(action, hand_selection_state)

        assert result is False

    @pytest.mark.asyncio
    async def test_validate_play_hand_empty_selection(
        self, action_handler, hand_selection_state
    ):
        """Test play hand validation with empty card selection."""
        action = PlayHandAction(card_indices=[])

        result = await action_handler._validate_play_hand(action, hand_selection_state)

        assert result is False


class TestDiscardCardsValidation:
    """Test discard cards action validation."""

    @pytest.mark.asyncio
    async def test_validate_discard_cards_valid(
        self, action_handler, hand_selection_state
    ):
        """Test valid discard cards action."""
        action = DiscardCardsAction(card_indices=[0, 1])

        result = await action_handler._validate_discard_cards(
            action, hand_selection_state
        )

        assert result is True

    @pytest.mark.asyncio
    async def test_validate_discard_cards_wrong_phase(self, action_handler, shop_state):
        """Test discard cards validation in wrong phase."""
        action = DiscardCardsAction(card_indices=[0, 1])

        result = await action_handler._validate_discard_cards(action, shop_state)

        assert result is False

    @pytest.mark.asyncio
    async def test_validate_discard_cards_no_discards_remaining(
        self, action_handler, hand_selection_state
    ):
        """Test discard cards validation with no discards remaining."""
        hand_selection_state.discards_remaining = 0
        action = DiscardCardsAction(card_indices=[0, 1])

        result = await action_handler._validate_discard_cards(
            action, hand_selection_state
        )

        assert result is False


class TestGoToShopValidation:
    """Test go to shop action validation."""

    @pytest.mark.asyncio
    async def test_validate_go_to_shop_valid(
        self, action_handler, hand_selection_state
    ):
        """Test valid go to shop action."""
        action = GoToShopAction()

        result = await action_handler._validate_go_to_shop(action, hand_selection_state)

        assert result is True

    @pytest.mark.asyncio
    async def test_validate_go_to_shop_wrong_phase(self, action_handler, shop_state):
        """Test go to shop validation in wrong phase."""
        action = GoToShopAction()

        result = await action_handler._validate_go_to_shop(action, shop_state)

        assert result is False


class TestBuyItemValidation:
    """Test buy item action validation."""

    @pytest.mark.asyncio
    async def test_validate_buy_item_valid(self, action_handler, shop_state):
        """Test valid buy item action."""
        action = BuyItemAction(shop_index=0)

        result = await action_handler._validate_buy_item(action, shop_state)

        assert result is True

    @pytest.mark.asyncio
    async def test_validate_buy_item_wrong_phase(
        self, action_handler, hand_selection_state
    ):
        """Test buy item validation in wrong phase."""
        action = BuyItemAction(shop_index=0)

        result = await action_handler._validate_buy_item(action, hand_selection_state)

        assert result is False

    @pytest.mark.asyncio
    async def test_validate_buy_item_invalid_index(self, action_handler, shop_state):
        """Test buy item validation with invalid shop index."""
        action = BuyItemAction(shop_index=10)  # Out of range

        result = await action_handler._validate_buy_item(action, shop_state)

        assert result is False

    @pytest.mark.asyncio
    async def test_validate_buy_item_insufficient_money(
        self, action_handler, shop_state
    ):
        """Test buy item validation with insufficient money."""
        shop_state.money = 10  # Less than item cost (50)
        action = BuyItemAction(shop_index=0)

        result = await action_handler._validate_buy_item(action, shop_state)

        assert result is False


class TestSellJokerValidation:
    """Test sell joker action validation."""

    @pytest.mark.asyncio
    async def test_validate_sell_joker_valid(self, action_handler, shop_state):
        """Test valid sell joker action."""
        action = SellJokerAction(joker_index=0)

        result = await action_handler._validate_sell_joker(action, shop_state)

        assert result is True

    @pytest.mark.asyncio
    async def test_validate_sell_joker_wrong_phase(
        self, action_handler, hand_selection_state
    ):
        """Test sell joker validation in wrong phase."""
        action = SellJokerAction(joker_index=0)

        result = await action_handler._validate_sell_joker(action, hand_selection_state)

        assert result is False

    @pytest.mark.asyncio
    async def test_validate_sell_joker_invalid_index(self, action_handler, shop_state):
        """Test sell joker validation with invalid joker index."""
        action = SellJokerAction(joker_index=10)  # Out of range

        result = await action_handler._validate_sell_joker(action, shop_state)

        assert result is False


class TestReorderJokersValidation:
    """Test reorder jokers action validation."""

    @pytest.mark.asyncio
    async def test_validate_reorder_jokers_valid(
        self, action_handler, reorder_available_state
    ):
        """Test valid reorder jokers action."""
        action = ReorderJokersAction(new_order=[2, 0, 1])

        result = await action_handler._validate_reorder_jokers(
            action, reorder_available_state
        )

        assert result is True

    @pytest.mark.asyncio
    async def test_validate_reorder_jokers_not_available(
        self, action_handler, hand_selection_state
    ):
        """Test reorder jokers validation when not available."""
        action = ReorderJokersAction(new_order=[0])

        result = await action_handler._validate_reorder_jokers(
            action, hand_selection_state
        )

        assert result is False

    @pytest.mark.asyncio
    async def test_validate_reorder_jokers_wrong_count(
        self, action_handler, reorder_available_state
    ):
        """Test reorder jokers validation with wrong count."""
        action = ReorderJokersAction(new_order=[0, 1])  # Missing one joker

        result = await action_handler._validate_reorder_jokers(
            action, reorder_available_state
        )

        assert result is False

    @pytest.mark.asyncio
    async def test_validate_reorder_jokers_invalid_indices(
        self, action_handler, reorder_available_state
    ):
        """Test reorder jokers validation with invalid indices."""
        action = ReorderJokersAction(new_order=[0, 1, 3])  # Index 3 doesn't exist

        result = await action_handler._validate_reorder_jokers(
            action, reorder_available_state
        )

        assert result is False

    @pytest.mark.asyncio
    async def test_validate_reorder_jokers_duplicate_indices(
        self, action_handler, reorder_available_state
    ):
        """Test reorder jokers validation with duplicate indices."""
        action = ReorderJokersAction(new_order=[0, 0, 1])  # Duplicate index

        result = await action_handler._validate_reorder_jokers(
            action, reorder_available_state
        )

        assert result is False


class TestBlindSelectionValidation:
    """Test blind selection action validation."""

    @pytest.mark.asyncio
    async def test_validate_select_blind_valid(
        self, action_handler, blind_selection_state
    ):
        """Test valid select blind action."""
        action = SelectBlindAction(blind_type="small")

        result = await action_handler._validate_select_blind(
            action, blind_selection_state
        )

        assert result is True

    @pytest.mark.asyncio
    async def test_validate_select_blind_wrong_phase(
        self, action_handler, hand_selection_state
    ):
        """Test select blind validation in wrong phase."""
        action = SelectBlindAction(blind_type="small")

        result = await action_handler._validate_select_blind(
            action, hand_selection_state
        )

        assert result is False


class TestRerollValidation:
    """Test reroll action validation."""

    @pytest.mark.asyncio
    async def test_validate_reroll_boss_valid(
        self, action_handler, blind_selection_state
    ):
        """Test valid reroll boss action."""
        action = RerollBossAction()

        result = await action_handler._validate_reroll_boss(
            action, blind_selection_state
        )

        assert result is True

    @pytest.mark.asyncio
    async def test_validate_reroll_boss_wrong_phase(self, action_handler, shop_state):
        """Test reroll boss validation in wrong phase."""
        action = RerollBossAction()

        result = await action_handler._validate_reroll_boss(action, shop_state)

        assert result is False

    @pytest.mark.asyncio
    async def test_validate_reroll_shop_valid(self, action_handler, shop_state):
        """Test valid reroll shop action."""
        action = RerollShopAction()

        result = await action_handler._validate_reroll_shop(action, shop_state)

        assert result is True

    @pytest.mark.asyncio
    async def test_validate_reroll_shop_wrong_phase(
        self, action_handler, hand_selection_state
    ):
        """Test reroll shop validation in wrong phase."""
        action = RerollShopAction()

        result = await action_handler._validate_reroll_shop(
            action, hand_selection_state
        )

        assert result is False


class TestSortHandValidation:
    """Test sort hand action validation."""

    @pytest.mark.asyncio
    async def test_validate_sort_hand_by_rank_valid(
        self, action_handler, hand_selection_state
    ):
        """Test valid sort hand by rank action."""
        action = SortHandByRankAction()

        result = await action_handler._validate_sort_hand(action, hand_selection_state)

        assert result is True

    @pytest.mark.asyncio
    async def test_validate_sort_hand_by_suit_valid(
        self, action_handler, hand_selection_state
    ):
        """Test valid sort hand by suit action."""
        action = SortHandBySuitAction()

        result = await action_handler._validate_sort_hand(action, hand_selection_state)

        assert result is True

    @pytest.mark.asyncio
    async def test_validate_sort_hand_wrong_phase(self, action_handler, shop_state):
        """Test sort hand validation in wrong phase."""
        action = SortHandByRankAction()

        result = await action_handler._validate_sort_hand(action, shop_state)

        assert result is False


class TestUseConsumableValidation:
    """Test use consumable action validation."""

    @pytest.mark.asyncio
    async def test_validate_use_consumable_valid(
        self, action_handler, hand_selection_state
    ):
        """Test valid use consumable action."""
        action = UseConsumableAction(item_id="cons1")

        result = await action_handler._validate_use_consumable(
            action, hand_selection_state
        )

        assert result is True

    @pytest.mark.asyncio
    async def test_validate_use_consumable_invalid_id(
        self, action_handler, hand_selection_state
    ):
        """Test use consumable validation with invalid ID."""
        action = UseConsumableAction(item_id="nonexistent")

        result = await action_handler._validate_use_consumable(
            action, hand_selection_state
        )

        assert result is False


class TestActionResultProcessor:
    """Test ActionResultProcessor utility class."""

    @pytest.fixture
    def processor(self, mock_state_manager):
        """Create ActionResultProcessor for testing."""
        return ActionResultProcessor(mock_state_manager)

    @pytest.mark.asyncio
    async def test_process_result_success_with_new_state(
        self, processor, mock_state_manager, hand_selection_state
    ):
        """Test processing successful result with new state."""
        action = PlayHandAction(card_indices=[0, 1])
        result = ActionResult(success=True, new_state=hand_selection_state)

        await processor.process_result(action, result)

        mock_state_manager.update_state.assert_called_once_with(hand_selection_state)

    @pytest.mark.asyncio
    async def test_process_result_success_no_new_state(
        self, processor, mock_state_manager
    ):
        """Test processing successful result without new state."""
        action = PlayHandAction(card_indices=[0, 1])
        result = ActionResult(success=True, new_state=None)

        await processor.process_result(action, result)

        mock_state_manager.update_state.assert_not_called()

    @pytest.mark.asyncio
    async def test_process_result_failure(self, processor, mock_state_manager):
        """Test processing failed result."""
        action = PlayHandAction(card_indices=[0, 1])
        result = ActionResult(success=False, error_message="Test error")

        await processor.process_result(action, result)

        mock_state_manager.update_state.assert_not_called()

"""
Unit tests for schemas module.
Tests Pydantic data models for game state, actions, and communication.
"""

import pytest
from datetime import datetime
from pydantic import ValidationError

from server.schemas import (
    GamePhase,
    CardEnhancement,
    CardEdition,
    CardSeal,
    BlindType,
    MessageType,
    Card,
    Joker,
    Consumable,
    Blind,
    ShopItem,
    GameState,
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
    GameStateMessage,
    ActionCommandMessage,
    ActionResult,
    ActionResultMessage,
)


class TestEnums:
    """Test enum definitions."""

    def test_game_phase_values(self):
        """Test GamePhase enum values."""
        assert GamePhase.HAND_SELECTION == "hand_selection"
        assert GamePhase.SHOP == "shop"
        assert GamePhase.BLIND_SELECTION == "blind_selection"
        assert GamePhase.SCORING == "scoring"

    def test_card_enhancement_values(self):
        """Test CardEnhancement enum values."""
        assert CardEnhancement.NONE == "none"
        assert CardEnhancement.GOLD == "gold"
        assert CardEnhancement.STEEL == "steel"
        assert CardEnhancement.GLASS == "glass"

    def test_card_edition_values(self):
        """Test CardEdition enum values."""
        assert CardEdition.NONE == "none"
        assert CardEdition.FOIL == "foil"
        assert CardEdition.HOLOGRAPHIC == "holographic"
        assert CardEdition.POLYCHROME == "polychrome"

    def test_card_seal_values(self):
        """Test CardSeal enum values."""
        assert CardSeal.NONE == "none"
        assert CardSeal.RED == "red"
        assert CardSeal.BLUE == "blue"
        assert CardSeal.GOLD == "gold"

    def test_blind_type_values(self):
        """Test BlindType enum values."""
        assert BlindType.SMALL == "small"
        assert BlindType.BIG == "big"
        assert BlindType.BOSS == "boss"

    def test_message_type_values(self):
        """Test MessageType enum values."""
        assert MessageType.GAME_STATE == "game_state"
        assert MessageType.ACTION_COMMAND == "action_command"
        assert MessageType.ACTION_RESULT == "action_result"


class TestCard:
    """Test Card model."""

    def test_card_creation_minimal(self):
        """Test creating card with minimal required fields."""
        card = Card(id="card_1", rank="A", suit="hearts")
        assert card.id == "card_1"
        assert card.rank == "A"
        assert card.suit == "hearts"
        assert card.enhancement == CardEnhancement.NONE
        assert card.edition == CardEdition.NONE
        assert card.seal == CardSeal.NONE

    def test_card_creation_full(self):
        """Test creating card with all fields."""
        card = Card(
            id="card_2",
            rank="K",
            suit="spades",
            enhancement=CardEnhancement.GOLD,
            edition=CardEdition.FOIL,
            seal=CardSeal.RED,
        )
        assert card.id == "card_2"
        assert card.rank == "K"
        assert card.suit == "spades"
        assert card.enhancement == CardEnhancement.GOLD
        assert card.edition == CardEdition.FOIL
        assert card.seal == CardSeal.RED

    def test_card_validation_errors(self):
        """Test card validation errors."""
        with pytest.raises(ValidationError):
            Card()  # Missing required fields

        # Empty ID is actually valid in Pydantic V2 - test with None instead
        with pytest.raises(ValidationError):
            Card(id=None, rank="A", suit="hearts")  # None ID


class TestJoker:
    """Test Joker model."""

    def test_joker_creation_minimal(self):
        """Test creating joker with minimal fields."""
        joker = Joker(id="joker_1", name="Test Joker", position=0)
        assert joker.id == "joker_1"
        assert joker.name == "Test Joker"
        assert joker.position == 0
        assert joker.properties == {}

    def test_joker_creation_with_properties(self):
        """Test creating joker with properties."""
        properties = {"multiplier": 2, "bonus": 10}
        joker = Joker(id="joker_2", name="Blueprint", position=1, properties=properties)
        assert joker.properties == properties

    def test_joker_validation_errors(self):
        """Test joker validation errors."""
        with pytest.raises(ValidationError):
            Joker(id="joker_1", name="Test")  # Missing position


class TestConsumable:
    """Test Consumable model."""

    def test_consumable_creation(self):
        """Test creating consumable."""
        consumable = Consumable(id="cons_1", name="Tarot", card_type="tarot")
        assert consumable.id == "cons_1"
        assert consumable.name == "Tarot"
        assert consumable.card_type == "tarot"
        assert consumable.properties == {}


class TestBlind:
    """Test Blind model."""

    def test_blind_creation(self):
        """Test creating blind."""
        blind = Blind(
            name="The Wall",
            blind_type=BlindType.BOSS,
            requirement=500,
            reward=100,
        )
        assert blind.name == "The Wall"
        assert blind.blind_type == BlindType.BOSS
        assert blind.requirement == 500
        assert blind.reward == 100


class TestShopItem:
    """Test ShopItem model."""

    def test_shop_item_creation(self):
        """Test creating shop item."""
        item = ShopItem(index=0, item_type="joker", name="Test Joker", cost=50)
        assert item.index == 0
        assert item.item_type == "joker"
        assert item.name == "Test Joker"
        assert item.cost == 50


class TestGameState:
    """Test GameState model."""

    def test_game_state_creation_minimal(self):
        """Test creating game state with minimal fields."""
        state = GameState(
            session_id="session_1",
            current_phase=GamePhase.HAND_SELECTION,
            ante=1,
            money=100,
            hands_remaining=4,
            discards_remaining=3,
            hand_cards=[],
            jokers=[],
            consumables=[],
            current_blind=None,
            shop_contents=[],
            available_actions=["play_hand", "discard_cards"],
        )
        assert state.session_id == "session_1"
        assert state.current_phase == GamePhase.HAND_SELECTION
        assert state.ante == 1
        assert state.money == 100
        assert not state.post_hand_joker_reorder_available

    def test_game_state_with_cards(self):
        """Test game state with cards and jokers."""
        cards = [Card(id="c1", rank="A", suit="hearts")]
        jokers = [Joker(id="j1", name="Test", position=0)]

        state = GameState(
            session_id="session_2",
            current_phase=GamePhase.SHOP,
            ante=2,
            money=200,
            hands_remaining=3,
            discards_remaining=2,
            hand_cards=cards,
            jokers=jokers,
            consumables=[],
            current_blind=None,
            shop_contents=[],
            available_actions=["buy_item"],
            post_hand_joker_reorder_available=True,
        )
        assert len(state.hand_cards) == 1
        assert len(state.jokers) == 1
        assert state.post_hand_joker_reorder_available


class TestActions:
    """Test action models."""

    def test_play_hand_action(self):
        """Test PlayHandAction."""
        action = PlayHandAction(card_indices=[0, 1, 2])
        assert action.action_type == "play_hand"
        assert action.card_indices == [0, 1, 2]

    def test_discard_cards_action(self):
        """Test DiscardCardsAction."""
        action = DiscardCardsAction(card_indices=[3, 4])
        assert action.action_type == "discard_cards"
        assert action.card_indices == [3, 4]

    def test_go_to_shop_action(self):
        """Test GoToShopAction."""
        action = GoToShopAction()
        assert action.action_type == "go_to_shop"

    def test_buy_item_action(self):
        """Test BuyItemAction."""
        action = BuyItemAction(shop_index=2)
        assert action.action_type == "buy_item"
        assert action.shop_index == 2

    def test_sell_joker_action(self):
        """Test SellJokerAction."""
        action = SellJokerAction(joker_index=1)
        assert action.action_type == "sell_joker"
        assert action.joker_index == 1

    def test_sell_consumable_action(self):
        """Test SellConsumableAction."""
        action = SellConsumableAction(consumable_index=0)
        assert action.action_type == "sell_consumable"
        assert action.consumable_index == 0

    def test_reorder_jokers_action(self):
        """Test ReorderJokersAction."""
        action = ReorderJokersAction(new_order=[2, 0, 1])
        assert action.action_type == "reorder_jokers"
        assert action.new_order == [2, 0, 1]

    def test_select_blind_action(self):
        """Test SelectBlindAction."""
        action = SelectBlindAction(blind_type="small")
        assert action.action_type == "select_blind"
        assert action.blind_type == "small"

    def test_select_pack_offer_action(self):
        """Test SelectPackOfferAction."""
        action = SelectPackOfferAction(pack_index=1)
        assert action.action_type == "select_pack_offer"
        assert action.pack_index == 1

    def test_reroll_boss_action(self):
        """Test RerollBossAction."""
        action = RerollBossAction()
        assert action.action_type == "reroll_boss"

    def test_reroll_shop_action(self):
        """Test RerollShopAction."""
        action = RerollShopAction()
        assert action.action_type == "reroll_shop"

    def test_sort_hand_by_rank_action(self):
        """Test SortHandByRankAction."""
        action = SortHandByRankAction()
        assert action.action_type == "sort_hand_by_rank"

    def test_sort_hand_by_suit_action(self):
        """Test SortHandBySuitAction."""
        action = SortHandBySuitAction()
        assert action.action_type == "sort_hand_by_suit"

    def test_use_consumable_action(self):
        """Test UseConsumableAction."""
        action = UseConsumableAction(item_id="tarot_1")
        assert action.action_type == "use_consumable"
        assert action.item_id == "tarot_1"


class TestCommunicationMessages:
    """Test communication message models."""

    def test_game_state_message(self):
        """Test GameStateMessage creation."""
        state = GameState(
            session_id="test",
            current_phase=GamePhase.HAND_SELECTION,
            ante=1,
            money=100,
            hands_remaining=4,
            discards_remaining=3,
            hand_cards=[],
            jokers=[],
            consumables=[],
            current_blind=None,
            shop_contents=[],
            available_actions=[],
        )

        message = GameStateMessage(game_state=state, sequence_id=1)
        assert message.message_type == MessageType.GAME_STATE
        assert message.sequence_id == 1
        assert isinstance(message.timestamp, datetime)

    def test_action_command_message(self):
        """Test ActionCommandMessage creation."""
        action = PlayHandAction(card_indices=[0, 1])
        message = ActionCommandMessage(action=action, sequence_id=2)

        assert message.message_type == MessageType.ACTION_COMMAND
        assert message.sequence_id == 2
        assert isinstance(message.timestamp, datetime)

    def test_action_result(self):
        """Test ActionResult model."""
        result = ActionResult(success=True)
        assert result.success is True
        assert result.error_message is None
        assert result.new_state is None

        result_with_error = ActionResult(success=False, error_message="Invalid action")
        assert result_with_error.success is False
        assert result_with_error.error_message == "Invalid action"

    def test_action_result_message(self):
        """Test ActionResultMessage creation."""
        result = ActionResult(success=True)
        message = ActionResultMessage(result=result, sequence_id=3)

        assert message.message_type == MessageType.ACTION_RESULT
        assert message.sequence_id == 3
        assert isinstance(message.timestamp, datetime)


class TestActionValidation:
    """Test action validation requirements."""

    def test_action_validation_errors(self):
        """Test actions with invalid data."""
        # Empty list is actually valid for PlayHandAction
        action = PlayHandAction(card_indices=[])
        assert action.card_indices == []

        with pytest.raises(ValidationError):
            BuyItemAction()  # Missing shop_index

        with pytest.raises(ValidationError):
            SellJokerAction()  # Missing joker_index

        with pytest.raises(ValidationError):
            UseConsumableAction()  # Missing item_id

    def test_negative_indices(self):
        """Test actions with negative indices."""
        # These should be valid at schema level, validation happens at business logic level
        action = BuyItemAction(shop_index=-1)
        assert action.shop_index == -1

        action = SellJokerAction(joker_index=-1)
        assert action.joker_index == -1

"""
Shared test fixtures and configuration for Balatro MCP Server tests.
"""

import pytest
from unittest.mock import Mock, AsyncMock
from datetime import datetime

from server.schemas import (
    GameState,
    GamePhase,
    Card,
    Joker,
    Consumable,
    Blind,
    ShopItem,
    BlindType,
    CardEnhancement,
    CardEdition,
    CardSeal,
    ActionResult,
)
from server.interfaces import IFileIO, IStateManager, IActionHandler


@pytest.fixture
def basic_card():
    """Create a basic card for testing."""
    return Card(id="card_1", rank="A", suit="hearts")


@pytest.fixture
def enhanced_card():
    """Create an enhanced card for testing."""
    return Card(
        id="card_2",
        rank="K",
        suit="spades",
        enhancement=CardEnhancement.GOLD,
        edition=CardEdition.FOIL,
        seal=CardSeal.RED,
    )


@pytest.fixture
def basic_joker():
    """Create a basic joker for testing."""
    return Joker(id="joker_1", name="Test Joker", position=0)


@pytest.fixture
def blueprint_joker():
    """Create a Blueprint joker for testing."""
    return Joker(
        id="joker_blueprint",
        name="Blueprint",
        position=1,
        properties={"copies_leftmost": True},
    )


@pytest.fixture
def basic_consumable():
    """Create a basic consumable for testing."""
    return Consumable(id="cons_1", name="The Fool", card_type="tarot")


@pytest.fixture
def boss_blind():
    """Create a boss blind for testing."""
    return Blind(
        name="The Hook",
        blind_type=BlindType.BOSS,
        requirement=2000,
        reward=100,
        properties={"debuff_played_cards": True},
    )


@pytest.fixture
def shop_item_joker():
    """Create a shop joker item for testing."""
    return ShopItem(
        index=0,
        item_type="joker",
        name="Burglar",
        cost=50,
        properties={"rarity": "common"},
    )


@pytest.fixture
def minimal_game_state():
    """Create a minimal game state for testing."""
    return GameState(
        session_id="test_session",
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
        available_actions=["play_hand"],
    )


@pytest.fixture
def complete_game_state(
    basic_card, basic_joker, basic_consumable, boss_blind, shop_item_joker
):
    """Create a complete game state with all components for testing."""
    return GameState(
        session_id="complete_session",
        current_phase=GamePhase.SHOP,
        ante=2,
        money=200,
        hands_remaining=3,
        discards_remaining=2,
        hand_cards=[basic_card],
        jokers=[basic_joker],
        consumables=[basic_consumable],
        current_blind=boss_blind,
        shop_contents=[shop_item_joker],
        available_actions=["buy_item", "sell_joker"],
        post_hand_joker_reorder_available=True,
    )


@pytest.fixture
def success_action_result():
    """Create a successful action result for testing."""
    return ActionResult(success=True, error_message=None, new_state=None)


@pytest.fixture
def failure_action_result():
    """Create a failed action result for testing."""
    return ActionResult(
        success=False,
        error_message="Invalid action",
        new_state=None,
    )


@pytest.fixture
def mock_file_io():
    """Create a mock file I/O interface."""
    mock = Mock(spec=IFileIO)
    mock.read_game_state = AsyncMock(return_value=None)
    mock.write_action = AsyncMock(return_value=True)
    mock.read_action_result = AsyncMock(return_value=None)
    mock.get_next_sequence_id = Mock(return_value=1)
    mock.wait_for_action_result = AsyncMock(return_value=None)
    mock.cleanup_old_files = AsyncMock()
    mock.ensure_directories = AsyncMock()
    return mock


@pytest.fixture
def mock_state_manager():
    """Create a mock state manager."""
    mock = Mock(spec=IStateManager)
    mock.get_current_state = AsyncMock(return_value=None)
    mock.update_state = AsyncMock()
    mock.is_state_changed = AsyncMock(return_value=False)
    return mock


@pytest.fixture
def mock_action_handler():
    """Create a mock action handler."""
    mock = Mock(spec=IActionHandler)
    mock.execute_action = AsyncMock()
    mock.validate_action = AsyncMock(return_value=True)
    mock.get_available_actions = AsyncMock(return_value=[])
    return mock


@pytest.fixture
def timestamp_now():
    """Create a fixed timestamp for testing."""
    return datetime(2024, 1, 1, 12, 0, 0)


# Test markers for categorizing tests
pytest_markers = [
    "unit: Unit tests",
    "slow: Slow running tests",
    "integration: Integration tests",
    "schemas: Schema validation tests",
    "file_io: File I/O tests",
    "state_manager: State management tests",
    "action_handler: Action handling tests",
    "main: Main server tests",
]


def pytest_configure(config):
    """Configure pytest with custom markers."""
    for marker in pytest_markers:
        config.addinivalue_line("markers", marker)


# Test utilities
class TestDataFactory:
    """Factory class for creating test data."""

    @staticmethod
    def create_cards(count: int, suit: str = "hearts") -> list[Card]:
        """Create a list of cards for testing."""
        ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
        return [
            Card(id=f"card_{i}", rank=ranks[i % len(ranks)], suit=suit)
            for i in range(count)
        ]

    @staticmethod
    def create_jokers(count: int) -> list[Joker]:
        """Create a list of jokers for testing."""
        joker_names = [
            "Joker",
            "Greedy Joker",
            "Lusty Joker",
            "Wrathful Joker",
            "Gluttonous Joker",
            "Jolly Joker",
            "Zany Joker",
            "Mad Joker",
            "Crazy Joker",
            "Droll Joker",
            "Sly Joker",
            "Wily Joker",
            "Clever Joker",
            "Devious Joker",
            "Crafty Joker",
        ]
        return [
            Joker(id=f"joker_{i}", name=joker_names[i % len(joker_names)], position=i)
            for i in range(count)
        ]

    @staticmethod
    def create_shop_items(count: int) -> list[ShopItem]:
        """Create a list of shop items for testing."""
        item_types = ["joker", "consumable", "pack"]
        return [
            ShopItem(
                index=i,
                item_type=item_types[i % len(item_types)],
                name=f"Shop Item {i}",
                cost=50 + (i * 10),
            )
            for i in range(count)
        ]


# Add the factory to fixtures
@pytest.fixture
def test_data_factory():
    """Provide the test data factory."""
    return TestDataFactory

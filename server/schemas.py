"""
Data schemas for Balatro MCP Server communication.
Defines the structure of game state, actions, and communication messages.
"""

from typing import List, Optional, Dict, Any, Literal, Union
from pydantic import BaseModel, Field
from datetime import datetime, timezone
from enum import Enum


class GamePhase(str, Enum):
    """Current phase of the game."""

    HAND_SELECTION = "hand_selection"
    SHOP = "shop"
    BLIND_SELECTION = "blind_selection"
    SCORING = "scoring"


class CardEnhancement(str, Enum):
    """Card enhancement types."""

    NONE = "none"
    GOLD = "gold"
    STEEL = "steel"
    GLASS = "glass"
    WILD = "wild"
    BONUS = "bonus"
    MULT = "mult"
    STONE = "stone"


class CardEdition(str, Enum):
    """Card edition types."""

    NONE = "none"
    FOIL = "foil"
    HOLOGRAPHIC = "holographic"
    POLYCHROME = "polychrome"
    NEGATIVE = "negative"


class CardSeal(str, Enum):
    """Card seal types."""

    NONE = "none"
    RED = "red"
    BLUE = "blue"
    GOLD = "gold"
    PURPLE = "purple"


class BlindType(str, Enum):
    """Blind types."""

    SMALL = "small"
    BIG = "big"
    BOSS = "boss"


class MessageType(str, Enum):
    """Communication message types."""

    GAME_STATE = "game_state"
    ACTION_COMMAND = "action_command"
    ACTION_RESULT = "action_result"


class Card(BaseModel):
    """Represents a playing card."""

    id: str
    rank: str
    suit: str
    enhancement: CardEnhancement = CardEnhancement.NONE
    edition: CardEdition = CardEdition.NONE
    seal: CardSeal = CardSeal.NONE


class Joker(BaseModel):
    """Represents a joker card."""

    id: str
    name: str
    position: int
    properties: Dict[str, Any] = Field(default_factory=dict)


class Consumable(BaseModel):
    """Represents a consumable card."""

    id: str
    name: str
    card_type: str
    properties: Dict[str, Any] = Field(default_factory=dict)


class Blind(BaseModel):
    """Represents a blind."""

    name: str
    blind_type: BlindType
    requirement: int
    reward: int
    properties: Dict[str, Any] = Field(default_factory=dict)


class ShopItem(BaseModel):
    """Represents an item in the shop."""

    index: int
    item_type: str  # "joker", "consumable", "pack"
    name: str
    cost: int
    properties: Dict[str, Any] = Field(default_factory=dict)


class GameState(BaseModel):
    """Complete game state representation."""

    session_id: str
    current_phase: GamePhase
    ante: int
    money: int
    hands_remaining: int
    discards_remaining: int
    hand_cards: List[Card]
    jokers: List[Joker]
    consumables: List[Consumable]
    current_blind: Optional[Blind]
    shop_contents: List[ShopItem]
    available_actions: List[str]
    post_hand_joker_reorder_available: bool = False


# Action Schemas


class PlayHandAction(BaseModel):
    """Action to play selected cards."""

    action_type: Literal["play_hand"] = "play_hand"
    card_indices: List[int]


class DiscardCardsAction(BaseModel):
    """Action to discard selected cards."""

    action_type: Literal["discard_cards"] = "discard_cards"
    card_indices: List[int]


class GoToShopAction(BaseModel):
    """Action to navigate to shop."""

    action_type: Literal["go_to_shop"] = "go_to_shop"


class BuyItemAction(BaseModel):
    """Action to buy shop item."""

    action_type: Literal["buy_item"] = "buy_item"
    shop_index: int


class SellJokerAction(BaseModel):
    """Action to sell a joker."""

    action_type: Literal["sell_joker"] = "sell_joker"
    joker_index: int


class SellConsumableAction(BaseModel):
    """Action to sell a consumable."""

    action_type: Literal["sell_consumable"] = "sell_consumable"
    consumable_index: int


class ReorderJokersAction(BaseModel):
    """Action to reorder jokers - critical for Blueprint/Brainstorm strategy."""

    action_type: Literal["reorder_jokers"] = "reorder_jokers"
    new_order: List[int]


class SelectBlindAction(BaseModel):
    """Action to select blind type."""

    action_type: Literal["select_blind"] = "select_blind"
    blind_type: str


class SelectPackOfferAction(BaseModel):
    """Action to select pack offer."""

    action_type: Literal["select_pack_offer"] = "select_pack_offer"
    pack_index: int


class RerollBossAction(BaseModel):
    """Action to reroll boss blind."""

    action_type: Literal["reroll_boss"] = "reroll_boss"


class RerollShopAction(BaseModel):
    """Action to reroll shop."""

    action_type: Literal["reroll_shop"] = "reroll_shop"


class SortHandByRankAction(BaseModel):
    """Action to sort hand by rank."""

    action_type: Literal["sort_hand_by_rank"] = "sort_hand_by_rank"


class SortHandBySuitAction(BaseModel):
    """Action to sort hand by suit."""

    action_type: Literal["sort_hand_by_suit"] = "sort_hand_by_suit"


class UseConsumableAction(BaseModel):
    """Action to use a consumable."""

    action_type: Literal["use_consumable"] = "use_consumable"
    item_id: str


# Union type for all actions
GameAction = Union[
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
]


class CommunicationMessage(BaseModel):
    """Base communication message structure."""

    timestamp: datetime
    sequence_id: int
    message_type: MessageType
    data: Dict[str, Any]


class GameStateMessage(CommunicationMessage):
    """Game state communication message."""

    message_type: Literal[MessageType.GAME_STATE] = MessageType.GAME_STATE
    data: GameState

    def __init__(self, game_state: GameState, sequence_id: int, **kwargs):
        super().__init__(
            timestamp=datetime.now(timezone.utc),
            sequence_id=sequence_id,
            message_type=MessageType.GAME_STATE,
            data=game_state.model_dump(),
            **kwargs
        )


class ActionCommandMessage(CommunicationMessage):
    """Action command communication message."""

    message_type: Literal[MessageType.ACTION_COMMAND] = MessageType.ACTION_COMMAND
    data: GameAction

    def __init__(self, action: GameAction, sequence_id: int, **kwargs):
        super().__init__(
            timestamp=datetime.now(timezone.utc),
            sequence_id=sequence_id,
            message_type=MessageType.ACTION_COMMAND,
            data=action.model_dump(),
            **kwargs
        )


class ActionResult(BaseModel):
    """Result of action execution."""

    success: bool
    error_message: Optional[str] = None
    new_state: Optional[GameState] = None


class ActionResultMessage(CommunicationMessage):
    """Action result communication message."""

    message_type: Literal[MessageType.ACTION_RESULT] = MessageType.ACTION_RESULT
    data: ActionResult

    def __init__(self, result: ActionResult, sequence_id: int, **kwargs):
        super().__init__(
            timestamp=datetime.now(timezone.utc),
            sequence_id=sequence_id,
            message_type=MessageType.ACTION_RESULT,
            data=result.model_dump(),
            **kwargs
        )

#!/usr/bin/env python3
"""
Basic Balatro AI Agent Example

Demonstrates fundamental AI agent integration with the Balatro MCP system.
This example shows how to connect, read game state, and execute strategic actions.
"""

import asyncio
import logging
import json
from typing import Dict, Any, List
from mcp import ClientSession

# Configure logging for debugging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class BasicBalatroAI:
    """
    A foundational AI agent for Balatro.
    
    Demonstrates core functionality:
    - MCP server connection
    - Game state monitoring
    - Basic strategic decision making
    - Action execution with error handling
    """
    
    def __init__(self):
        self.session = None
        self.running = False
        self.last_state_hash = None
        
        # Basic strategy parameters
        self.min_hand_strength = 0.3  # Minimum strength to play hand
        self.min_shop_money = 10      # Minimum money before shopping
        self.preferred_jokers = [
            "Blueprint", "Brainstorm", "Mime", "Certificate", "Joker Stencil"
        ]
    
    async def connect(self):
        """Establish connection to Balatro MCP server."""
        try:
            self.session = ClientSession("stdio", command=["python", "-m", "server.main"])
            await self.session.__aenter__()
            
            # Verify connection
            resources = await self.session.list_resources()
            tools = await self.session.list_tools()
            
            logger.info(f"Connected successfully!")
            logger.info(f"Available resources: {len(resources.resources)}")
            logger.info(f"Available tools: {len(tools.tools)}")
            
            return True
            
        except Exception as e:
            logger.error(f"Connection failed: {e}")
            return False
    
    async def disconnect(self):
        """Clean shutdown of MCP connection."""
        if self.session:
            try:
                await self.session.__aexit__(None, None, None)
                logger.info("Disconnected from MCP server")
            except Exception as e:
                logger.error(f"Disconnect error: {e}")
    
    async def run(self):
        """Main AI agent execution loop."""
        if not await self.connect():
            return
        
        self.running = True
        logger.info("🤖 Basic Balatro AI Agent starting...")
        
        try:
            while self.running:
                await self.execute_turn()
                await asyncio.sleep(0.5)  # Prevent overwhelming the system
                
        except KeyboardInterrupt:
            logger.info("🛑 AI Agent stopped by user")
        except Exception as e:
            logger.error(f"💥 AI Agent crashed: {e}")
        finally:
            self.running = False
            await self.disconnect()
    
    async def execute_turn(self):
        """Execute one turn of AI decision making."""
        try:
            # Get current game state
            state_data = await self.session.read_resource("balatro://game-state")
            if not state_data:
                return
            
            # Parse state (simplified - real implementation would use proper parsing)
            state = self.parse_state_data(state_data)
            if not state:
                return
            
            # Check if state changed
            current_hash = self.calculate_state_hash(state)
            if current_hash == self.last_state_hash:
                return  # No change, skip processing
            
            self.last_state_hash = current_hash
            logger.info(f"🎮 Phase: {state.get('current_phase', 'unknown')}, "
                       f"Ante: {state.get('ante', 0)}, "
                       f"Money: ${state.get('money', 0)}")
            
            # Execute strategy based on current phase
            phase = state.get('current_phase', '')
            
            if phase == 'hand_selection':
                await self.handle_hand_phase(state)
            elif phase == 'shop':
                await self.handle_shop_phase(state)
            elif phase == 'blind_selection':
                await self.handle_blind_phase(state)
                
        except Exception as e:
            logger.error(f"Turn execution error: {e}")
    
    async def handle_hand_phase(self, state: Dict[str, Any]):
        """Handle decision making during hand selection phase."""
        hand_cards = state.get('hand_cards', [])
        hands_remaining = state.get('hands_remaining', 0)
        discards_remaining = state.get('discards_remaining', 0)
        
        if not hand_cards or hands_remaining <= 0:
            return
        
        # Check for joker reordering opportunity first
        if state.get('post_hand_joker_reorder_available', False):
            await self.attempt_joker_reordering(state)
            return
        
        # Analyze hand strength
        hand_strength = self.analyze_hand_strength(hand_cards)
        logger.info(f"🃏 Hand strength: {hand_strength:.2f}")
        
        if hand_strength >= self.min_hand_strength:
            # Play the best available hand
            best_cards = self.find_best_hand_combination(hand_cards)
            if best_cards:
                await self.play_hand(best_cards)
        elif discards_remaining > 0:
            # Discard weak cards to improve hand
            weak_cards = self.identify_weak_cards(hand_cards)
            if weak_cards:
                await self.discard_cards(weak_cards)
        else:
            # No discards left, play best available hand
            best_cards = self.find_best_hand_combination(hand_cards)
            if best_cards:
                await self.play_hand(best_cards)
    
    async def handle_shop_phase(self, state: Dict[str, Any]):
        """Handle shop phase decisions."""
        money = state.get('money', 0)
        shop_contents = state.get('shop_contents', [])
        
        if money < self.min_shop_money:
            logger.info("💰 Not enough money for shopping, continuing...")
            return
        
        # Look for preferred jokers
        for item in shop_contents:
            if (item.get('item_type') == 'joker' and 
                item.get('name') in self.preferred_jokers and
                item.get('cost', 999) <= money):
                
                logger.info(f"🃏 Buying preferred joker: {item['name']}")
                await self.buy_item(item['index'])
                return
        
        # Look for any affordable joker
        for item in shop_contents:
            if (item.get('item_type') == 'joker' and 
                item.get('cost', 999) <= money):
                
                logger.info(f"🃏 Buying joker: {item['name']}")
                await self.buy_item(item['index']) 
                return
        
        logger.info("🛍️ Nothing interesting in shop, continuing...")
    
    async def handle_blind_phase(self, state: Dict[str, Any]):
        """Handle blind selection decisions."""
        # Simple strategy: choose small blind if available, otherwise big blind
        try:
            logger.info("👁️ Selecting blind...")
            await self.select_blind("small")
        except Exception:
            try:
                await self.select_blind("big")
            except Exception as e:
                logger.error(f"Blind selection failed: {e}")
    
    async def attempt_joker_reordering(self, state: Dict[str, Any]):
        """Attempt advanced joker reordering strategy."""
        jokers = state.get('jokers', [])
        if len(jokers) < 2:
            return
        
        # Find Blueprint and target jokers
        blueprint_idx = None
        mime_idx = None
        
        for i, joker in enumerate(jokers):
            if joker.get('name') == 'Blueprint':
                blueprint_idx = i
            elif joker.get('name') == 'Mime':
                mime_idx = i
        
        if blueprint_idx is not None and mime_idx is not None:
            # Advanced Blueprint + Mime strategy
            new_order = list(range(len(jokers)))
            
            # Move Mime to be adjacent to Blueprint for optimal copying
            if blueprint_idx < mime_idx:
                new_order.insert(blueprint_idx + 1, new_order.pop(mime_idx))
            else:
                new_order.insert(blueprint_idx, new_order.pop(mime_idx))
            
            logger.info("🎯 Executing Blueprint + Mime optimization!")
            await self.reorder_jokers(new_order)
    
    # Action execution methods
    
    async def play_hand(self, card_indices: List[int]):
        """Execute play hand action."""
        try:
            result = await self.session.call_tool("play_hand", {
                "card_indices": card_indices
            })
            
            if result.get('success'):
                logger.info(f"✅ Played hand: {card_indices}")
            else:
                logger.error(f"❌ Play hand failed: {result.get('error_message')}")
                
        except Exception as e:
            logger.error(f"Play hand error: {e}")
    
    async def discard_cards(self, card_indices: List[int]):
        """Execute discard cards action."""
        try:
            result = await self.session.call_tool("discard_cards", {
                "card_indices": card_indices
            })
            
            if result.get('success'):
                logger.info(f"🗑️ Discarded cards: {card_indices}")
            else:
                logger.error(f"❌ Discard failed: {result.get('error_message')}")
                
        except Exception as e:
            logger.error(f"Discard error: {e}")
    
    async def buy_item(self, shop_index: int):
        """Execute buy item action."""
        try:
            result = await self.session.call_tool("buy_item", {
                "shop_index": shop_index
            })
            
            if result.get('success'):
                logger.info(f"🛒 Bought item at index: {shop_index}")
            else:
                logger.error(f"❌ Purchase failed: {result.get('error_message')}")
                
        except Exception as e:
            logger.error(f"Purchase error: {e}")
    
    async def select_blind(self, blind_type: str):
        """Execute select blind action."""
        try:
            result = await self.session.call_tool("select_blind", {
                "blind_type": blind_type
            })
            
            if result.get('success'):
                logger.info(f"👁️ Selected blind: {blind_type}")
            else:
                logger.error(f"❌ Blind selection failed: {result.get('error_message')}")
                
        except Exception as e:
            logger.error(f"Blind selection error: {e}")
    
    async def reorder_jokers(self, new_order: List[int]):
        """Execute joker reordering action."""
        try:
            result = await self.session.call_tool("reorder_jokers", {
                "new_order": new_order
            })
            
            if result.get('success'):
                logger.info(f"🔄 Reordered jokers: {new_order}")
            else:
                logger.error(f"❌ Reorder failed: {result.get('error_message')}")
                
        except Exception as e:
            logger.error(f"Reorder error: {e}")
    
    # Utility methods
    
    def parse_state_data(self, state_data) -> Dict[str, Any]:
        """Parse state data from MCP resource."""
        try:
            if isinstance(state_data, str):
                return json.loads(state_data)
            elif hasattr(state_data, 'dict'):
                return state_data.dict()
            elif isinstance(state_data, dict):
                return state_data
            else:
                return {}
        except Exception as e:
            logger.error(f"State parsing error: {e}")
            return {}
    
    def calculate_state_hash(self, state: Dict[str, Any]) -> str:
        """Calculate simple hash for state change detection."""
        key_fields = [
            state.get('current_phase', ''),
            str(state.get('ante', 0)),
            str(state.get('money', 0)),
            str(state.get('hands_remaining', 0)),
            str(len(state.get('hand_cards', []))),
            str(len(state.get('jokers', [])))
        ]
        return '|'.join(key_fields)
    
    def analyze_hand_strength(self, hand_cards: List[Dict[str, Any]]) -> float:
        """Analyze hand strength (simplified algorithm)."""
        if not hand_cards:
            return 0.0
        
        # Simple scoring based on ranks and suits
        rank_values = {
            'A': 14, 'K': 13, 'Q': 12, 'J': 11, '10': 10,
            '9': 9, '8': 8, '7': 7, '6': 6, '5': 5, '4': 4, '3': 3, '2': 2
        }
        
        total_value = 0
        suits = {}
        ranks = {}
        
        for card in hand_cards:
            rank = card.get('rank', '2')
            suit = card.get('suit', 'hearts')
            
            total_value += rank_values.get(rank, 2)
            suits[suit] = suits.get(suit, 0) + 1
            ranks[rank] = ranks.get(rank, 0) + 1
        
        # Base strength from card values
        strength = min(total_value / 70.0, 1.0)  # Normalize to 0-1
        
        # Bonus for pairs, flushes, etc.
        max_suit_count = max(suits.values()) if suits else 0
        max_rank_count = max(ranks.values()) if ranks else 0
        
        if max_suit_count >= 5:
            strength += 0.3  # Flush bonus
        if max_rank_count >= 2:
            strength += 0.2 * max_rank_count  # Pair/triple bonus
        
        return min(strength, 1.0)
    
    def find_best_hand_combination(self, hand_cards: List[Dict[str, Any]]) -> List[int]:
        """Find the best 5-card combination to play."""
        if len(hand_cards) <= 5:
            return list(range(len(hand_cards)))
        
        # Simple strategy: play first 5 cards
        # Real implementation would analyze all combinations
        return [0, 1, 2, 3, 4]
    
    def identify_weak_cards(self, hand_cards: List[Dict[str, Any]]) -> List[int]:
        """Identify cards to discard."""
        if not hand_cards:
            return []
        
        # Simple strategy: discard lowest rank cards
        rank_values = {
            'A': 14, 'K': 13, 'Q': 12, 'J': 11, '10': 10,
            '9': 9, '8': 8, '7': 7, '6': 6, '5': 5, '4': 4, '3': 3, '2': 2
        }
        
        card_values = [
            (i, rank_values.get(card.get('rank', '2'), 2))
            for i, card in enumerate(hand_cards)
        ]
        
        # Sort by value and return indices of weakest cards
        card_values.sort(key=lambda x: x[1])
        weak_count = min(3, len(card_values))  # Discard up to 3 cards
        
        return [card_values[i][0] for i in range(weak_count)]


async def main():
    """Main entry point for the basic AI agent."""
    print("🚀 Starting Basic Balatro AI Agent")
    print("💡 Make sure the MCP server and Balatro mod are running!")
    print("⚡ Press Ctrl+C to stop the agent\n")
    
    agent = BasicBalatroAI()
    await agent.run()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n🛑 Agent stopped by user")
    except Exception as e:
        print(f"\n💥 Agent crashed: {e}")
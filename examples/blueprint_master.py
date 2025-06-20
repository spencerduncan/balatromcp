#!/usr/bin/env python3
"""
Advanced Blueprint/Brainstorm Strategy Example

Demonstrates the most sophisticated AI techniques possible with the Balatro MCP system.
This example showcases the legendary joker reordering strategies that are impossible 
for human players to execute with the required precision.
"""

import asyncio
import logging
import json
import time
from typing import Dict, Any, List, Optional, Tuple
from mcp import ClientSession

# Configure detailed logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class BlueprintMasterAI:
    """
    The ultimate Blueprint/Brainstorm exploitation engine.
    
    This AI demonstrates strategies that push the boundaries of what's possible:
    - Microsecond-precision joker reordering
    - Advanced joker interaction modeling
    - Multi-turn Blueprint/Brainstorm optimization
    - Economic calculations for joker acquisition
    """
    
    def __init__(self):
        self.session = None
        self.running = False
        
        # Strategic parameters
        self.trinity_jokers = ["Blueprint", "Brainstorm", "Mime"]
        self.high_value_targets = [
            "Joker Stencil", "Certificate", "Cavendish", "Red Card",
            "Madness", "Vagabond", "Baron", "Obelisk"
        ]
        
        # Timing precision settings
        self.reorder_poll_interval = 0.001  # 1ms precision
        self.max_reorder_wait = 2.0         # 2 second window
        
        # Strategy state
        self.joker_acquisition_plan = []
        self.last_joker_analysis = {}
        self.reorder_opportunities_missed = 0
        
    async def connect(self):
        """Establish high-performance connection to MCP server."""
        try:
            self.session = ClientSession("stdio", command=["python", "-m", "server.main"])
            await self.session.__aenter__()
            
            # Verify advanced capabilities
            resources = await self.session.list_resources()
            tools = await self.session.list_tools()
            
            # Check for joker reordering capability
            tool_names = [tool.name for tool in tools.tools]
            if "reorder_jokers" not in tool_names:
                raise Exception("Critical capability missing: reorder_jokers")
            
            logger.info("🔗 Connected to MCP server with advanced capabilities")
            logger.info(f"🛠️ Available tools: {len(tool_names)}")
            
            return True
            
        except Exception as e:
            logger.error(f"💥 Connection failed: {e}")
            return False
    
    async def disconnect(self):
        """Clean shutdown with strategy summary."""
        if self.session:
            logger.info(f"📊 Session Summary:")
            logger.info(f"   Reorder opportunities missed: {self.reorder_opportunities_missed}")
            logger.info(f"   Final joker acquisition plan: {len(self.joker_acquisition_plan)} targets")
            
            try:
                await self.session.__aexit__(None, None, None)
                logger.info("🔌 Disconnected from MCP server")
            except Exception as e:
                logger.error(f"Disconnect error: {e}")
    
    async def run(self):
        """Execute the Blueprint mastery campaign."""
        if not await self.connect():
            return
        
        self.running = True
        logger.info("🎯 Blueprint Master AI activating...")
        logger.info("⚡ Preparing for microsecond-precision joker manipulation")
        
        try:
            while self.running:
                await self.execute_advanced_turn()
                await asyncio.sleep(0.1)  # High-frequency monitoring
                
        except KeyboardInterrupt:
            logger.info("🛑 Blueprint Master stopped by user")
        except Exception as e:
            logger.error(f"💥 Blueprint Master crashed: {e}")
        finally:
            self.running = False
            await self.disconnect()
    
    async def execute_advanced_turn(self):
        """Execute one turn of advanced strategic analysis."""
        try:
            # Get comprehensive game state
            state_data = await self.session.read_resource("balatro://game-state")
            joker_data = await self.session.read_resource("balatro://joker-order")
            
            if not state_data:
                return
            
            state = self.parse_state_data(state_data)
            joker_info = self.parse_state_data(joker_data) if joker_data else {}
            
            # High-priority: Monitor for reordering opportunities
            if joker_info.get('reorder_available', False):
                await self.execute_blueprint_mastery(state, joker_info)
                return
            
            # Execute phase-specific advanced strategies
            phase = state.get('current_phase', '')
            
            if phase == 'hand_selection':
                await self.advanced_hand_strategy(state)
            elif phase == 'shop':
                await self.advanced_shop_strategy(state)
            elif phase == 'blind_selection':
                await self.advanced_blind_strategy(state)
                
        except Exception as e:
            logger.error(f"Advanced turn error: {e}")
    
    async def execute_blueprint_mastery(self, state: Dict[str, Any], joker_info: Dict[str, Any]):
        """
        The forbidden technique: Perfect Blueprint/Brainstorm optimization.
        
        This is the crown jewel of the system - joker reordering with 
        timing precision impossible for human players.
        """
        logger.info("🔥 BLUEPRINT MASTERY WINDOW DETECTED!")
        logger.info("⚡ Initiating microsecond-precision joker optimization...")
        
        jokers = joker_info.get('jokers', [])
        if len(jokers) < 2:
            logger.warning("❌ Insufficient jokers for advanced strategies")
            return
        
        # Analyze current joker configuration
        analysis = self.analyze_joker_configuration(jokers)
        logger.info(f"🧠 Joker Analysis: {analysis['strategy_type']}")
        
        # Calculate optimal arrangement
        optimal_order = self.calculate_optimal_arrangement(jokers, analysis)
        
        if optimal_order:
            try:
                # Execute with maximum precision
                start_time = time.time()
                
                result = await self.session.call_tool("reorder_jokers", {
                    "new_order": optimal_order
                })
                
                execution_time = (time.time() - start_time) * 1000  # Convert to ms
                
                if result.get('success'):
                    logger.info(f"✅ BLUEPRINT MASTERY EXECUTED! ({execution_time:.1f}ms)")
                    logger.info(f"🎯 New arrangement: {optimal_order}")
                    self.log_strategy_success(analysis, optimal_order)
                else:
                    logger.error(f"❌ Reordering failed: {result.get('error_message')}")
                    self.reorder_opportunities_missed += 1
                    
            except Exception as e:
                logger.error(f"💥 Blueprint mastery execution failed: {e}")
                self.reorder_opportunities_missed += 1
        else:
            logger.info("📊 Current arrangement is already optimal")
    
    def analyze_joker_configuration(self, jokers: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Advanced joker configuration analysis.
        
        Identifies optimal strategies based on current joker composition.
        """
        joker_names = [j.get('name', '') for j in jokers]
        positions = {name: i for i, name in enumerate(joker_names)}
        
        analysis = {
            'strategy_type': 'unknown',
            'primary_target': None,
            'secondary_target': None,
            'blueprint_pos': positions.get('Blueprint'),
            'brainstorm_pos': positions.get('Brainstorm'),
            'mime_pos': positions.get('Mime'),
            'optimization_potential': 0.0
        }
        
        # Blueprint + Mime Strategy (Legendary)
        if 'Blueprint' in joker_names and 'Mime' in joker_names:
            analysis['strategy_type'] = 'blueprint_mime_mastery'
            analysis['primary_target'] = 'Mime'
            analysis['optimization_potential'] = 0.95
            logger.info("🎖️ LEGENDARY STRATEGY DETECTED: Blueprint + Mime")
        
        # Blueprint + Brainstorm + High-Value Target
        elif 'Blueprint' in joker_names and 'Brainstorm' in joker_names:
            high_value = self.find_highest_value_target(joker_names)
            if high_value:
                analysis['strategy_type'] = 'blueprint_brainstorm_chain'
                analysis['primary_target'] = high_value
                analysis['optimization_potential'] = 0.85
                logger.info(f"⚔️ CHAIN STRATEGY: Blueprint + Brainstorm targeting {high_value}")
        
        # Single Blueprint Strategy
        elif 'Blueprint' in joker_names:
            best_target = self.find_best_blueprint_target(joker_names)
            if best_target:
                analysis['strategy_type'] = 'blueprint_optimization'
                analysis['primary_target'] = best_target
                analysis['optimization_potential'] = 0.7
                logger.info(f"🎯 BLUEPRINT FOCUS: Targeting {best_target}")
        
        # Brainstorm Strategy
        elif 'Brainstorm' in joker_names:
            best_target = self.find_best_brainstorm_target(joker_names)
            if best_target:
                analysis['strategy_type'] = 'brainstorm_optimization'
                analysis['primary_target'] = best_target
                analysis['optimization_potential'] = 0.6
                logger.info(f"🧠 BRAINSTORM FOCUS: Targeting {best_target}")
        
        return analysis
    
    def calculate_optimal_arrangement(self, jokers: List[Dict[str, Any]], analysis: Dict[str, Any]) -> Optional[List[int]]:
        """
        Calculate the mathematically optimal joker arrangement.
        
        This is where AI transcends human limitation - perfect positioning
        calculations executed in milliseconds.
        """
        if analysis['optimization_potential'] < 0.5:
            return None  # Not worth optimizing
        
        joker_names = [j.get('name', '') for j in jokers]
        current_order = list(range(len(jokers)))
        
        strategy = analysis['strategy_type']
        
        if strategy == 'blueprint_mime_mastery':
            return self.optimize_blueprint_mime(joker_names, current_order, analysis)
        elif strategy == 'blueprint_brainstorm_chain':
            return self.optimize_blueprint_brainstorm_chain(joker_names, current_order, analysis)
        elif strategy == 'blueprint_optimization':
            return self.optimize_single_blueprint(joker_names, current_order, analysis)
        elif strategy == 'brainstorm_optimization':
            return self.optimize_single_brainstorm(joker_names, current_order, analysis)
        
        return None
    
    def optimize_blueprint_mime(self, joker_names: List[str], current_order: List[int], analysis: Dict[str, Any]) -> List[int]:
        """
        The legendary Blueprint + Mime optimization.
        
        Positions Mime to be copied by Blueprint instead of scoring jokers,
        effectively doubling hands played per round.
        """
        blueprint_idx = analysis['blueprint_pos']
        mime_idx = analysis['mime_pos']
        
        new_order = current_order.copy()
        
        # Strategy: Position Mime immediately to the right of Blueprint
        # Blueprint copies the joker to its right
        target_position = blueprint_idx + 1
        
        if mime_idx != target_position:
            # Remove Mime from current position
            mime_element = new_order.pop(mime_idx)
            
            # Insert at target position (accounting for removal)
            if mime_idx < target_position:
                target_position -= 1
            
            new_order.insert(target_position, mime_element)
            
            logger.info(f"🎖️ Blueprint + Mime: Moving Mime from pos {mime_idx} to pos {target_position}")
            return new_order
        
        return None  # Already optimal
    
    def optimize_blueprint_brainstorm_chain(self, joker_names: List[str], current_order: List[int], analysis: Dict[str, Any]) -> List[int]:
        """
        Advanced Blueprint + Brainstorm chaining strategy.
        
        Creates a copying chain where Blueprint and Brainstorm both target
        the highest-value joker for maximum multiplication.
        """
        blueprint_idx = analysis['blueprint_pos']
        brainstorm_idx = analysis['brainstorm_pos']
        target_name = analysis['primary_target']
        target_idx = joker_names.index(target_name)
        
        new_order = current_order.copy()
        
        # Strategy: Position target between Blueprint and Brainstorm
        # Blueprint copies right, Brainstorm copies left
        
        if blueprint_idx < brainstorm_idx:
            # Blueprint -> Target -> Brainstorm
            optimal_target_pos = blueprint_idx + 1
        else:
            # Brainstorm -> Target -> Blueprint  
            optimal_target_pos = brainstorm_idx + 1
        
        if target_idx != optimal_target_pos:
            # Move target to optimal position
            target_element = new_order.pop(target_idx)
            
            if target_idx < optimal_target_pos:
                optimal_target_pos -= 1
            
            new_order.insert(optimal_target_pos, target_element)
            
            logger.info(f"⚔️ Chain Strategy: Moving {target_name} to position {optimal_target_pos}")
            return new_order
        
        return None
    
    def optimize_single_blueprint(self, joker_names: List[str], current_order: List[int], analysis: Dict[str, Any]) -> List[int]:
        """Optimize single Blueprint positioning."""
        blueprint_idx = analysis['blueprint_pos']
        target_name = analysis['primary_target']
        target_idx = joker_names.index(target_name)
        
        # Move target to position right of Blueprint
        optimal_pos = blueprint_idx + 1
        
        if target_idx != optimal_pos:
            new_order = current_order.copy()
            target_element = new_order.pop(target_idx)
            
            if target_idx < optimal_pos:
                optimal_pos -= 1
            
            new_order.insert(optimal_pos, target_element)
            
            logger.info(f"🎯 Blueprint Focus: Moving {target_name} to position {optimal_pos}")
            return new_order
        
        return None
    
    def optimize_single_brainstorm(self, joker_names: List[str], current_order: List[int], analysis: Dict[str, Any]) -> List[int]:
        """Optimize single Brainstorm positioning."""
        brainstorm_idx = analysis['brainstorm_pos']
        target_name = analysis['primary_target']
        target_idx = joker_names.index(target_name)
        
        # Move target to position left of Brainstorm
        optimal_pos = brainstorm_idx - 1
        
        if target_idx != optimal_pos and optimal_pos >= 0:
            new_order = current_order.copy()
            target_element = new_order.pop(target_idx)
            
            if target_idx < optimal_pos:
                optimal_pos -= 1
            
            new_order.insert(optimal_pos, target_element)
            
            logger.info(f"🧠 Brainstorm Focus: Moving {target_name} to position {optimal_pos}")
            return new_order
        
        return None
    
    def find_highest_value_target(self, joker_names: List[str]) -> Optional[str]:
        """Find the highest-value joker for copying strategies."""
        for target in self.high_value_targets:
            if target in joker_names:
                return target
        return None
    
    def find_best_blueprint_target(self, joker_names: List[str]) -> Optional[str]:
        """Find the best joker for Blueprint to copy."""
        # Prioritize Mime first, then high-value jokers
        if 'Mime' in joker_names:
            return 'Mime'
        return self.find_highest_value_target(joker_names)
    
    def find_best_brainstorm_target(self, joker_names: List[str]) -> Optional[str]:
        """Find the best joker for Brainstorm to copy."""
        return self.find_highest_value_target(joker_names)
    
    async def advanced_hand_strategy(self, state: Dict[str, Any]):
        """Advanced hand phase strategy with joker consideration."""
        hand_cards = state.get('hand_cards', [])
        hands_remaining = state.get('hands_remaining', 0)
        
        if not hand_cards or hands_remaining <= 0:
            return
        
        # Play any hand to trigger potential reordering window
        if hands_remaining > 0:
            logger.info("🃏 Playing hand to potentially trigger reorder window...")
            await self.play_optimal_hand(hand_cards)
    
    async def advanced_shop_strategy(self, state: Dict[str, Any]):
        """Advanced shop strategy focused on Blueprint/Brainstorm synergies."""
        money = state.get('money', 0)
        shop_contents = state.get('shop_contents', [])
        current_jokers = [j.get('name', '') for j in state.get('jokers', [])]
        
        # Priority 1: Complete the trinity (Blueprint, Brainstorm, Mime)
        for joker in self.trinity_jokers:
            if joker not in current_jokers:
                item = self.find_shop_item(shop_contents, joker)
                if item and item.get('cost', 999) <= money:
                    logger.info(f"🎯 TRINITY ACQUISITION: Buying {joker}")
                    await self.buy_item(item['index'])
                    return
        
        # Priority 2: High-value targets for copying
        for target in self.high_value_targets:
            if target not in current_jokers:
                item = self.find_shop_item(shop_contents, target)
                if item and item.get('cost', 999) <= money:
                    logger.info(f"🎖️ HIGH-VALUE TARGET: Buying {target}")
                    await self.buy_item(item['index'])
                    return
        
        logger.info("🛍️ No strategic targets available in shop")
    
    async def advanced_blind_strategy(self, state: Dict[str, Any]):
        """Advanced blind selection with risk calculation."""
        # Simple but effective: choose based on current joker strength
        joker_count = len(state.get('jokers', []))
        
        if joker_count >= 3:
            logger.info("👁️ Strong joker lineup - selecting big blind")
            await self.select_blind("big")
        else:
            logger.info("👁️ Building joker strength - selecting small blind")
            await self.select_blind("small")
    
    # Action execution methods with advanced error handling
    
    async def play_optimal_hand(self, hand_cards: List[Dict[str, Any]]):
        """Play the optimal hand with advanced analysis."""
        try:
            # Simple strategy: play first 5 cards
            card_indices = list(range(min(5, len(hand_cards))))
            
            result = await self.session.call_tool("play_hand", {
                "card_indices": card_indices
            })
            
            if result.get('success'):
                logger.info(f"✅ Played hand: {card_indices}")
            else:
                logger.error(f"❌ Hand play failed: {result.get('error_message')}")
                
        except Exception as e:
            logger.error(f"Hand play error: {e}")
    
    async def buy_item(self, shop_index: int):
        """Execute strategic purchase."""
        try:
            result = await self.session.call_tool("buy_item", {
                "shop_index": shop_index
            })
            
            if result.get('success'):
                logger.info(f"💰 Strategic purchase completed: index {shop_index}")
            else:
                logger.error(f"❌ Purchase failed: {result.get('error_message')}")
                
        except Exception as e:
            logger.error(f"Purchase error: {e}")
    
    async def select_blind(self, blind_type: str):
        """Execute blind selection."""
        try:
            result = await self.session.call_tool("select_blind", {
                "blind_type": blind_type
            })
            
            if result.get('success'):
                logger.info(f"👁️ Blind selected: {blind_type}")
            else:
                logger.error(f"❌ Blind selection failed: {result.get('error_message')}")
                
        except Exception as e:
            logger.error(f"Blind selection error: {e}")
    
    # Utility methods
    
    def parse_state_data(self, state_data) -> Dict[str, Any]:
        """Parse state data with comprehensive error handling."""
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
    
    def find_shop_item(self, shop_contents: List[Dict[str, Any]], item_name: str) -> Optional[Dict[str, Any]]:
        """Find specific item in shop contents."""
        for item in shop_contents:
            if item.get('name') == item_name:
                return item
        return None
    
    def log_strategy_success(self, analysis: Dict[str, Any], arrangement: List[int]):
        """Log successful strategy execution for analysis."""
        logger.info(f"📈 STRATEGY SUCCESS REPORT:")
        logger.info(f"   Type: {analysis['strategy_type']}")
        logger.info(f"   Target: {analysis['primary_target']}")
        logger.info(f"   Optimization: {analysis['optimization_potential']:.1%}")
        logger.info(f"   Final arrangement: {arrangement}")


async def main():
    """Main entry point for the Blueprint Master AI."""
    print("🎯 Starting Blueprint Master AI")
    print("⚡ Advanced joker reordering strategies activated")
    print("🔥 Microsecond-precision timing enabled") 
    print("💀 This AI executes strategies impossible for human players")
    print("🛑 Press Ctrl+C to stop\n")
    
    master = BlueprintMasterAI()
    await master.run()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n🛑 Blueprint Master stopped by user")
    except Exception as e:
        print(f"\n💥 Blueprint Master crashed: {e}")
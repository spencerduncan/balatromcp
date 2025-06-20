# Usage Guide: Mastering Balatro with AI

> **Step into the arena where artificial intelligence meets Balatro's infinite complexity.** This guide reveals how to harness the full power of the MCP integration for superhuman gameplay.

## Starting the MCP Server

**Your gateway to AI-controlled Balatro mastery begins here.**

### Basic Server Launch
```bash
cd server/
python -m main
```

The server initializes with surgical precision:
```
INFO - BalatroFileIO initialized with base path: shared
INFO - BalatroStateManager initialized  
INFO - BalatroActionHandler initialized
INFO - BalatroMCPServer started
INFO - State monitoring active
```

### Advanced Server Configuration
Control every aspect of the integration:

```bash
# Custom shared directory
BALATRO_MCP_SHARED_PATH="/custom/path" python -m main

# Debug mode for detailed logging
BALATRO_MCP_DEBUG=1 python -m main

# Disable state monitoring for manual control
BALATRO_MCP_NO_MONITOR=1 python -m main
```

## MCP Resources: Your Intelligence Network

The system exposes three critical intelligence channels:

### `balatro://game-state`
**Complete battlefield awareness.** Access every detail of the current game state:

```python
async def get_complete_state(session):
    state = await session.read_resource("balatro://game-state")
    
    # Extract critical information
    phase = state.current_phase  # hand_selection, shop, blind_selection, scoring
    money = state.money          # Available currency
    ante = state.ante           # Current difficulty level
    hands_left = state.hands_remaining    # Remaining attempts
    discards_left = state.discards_remaining  # Discard opportunities
    
    # Analyze your arsenal
    hand_cards = state.hand_cards        # Current hand composition
    jokers = state.jokers               # Your strategic multipliers
    consumables = state.consumables     # Available power-ups
    
    # Strategic opportunities
    available_actions = state.available_actions
    reorder_window = state.post_hand_joker_reorder_available
```

### `balatro://available-actions`
**Real-time tactical options.** Know exactly what moves are possible:

```python
async def check_options(session):
    actions = await session.read_resource("balatro://available-actions")
    
    # Actions adapt to game state
    if "play_hand" in actions.available_actions:
        # Hand play window is open
    if "reorder_jokers" in actions.available_actions:
        # Critical timing window for joker optimization
    if "buy_item" in actions.available_actions:
        # Shop is accessible
```

### `balatro://joker-order`
**Blueprint/Brainstorm mastery intel.** The crown jewel of advanced strategy:

```python
async def analyze_joker_setup(session):
    joker_info = await session.read_resource("balatro://joker-order")
    
    # Current joker arrangement
    jokers = joker_info.jokers  # [{position: 0, name: "Blueprint"}, ...]
    reorder_available = joker_info.reorder_available
    
    if reorder_available:
        # The gods have opened the timing window
        # Blueprint/Brainstorm strategies are now possible
```

## The 15 Actions: Your Arsenal of Control

### Core Hand Management

#### `play_hand` - Execute Your Strategy
**The moment of truth.** Play your selected cards with precision:

```python
# Play the first 5 cards
await session.call_tool("play_hand", {
    "card_indices": [0, 1, 2, 3, 4]
})

# Strategic selection - play only specific ranks
royal_cards = [i for i, card in enumerate(hand_cards) 
               if card.rank in ["A", "K", "Q", "J", "10"]]
await session.call_tool("play_hand", {"card_indices": royal_cards})
```

#### `discard_cards` - Surgical Card Removal
**Eliminate the weak to empower the strong:**

```python
# Discard low-value cards
weak_cards = [i for i, card in enumerate(hand_cards) 
              if int(card.rank) if card.rank.isdigit() else 0 < 5]
await session.call_tool("discard_cards", {"card_indices": weak_cards})
```

### Shop Mastery

#### `go_to_shop` - Enter the Marketplace
**Transition to economic warfare:**

```python
# Move to shop phase when strategic
if state.hands_remaining > 0 and state.money > 10:
    await session.call_tool("go_to_shop", {})
```

#### `buy_item` - Strategic Acquisitions
**Invest in power multipliers:**

```python
# Analyze shop contents
for i, item in enumerate(state.shop_contents):
    if item.item_type == "joker" and item.cost <= state.money:
        if item.name in ["Blueprint", "Brainstorm", "Mime"]:
            # Priority purchases for advanced strategies
            await session.call_tool("buy_item", {"shop_index": i})
            break
```

#### `sell_joker` / `sell_consumable` - Portfolio Optimization
**Liquidate assets for strategic advantage:**

```python
# Sell underperforming jokers
for i, joker in enumerate(state.jokers):
    if joker.name in ["weak_joker_names"] and state.money < 10:
        await session.call_tool("sell_joker", {"joker_index": i})
        break

# Sell consumables for immediate cash
if state.consumables and state.money < needed_amount:
    await session.call_tool("sell_consumable", {"consumable_index": 0})
```

### The Crown Jewel: `reorder_jokers`

**The most sophisticated action in the arsenal.** This is where AI transcends human limitation:

```python
async def execute_blueprint_strategy(session, state):
    """
    The legendary Blueprint/Brainstorm optimization.
    This timing window is impossibly precise for human players.
    """
    if not state.post_hand_joker_reorder_available:
        return False  # Window closed
    
    # Identify strategic jokers
    joker_names = [j.name for j in state.jokers]
    
    # Find Blueprint and Brainstorm positions
    blueprint_pos = next((i for i, name in enumerate(joker_names) 
                         if name == "Blueprint"), None)
    brainstorm_pos = next((i for i, name in enumerate(joker_names) 
                          if name == "Brainstorm"), None)
    mime_pos = next((i for i, name in enumerate(joker_names) 
                    if name == "Mime"), None)
    
    if blueprint_pos is not None and mime_pos is not None:
        # Optimal strategy: Blueprint copies Mime instead of scoring jokers
        new_order = list(range(len(state.jokers)))
        
        # Move Mime to be copied by Blueprint
        mime_idx = new_order.pop(mime_pos)
        new_order.insert(blueprint_pos - 1, mime_idx)
        
        await session.call_tool("reorder_jokers", {"new_order": new_order})
        return True
    
    return False
```

### Blind Navigation

#### `select_blind` - Choose Your Challenge
**Strategic risk assessment:**

```python
# Analyze blind options and select optimal path
blinds = ["small", "big", "boss"]  # Typically available options
difficulty_assessment = calculate_blind_difficulty(state, blinds)
selected_blind = min(blinds, key=lambda b: difficulty_assessment[b])

await session.call_tool("select_blind", {"blind_type": selected_blind})
```

#### `reroll_boss` - Manipulate Fate
**When the offered boss blinds are unfavorable:**

```python
if state.current_phase == "blind_selection" and can_afford_reroll(state):
    await session.call_tool("reroll_boss", {})
```

### Hand Organization

#### `sort_hand_by_rank` / `sort_hand_by_suit`
**Perfect your hand presentation:**

```python
# Sort for optimal visual analysis
await session.call_tool("sort_hand_by_rank", {})

# Or organize by suit for flush detection
await session.call_tool("sort_hand_by_suit", {})
```

## Advanced AI Agent Patterns

### Pattern 1: The Perfectionist
**Never make a suboptimal move:**

```python
async def perfectionist_strategy(session):
    while True:
        state = await session.read_resource("balatro://game-state")
        
        if state.current_phase == "hand_selection":
            # Calculate optimal hand
            best_hand = analyze_all_possible_hands(state.hand_cards)
            await session.call_tool("play_hand", {"card_indices": best_hand})
            
            # Check for joker reordering opportunity
            if state.post_hand_joker_reorder_available:
                optimal_order = calculate_optimal_joker_order(state.jokers)
                await session.call_tool("reorder_jokers", {"new_order": optimal_order})
        
        elif state.current_phase == "shop":
            # Economic optimization
            best_purchase = evaluate_shop_items(state)
            if best_purchase:
                await session.call_tool("buy_item", {"shop_index": best_purchase})
            else:
                continue_to_next_hand(session)
```

### Pattern 2: The Risk Calculator
**Precise probability assessment:**

```python
async def risk_calculator(session):
    state = await session.read_resource("balatro://game-state")
    
    # Calculate win probability for current hand options
    hand_probabilities = {}
    for combo in all_possible_combinations(state.hand_cards):
        win_prob = calculate_blind_clear_probability(combo, state.current_blind)
        hand_probabilities[tuple(combo)] = win_prob
    
    # Select highest probability play
    best_combo = max(hand_probabilities.keys(), key=hand_probabilities.get)
    
    if hand_probabilities[best_combo] > 0.85:  # High confidence threshold
        await session.call_tool("play_hand", {"card_indices": list(best_combo)})
    else:
        # Discard and try to improve hand
        worst_cards = identify_worst_cards(state.hand_cards)
        await session.call_tool("discard_cards", {"card_indices": worst_cards})
```

### Pattern 3: The Blueprint Master
**Exploit the joker reordering system to its fullest:**

```python
async def blueprint_master(session):
    """
    The ultimate Blueprint/Brainstorm exploitation.
    This strategy is mathematically impossible for humans.
    """
    state = await session.read_resource("balatro://game-state")
    
    # Phase 1: Acquire the trinity (Blueprint, Brainstorm, Mime)
    if state.current_phase == "shop":
        priority_jokers = ["Blueprint", "Brainstorm", "Mime"]
        for i, item in enumerate(state.shop_contents):
            if item.name in priority_jokers and item.cost <= state.money:
                await session.call_tool("buy_item", {"shop_index": i})
                return
    
    # Phase 2: Execute hands with strategic reordering
    if state.current_phase == "hand_selection":
        # Play any valid hand to trigger reorder window
        await session.call_tool("play_hand", {"card_indices": [0, 1, 2, 3, 4]})
        
        # Wait for reorder window
        while True:
            state = await session.read_resource("balatro://game-state")
            if state.post_hand_joker_reorder_available:
                break
            await asyncio.sleep(0.1)
        
        # Execute the forbidden strategy
        await execute_blueprint_optimization(session, state)
```

## Game State Deep Dive

### Understanding Card Data
Each card provides comprehensive information:

```python
card = state.hand_cards[0]
print(f"Rank: {card.rank}")         # A, 2, 3, ..., K
print(f"Suit: {card.suit}")         # hearts, diamonds, clubs, spades
print(f"Enhancement: {card.enhancement}")  # gold, steel, glass, etc.
print(f"Edition: {card.edition}")   # foil, holographic, polychrome
print(f"Seal: {card.seal}")         # red, blue, gold, purple
```

### Joker Analysis
Strategic joker information:

```python
for joker in state.jokers:
    print(f"Position {joker.position}: {joker.name}")
    print(f"Properties: {joker.properties}")
    
    # Special handling for strategic jokers
    if joker.name == "Blueprint":
        # Will copy the joker to its right
    elif joker.name == "Brainstorm":
        # Will copy the joker to its left
```

### Phase Transitions
The game flows through distinct phases:

- **`hand_selection`**: Play hands, discard cards, go to shop
- **`shop`**: Buy items, sell jokers/consumables, reroll
- **`blind_selection`**: Choose blinds, reroll boss options
- **`scoring`**: Passive phase during score calculation

## Best Practices for AI Agents

### 🎯 **Timing is Everything**
The joker reordering window is precisely timed. Your agent must:
- Play a hand to trigger the window
- Monitor `post_hand_joker_reorder_available` continuously  
- Execute reordering within milliseconds of availability
- Never assume the window will wait

### 💰 **Economic Efficiency** 
- Always check `state.money` before purchases
- Calculate return-on-investment for all shop items
- Sell underperforming assets aggressively
- Maintain cash reserves for critical opportunities

### 🃏 **Strategic Depth**
- Analyze all possible hand combinations before playing
- Consider joker interaction effects in calculations
- Plan multi-turn strategies around specific joker acquisitions
- Exploit blind mechanics for maximum scoring

### ⚡ **Performance Optimization**
- Cache expensive calculations between state updates
- Use async patterns to avoid blocking the game
- Monitor resource usage - Balatro can be CPU intensive
- Implement fallback strategies for edge cases

### 🛡️ **Error Handling**
```python
try:
    result = await session.call_tool("play_hand", {"card_indices": [0, 1, 2]})
    if not result.success:
        print(f"Action failed: {result.error_message}")
        # Implement fallback strategy
except Exception as e:
    print(f"Communication error: {e}")
    # Reconnect or restart
```

## Debugging Your AI Agent

### Monitor Communication Files
Watch the shared files for real-time debugging:

```bash
# Monitor game state updates
tail -f shared/game_state.json

# Watch action execution
tail -f shared/action_results.json
```

### Enable Debug Logging
```python
import logging
logging.basicConfig(level=logging.DEBUG)

# Your agent will now show detailed communication logs
```

### Common Issues and Solutions

**"Action not available"**
```python
# Always check available actions first
actions = await session.read_resource("balatro://available-actions")
if "play_hand" in actions.available_actions:
    await session.call_tool("play_hand", {"card_indices": [0, 1, 2]})
```

**"Invalid card indices"**
```python
# Validate indices against current hand size
valid_indices = [i for i in card_indices if 0 <= i < len(state.hand_cards)]
await session.call_tool("play_hand", {"card_indices": valid_indices})
```

**"Timeout waiting for result"**
```python
# Implement retry logic with exponential backoff
async def retry_action(session, action, params, max_retries=3):
    for attempt in range(max_retries):
        try:
            return await session.call_tool(action, params)
        except TimeoutError:
            await asyncio.sleep(2 ** attempt)  # Exponential backoff
    raise Exception(f"Action {action} failed after {max_retries} attempts")
```

## Advanced Example: Tournament-Level Agent

Here's a complete example of a tournament-caliber AI agent:

```python
import asyncio
from mcp import ClientSession
from typing import List, Dict, Any

class BalatroTournamentAI:
    """
    Professional-grade Balatro AI agent.
    Implements multi-layered strategy with perfect execution.
    """
    
    def __init__(self):
        self.strategy_cache = {}
        self.joker_priorities = {
            "Blueprint": 100, "Brainstorm": 95, "Mime": 90,
            "Joker Stencil": 85, "Certificate": 80
        }
    
    async def run_session(self):
        async with ClientSession("stdio", command=["python", "-m", "server.main"]) as session:
            while True:
                try:
                    await self.execute_turn(session)
                    await asyncio.sleep(0.5)  # Prevent overwhelming the system
                except Exception as e:
                    print(f"Error in turn execution: {e}")
                    await asyncio.sleep(1)
    
    async def execute_turn(self, session):
        state = await session.read_resource("balatro://game-state")
        
        if state.current_phase == "hand_selection":
            await self.execute_hand_phase(session, state)
        elif state.current_phase == "shop":
            await self.execute_shop_phase(session, state)
        elif state.current_phase == "blind_selection":
            await self.execute_blind_phase(session, state)
    
    async def execute_hand_phase(self, session, state):
        # Multi-layered hand analysis
        best_play = self.analyze_optimal_play(state)
        
        if best_play["action"] == "play":
            await session.call_tool("play_hand", {"card_indices": best_play["cards"]})
            
            # Monitor for joker reordering opportunity
            await self.monitor_reorder_window(session)
            
        elif best_play["action"] == "discard":
            await session.call_tool("discard_cards", {"card_indices": best_play["cards"]})
    
    async def monitor_reorder_window(self, session):
        """The microsecond-precision joker reordering system."""
        start_time = asyncio.get_event_loop().time()
        
        while (asyncio.get_event_loop().time() - start_time) < 2.0:  # 2-second window
            state = await session.read_resource("balatro://game-state")
            
            if state.post_hand_joker_reorder_available:
                optimal_order = self.calculate_optimal_joker_order(state.jokers)
                await session.call_tool("reorder_jokers", {"new_order": optimal_order})
                break
                
            await asyncio.sleep(0.01)  # 10ms polling for maximum responsiveness
    
    def analyze_optimal_play(self, state) -> Dict[str, Any]:
        """
        Tournament-level hand analysis.
        Considers all factors: current blind, joker effects, economic state.
        """
        # Implementation of advanced game theory analysis
        # This is where the magic happens
        pass
    
    def calculate_optimal_joker_order(self, jokers) -> List[int]:
        """
        The forbidden art of joker optimization.
        Calculates the mathematically perfect joker arrangement.
        """
        # Advanced joker interaction analysis
        # Blueprint/Brainstorm positioning algorithms
        pass

# Launch the tournament AI
if __name__ == "__main__":
    ai = BalatroTournamentAI()
    asyncio.run(ai.run_session())
```

## Next Steps

**Master the fundamentals:**
- Practice with the basic examples above
- Experiment with different strategy patterns
- Monitor your AI's performance in different scenarios

**Advance to expert level:**
- Study the [API Reference](api-reference.md) for complete action details
- Explore the [Developer Guide](developer-guide.md) for system customization
- Build your own unique AI strategies

**Ready to dominate Balatro with superhuman precision?** Your AI agent awaits your command.

---

*The age of human Balatro limitation ends here. AI mastery begins now.*
# API Reference: Balatro MCP Server

> **Complete technical specification for the Balatro MCP integration.** Every endpoint, every parameter, every response - documented with surgical precision.

## MCP Server Overview

The Balatro MCP Server exposes three types of interfaces:
- **Resources**: Real-time game state data
- **Tools**: Game action execution
- **Communication Protocol**: File-based message exchange

**Base Configuration:**
- **Protocol**: Model Context Protocol (MCP) v1.0+
- **Transport**: stdio (standard input/output)
- **Communication**: File-based JSON exchange
- **Server Name**: `balatro-mcp`
- **Server Version**: `1.0.0`

## Resources

### `balatro://game-state`

**Complete game state intelligence.** Real-time access to every aspect of the current game.

#### Response Schema
```json
{
  "session_id": "string",
  "current_phase": "hand_selection|shop|blind_selection|scoring",
  "ante": "integer",
  "money": "integer", 
  "hands_remaining": "integer",
  "discards_remaining": "integer",
  "hand_cards": [
    {
      "id": "string",
      "rank": "string", 
      "suit": "string",
      "enhancement": "none|gold|steel|glass|wild|bonus|mult|stone",
      "edition": "none|foil|holographic|polychrome|negative",
      "seal": "none|red|blue|gold|purple"
    }
  ],
  "jokers": [
    {
      "id": "string",
      "name": "string",
      "position": "integer",
      "properties": {}
    }
  ],
  "consumables": [
    {
      "id": "string", 
      "name": "string",
      "card_type": "string",
      "properties": {}
    }
  ],
  "current_blind": {
    "name": "string",
    "blind_type": "small|big|boss",
    "requirement": "integer",
    "reward": "integer",
    "properties": {}
  },
  "shop_contents": [
    {
      "index": "integer",
      "item_type": "joker|consumable|pack",
      "name": "string", 
      "cost": "integer",
      "properties": {}
    }
  ],
  "available_actions": ["string"],
  "post_hand_joker_reorder_available": "boolean"
}
```

#### Usage Example
```python
state = await session.read_resource("balatro://game-state")
print(f"Current phase: {state.current_phase}")
print(f"Money: ${state.money}")
print(f"Hand size: {len(state.hand_cards)}")
```

### `balatro://available-actions`

**Real-time action availability.** Know exactly which moves are possible in the current game state.

#### Response Schema
```json
{
  "available_actions": [
    "get_game_state",
    "play_hand", 
    "discard_cards",
    "go_to_shop",
    "buy_item",
    "sell_joker",
    "sell_consumable", 
    "reorder_jokers",
    "select_blind",
    "select_pack_offer",
    "reroll_boss",
    "reroll_shop",
    "sort_hand_by_rank",
    "sort_hand_by_suit", 
    "use_consumable"
  ]
}
```

#### Usage Example
```python
actions = await session.read_resource("balatro://available-actions")
if "reorder_jokers" in actions.available_actions:
    # Critical timing window is open
    await execute_joker_reordering(session)
```

### `balatro://joker-order`

**Strategic joker arrangement intelligence.** Critical for Blueprint/Brainstorm optimization.

#### Response Schema
```json
{
  "jokers": [
    {
      "position": "integer",
      "name": "string"
    }
  ],
  "reorder_available": "boolean"
}
```

#### Usage Example
```python
joker_info = await session.read_resource("balatro://joker-order")
if joker_info.reorder_available:
    # The timing window is open - execute advanced strategies
    blueprint_pos = next(j.position for j in joker_info.jokers if j.name == "Blueprint")
```

## Tools (Game Actions)

### Core Hand Management Tools

#### `get_game_state`

**Explicit state retrieval.** Alternative to resource access.

```json
{
  "name": "get_game_state",
  "description": "Retrieve the current game state",
  "inputSchema": {
    "type": "object",
    "properties": {},
    "required": []
  }
}
```

**Usage:**
```python
result = await session.call_tool("get_game_state", {})
# Returns same data as balatro://game-state resource
```

#### `play_hand`

**Execute card combinations.** The core scoring mechanism.

```json
{
  "name": "play_hand",
  "description": "Play selected cards from hand",
  "inputSchema": {
    "type": "object",
    "properties": {
      "card_indices": {
        "type": "array",
        "items": {"type": "integer"},
        "description": "Indices of cards to play (0-based)"
      }
    },
    "required": ["card_indices"]
  }
}
```

**Parameters:**
- `card_indices`: Array of integers representing card positions in hand (0-based indexing)

**Validation Rules:**
- Must be in `hand_selection` phase
- `hands_remaining > 0`
- All indices must be valid (0 ≤ index < hand_size)
- At least one card must be selected
- Cards must form a valid Balatro hand

**Usage Example:**
```python
# Play a straight flush
await session.call_tool("play_hand", {
    "card_indices": [0, 1, 2, 3, 4]
})

# Play specific cards
royal_indices = [i for i, card in enumerate(hand_cards) 
                 if card.rank in ["A", "K", "Q", "J", "10"]]
await session.call_tool("play_hand", {
    "card_indices": royal_indices
})
```

#### `discard_cards`

**Strategic card removal.** Hand optimization through selective discarding.

```json
{
  "name": "discard_cards", 
  "description": "Discard selected cards from hand",
  "inputSchema": {
    "type": "object",
    "properties": {
      "card_indices": {
        "type": "array",
        "items": {"type": "integer"},
        "description": "Indices of cards to discard (0-based)"
      }
    },
    "required": ["card_indices"]
  }
}
```

**Parameters:**
- `card_indices`: Array of integers representing card positions to discard

**Validation Rules:**
- Must be in `hand_selection` phase
- `discards_remaining > 0` 
- All indices must be valid
- At least one card must be selected

**Usage Example:**
```python
# Discard low-value cards
low_cards = [i for i, card in enumerate(hand_cards) 
             if card.rank in ["2", "3", "4"]]
await session.call_tool("discard_cards", {
    "card_indices": low_cards
})
```

### Shop Management Tools

#### `go_to_shop`

**Navigate to the marketplace.** Transition from hand phase to shop phase.

```json
{
  "name": "go_to_shop",
  "description": "Navigate to the shop phase", 
  "inputSchema": {
    "type": "object",
    "properties": {},
    "required": []
  }
}
```

**Validation Rules:**
- Must be in `hand_selection` phase
- Action must be available (not all game states allow shop access)

**Usage Example:**
```python
# Strategic shop entry
if state.money > 10 and state.hands_remaining > 0:
    await session.call_tool("go_to_shop", {})
```

#### `buy_item`

**Strategic acquisitions.** Purchase items from the shop.

```json
{
  "name": "buy_item",
  "description": "Purchase an item from the shop",
  "inputSchema": {
    "type": "object", 
    "properties": {
      "shop_index": {
        "type": "integer",
        "description": "Index of shop item to purchase (0-based)"
      }
    },
    "required": ["shop_index"]
  }
}
```

**Parameters:**
- `shop_index`: Integer index of the item in `shop_contents` array

**Validation Rules:**
- Must be in `shop` phase
- Index must be valid (0 ≤ index < shop_contents.length)
- Player must have sufficient money (`money >= item.cost`)

**Usage Example:**
```python
# Buy the first affordable joker
for i, item in enumerate(state.shop_contents):
    if item.item_type == "joker" and item.cost <= state.money:
        await session.call_tool("buy_item", {"shop_index": i})
        break
```

#### `sell_joker`

**Portfolio optimization.** Liquidate jokers for cash.

```json
{
  "name": "sell_joker",
  "description": "Sell a joker from collection",
  "inputSchema": {
    "type": "object",
    "properties": {
      "joker_index": {
        "type": "integer", 
        "description": "Index of joker to sell (0-based)"
      }
    },
    "required": ["joker_index"] 
  }
}
```

**Parameters:**
- `joker_index`: Integer index of the joker in `jokers` array

**Validation Rules:**
- Must be in `shop` phase
- Index must be valid (0 ≤ index < jokers.length)

**Usage Example:**
```python
# Sell underperforming jokers
weak_jokers = ["Joker", "Sly Joker"] 
for i, joker in enumerate(state.jokers):
    if joker.name in weak_jokers:
        await session.call_tool("sell_joker", {"joker_index": i})
        break
```

#### `sell_consumable`

**Consumable liquidation.** Convert consumables to immediate cash.

```json
{
  "name": "sell_consumable",
  "description": "Sell a consumable card",
  "inputSchema": {
    "type": "object",
    "properties": {
      "consumable_index": {
        "type": "integer",
        "description": "Index of consumable to sell (0-based)"
      }
    },
    "required": ["consumable_index"]
  }
}
```

**Parameters:**
- `consumable_index`: Integer index of the consumable in `consumables` array

**Validation Rules:**
- Must be in `shop` phase
- Index must be valid (0 ≤ index < consumables.length)

**Usage Example:**
```python
# Emergency cash generation
if state.money < needed_amount and state.consumables:
    await session.call_tool("sell_consumable", {"consumable_index": 0})
```

#### `reroll_shop`

**Manipulate shop inventory.** Refresh shop contents for better options.

```json
{
  "name": "reroll_shop",
  "description": "Reroll shop contents",
  "inputSchema": {
    "type": "object",
    "properties": {},
    "required": []
  }
}
```

**Validation Rules:**
- Must be in `shop` phase
- Player must have sufficient money for reroll cost
- Reroll must be available (some shop states don't allow rerolls)

**Usage Example:**
```python
# Reroll for better jokers
if state.money > 10 and no_good_items_in_shop(state.shop_contents):
    await session.call_tool("reroll_shop", {})
```

### The Crown Jewel: `reorder_jokers`

**The most sophisticated action.** Enables impossible-for-humans Blueprint/Brainstorm strategies.

```json
{
  "name": "reorder_jokers",
  "description": "Reorder jokers for Blueprint/Brainstorm strategy",
  "inputSchema": {
    "type": "object",
    "properties": {
      "new_order": {
        "type": "array",
        "items": {"type": "integer"},
        "description": "New joker order (indices representing positions)"
      }
    },
    "required": ["new_order"]
  }
}
```

**Parameters:**
- `new_order`: Array of integers representing the new joker arrangement

**Critical Validation Rules:**
- `post_hand_joker_reorder_available` must be `true`
- Array length must equal current joker count
- Array must contain each joker index exactly once (valid permutation)
- Timing window is extremely narrow (microseconds after hand play)

**Advanced Usage:**
```python
async def execute_blueprint_mastery(session, state):
    """The forbidden joker reordering technique."""
    
    # Wait for the precise timing window
    while True:
        current_state = await session.read_resource("balatro://game-state")
        if current_state.post_hand_joker_reorder_available:
            break
        await asyncio.sleep(0.001)  # 1ms precision
    
    # Calculate optimal arrangement
    joker_names = [j.name for j in state.jokers]
    
    # Find strategic positions
    blueprint_idx = joker_names.index("Blueprint") if "Blueprint" in joker_names else None
    mime_idx = joker_names.index("Mime") if "Mime" in joker_names else None
    
    if blueprint_idx is not None and mime_idx is not None:
        # Move Mime adjacent to Blueprint for copying
        new_order = list(range(len(state.jokers)))
        
        # Advanced positioning algorithm
        if blueprint_idx > mime_idx:
            # Blueprint copies joker to its right
            new_order.insert(blueprint_idx + 1, new_order.pop(mime_idx))
        else:
            # Blueprint copies joker to its left  
            new_order.insert(blueprint_idx, new_order.pop(mime_idx))
        
        await session.call_tool("reorder_jokers", {"new_order": new_order})
        return True
    
    return False
```

### Blind Management Tools

#### `select_blind`

**Choose your challenge.** Strategic blind selection.

```json
{
  "name": "select_blind",
  "description": "Select blind type",
  "inputSchema": {
    "type": "object",
    "properties": {
      "blind_type": {
        "type": "string",
        "description": "Type of blind to select"
      }
    },
    "required": ["blind_type"]
  }
}
```

**Parameters:**
- `blind_type`: String identifier for the blind ("small", "big", "boss", or specific boss names)

**Validation Rules:**
- Must be in `blind_selection` phase
- Blind type must be available as an option

**Usage Example:**
```python
# Strategic blind selection based on current hand strength
hand_strength = calculate_hand_strength(state)
if hand_strength > 0.8:
    await session.call_tool("select_blind", {"blind_type": "boss"})
else:
    await session.call_tool("select_blind", {"blind_type": "small"})
```

#### `reroll_boss`

**Manipulate boss options.** Refresh boss blind choices.

```json
{
  "name": "reroll_boss", 
  "description": "Reroll boss blind options",
  "inputSchema": {
    "type": "object",
    "properties": {},
    "required": []
  }
}
```

**Validation Rules:**
- Must be in `blind_selection` phase
- Player must have sufficient money for reroll
- Boss reroll must be available

**Usage Example:**
```python
# Reroll unfavorable boss blinds
if all_bosses_are_unfavorable(available_bosses) and state.money > 5:
    await session.call_tool("reroll_boss", {})
```

#### `select_pack_offer`

**Pack selection.** Choose from available card packs.

```json
{
  "name": "select_pack_offer",
  "description": "Select from pack offers", 
  "inputSchema": {
    "type": "object",
    "properties": {
      "pack_index": {
        "type": "integer",
        "description": "Index of pack to select (0-based)"
      }
    },
    "required": ["pack_index"]
  }
}
```

**Parameters:**
- `pack_index`: Integer index of the pack to select

**Usage Example:**
```python
# Select the most valuable pack
best_pack = analyze_pack_value(available_packs)
await session.call_tool("select_pack_offer", {"pack_index": best_pack})
```

### Hand Organization Tools

#### `sort_hand_by_rank`

**Hand organization by rank.** Sort cards for optimal visual analysis.

```json
{
  "name": "sort_hand_by_rank",
  "description": "Sort hand cards by rank",
  "inputSchema": {
    "type": "object", 
    "properties": {},
    "required": []
  }
}
```

**Validation Rules:**
- Must be in `hand_selection` phase

**Usage Example:**
```python
# Organize hand for straight detection
await session.call_tool("sort_hand_by_rank", {})
```

#### `sort_hand_by_suit`

**Hand organization by suit.** Sort cards for flush analysis.

```json
{
  "name": "sort_hand_by_suit",
  "description": "Sort hand cards by suit",
  "inputSchema": {
    "type": "object",
    "properties": {},
    "required": []
  }
}
```

**Usage Example:**
```python
# Organize hand for flush detection
await session.call_tool("sort_hand_by_suit", {})
```

#### `use_consumable`

**Activate consumable effects.** Use consumable cards for strategic advantage.

```json
{
  "name": "use_consumable",
  "description": "Use a consumable card",
  "inputSchema": {
    "type": "object",
    "properties": {
      "item_id": {
        "type": "string", 
        "description": "ID of consumable to use"
      }
    },
    "required": ["item_id"]
  }
}
```

**Parameters:**
- `item_id`: String ID of the consumable (from consumables array)

**Validation Rules:**
- Consumable with specified ID must exist in current consumables
- Consumable must be usable in current game state

**Usage Example:**
```python
# Use Temperance card for money
temperance_id = next(c.id for c in state.consumables if c.name == "Temperance")
await session.call_tool("use_consumable", {"item_id": temperance_id})
```

## Response Format

All tool calls return a standardized response:

```json
{
  "success": "boolean",
  "error_message": "string|null", 
  "tool": "string",
  "timestamp": "ISO 8601 timestamp"
}
```

### Success Response
```python
{
  "success": True,
  "error_message": None,
  "tool": "play_hand", 
  "timestamp": "2024-01-01T12:00:00Z"
}
```

### Error Response  
```python
{
  "success": False,
  "error_message": "Action play_hand is not valid in current state",
  "tool": "play_hand",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

## Error Codes and Handling

### Common Error Types

#### `ActionNotAvailable`
**The requested action is not currently available.**

```python
# Error message: "Action play_hand is not valid in current state"
# Solution: Check available_actions before calling
actions = await session.read_resource("balatro://available-actions")
if "play_hand" in actions.available_actions:
    await session.call_tool("play_hand", params)
```

#### `InvalidParameters`
**The provided parameters are invalid.**

```python
# Error message: "Invalid card indices: [5, 6] for hand size 5"
# Solution: Validate parameters against current state
valid_indices = [i for i in card_indices if 0 <= i < len(state.hand_cards)]
await session.call_tool("play_hand", {"card_indices": valid_indices})
```

#### `InsufficientResources`
**Not enough money/discards/hands for the action.**

```python
# Error message: "Insufficient money: need 10, have 5"
# Solution: Check resources before spending
if state.money >= item.cost:
    await session.call_tool("buy_item", {"shop_index": index})
```

#### `TimingWindowClosed`
**The timing window for the action has expired.**

```python
# Error message: "Joker reordering window is no longer available"
# Solution: Monitor timing windows precisely
if state.post_hand_joker_reorder_available:
    await session.call_tool("reorder_jokers", {"new_order": order})
```

#### `CommunicationTimeout`
**The mod didn't respond within the timeout period.**

```python
# Error message: "Timeout waiting for action result"
# Solution: Implement retry logic with exponential backoff
async def retry_with_backoff(session, tool, params, max_retries=3):
    for attempt in range(max_retries):
        try:
            return await session.call_tool(tool, params)
        except TimeoutError:
            await asyncio.sleep(2 ** attempt)
    raise Exception(f"Action {tool} failed after {max_retries} attempts")
```

## Advanced Integration Patterns

### Async Action Chains
Execute multiple actions in sequence with proper error handling:

```python
async def execute_action_chain(session, actions):
    """Execute a series of actions with rollback on failure."""
    completed_actions = []
    
    try:
        for action_data in actions:
            result = await session.call_tool(action_data["tool"], action_data["params"])
            if not result["success"]:
                raise Exception(f"Action {action_data['tool']} failed: {result['error_message']}")
            completed_actions.append(action_data)
            
    except Exception as e:
        # Implement rollback logic if needed
        print(f"Action chain failed at step {len(completed_actions)}: {e}")
        raise
    
    return completed_actions
```

### State-Driven Action Selection
Choose actions based on comprehensive state analysis:

```python
async def intelligent_action_selection(session):
    """Advanced AI action selection based on complete state analysis."""
    state = await session.read_resource("balatro://game-state")
    actions = await session.read_resource("balatro://available-actions")
    
    # Multi-factor decision matrix
    decision_factors = {
        "economic_pressure": calculate_economic_pressure(state),
        "hand_strength": analyze_hand_strength(state.hand_cards),
        "joker_synergy": evaluate_joker_synergies(state.jokers),
        "blind_difficulty": assess_blind_challenge(state.current_blind)
    }
    
    # Action selection algorithm
    if decision_factors["economic_pressure"] > 0.7 and "go_to_shop" in actions.available_actions:
        return {"tool": "go_to_shop", "params": {}}
    elif decision_factors["hand_strength"] > 0.8 and "play_hand" in actions.available_actions:
        best_hand = calculate_optimal_hand(state.hand_cards)
        return {"tool": "play_hand", "params": {"card_indices": best_hand}}
    elif state.post_hand_joker_reorder_available:
        optimal_order = calculate_joker_order(state.jokers)
        return {"tool": "reorder_jokers", "params": {"new_order": optimal_order}}
    
    # Default action
    return None
```

### Real-Time State Monitoring
Monitor game state changes for reactive strategies:

```python
async def reactive_monitoring(session):
    """Monitor game state changes and react immediately."""
    last_state_hash = None
    
    while True:
        try:
            state = await session.read_resource("balatro://game-state")
            current_hash = calculate_state_hash(state)
            
            if current_hash != last_state_hash:
                # State changed - analyze and react
                await analyze_state_change(session, state)
                last_state_hash = current_hash
                
                # Special handling for critical timing windows
                if state.post_hand_joker_reorder_available:
                    await handle_joker_reorder_window(session, state)
            
            await asyncio.sleep(0.1)  # 100ms polling
            
        except Exception as e:
            print(f"Monitoring error: {e}")
            await asyncio.sleep(1.0)  # Back off on error
```

## Performance Considerations

### Optimal Polling Rates
- **Game State**: Poll every 100-500ms for general state monitoring
- **Joker Reordering**: Poll every 1-10ms during timing windows
- **Action Results**: Poll every 50-100ms when waiting for responses

### Memory Management
- Cache expensive calculations between state updates
- Clean up old state data to prevent memory leaks
- Use async generators for streaming large datasets

### Network Efficiency
- Batch multiple resource reads when possible
- Implement local caching for frequently accessed data
- Use conditional requests to avoid unnecessary data transfer

## File Communication Protocol

The system uses three JSON files for communication:

### `shared/game_state.json`
**Mod → MCP Server**: Game state updates

```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "sequence_id": 123,
  "message_type": "game_state", 
  "data": {
    // GameState object
  }
}
```

### `shared/actions.json`
**MCP Server → Mod**: Action commands

```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "sequence_id": 124,
  "message_type": "action_command",
  "data": {
    "action_type": "play_hand",
    "card_indices": [0, 1, 2, 3, 4]
  }
}
```

### `shared/action_results.json`
**Mod → MCP Server**: Action execution results

```json
{
  "timestamp": "2024-01-01T12:00:00Z", 
  "sequence_id": 124,
  "message_type": "action_result",
  "data": {
    "success": true,
    "error_message": null,
    "new_state": {
      // Updated GameState object (optional)
    }
  }
}
```

## Integration Examples

### Basic MCP Client Setup
```python
import asyncio
from mcp import ClientSession

async def basic_integration():
    # Connect to MCP server
    async with ClientSession("stdio", command=["python", "-m", "server.main"]) as session:
        # List available resources
        resources = await session.list_resources()
        print("Available resources:", [r.name for r in resources.resources])
        
        # List available tools
        tools = await session.list_tools()
        print("Available tools:", [t.name for t in tools.tools])
        
        # Read game state
        state = await session.read_resource("balatro://game-state")
        print(f"Current phase: {state}")
        
        # Execute action
        result = await session.call_tool("get_game_state", {})
        print(f"Action result: {result}")

asyncio.run(basic_integration())
```

### Advanced Tournament AI
```python
class TournamentBalatroAI:
    async def run_tournament(self):
        async with ClientSession("stdio", command=["python", "-m", "server.main"]) as session:
            while True:
                # Get comprehensive state
                state = await session.read_resource("balatro://game-state")
                
                # Multi-layered decision making
                decision = await self.calculate_optimal_decision(session, state)
                
                if decision:
                    result = await session.call_tool(decision["tool"], decision["params"])
                    if not result["success"]:
                        await self.handle_action_failure(result)
                
                await asyncio.sleep(0.1)  # Prevent overwhelming the system
    
    async def calculate_optimal_decision(self, session, state):
        """Tournament-level decision calculation with perfect information."""
        # Implementation of advanced game theory
        pass
```

## Next Steps

**Master the API:**
- Implement each action with proper error handling
- Build comprehensive state monitoring systems
- Develop advanced strategy algorithms

**Advance to expert level:**
- Study the [Developer Guide](developer-guide.md) for system extension
- Explore advanced joker reordering strategies
- Build tournament-level AI agents

**Ready to dominate Balatro with mathematical precision?** The complete API is at your command.

---

*Every endpoint documented. Every parameter specified. Perfect control awaits.*
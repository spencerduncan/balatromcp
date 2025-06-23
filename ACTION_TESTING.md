# Action Testing Scripts

This directory contains scripts to generate properly formatted `actions.json` files for testing BalatroMCP action execution.

## Scripts

### `create-action.ps1` (PowerShell Script)
Comprehensive PowerShell script that generates actions.json with proper message wrapper structure.

**Usage:**
```powershell
.\create-action.ps1 -Action [ACTION_TYPE] -Sequence [SEQUENCE_ID] [additional_params]
```

### `test-actions.bat` (Batch File)
Simple Windows batch file wrapper for common testing scenarios.

**Usage:**
```cmd
test-actions.bat [action_type] [sequence] [additional_params...]
```

## Supported Action Types

### Basic Actions
- **skip_blind**: Skip the current blind selection
- **reroll_shop**: Reroll shop items

### Blind Selection
- **select_blind**: Choose a specific blind type
  - Parameters: `blind_type` (small, big, boss)

### Card Actions
- **play_hand**: Play selected cards
  - Parameters: `card_ids` (comma-separated list)
- **discard_hand**: Discard selected cards
  - Parameters: `card_ids` (comma-separated list)

### Shop Actions
- **buy_item**: Purchase item from shop
  - Parameters: `item_index` (shop position: 0, 1, 2, etc.)

### Joker Management
- **sell_joker**: Sell a joker
  - Parameters: `joker_id` (joker's unique ID)
- **reorder_jokers**: Reorder jokers in collection
  - Parameters: `new_order` (comma-separated joker IDs)

### Consumables
- **use_consumable**: Use a consumable item
  - Parameters: `consumable_id` (consumable's unique ID)

## Examples

### Skip Blind
```cmd
test-actions.bat skip_blind 35
```

### Select Big Blind
```cmd
test-actions.bat select_blind 36 big
```

### Play Hand (cards 1,2,3,4,5)
```cmd
test-actions.bat play_hand 37 "1,2,3,4,5"
```

### Buy First Shop Item
```cmd
test-actions.bat buy_item 38 0
```

### Sell Joker
```cmd
test-actions.bat sell_joker 39 123.456
```

### Advanced PowerShell Usage
```powershell
# Create skip blind action with sequence 40
.\create-action.ps1 -Action skip_blind -Sequence 40

# Create select blind action for boss blind
.\create-action.ps1 -Action select_blind -Sequence 41 -BlindType boss

# Create play hand action with specific cards
.\create-action.ps1 -Action play_hand -Sequence 42 -Cards "10,11,12,13,14"

# Create reorder jokers action
.\create-action.ps1 -Action reorder_jokers -Sequence 43 -NewOrder "123.1,456.2,789.3"

# Output to custom location
.\create-action.ps1 -Action skip_blind -Sequence 44 -OutputPath "./test_actions/skip_44.json"
```

## Generated JSON Format

All actions are wrapped in the proper message structure expected by BalatroMCP:

```json
{
  "data": {
    "action_type": "skip_blind",
    "sequence": 35
  }
}
```

Actions with parameters include additional fields:

```json
{
  "data": {
    "action_type": "select_blind",
    "sequence": 36,
    "blind_type": "big"
  }
}
```

## Testing Workflow

1. Check current game state to determine valid actions
2. Use appropriate sequence ID (increment from last used)
3. Generate action using scripts
4. Monitor `action_results.json` for execution results
5. Verify game state changes as expected

## Tips

- Always increment sequence IDs to avoid conflicts
- Check `game_state.json` for current phase and available actions
- Use `action_results.json` to verify action execution
- Card IDs and joker IDs can be found in game state data
- Shop item indices start from 0 (leftmost item)
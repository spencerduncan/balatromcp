# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Testing
```bash
# Run all LuaUnit tests (293 tests across 35+ modules)
lua tests/run_luaunit_tests.lua

# Run specific test module
lua -e "require('tests.test_file_transport_luaunit')"

# Test a specific component (alternative)
lua tests/test_state_extractor_luaunit.lua
```

### Action Testing
```bash
# Test specific game actions via PowerShell
powershell -ExecutionPolicy Bypass -File create-action.ps1 -Action play_hand -Sequence 42 -Cards "1,2,3,4,5"
powershell -ExecutionPolicy Bypass -File create-action.ps1 -Action select_blind -Sequence 43 -BlindType big

# Quick action testing via batch
test-actions.bat play_hand 42 "1,2,3,4,5"
test-actions.bat reorder_jokers 44 "123.1,456.2,789.3"
```

### Mod Deployment
```bash
# Deploy mod to Balatro (Windows)
powershell -ExecutionPolicy Bypass -File deploy-mod.ps1

# Manual installation: Copy entire directory to:
# Windows: %APPDATA%/Balatro/Mods/BalatroMCP/
# Steam: steamapps/common/Balatro/Mods/BalatroMCP/
```

## High-Level Architecture

### Core Design Pattern: Transport-Based Message Layer
The codebase follows a **Transport Abstraction Pattern** where all communication between Balatro and external AI agents flows through pluggable transport implementations:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   AI Agent      │◄──►│ MessageManager  │◄──►│ IMessageTransport│
│   (External)    │    │                 │    │ Implementation  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │                        │
                              ▼                        ▼
                    ┌─────────────────┐    ┌─────────────────┐
                    │ StateExtractor  │    │ AsyncFileTransport│
                    │ (Game→JSON)     │    │ (Non-blocking I/O)│
                    └─────────────────┘    └─────────────────┘
```

**Key Transport Properties:**
- **Async File Transport**: Uses Love2D threading for non-blocking file operations with worker threads and channels
- **Message Manager**: Handles JSON serialization, sequence IDs, and transport coordination
- **Interface Abstraction**: All transports implement `IMessageTransport` with methods: `write_message()`, `read_message()`, `verify_message()`, `cleanup_old_messages()`

### Three-Layer State Extraction Architecture

The **StateExtractor** uses a modular facade pattern after recent refactoring:

```
state_extractor.lua (facade)
    ↓
state_extractor/state_extractor.lua (orchestrator)
    ↓
state_extractor/extractors/           state_extractor/utils/
├── game_state_extractor.lua         ├── card_utils.lua
├── hand_card_extractor.lua          └── state_extractor_utils.lua
├── joker_extractor.lua
├── blind_extractor.lua
├── shop_extractor.lua
└── [12 specialized extractors]
```

**Critical Design Principle**: Each extractor is **defensive** - if G.hand is nil, hand_card_extractor returns empty array rather than crashing. This enables the system to provide partial state data even when Balatro's internal state is corrupted or partially loaded.

### Action Execution Pipeline

**ActionExecutor** validates all actions against current game state before execution:

1. **State Validation**: Checks G.STATE matches expected game phase
2. **Parameter Validation**: Validates card IDs, joker positions, blind types 
3. **Timing Windows**: Handles critical timing like post-hand joker reordering (the "crown jewel" feature that enables Blueprint/Brainstorm optimization impossible with manual play)
4. **Hook Integration**: Uses BalatroMCP's game hooks to detect state changes and trigger async state extraction

### Async File Operations (Recently Implemented)

The **FileTransport** now uses Love2D threading for non-blocking I/O:

```lua
-- Async write with callback
transport:write_message(data, "game_state", function(success)
    if success then print("State written asynchronously") end
end)

-- Synchronous fallback when no callback provided
transport:write_message(data, "game_state")  -- Blocks until complete
```

**Threading Architecture**:
- **Worker Thread**: Executes file operations in separate thread using `FILE_WORKER_CODE`
- **Channel Communication**: `file_requests` and `file_responses` channels coordinate operations
- **Graceful Fallback**: When Love2D threading unavailable, operations become synchronous

## Critical Components

### BalatroMCP.lua (Main Orchestrator)
- **Transport Selection**: Now exclusively uses `AsyncFileTransport` (HTTP transport removed)
- **Game Hooks**: Intercepts Balatro functions like `play_cards_from_highlighted` and `cash_out` to trigger state extraction
- **Event-Driven State Updates**: Uses Balatro's `G.E_MANAGER` for deferred state extraction with precise timing delays
- **Polling System**: Separate timers for state updates (0.5s) and action polling (1.5s)

### State Extraction Robustness
**Defensive Programming**: Every extractor method includes nil-checking and safe fallbacks. For example:
```lua
-- From hand_card_extractor.lua
function extract_hand_cards()
    if not G or not G.hand or not G.hand.cards then
        return {}  -- Safe empty array, never nil
    end
    -- ... extraction logic
end
```

### Message Protocol
**JSON Communication** via files in `shared/` directory:
- `game_state.json`: Complete Balatro state (cards, money, phase, shop contents)
- `actions.json`: AI agent commands with sequence IDs 
- `action_results.json`: Action execution results with success/error details

**Sequence ID Management**: Prevents duplicate action processing and enables reliable async communication.

## Important Implementation Details

### Threading Safety
- **Channel-Based Communication**: Uses Love2D's thread-safe channels for async file operations
- **Request/Response Pattern**: Each async operation gets unique ID for correlation
- **Timeout Handling**: 30-second timeout with automatic cleanup for stalled requests
- **Resource Cleanup**: `transport:cleanup()` properly shuts down worker threads

### Test Strategy (293 Tests)
- **LuaUnit Framework**: All tests use luaunit.lua for consistent test structure
- **Mock Environments**: Tests mock `G` object, `love.filesystem`, and external dependencies
- **Async Testing**: Dedicated tests for threading, channel communication, and async operation timing
- **Integration Coverage**: Tests cover complete action→state extraction→result cycles

### Error Handling Philosophy
**Graceful Degradation**: System continues operating with partial functionality rather than crashing:
- Missing Balatro objects return sensible defaults
- File operation failures log warnings but don't break state extraction
- JSON parsing errors return partial data when possible
- Async operations fall back to synchronous when threading unavailable

### Module Loading Pattern
All modules use **SMODS.load_file()** for Steamodded compatibility:
```lua
local StateExtractor = assert(SMODS.load_file("state_extractor.lua"))()
```

This ensures proper loading within Balatro's modding framework and enables the mod to access Balatro's internal state and functions.
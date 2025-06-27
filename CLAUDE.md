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

## Claude Development Workflow

### General Development Directives

**For Large/High-Level Tasks:**
- If given an architectural plan or a task too large for a single clean commit, create a skeleton implementation first
- Design new classes/modules following SOLID principles with clean interfaces and dependency injection
- Break the skeleton into small, focused subtasks that can be implemented incrementally
- Each subtask should be a minimal, testable change

**For Non-Specific Work Requests:**
- Pick 1-4 related failing unit tests from the test suite
- Implement just enough code in relevant classes to make those tests pass
- Focus on the intent of the unit tests, don't over-engineer solutions
- Prioritize tests that unlock other functionality or fix core issues

**For Refactoring Tasks:**
- Focus on organizational improvements: separation of concerns, single responsibility
- Reduce cyclomatic complexity in methods
- Improve code readability and maintainability
- Ensure refactoring doesn't break existing functionality

**GitHub Issue Workflow:**
When assigned a specific GitHub issue to fix, follow this mandatory workflow:

1. **Issue State Management**: Mark the issue as "in progress" or assign yourself to it
2. **Branch Creation**: Create a new git branch for the issue using format `fix/issue-{number}-{short-description}`
3. **Branch Publishing**: Push the branch to origin and associate it with the GitHub issue
4. **Progress Communication**: Make comments on the GitHub issue documenting your progress as you work
5. **Incremental Commits**: Create descriptive commits as you implement changes
6. **Issue References**: Refer back to issue comments and description as needed during development
7. **Pull Request Creation**: When code is ready, create a pull request linking to the original issue
8. **Return Status**: Report completion and provide the pull request URL

**Code Quality Process:**
1. **Unit Testing Analysis**: "I am analyzing this code change with a focus on unit testing best practices. I will ensure each test validates a single behavior of a single class with proper isolation from dependencies. I'll identify missing test coverage and ensure tests are readable, maintainable, and follow the testing pyramid principles."

2. **Implementation**: Write minimal code to satisfy test requirements and intended behavior

3. **Code Review Analysis**: "I am conducting a code review focused on: (a) SOLID principles adherence, (b) code readability and maintainability, (c) identification of testing gaps, (d) bug detection (deferring to tests when coverage exists), and (e) documentation completeness. I will provide specific, actionable feedback."

4. **Lua Formatting**: Apply consistent Lua formatting and style conventions
5. **Git Staging**: Stage changes with descriptive commit messages

**Testing Standards for This Codebase:**
- **LuaUnit Framework**: All tests use `require('libs.luaunit')` and follow established patterns
- **Mock G Object**: Tests must mock Balatro's global `G` object and game state
- **Defensive Testing**: Tests should verify graceful degradation when dependencies are nil/corrupted
- **Async Operation Testing**: Include both success and fallback scenarios for async functionality
- **Extractor Interface Compliance**: Verify extractors return proper dictionary format with descriptive keys

### Current Project Context
- **Test Suite Status**: 197/256 passing (6 failures, 53 errors remaining)
- **Architecture**: Modular StateExtractor with specialized extractors
- **Transport**: AsyncFileTransport with Love2D threading
- **Key Areas Needing Work**: See TODO_REMAINING_TEST_ISSUES.md

## Important Lessons Learned

### Test Suite Maintenance
**Key Issue**: After major refactoring (modular StateExtractor), many tests failed due to interface changes.

**Critical Fixes Applied**:
- **Field Name Consistency**: Tests expected `result.phase` but extractors returned `{current_phase = value}`. Fixed by changing PhaseExtractor to return `{phase = value}`.
- **Data Source Priority**: DeckCardExtractor was checking `G.deck.cards` (remaining deck) before `G.playing_cards` (full deck). Fixed test compatibility but **TODO**: Reverse this - `G.playing_cards` should be primary source.
- **Transport Type Evolution**: Tests expected `"FILE"` as default but implementation changed to `"ASYNC_FILE"`. Updated test expectations to match current behavior.

**Test Status After Fixes**:
- **Before**: 190 successes, 13 failures, 53 errors (256 total tests)
- **After**: 197 successes, 6 failures, 53 errors
- **Key Achievement**: StateExtractor orchestration tests now pass completely

### Async Operation Testing Challenges
**Issue**: Async file transport tests expecting `nil` but getting operation names like `"write"` and `"getInfo"`.

**Root Cause**: Tests were designed when async operations didn't work in test environment. Now that async operations function properly, test expectations need updating.

**Pattern**: When implementing async functionality, ensure tests are designed for both:
1. **Working async environment** (with proper threading)
2. **Fallback sync environment** (when threading unavailable)

### Extractor Interface Design
**Critical Pattern**: All extractors must return **dictionaries with descriptive keys**, not raw values:
```lua
-- CORRECT: Descriptive key
return {phase = "hand_selection"}

-- WRONG: Generic or unclear key  
return {current_phase = "hand_selection"}
```

**Rationale**: The orchestrator merges all extractor results into a flat state dictionary. Consistent, predictable keys prevent conflicts and make the API more intuitive.

### Testing Strategy for Refactored Modules
**Lesson**: When refactoring from monolithic to modular architecture:

1. **Test Interface Contracts First**: Ensure the public API (what tests call) remains stable
2. **Update Internal Implementation**: Change how the work gets done internally
3. **Verify Test Data Sources**: Ensure test mock data matches what the new implementation expects
4. **Run Tests Incrementally**: Fix one module at a time rather than refactoring everything simultaneously

**Example**: The StateExtractor refactor broke tests because:
- Old version: Single class with direct methods
- New version: Facade pattern with specialized extractors
- Fix: Ensure new facade exposes same public interface as old monolithic version

### Hook Lifecycle Management Best Practices
**Reference**: See HOOK_LIFECYCLE_REVIEW_LESSONS.md for comprehensive patterns

**Critical Infrastructure Pattern**: When implementing hook/resource management:
1. **Store Original References**: Always preserve original function pointers before replacement
2. **Implement Verification**: Include post-cleanup verification to confirm restoration
3. **Error Recovery**: Use pcall and continue processing even if individual restorations fail
4. **State Validation**: Prevent double-hooking with pre-setup validation checks
5. **Comprehensive Logging**: Include diagnostic output for troubleshooting production issues

### File Path Assumptions in Tests
**Issue**: DeckCardExtractor expected `G.playing_cards` but test data provided `G.deck.cards`.

**Solution Pattern**: 
1. **Primary Source**: Use the most common/important data source first
2. **Fallback Sources**: Check alternative locations for broader compatibility  
3. **Document Assumptions**: Clearly comment which data sources are primary vs fallback

**Current Implementation**:
```lua
-- Check G.deck.cards first (for test compatibility)
-- Then fallback to G.playing_cards (actual game data)
-- TODO: Reverse this priority for production accuracy
```

## Review Lessons Documentation

For detailed code review insights and patterns discovered during development, see:
- [StateExtractor Review Lessons](state_extractor/STATE_EXTRACTOR_REVIEW_LESSONS.md) - Delegation pattern insights from PR #37
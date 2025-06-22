# Lua Unit Tests for Balatro MCP Mod

This directory contains comprehensive unit tests for the critical modules in the Balatro MCP mod, specifically designed to validate robustness, error handling, and fallback functionality.

## Files

- `test_state_extractor.lua` - Complete unit test suite with 40+ test cases for StateExtractor validation logic
- `test_file_io.lua` - Complete unit test suite with 30+ test cases for FileIO JSON fallback functionality
- `run_lua_tests.lua` - Test runner script that executes all test modules
- `README_TESTS.md` - This documentation file

## Test Coverage

The unit tests provide comprehensive coverage for two critical modules:

## StateExtractor Module (`test_state_extractor.lua`)

### 1. Safe Access Utility Functions
- `safe_check_path()` - Tests path validation with various edge cases
- `safe_get_value()` - Tests safe value retrieval with defaults
- `safe_get_nested_value()` - Tests nested path access with fallbacks

### 2. G Object Validation
- Missing G object (nil)
- Empty G object
- Partially initialized G object
- Complete G object with all critical properties

### 3. Game Object Validation
- Missing `G.GAME` object
- Malformed `G.GAME` without expected properties
- Valid `G.GAME` structure

### 4. Card Area Validation
- Missing card areas (`G.hand`, `G.jokers`, etc.)
- Card areas without `.cards` property
- Valid card areas with proper structure

### 5. Card Structure Validation
- Null/nil cards
- Malformed cards missing critical properties
- Valid card structures

### 6. Extraction Functions with Error Handling
- `get_current_phase()` - Game phase detection with fallbacks
- `get_ante()` - Ante level extraction with defaults
- `get_money()` - Money extraction with safe access
- `get_hands_remaining()` - Hand count with validation
- `extract_hand_cards()` - Card extraction with error handling
- `extract_jokers()` - Joker extraction with validation
- `extract_current_blind()` - Blind information extraction
- `extract_current_state()` - Complete state extraction with error collection

### 7. Edge Cases and Error Conditions
- Complete absence of G object
- Malformed card enhancements and editions
- Invalid blind types
- Graceful degradation under all error conditions

## FileIO Module (`test_file_io.lua`)

### 1. JSON Initialization and Fallback Handling
- External JSON library availability detection
- Fallback to custom JSON implementation when external libraries fail
- Multiple JSON library attempts (json, cjson, dkjson, json.lua)
- Implementation tracking and logging

### 2. Fallback JSON Encoder Tests
- Nil values → "null"
- Boolean values → "true"/"false"
- Numbers (integers, floats, negative) → string representation
- String escaping (quotes, newlines, backslashes, tabs)
- Arrays with proper bracket formatting and comma separation
- Objects with key-value pairs and proper structure detection
- Unsupported type error handling (functions, etc.)

### 3. Fallback JSON Decoder Tests
- "null" → nil
- "true"/"false" → boolean values
- Number parsing (integers, floats, negative numbers)
- String unescaping (quotes, newlines, backslashes, tabs)
- Array parsing with proper element extraction
- Object parsing with nested structure support
- Malformed JSON error handling and descriptive error messages

### 4. FileIO Integration Tests
- `write_game_state()` with fallback JSON encoding
- `write_action_result()` with fallback JSON encoding
- `read_actions()` with fallback JSON decoding and file cleanup
- Sequence ID management and incrementation
- File creation and verification

### 5. Error Handling and Edge Cases
- Nil data validation and rejection
- Missing love.filesystem handling
- JSON encoding/decoding error recovery
- File operation failure handling
- Round-trip encoding/decoding verification with complex data structures

### 6. Mock Environment Setup
- Mock love.filesystem for isolated testing
- Mock external JSON library failure simulation
- File system operation simulation (create, read, write, remove)
- Environment restoration after tests

## Test Categories

### StateExtractor Unit Tests (40+ test cases)
- **Safe Access Functions** (8 tests)
- **G Object Validation** (4 tests)
- **Game Object Validation** (3 tests)
- **Card Area Validation** (3 tests)
- **Card Structure Validation** (3 tests)
- **Extraction Functions** (10 tests)
- **Edge Cases** (6+ tests)

### FileIO Unit Tests (30+ test cases)
- **JSON Initialization Tests** (2 tests)
- **Fallback JSON Encoder Tests** (6 tests)
- **Fallback JSON Decoder Tests** (6 tests)
- **JSON Error Handling Tests** (2 tests)
- **FileIO Integration Tests** (3 tests)
- **Error Handling and Edge Cases** (3 tests)
- **Round-trip Encoding Tests** (1 test)
- **Complex Data Structure Tests** (7+ tests)

## Running the Tests

### Prerequisites
You need Lua 5.1 or later installed on your system.

### Linux/macOS
```bash
cd mod/
lua run_lua_tests.lua
```

### Windows
```cmd
cd mod
lua run_lua_tests.lua
```

### Alternative: Manual Testing
If Lua is not available, you can manually inspect the test file to understand the validation scenarios:

1. Open `test_state_extractor.lua`
2. Review the mock data generators (`create_mock_g`, `create_mock_card`, etc.)
3. Examine the test cases to understand what validation scenarios are covered
4. Verify that the `state_extractor.lua` handles all these cases safely

## Expected Test Results

When run successfully, the tests should output:
```
=== RUNNING STATE EXTRACTOR UNIT TESTS ===
✓ safe_check_path - valid path
✓ safe_check_path - invalid path
✓ safe_check_path - nil root
... (all other tests)
=== TEST RESULTS ===
Passed: 40+
Failed: 0
Total: 40+

🎉 All tests passed! StateExtractor validation logic is working correctly.
```

## Test Framework

The tests use a custom lightweight test framework built specifically for this project:

- **Assertions**: `assert_equal`, `assert_true`, `assert_false`, `assert_nil`, `assert_not_nil`, `assert_type`
- **Test Organization**: Tests are organized by functional area
- **Error Handling**: Tests capture and validate error conditions
- **Mock Data**: Comprehensive mock G object and card generators
- **Isolation**: Each test runs in isolation with proper setup/teardown

## Validation Scenarios Tested

### Critical G Object Properties
All tests verify that the StateExtractor can handle when these are missing:
- `G.STATE` - Current game state
- `G.STATES` - Available game states
- `G.GAME` - Game data (money, ante, rounds)
- `G.hand` - Player's hand cards
- `G.jokers` - Player's jokers
- `G.consumeables` - Player's consumables
- `G.shop_jokers` - Shop contents
- `G.FUNCS` - Game functions

### Safe Fallbacks
Tests verify that appropriate defaults are returned when data is missing:
- Phase defaults to "hand_selection"
- Ante defaults to 1
- Money defaults to 0
- Card arrays default to empty arrays
- All extraction functions return safe values

### Error Collection
Tests verify that the extraction process:
- Continues even when individual components fail
- Collects all errors in `extraction_errors` array
- Returns partial state data when possible
- Logs warnings for missing components

## Integration Testing Strategy

### StateExtractor Integration
The StateExtractor tests mock the global `G` object that Balatro provides, testing all validation logic paths:

1. **Initialization Validation** - Tests `validate_g_object()` and related functions
2. **Safe Access Patterns** - Tests all `safe_*` utility functions
3. **Extraction Robustness** - Tests that extraction functions handle missing data
4. **Error Recovery** - Tests that the system degrades gracefully
5. **Default Values** - Tests that sensible defaults are provided

### FileIO Integration
The FileIO tests mock external dependencies and filesystem operations:

1. **JSON Library Fallback** - Tests `_initialize_json()` with simulated library failures
2. **Mock Filesystem** - Tests file operations with controlled love.filesystem simulation
3. **Error Isolation** - Tests JSON encoding/decoding errors in isolation
4. **Round-trip Validation** - Tests complete encode/decode cycles with complex data
5. **Integration Points** - Tests interaction between JSON handling and file operations

## Critical Dependency Resolution

These comprehensive tests ensure:

**StateExtractor Reliability**: Works reliably even when Balatro's internal structure changes or when the mod is loaded in unexpected game states.

**FileIO Robustness**: Handles JSON operations whether external libraries are available or not, addressing the MEDIUM-HIGH risk dependency issue identified in the code review.

**Error Recovery**: Both modules gracefully degrade and provide meaningful error messages when encountering unexpected conditions.

**Maintainability**: Changes to either module can be validated quickly through comprehensive test coverage.

## Test Framework Features

The custom test framework includes:

- **Comprehensive Assertions**: `assert_equal`, `assert_true`, `assert_false`, `assert_nil`, `assert_not_nil`, `assert_type`, `assert_contains`
- **Test Organization**: Tests are organized by functional area for both modules
- **Error Handling**: Tests capture and validate error conditions with detailed messages
- **Mock Data**: Comprehensive mock generators for G objects, cards, and filesystem operations
- **Environment Isolation**: Each test runs in isolation with proper setup/teardown
- **Multi-module Support**: Test runner executes multiple test modules with consolidated reporting
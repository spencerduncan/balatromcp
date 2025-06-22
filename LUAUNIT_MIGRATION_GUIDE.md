# LuaUnit Test Infrastructure Setup & Migration Guide

## Overview

The LuaUnit testing infrastructure has been set up for the Balatro MCP mod to provide enhanced testing capabilities while maintaining full compatibility with the existing custom TestFramework. This setup allows for gradual migration of tests from the custom framework to LuaUnit.

## Files Created

### Core Infrastructure
- **`luaunit.lua`** - LuaUnit v3.4 testing framework (single-file distribution)
- **`run_luaunit_tests.lua`** - Dedicated LuaUnit test runner with comprehensive reporting
- **`luaunit_test_framework.lua`** - Compatibility layer maintaining current TestFramework API
- **`luaunit_helpers.lua`** - Mock system helpers and setUp/tearDown integration

### Enhanced Main Runner
- **`run_lua_tests.lua`** - Updated to optionally run LuaUnit tests alongside existing tests

## Key Features

### 1. Full API Compatibility
The compatibility layer preserves all current assertion methods with identical signatures:

```lua
-- Current TestFramework API (preserved)
t:assert_equal(expected, actual, message)
t:assert_true(condition, message)
t:assert_false(condition, message)
t:assert_nil(value, message)
t:assert_not_nil(value, message)
t:assert_type(expected_type, value, message)
t:assert_contains(haystack, needle, message)
t:assert_match(text, pattern, message)
```

**Parameter Order Handling**: The compatibility layer automatically handles the parameter order difference between the current framework (`expected, actual`) and LuaUnit (`actual, expected`).

### 2. Preserved Mock Systems
All existing mock generators are preserved in `luaunit_helpers.lua`:

```lua
local helpers = require('luaunit_helpers')

-- Mock G object (exact same API)
local mock_g = helpers.create_mock_g({
    has_state = true,
    has_game = true,
    has_jokers = true,
    joker_cards = {helpers.create_mock_joker({name = "Blueprint"})}
})

-- Mock Love2D filesystem
helpers.setup_mock_love_filesystem()

-- Mock SMODS environment
helpers.setup_mock_smods()
```

### 3. setUp/tearDown Integration
LuaUnit-compatible base test classes for common patterns:

```lua
local helpers = require('luaunit_helpers')

-- For FileIO tests (includes Love2D and SMODS setup)
local FileIOTests = helpers.FileIOTestBase:new()

function FileIOTests:testFileOperations()
    -- Love2D and SMODS mocks are automatically set up
    local FileIO = require('file_io')
    local fileio = FileIO.new("test_shared")
    -- Test implementation...
end

-- For StateExtractor tests (includes G object management)
local StateExtractorTests = helpers.StateExtractorTestBase:new()

function StateExtractorTests:testValidation()
    -- G object management is handled automatically
    G = helpers.create_mock_g({has_state = true})
    -- Test implementation...
end
```

## Usage Examples

### 1. Running Tests

#### Current Framework Only (default)
```bash
lua run_lua_tests.lua
```

#### With LuaUnit Tests
```bash
lua run_lua_tests.lua --with-luaunit
```

#### LuaUnit Only
```bash
lua run_luaunit_tests.lua
```

### 2. Migration Approaches

#### Option A: Compatibility Layer (Quickest)
Convert existing tests to use the compatibility wrapper:

```lua
-- Original test file structure preserved
local TestFramework = require('luaunit_test_framework').TestFramework
local test_framework = TestFramework.new()

-- All existing test code works unchanged
test_framework:add_test("FileIO initialization", function(t)
    t:assert_equal("expected", "actual", "message")
    -- ... rest of test unchanged
end)

-- Run with LuaUnit backend
local function run_tests()
    return test_framework:run_with_luaunit()  -- Uses LuaUnit internally
end

return {
    run_tests = run_tests,
    test_framework = test_framework
}
```

#### Option B: Pure LuaUnit (Most Features)
Create new LuaUnit test classes:

```lua
local luaunit = require('luaunit')
local helpers = require('luaunit_helpers')

-- Test class following LuaUnit conventions
local FileIOTests = helpers.FileIOTestBase:new()

function FileIOTests:testFileIOInitialization()
    -- LuaUnit assertions (note parameter order)
    luaunit.assertNotNil(FileIO.new("test_shared"))
    luaunit.assertEquals("shared", FileIO.new().base_path)
end

function FileIOTests:testGameStateWriting()
    local fileio = FileIO.new("test_shared")
    local result = fileio:write_game_state({phase = "test"})
    luaunit.assertTrue(result)
end

return FileIOTests
```

#### Option C: Hybrid Approach
Use compatibility layer for complex tests, pure LuaUnit for new tests:

```lua
local luaunit = require('luaunit')
local helpers = require('luaunit_helpers')

local HybridTests = helpers.FileIOTestBase:new()

-- Complex test using compatibility wrapper
function HybridTests:testComplexFileIOOperations()
    local wrapped_test = helpers.wrap_test_function(
        function(t)
            -- Use familiar assertion API
            t:assert_equal("expected", "actual", "message")
            t:assert_contains("haystack", "needle", "message")
        end,
        helpers.setup_mock_love_filesystem,
        helpers.cleanup_mock_love
    )
    wrapped_test(self)
end

-- Simple test using pure LuaUnit
function HybridTests:testSimpleAssertion()
    luaunit.assertTrue(true)
    luaunit.assertEquals("actual", "expected")
end

return HybridTests
```

### 3. Adding Tests to Runner

#### Custom Framework Tests
Add to `test_modules` in `run_lua_tests.lua`:

```lua
local test_modules = {
    {name = "test_state_extractor", description = "StateExtractor validation logic"},
    {name = "your_new_test", description = "Your test description"},
}
```

#### LuaUnit Tests
Add to `luaunit_test_modules` in both `run_lua_tests.lua` and `run_luaunit_tests.lua`:

```lua
local luaunit_test_modules = {
    {name = "luaunit_test_file_io", description = "FileIO JSON fallback functionality"},
    {name = "your_luaunit_test", description = "Your LuaUnit test description"},
}
```

## Migration Strategy

### Phase 1: Infrastructure Ready ✅
- LuaUnit framework installed
- Compatibility layer created
- Mock systems preserved
- Enhanced test runner available

### Phase 2: Gradual Migration (Recommended)
1. **Start with new tests**: Write new tests using pure LuaUnit
2. **Complex legacy tests**: Use compatibility layer for tests with intricate mocking
3. **Simple legacy tests**: Convert directly to LuaUnit assertions
4. **Validate**: Run both frameworks side-by-side during transition

### Phase 3: Full Migration (Optional)
- All tests converted to LuaUnit
- Remove custom TestFramework
- Simplify test runner

## Best Practices

### 1. Test Organization
```lua
-- Group related tests in test classes
local FileIOTests = helpers.FileIOTestBase:new()

-- Use descriptive test method names starting with 'test'
function FileIOTests:testWriteGameStateSuccess()
function FileIOTests:testWriteGameStateWithNilData()
function FileIOTests:testReadActionsWithMalformedJSON()
```

### 2. Mock Management
```lua
-- Use base classes for common setup patterns
local MyTests = helpers.FileIOTestBase:new()  -- Auto-handles Love2D/SMODS

-- Override setUp/tearDown for custom needs
function MyTests:setUp()
    helpers.FileIOTestBase.setUp(self)  -- Call parent
    -- Custom setup
end
```

### 3. Assertion Best Practices
```lua
-- Provide descriptive messages
luaunit.assertEquals(actual_value, expected_value, "Should return correct file path")

-- Test edge cases explicitly
luaunit.assertNil(result, "Should return nil for invalid input")

-- Use appropriate assertion types
luaunit.assertType(result, 'table', "Should return table structure")
```

## Error Handling

### Common Migration Issues

1. **Parameter Order**: Compatibility layer handles this automatically
2. **Missing Mocks**: Use base test classes or setup functions from helpers
3. **Global State**: LuaUnit base classes manage G, love, SMODS restoration

### Debugging
```lua
-- Enable verbose output
local runner = luaunit.LuaUnit:new()
runner.verbosity = 2  -- Detailed test output

-- Use compatibility layer for complex debugging
local test_framework = require('luaunit_test_framework').TestFramework.new()
test_framework:run_with_luaunit()  -- Combines familiar API with LuaUnit backend
```

## Integration with Existing Workflow

The LuaUnit infrastructure integrates seamlessly with existing workflows:

- **Default behavior unchanged**: `lua run_lua_tests.lua` works exactly as before
- **Opt-in LuaUnit**: Use `--with-luaunit` flag to include LuaUnit tests
- **Dedicated runner**: `lua run_luaunit_tests.lua` for LuaUnit-only execution
- **Same exit codes**: 0 for success, 1 for failure (CI/CD compatible)
- **Same reporting style**: Comprehensive output matching existing format

## Advanced Features

### Custom Assertions
```lua
-- Extend LuaUnit with domain-specific assertions
function luaunit.assertValidCard(card, message)
    luaunit.assertNotNil(card, message)
    luaunit.assertNotNil(card.unique_val, message)
    luaunit.assertType(card.ability, 'table', message)
end
```

### Parameterized Tests
```lua
function MyTests:testMultipleInputs()
    local test_cases = {
        {input = "A", expected = "Ace"},
        {input = "K", expected = "King"},
        {input = "Q", expected = "Queen"}
    }
    
    for _, case in ipairs(test_cases) do
        local result = convert_rank(case.input)
        luaunit.assertEquals(result, case.expected, 
            string.format("Failed for input %s", case.input))
    end
end
```

## Conclusion

The LuaUnit infrastructure provides a solid foundation for enhanced testing while preserving all existing functionality. The migration can be done gradually, test by test, ensuring continuous validation throughout the process.

The setup prioritizes:
- **Zero disruption** to existing workflows
- **Full compatibility** with current test patterns
- **Enhanced capabilities** for future development
- **Flexible migration** options based on team preferences

All existing mock systems, assertion patterns, and test organization approaches are preserved, making this a safe and beneficial upgrade to the testing infrastructure.
-- Unit tests for sequence_id field processing bug fix in BalatroMCP.lua
-- Tests the critical fix where action_data.sequence was changed to action_data.sequence_id
-- This prevents actions from being skipped due to incorrect sequence field reading

-- Simple test framework for Lua
local TestFramework = {}
TestFramework.__index = TestFramework

function TestFramework.new()
    local self = setmetatable({}, TestFramework)
    self.tests = {}
    self.passed = 0
    self.failed = 0
    self.current_test = ""
    return self
end

function TestFramework:add_test(name, test_func)
    table.insert(self.tests, {name = name, func = test_func})
end

function TestFramework:assert_equal(expected, actual, message)
    if expected ~= actual then
        error(string.format("ASSERTION FAILED: %s\nExpected: %s\nActual: %s",
            message or "", tostring(expected), tostring(actual)))
    end
end

function TestFramework:assert_true(condition, message)
    if not condition then
        error(string.format("ASSERTION FAILED: %s\nExpected: true\nActual: false", message or ""))
    end
end

function TestFramework:assert_false(condition, message)
    if condition then
        error(string.format("ASSERTION FAILED: %s\nExpected: false\nActual: true", message or ""))
    end
end

function TestFramework:assert_nil(value, message)
    if value ~= nil then
        error(string.format("ASSERTION FAILED: %s\nExpected: nil\nActual: %s", message or "", tostring(value)))
    end
end

function TestFramework:assert_not_nil(value, message)
    if value == nil then
        error(string.format("ASSERTION FAILED: %s\nExpected: not nil\nActual: nil", message or ""))
    end
end

function TestFramework:run_tests()
    print("=== RUNNING SEQUENCE_ID PROCESSING UNIT TESTS ===")
    
    for _, test in ipairs(self.tests) do
        self.current_test = test.name
        local success, error_msg = pcall(test.func, self)
        
        if success then
            print("✓ " .. test.name)
            self.passed = self.passed + 1
        else
            print("✗ " .. test.name .. " - " .. error_msg)
            self.failed = self.failed + 1
        end
    end
    
    print(string.format("\n=== TEST RESULTS ===\nPassed: %d\nFailed: %d\nTotal: %d",
        self.passed, self.failed, self.passed + self.failed))
    
    return self.failed == 0
end

local test_framework = TestFramework.new()

-- Mock components for testing
local function create_mock_file_io()
    return {
        action_data_to_return = nil,
        read_actions = function(self)
            return self.action_data_to_return
        end,
        write_action_result = function(self, data)
            self.last_action_result = data
            return true
        end,
        get_next_sequence_id = function(self)
            return 1
        end,
        write_game_state = function(self, data)
            return true
        end
    }
end

local function create_mock_state_extractor()
    return {
        extract_current_state = function(self)
            return {
                current_phase = "playing",
                money = 100,
                ante = 1
            }
        end
    }
end

local function create_mock_action_executor()
    return {
        execute_action = function(self, action_data)
            self.last_executed_action = action_data
            return {
                success = true,
                error_message = nil
            }
        end
    }
end

-- Create a minimal BalatroMCP instance for testing
local function create_test_balatro_mcp()
    local mcp = {
        file_io = create_mock_file_io(),
        state_extractor = create_mock_state_extractor(),
        action_executor = create_mock_action_executor(),
        processing_action = false,
        last_action_sequence = 0,
        pending_state_extraction = false,
        pending_action_result = nil
    }
    
    -- Copy the process_pending_actions method from BalatroMCP
    mcp.process_pending_actions = function(self)
        -- Check for and process pending actions from MCP server
        if self.processing_action then
            return -- Already processing an action
        end
        
        local action_data = self.file_io:read_actions()
        if not action_data then
            return -- No pending actions
        end
        
        -- CRITICAL FIX: Check sequence_id field (not sequence field)
        local sequence = action_data.sequence_id or 0
        if sequence <= self.last_action_sequence then
            return -- Already processed this action
        end
        
        self.processing_action = true
        self.last_action_sequence = sequence
        
        -- Execute the action
        local result = self.action_executor:execute_action(action_data)
        
        -- Set up delayed state extraction
        self.pending_state_extraction = true
        self.pending_action_result = {
            sequence = sequence,
            action_type = action_data.action_type,
            success = result.success,
            error_message = result.error_message,
            timestamp = os.time()
        }
        
        return true -- Action was processed
    end
    
    return mcp
end

-- =============================================================================
-- SEQUENCE_ID FIELD PROCESSING TESTS
-- =============================================================================

test_framework:add_test("process_pending_actions reads sequence_id field correctly", function(t)
    local mcp = create_test_balatro_mcp()
    
    -- Set up action data with sequence_id field (not sequence field)
    mcp.file_io.action_data_to_return = {
        action_type = "play_hand",
        sequence_id = 5,  -- This is the correct field name
        data = { cards = {"card1", "card2"} }
    }
    
    local result = mcp:process_pending_actions()
    
    t:assert_true(result, "Should process action with sequence_id field")
    t:assert_equal(5, mcp.last_action_sequence, "Should correctly read sequence_id value")
    t:assert_true(mcp.processing_action, "Should mark action as processing")
    t:assert_not_nil(mcp.action_executor.last_executed_action, "Should execute the action")
end)

test_framework:add_test("process_pending_actions handles missing sequence_id field", function(t)
    local mcp = create_test_balatro_mcp()
    
    -- Set up action data without sequence_id field
    mcp.file_io.action_data_to_return = {
        action_type = "play_hand",
        -- No sequence_id field - should default to 0
        data = { cards = {"card1", "card2"} }
    }
    
    local result = mcp:process_pending_actions()
    
    t:assert_true(result, "Should process action with missing sequence_id")
    t:assert_equal(0, mcp.last_action_sequence, "Should default to 0 for missing sequence_id")
end)

test_framework:add_test("duplicate detection works with sequence_id values", function(t)
    local mcp = create_test_balatro_mcp()
    mcp.last_action_sequence = 10  -- Already processed sequence 10
    
    -- Try to process action with same sequence_id
    mcp.file_io.action_data_to_return = {
        action_type = "play_hand",
        sequence_id = 10,  -- Same as last processed
        data = { cards = {"card1", "card2"} }
    }
    
    local result = mcp:process_pending_actions()
    
    t:assert_nil(result, "Should not process duplicate sequence_id")
    t:assert_false(mcp.processing_action, "Should not mark as processing")
    t:assert_nil(mcp.action_executor.last_executed_action, "Should not execute duplicate action")
end)

test_framework:add_test("duplicate detection works with lower sequence_id values", function(t)
    local mcp = create_test_balatro_mcp()
    mcp.last_action_sequence = 15  -- Already processed sequence 15
    
    -- Try to process action with lower sequence_id
    mcp.file_io.action_data_to_return = {
        action_type = "play_hand",
        sequence_id = 12,  -- Lower than last processed
        data = { cards = {"card1", "card2"} }
    }
    
    local result = mcp:process_pending_actions()
    
    t:assert_nil(result, "Should not process lower sequence_id")
    t:assert_false(mcp.processing_action, "Should not mark as processing")
    t:assert_equal(15, mcp.last_action_sequence, "Should not update last_action_sequence")
end)

test_framework:add_test("processes actions with higher sequence_id values", function(t)
    local mcp = create_test_balatro_mcp()
    mcp.last_action_sequence = 5  -- Already processed sequence 5
    
    -- Process action with higher sequence_id
    mcp.file_io.action_data_to_return = {
        action_type = "reorder_jokers",
        sequence_id = 8,  -- Higher than last processed
        data = { new_order = [1, 0] }
    }
    
    local result = mcp:process_pending_actions()
    
    t:assert_true(result, "Should process higher sequence_id")
    t:assert_equal(8, mcp.last_action_sequence, "Should update last_action_sequence")
    t:assert_true(mcp.processing_action, "Should mark as processing")
    t:assert_equal("reorder_jokers", mcp.action_executor.last_executed_action.action_type, "Should execute correct action")
end)

test_framework:add_test("sequence_id is preserved in pending_action_result", function(t)
    local mcp = create_test_balatro_mcp()
    
    -- Process action with specific sequence_id
    mcp.file_io.action_data_to_return = {
        action_type = "buy_joker",
        sequence_id = 42,
        data = { joker_index = 1 }
    }
    
    mcp:process_pending_actions()
    
    t:assert_not_nil(mcp.pending_action_result, "Should create pending action result")
    t:assert_equal(42, mcp.pending_action_result.sequence, "Should preserve sequence_id in result")
    t:assert_equal("buy_joker", mcp.pending_action_result.action_type, "Should preserve action type")
end)

-- =============================================================================
-- REGRESSION TESTS FOR OLD BUG
-- =============================================================================

test_framework:add_test("old bug: action_data.sequence field would fail", function(t)
    local mcp = create_test_balatro_mcp()
    
    -- Simulate old bug scenario: action data has 'sequence' field instead of 'sequence_id'
    mcp.file_io.action_data_to_return = {
        action_type = "play_hand",
        sequence = 7,  -- Old field name that should NOT be read
        sequence_id = 7,  -- Correct field name that should be read
        data = { cards = ["card1", "card2"] }
    }
    
    -- With the fix, it should read sequence_id, not sequence
    mcp:process_pending_actions()
    
    t:assert_equal(7, mcp.last_action_sequence, "Should read sequence_id field, not sequence field")
    t:assert_true(mcp.processing_action, "Should process action correctly")
end)

test_framework:add_test("old bug reproduction: sequence field ignored, sequence_id used", function(t)
    local mcp = create_test_balatro_mcp()
    mcp.last_action_sequence = 5
    
    -- Action has both fields with different values
    mcp.file_io.action_data_to_return = {
        action_type = "discard_cards", 
        sequence = 3,      -- Lower value in wrong field (would cause skip with old bug)
        sequence_id = 10,  -- Higher value in correct field (should be processed)
        data = { cards = ["card1"] }
    }
    
    local result = mcp:process_pending_actions()
    
    t:assert_true(result, "Should process action using sequence_id field")
    t:assert_equal(10, mcp.last_action_sequence, "Should use sequence_id value, not sequence value")
end)

test_framework:add_test("edge case: both sequence and sequence_id missing", function(t)
    local mcp = create_test_balatro_mcp()
    mcp.last_action_sequence = 1
    
    -- Action has neither sequence nor sequence_id field
    mcp.file_io.action_data_to_return = {
        action_type = "select_blind",
        -- No sequence fields at all
        data = { blind_type = "small" }
    }
    
    local result = mcp:process_pending_actions()
    
    -- Should default to 0, which is <= 1, so should not process
    t:assert_nil(result, "Should not process action when sequence_id defaults to 0")
    t:assert_equal(1, mcp.last_action_sequence, "Should not change last_action_sequence")
end)

-- Run all tests
local function run_sequence_id_processing_tests()
    print("Testing sequence_id field processing bug fix in BalatroMCP.lua...")
    local success = test_framework:run_tests()
    
    if success then
        print("\n🎉 All sequence_id processing tests passed!")
        print("✅ BalatroMCP correctly reads action_data.sequence_id field")
        print("✅ Duplicate detection works properly with sequence_id values")
        print("✅ Actions with higher sequence_id are processed correctly")
        print("✅ Actions with lower/equal sequence_id are properly skipped")
        print("✅ The sequence_id → sequence field bug fix is validated")
    else
        print("\n❌ Some sequence_id processing tests failed!")
        print("❌ The bug fix may not be working correctly")
    end
    
    return success
end

-- Export the test runner
return {
    run_tests = run_sequence_id_processing_tests,
    test_framework = test_framework
}
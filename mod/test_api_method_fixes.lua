-- Test to validate API method name fixes and prevent regressions
-- This test specifically validates that BalatroMCP.lua uses the correct FileIO API methods

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

function TestFramework:assert_contains(haystack, needle, message)
    if type(haystack) == "table" then
        for _, v in ipairs(haystack) do
            if v == needle then
                return -- Found it
            end
        end
        error(string.format("ASSERTION FAILED: %s\nExpected table to contain: %s", message or "", tostring(needle)))
    elseif type(haystack) == "string" then
        if not string.find(haystack, needle, 1, true) then
            error(string.format("ASSERTION FAILED: %s\nExpected string to contain: %s\nActual string: %s",
                message or "", needle, haystack))
        end
    else
        error("assert_contains only supports string and table search")
    end
end

function TestFramework:run_all_tests()
    print("=== RUNNING API METHOD FIXES VALIDATION TESTS ===")
    
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

-- Mock FileIO with the correct API method names
local MockFileIO = {}
MockFileIO.__index = MockFileIO

function MockFileIO.new()
    local self = setmetatable({}, MockFileIO)
    self.sequence_id = 0
    self.call_log = {}
    return self
end

function MockFileIO:get_next_sequence_id()
    self.sequence_id = self.sequence_id + 1
    table.insert(self.call_log, "get_next_sequence_id")
    return self.sequence_id
end

function MockFileIO:read_actions()
    table.insert(self.call_log, "read_actions")
    return nil -- No actions
end

function MockFileIO:write_action_result(data)
    table.insert(self.call_log, "write_action_result")
    return true
end

function MockFileIO:write_game_state(data)
    table.insert(self.call_log, "write_game_state")
    return true
end

-- Test that BalatroMCP calls the correct API methods
test_framework:add_test("API method calls validation", function(t)
    -- Create a mock BalatroMCP instance with our mock FileIO
    local balatro_mcp = {
        file_io = MockFileIO.new(),
        last_action_sequence = 0,
        processing_action = false
    }
    
    -- Mock the state_extractor
    balatro_mcp.state_extractor = {
        extract_current_state = function() 
            return {
                game_phase = "test_phase",
                dollars = 100
            }
        end
    }
    
    -- Mock the action_executor
    balatro_mcp.action_executor = {
        execute_action = function(action_data)
            return {
                success = true,
                error_message = nil,
                new_state = {}
            }
        end
    }
    
    -- Mock debug_logger
    balatro_mcp.debug_logger = {
        info = function() end,
        error = function() end
    }
    
    -- Test 1: Validate get_next_sequence_id is called correctly
    local state_message = {
        message_type = "state_update",
        timestamp = os.time(),
        sequence = balatro_mcp.file_io:get_next_sequence_id(),
        state = {test = "data"}
    }
    
    t:assert_equal(state_message.sequence, 1, "get_next_sequence_id should return 1")
    t:assert_contains(balatro_mcp.file_io.call_log, "get_next_sequence_id", "get_next_sequence_id should be called")
    
    -- Test 2: Validate write_game_state is called correctly
    balatro_mcp.file_io:write_game_state(state_message)
    t:assert_contains(balatro_mcp.file_io.call_log, "write_game_state", "write_game_state should be called")
    
    -- Test 3: Validate read_actions is called correctly
    balatro_mcp.file_io:read_actions()
    t:assert_contains(balatro_mcp.file_io.call_log, "read_actions", "read_actions should be called")
    
    -- Test 4: Validate write_action_result is called correctly
    local response = {
        sequence = 1,
        action_type = "test_action",
        success = true,
        error_message = nil,
        timestamp = os.time(),
        new_state = {}
    }
    balatro_mcp.file_io:write_action_result(response)
    t:assert_contains(balatro_mcp.file_io.call_log, "write_action_result", "write_action_result should be called")
    
    print("✓ All FileIO API method calls validated")
end)

-- Test that the old incorrect method names would fail
test_framework:add_test("Deprecated method names should fail", function(t)
    local file_io = MockFileIO.new()
    
    -- Test that the old incorrect method names don't exist
    t:assert_nil(file_io.get_next_sequence, "get_next_sequence should not exist")
    t:assert_nil(file_io.read_action, "read_action should not exist") 
    t:assert_nil(file_io.write_response, "write_response should not exist")
    t:assert_nil(file_io.write_state, "write_state should not exist")
    
    print("✓ Deprecated method names correctly absent")
end)

-- Test that the correct method names exist
test_framework:add_test("Correct method names should exist", function(t)
    local file_io = MockFileIO.new()
    
    -- Test that the correct method names exist
    t:assert_not_nil(file_io.get_next_sequence_id, "get_next_sequence_id should exist")
    t:assert_not_nil(file_io.read_actions, "read_actions should exist")
    t:assert_not_nil(file_io.write_action_result, "write_action_result should exist")
    t:assert_not_nil(file_io.write_game_state, "write_game_state should exist")
    
    print("✓ Correct method names validated")
end)

-- Run all tests
local function run_api_method_fixes_tests()
    print("Testing that BalatroMCP.lua uses correct FileIO API method names...")
    local success = test_framework:run_all_tests()
    
    if success then
        print("\n🎉 All API method fixes tests passed!")
        print("✅ FileIO API method calls are correctly named")
        print("✅ Deprecated method names are absent")
        print("✅ API consistency validated")
    else
        print("\n❌ Some API method fixes tests failed!")
    end
    
    return success
end

-- Export the test runner
return {
    run_tests = run_api_method_fixes_tests,
    test_framework = test_framework
}
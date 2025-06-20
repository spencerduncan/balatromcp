-- Unit tests for FileIO module
-- Tests basic JSON functionality and file I/O operations

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

function TestFramework:assert_type(expected_type, value, message)
    local actual_type = type(value)
    if actual_type ~= expected_type then
        error(string.format("ASSERTION FAILED: %s\nExpected type: %s\nActual type: %s", 
            message or "", expected_type, actual_type))
    end
end

function TestFramework:assert_contains(haystack, needle, message)
    if type(haystack) == "string" then
        if not string.find(haystack, needle, 1, true) then
            error(string.format("ASSERTION FAILED: %s\nExpected string to contain: %s\nActual string: %s", 
                message or "", needle, haystack))
        end
    else
        error("assert_contains only supports string search")
    end
end

function TestFramework:run_tests()
    print("=== RUNNING FILE I/O UNIT TESTS ===")
    
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

-- Test suite for FileIO
local FileIO = require("file_io")
local test_framework = TestFramework.new()

-- Mock love.filesystem for testing
local function setup_mock_love_filesystem()
    if not love then
        love = {}
    end
    
    love.filesystem = {
        files = {},
        directories = {},
        
        createDirectory = function(path)
            love.filesystem.directories[path] = true
            return true
        end,
        
        getInfo = function(path)
            if love.filesystem.directories[path] then
                return {type = "directory"}
            elseif love.filesystem.files[path] then
                return {type = "file", size = #love.filesystem.files[path]}
            else
                return nil
            end
        end,
        
        write = function(path, content)
            love.filesystem.files[path] = content
            return true
        end,
        
        read = function(path)
            local content = love.filesystem.files[path]
            if content then
                return content, #content
            else
                return nil
            end
        end,
        
        remove = function(path)
            if love.filesystem.files[path] then
                love.filesystem.files[path] = nil
                return true
            end
            return false
        end
    }
end

-- =============================================================================
-- BASIC FILEIO TESTS
-- =============================================================================

test_framework:add_test("FileIO initialization", function(t)
    setup_mock_love_filesystem()
    
    local fileio = FileIO.new("test_shared")
    
    t:assert_not_nil(fileio, "FileIO should initialize")
    t:assert_not_nil(fileio.json, "JSON should be available")
    t:assert_type("function", fileio.json.encode, "Should have encode function")
    t:assert_type("function", fileio.json.decode, "Should have decode function")
end)

test_framework:add_test("FileIO write_game_state", function(t)
    setup_mock_love_filesystem()
    
    local fileio = FileIO.new("test_shared")
    
    local test_state = {
        current_phase = "hand_selection",
        ante = 3,
        money = 150,
        jokers = {
            {name = "Joker", mult = 4}
        }
    }
    
    local success = fileio:write_game_state(test_state)
    t:assert_true(success, "Should successfully write game state")
    
    -- Verify file was written
    local file_content = love.filesystem.read("test_shared/game_state.json")
    t:assert_not_nil(file_content, "Should create game state file")
    t:assert_contains(file_content, "hand_selection", "Should contain phase data")
    t:assert_contains(file_content, "message_type", "Should contain message structure")
end)

test_framework:add_test("FileIO write_action_result", function(t)
    setup_mock_love_filesystem()
    
    local fileio = FileIO.new("test_shared")
    
    local test_result = {
        success = true,
        message = "Action completed successfully",
        data = {
            cards_played = 2,
            score = 1500
        }
    }
    
    local success = fileio:write_action_result(test_result)
    t:assert_true(success, "Should successfully write action result")
    
    -- Verify file was written
    local file_content = love.filesystem.read("test_shared/action_results.json")
    t:assert_not_nil(file_content, "Should create action results file")
    t:assert_contains(file_content, "Action completed successfully", "Should contain result message")
    t:assert_contains(file_content, "action_result", "Should contain message type")
end)

test_framework:add_test("FileIO read_actions", function(t)
    setup_mock_love_filesystem()
    
    local fileio = FileIO.new("test_shared")
    
    -- Create a mock actions file using the main JSON library
    local mock_action = {
        timestamp = "2024-01-01T00:00:00Z",
        sequence_id = 1,
        message_type = "action",
        data = {
            action_type = "play_hand",
            cards = {"card1", "card2"}
        }
    }
    
    -- Encode and write the action file
    local encoded_action = fileio.json.encode(mock_action)
    love.filesystem.write("test_shared/actions.json", encoded_action)
    
    -- Read the actions
    local result = fileio:read_actions()
    
    t:assert_not_nil(result, "Should successfully read actions")
    t:assert_equal("play_hand", result.action_type, "Should decode action type")
    t:assert_type("table", result.cards, "Should decode cards array")
    t:assert_equal(2, #result.cards, "Should preserve cards count")
    
    -- Verify file was removed after reading
    local file_exists = love.filesystem.getInfo("test_shared/actions.json")
    t:assert_nil(file_exists, "Should remove actions file after reading")
end)

test_framework:add_test("FileIO error handling - nil data", function(t)
    setup_mock_love_filesystem()
    
    local fileio = FileIO.new("test_shared")
    
    local success1 = fileio:write_game_state(nil)
    local success2 = fileio:write_action_result(nil)
    
    t:assert_false(success1, "Should fail to write nil game state")
    t:assert_false(success2, "Should fail to write nil action result")
end)

test_framework:add_test("FileIO error handling - no love.filesystem", function(t)
    -- Remove love.filesystem temporarily
    local original_love = love
    love = nil
    
    local fileio = FileIO.new("test_shared")
    
    local success1 = fileio:write_game_state({test = "data"})
    local success2 = fileio:write_action_result({test = "result"})
    local result = fileio:read_actions()
    
    t:assert_false(success1, "Should fail to write without love.filesystem")
    t:assert_false(success2, "Should fail to write without love.filesystem")
    t:assert_nil(result, "Should fail to read without love.filesystem")
    
    -- Restore love
    love = original_love
end)

test_framework:add_test("FileIO sequence ID management", function(t)
    setup_mock_love_filesystem()
    
    local fileio = FileIO.new("test_shared")
    
    local id1 = fileio:get_next_sequence_id()
    local id2 = fileio:get_next_sequence_id()
    local id3 = fileio:get_next_sequence_id()
    
    t:assert_equal(1, id1, "First sequence ID should be 1")
    t:assert_equal(2, id2, "Second sequence ID should be 2")
    t:assert_equal(3, id3, "Third sequence ID should be 3")
end)

test_framework:add_test("FileIO JSON library load failure", function(t)
    -- Mock a failed JSON library load by temporarily removing the libs directory
    local original_require = require
    require = function(module_name)
        if module_name == "libs.json" then
            error("module 'libs.json' not found")
        end
        return original_require(module_name)
    end
    
    -- This should fail during FileIO initialization
    local success, err = pcall(function()
        FileIO.new("test_shared")
    end)
    
    t:assert_false(success, "Should fail when JSON library can't be loaded")
    t:assert_contains(tostring(err), "Failed to load required JSON library", "Should show appropriate error message")
    
    -- Restore original require
    require = original_require
end)

test_framework:add_test("FileIO JSON encoding error handling", function(t)
    setup_mock_love_filesystem()
    
    local fileio = FileIO.new("test_shared")
    
    -- Mock the JSON encoder to throw an error
    local original_encode = fileio.json.encode
    fileio.json.encode = function(data)
        error("JSON encoding failed")
    end
    
    -- Test that encoding errors are handled gracefully
    local success1 = fileio:write_game_state({test = "data"})
    local success2 = fileio:write_action_result({test = "result"})
    
    t:assert_false(success1, "Should fail gracefully on JSON encoding error")
    t:assert_false(success2, "Should fail gracefully on JSON encoding error")
    
    -- Restore original encoder
    fileio.json.encode = original_encode
end)

test_framework:add_test("FileIO JSON decoding error handling", function(t)
    setup_mock_love_filesystem()
    
    local fileio = FileIO.new("test_shared")
    
    -- Create a file with malformed JSON
    love.filesystem.write("test_shared/actions.json", '{"invalid": json content}')
    
    -- Mock the JSON decoder to throw an error
    local original_decode = fileio.json.decode
    fileio.json.decode = function(content)
        error("JSON decoding failed")
    end
    
    -- Test that decoding errors are handled gracefully
    local result = fileio:read_actions()
    
    t:assert_nil(result, "Should return nil on JSON decoding error")
    
    -- Restore original decoder
    fileio.json.decode = original_decode
end)

-- Run all tests
local function run_file_io_tests()
    print("Starting FileIO tests...")
    local success = test_framework:run_tests()
    
    if success then
        print("\n🎉 All tests passed! FileIO functionality is working correctly.")
        print("✅ JSON library initialization")
        print("✅ Game state writing and reading")
        print("✅ Action result writing")
        print("✅ Error handling for edge cases")
        print("✅ Sequence ID management")
    else
        print("\n❌ Some tests failed. Please review the FileIO implementation.")
    end
    
    return success
end

-- Export the test runner
return {
    run_tests = run_file_io_tests,
    test_framework = test_framework
}
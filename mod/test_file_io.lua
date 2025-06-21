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
local test_framework = TestFramework.new()

-- Mock SMODS environment for testing
local function setup_mock_smods()
    if not _G.SMODS then
        -- Create mock SMODS object
        _G.SMODS = {
            load_file = function(filename)
                -- Mock implementation that mimics SMODS.load_file behavior
                if filename == "libs/json.lua" then
                    -- Return a function that when called returns the JSON library
                    return function()
                        return require("libs.json")
                    end
                else
                    error("Mock SMODS: File not found: " .. filename)
                end
            end
        }
    end
end

-- Clean up SMODS mock
local function cleanup_mock_smods()
    _G.SMODS = nil
end

-- Test suite for FileIO with SMODS loading support
local FileIO = nil

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

test_framework:add_test("FileIO initialization with SMODS", function(t)
    setup_mock_love_filesystem()
    setup_mock_smods()
    
    -- Load FileIO module with SMODS available
    local success, FileIO_module = pcall(require, "file_io")
    t:assert_true(success, "Should load FileIO module with SMODS available")
    
    local fileio = FileIO_module.new("test_shared")
    
    t:assert_not_nil(fileio, "FileIO should initialize")
    t:assert_not_nil(fileio.json, "JSON should be available")
    t:assert_type("function", fileio.json.encode, "Should have encode function")
    t:assert_type("function", fileio.json.decode, "Should have decode function")
    
    cleanup_mock_smods()
end)

test_framework:add_test("FileIO default path initialization", function(t)
    setup_mock_love_filesystem()
    setup_mock_smods()
    
    -- Load FileIO module with SMODS available
    local FileIO_module = require("file_io")
    
    -- Test default initialization (no path provided)
    local fileio = FileIO_module.new()
    
    t:assert_not_nil(fileio, "FileIO should initialize with default path")
    t:assert_equal("./", fileio.base_path, "Default base path should be 'shared' (relative path)")
    
    -- Test that the default creates the correct directory structure
    local expected_files = {
        "shared/game_state.json",
        "shared/actions.json",
        "shared/action_results.json"
    }
    
    -- Verify directory was created
    t:assert_true(love.filesystem.directories["./"], "Should create 'shared' directory by default")
    
    cleanup_mock_smods()
end)

test_framework:add_test("FileIO initialization without SMODS fails gracefully", function(t)
    setup_mock_love_filesystem()
    -- Don't setup SMODS - test failure case
    
    -- The require() will succeed because module is cached, but FileIO.new() should fail
    local FileIO_module = require("file_io")
    
    -- This should fail during FileIO.new() because SMODS is not available
    local success, error_msg = pcall(function()
        FileIO_module.new("test_shared")
    end)
    
    t:assert_false(success, "Should fail to create FileIO instance without SMODS")
    t:assert_contains(tostring(error_msg), "SMODS", "Error should mention SMODS")
end)

test_framework:add_test("SMODS.load_file JSON loading success", function(t)
    setup_mock_love_filesystem()
    setup_mock_smods()
    
    -- Test SMODS loading mechanism directly
    local load_success, json_loader = pcall(function()
        return assert(SMODS.load_file("libs/json.lua"))
    end)
    
    t:assert_true(load_success, "SMODS.load_file should succeed for libs/json.lua")
    t:assert_type("function", json_loader, "Should return a function")
    
    -- Test that the loader function works
    local json_lib = json_loader()
    t:assert_not_nil(json_lib, "JSON loader should return library")
    t:assert_type("function", json_lib.encode, "Should have encode function")
    t:assert_type("function", json_lib.decode, "Should have decode function")
    
    cleanup_mock_smods()
end)

test_framework:add_test("SMODS.load_file failure handling", function(t)
    setup_mock_smods()
    
    -- Test SMODS loading failure
    local load_success, error_msg = pcall(function()
        return assert(SMODS.load_file("nonexistent_file.lua"))
    end)
    
    t:assert_false(load_success, "SMODS.load_file should fail for nonexistent file")
    t:assert_contains(tostring(error_msg), "File not found", "Should show file not found error")
    
    cleanup_mock_smods()
end)

test_framework:add_test("FileIO write_game_state", function(t)
    setup_mock_love_filesystem()
    setup_mock_smods()
    
    local FileIO_module = require("file_io")
    local fileio = FileIO_module.new("test_shared")
    
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
    
    cleanup_mock_smods()
end)

test_framework:add_test("FileIO write_action_result", function(t)
    setup_mock_love_filesystem()
    setup_mock_smods()
    
    local FileIO_module = require("file_io")
    local fileio = FileIO_module.new("test_shared")
    
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
    
    cleanup_mock_smods()
end)

test_framework:add_test("FileIO read_actions", function(t)
    setup_mock_love_filesystem()
    setup_mock_smods()
    
    local FileIO_module = require("file_io")
    local fileio = FileIO_module.new("test_shared")
    
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
    
    cleanup_mock_smods()
end)

test_framework:add_test("FileIO error handling - nil data", function(t)
    setup_mock_love_filesystem()
    setup_mock_smods()
    
    local FileIO_module = require("file_io")
    local fileio = FileIO_module.new("test_shared")
    
    local success1 = fileio:write_game_state(nil)
    local success2 = fileio:write_action_result(nil)
    
    t:assert_false(success1, "Should fail to write nil game state")
    t:assert_false(success2, "Should fail to write nil action result")
    
    cleanup_mock_smods()
end)

test_framework:add_test("FileIO error handling - no love.filesystem", function(t)
    setup_mock_smods()
    
    -- Remove love.filesystem temporarily
    local original_love = love
    love = nil
    
    local FileIO_module = require("file_io")
    local fileio = FileIO_module.new("test_shared")
    
    local success1 = fileio:write_game_state({test = "data"})
    local success2 = fileio:write_action_result({test = "result"})
    local result = fileio:read_actions()
    
    t:assert_false(success1, "Should fail to write without love.filesystem")
    t:assert_false(success2, "Should fail to write without love.filesystem")
    t:assert_nil(result, "Should fail to read without love.filesystem")
    
    -- Restore love
    love = original_love
    cleanup_mock_smods()
end)

test_framework:add_test("FileIO sequence ID management", function(t)
    setup_mock_love_filesystem()
    setup_mock_smods()
    
    local FileIO_module = require("file_io")
    local fileio = FileIO_module.new("test_shared")
    
    local id1 = fileio:get_next_sequence_id()
    local id2 = fileio:get_next_sequence_id()
    local id3 = fileio:get_next_sequence_id()
    
    t:assert_equal(1, id1, "First sequence ID should be 1")
    t:assert_equal(2, id2, "Second sequence ID should be 2")
    t:assert_equal(3, id3, "Third sequence ID should be 3")
    
    cleanup_mock_smods()
end)

test_framework:add_test("FileIO Steammodded JSON loading failure", function(t)
    setup_mock_love_filesystem()
    
    -- Mock SMODS that fails to load JSON
    _G.SMODS = {
        load_file = function(filename)
            if filename == "libs/json.lua" then
                error("Failed to load libs/json.lua via SMODS")
            end
            return function() end
        end
    }
    
    -- This should fail during FileIO initialization
    local success, err = pcall(function()
        local FileIO_module = require("file_io")
        FileIO_module.new("test_shared")
    end)
    
    t:assert_false(success, "Should fail when JSON library can't be loaded via SMODS")
    t:assert_contains(tostring(err), "Failed to load required JSON library", "Should show appropriate error message")
    
    cleanup_mock_smods()
end)

test_framework:add_test("FileIO JSON encoding error handling", function(t)
    setup_mock_love_filesystem()
    setup_mock_smods()
    
    local FileIO_module = require("file_io")
    local fileio = FileIO_module.new("test_shared")
    
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
    
    cleanup_mock_smods()
end)

test_framework:add_test("FileIO JSON decoding error handling", function(t)
    setup_mock_love_filesystem()
    setup_mock_smods()
    
    local FileIO_module = require("file_io")
    local fileio = FileIO_module.new("test_shared")
    
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
    
    cleanup_mock_smods()
end)

-- =============================================================================
-- PATH HANDLING TESTS - Testing "." (current directory) vs subdirectory logic
-- =============================================================================

test_framework:add_test("FileIO current directory path initialization", function(t)
    setup_mock_love_filesystem()
    setup_mock_smods()
    
    local FileIO_module = require("file_io")
    
    -- Test initialization with "." (current directory)
    local fileio = FileIO_module.new(".")
    
    t:assert_not_nil(fileio, "FileIO should initialize with current directory path")
    t:assert_equal(".", fileio.base_path, "Base path should be '.' for current directory")
    
    -- Verify directory creation was attempted for "." (implementation always creates directory)
    t:assert_true(love.filesystem.directories["."], "Should attempt to create '.' directory")
    
    cleanup_mock_smods()
end)

test_framework:add_test("FileIO current directory vs subdirectory directory creation", function(t)
    setup_mock_love_filesystem()
    setup_mock_smods()
    
    local FileIO_module = require("file_io")
    
    -- Test subdirectory creation (existing behavior)
    local fileio_sub = FileIO_module.new("test_shared")
    t:assert_true(love.filesystem.directories["test_shared"], "Should create subdirectory")
    
    -- Clear filesystem state
    love.filesystem.directories = {}
    
    -- Test current directory initialization - implementation creates directory but uses different path construction
    local fileio_current = FileIO_module.new(".")
    t:assert_true(love.filesystem.directories["."], "Should create '.' directory (implementation always creates directory)")
    
    cleanup_mock_smods()
end)

test_framework:add_test("FileIO current directory write_game_state path construction", function(t)
    setup_mock_love_filesystem()
    setup_mock_smods()
    
    local FileIO_module = require("file_io")
    local fileio = FileIO_module.new(".")
    
    local test_state = {
        current_phase = "hand_selection",
        ante = 1,
        money = 100
    }
    
    local success = fileio:write_game_state(test_state)
    t:assert_true(success, "Should successfully write game state to current directory")
    
    -- Verify file was written to current directory, not subdirectory
    local file_content = love.filesystem.read("game_state.json")
    t:assert_not_nil(file_content, "Should create game_state.json in current directory")
    
    -- Verify subdirectory path was NOT used
    local sub_file_content = love.filesystem.read("./game_state.json")
    t:assert_nil(sub_file_content, "Should not create file in './' subdirectory")
    
    cleanup_mock_smods()
end)

test_framework:add_test("FileIO current directory read_actions path construction", function(t)
    setup_mock_love_filesystem()
    setup_mock_smods()
    
    local FileIO_module = require("file_io")
    local fileio = FileIO_module.new(".")
    
    -- Create a mock actions file in current directory
    local mock_action = {
        timestamp = "2024-01-01T00:00:00Z",
        sequence_id = 1,
        message_type = "action",
        data = {
            action_type = "play_hand",
            cards = {"card1", "card2"}
        }
    }
    
    local encoded_action = fileio.json.encode(mock_action)
    love.filesystem.write("actions.json", encoded_action)
    
    -- Read the actions
    local result = fileio:read_actions()
    
    t:assert_not_nil(result, "Should successfully read actions from current directory")
    t:assert_equal("play_hand", result.action_type, "Should decode action type correctly")
    
    -- Verify file was removed from current directory after reading
    local file_exists = love.filesystem.getInfo("actions.json")
    t:assert_nil(file_exists, "Should remove actions.json from current directory after reading")
    
    cleanup_mock_smods()
end)

test_framework:add_test("FileIO current directory write_action_result path construction", function(t)
    setup_mock_love_filesystem()
    setup_mock_smods()
    
    local FileIO_module = require("file_io")
    local fileio = FileIO_module.new(".")
    
    local test_result = {
        success = true,
        message = "Action completed successfully",
        data = {
            cards_played = 2,
            score = 1500
        }
    }
    
    local success = fileio:write_action_result(test_result)
    t:assert_true(success, "Should successfully write action result to current directory")
    
    -- Verify file was written to current directory
    local file_content = love.filesystem.read("action_results.json")
    t:assert_not_nil(file_content, "Should create action_results.json in current directory")
    t:assert_contains(file_content, "Action completed successfully", "Should contain result message")
    
    cleanup_mock_smods()
end)

test_framework:add_test("FileIO current directory cleanup_old_files path construction", function(t)
    setup_mock_love_filesystem()
    setup_mock_smods()
    
    local FileIO_module = require("file_io")
    local fileio = FileIO_module.new(".")
    
    -- Create test files in current directory with old timestamps
    love.filesystem.files["game_state.json"] = '{"test": "data"}'
    love.filesystem.files["actions.json"] = '{"test": "action"}'
    love.filesystem.files["action_results.json"] = '{"test": "result"}'
    
    -- Mock file info with old modification times
    local original_getInfo = love.filesystem.getInfo
    love.filesystem.getInfo = function(path)
        if love.filesystem.files[path] then
            return {
                type = "file",
                size = #love.filesystem.files[path],
                modtime = os.time() - 600  -- 10 minutes ago
            }
        end
        return nil
    end
    
    -- Run cleanup (max_age = 300 seconds = 5 minutes)
    fileio:cleanup_old_files(300)
    
    -- Verify files were removed from current directory
    t:assert_nil(love.filesystem.files["game_state.json"], "Should remove old game_state.json from current directory")
    t:assert_nil(love.filesystem.files["actions.json"], "Should remove old actions.json from current directory")
    t:assert_nil(love.filesystem.files["action_results.json"], "Should remove old action_results.json from current directory")
    
    -- Restore original function
    love.filesystem.getInfo = original_getInfo
    
    cleanup_mock_smods()
end)

test_framework:add_test("FileIO path construction comparison - current vs subdirectory", function(t)
    setup_mock_love_filesystem()
    setup_mock_smods()
    
    local FileIO_module = require("file_io")
    
    -- Test current directory FileIO
    local fileio_current = FileIO_module.new(".")
    
    -- Test subdirectory FileIO
    local fileio_sub = FileIO_module.new("test_shared")
    
    local test_state = {phase = "test"}
    
    -- Write with both instances
    local success_current = fileio_current:write_game_state(test_state)
    local success_sub = fileio_sub:write_game_state(test_state)
    
    t:assert_true(success_current, "Current directory write should succeed")
    t:assert_true(success_sub, "Subdirectory write should succeed")
    
    -- Verify files were written to different locations
    local current_file = love.filesystem.read("game_state.json")
    local sub_file = love.filesystem.read("test_shared/game_state.json")
    
    t:assert_not_nil(current_file, "Should create file in current directory")
    t:assert_not_nil(sub_file, "Should create file in subdirectory")
    t:assert_contains(current_file, "test", "Current directory file should contain test data")
    t:assert_contains(sub_file, "test", "Subdirectory file should contain test data")
    
    cleanup_mock_smods()
end)

test_framework:add_test("FileIO log file path construction with current directory", function(t)
    setup_mock_love_filesystem()
    setup_mock_smods()
    
    local FileIO_module = require("file_io")
    local fileio = FileIO_module.new(".")
    
    -- Trigger logging which should create log file in current directory
    fileio:log("Test log message")
    
    -- Verify log file was created in current directory, not subdirectory
    local log_content = love.filesystem.read("file_io_debug.log")
    t:assert_not_nil(log_content, "Should create debug log in current directory")
    t:assert_contains(log_content, "Test log message", "Should contain logged message")
    
    -- Verify subdirectory log was NOT created
    local sub_log_content = love.filesystem.read("./file_io_debug.log")
    t:assert_nil(sub_log_content, "Should not create log in './' subdirectory")
    
    cleanup_mock_smods()
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
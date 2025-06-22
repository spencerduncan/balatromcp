-- LuaUnit migration of FileIO module tests
-- Tests JSON functionality, file I/O operations, and path handling
-- Migrated from test_file_io.lua to use LuaUnit framework with individual function exports

local luaunit_helpers = require('luaunit_helpers')

-- Simple assertion wrapper functions that replicate the expected behavior
local function assert_equal(expected, actual, message)
    if expected ~= actual then
        error(string.format("ASSERTION FAILED: %s\nExpected: %s\nActual: %s",
            message or "", tostring(expected), tostring(actual)))
    end
end

local function assert_true(condition, message)
    if not condition then
        error(string.format("ASSERTION FAILED: %s\nExpected: true\nActual: false", message or ""))
    end
end

local function assert_false(condition, message)
    if condition then
        error(string.format("ASSERTION FAILED: %s\nExpected: false\nActual: true", message or ""))
    end
end

local function assert_nil(value, message)
    if value ~= nil then
        error(string.format("ASSERTION FAILED: %s\nExpected: nil\nActual: %s", message or "", tostring(value)))
    end
end

local function assert_not_nil(value, message)
    if value == nil then
        error(string.format("ASSERTION FAILED: %s\nExpected: not nil\nActual: nil", message or ""))
    end
end

local function assert_type(expected_type, value, message)
    local actual_type = type(value)
    if actual_type ~= expected_type then
        error(string.format("ASSERTION FAILED: %s\nExpected type: %s\nActual type: %s",
            message or "", expected_type, actual_type))
    end
end

local function assert_contains(haystack, needle, message)
    if type(haystack) == "string" then
        if not string.find(haystack, needle, 1, true) then
            error(string.format("ASSERTION FAILED: %s\nExpected string to contain: %s\nActual string: %s",
                message or "", needle, haystack))
        end
    else
        error("assert_contains only supports string search")
    end
end

-- Set up test environment once
local test_env = luaunit_helpers.FileIOTestBase:new()

-- Helper function to set up before each test
local function setUp()
    test_env:setUp()
end

-- Helper function to tear down after each test
local function tearDown()
    test_env:tearDown()
end

-- =============================================================================
-- BASIC FILEIO TESTS
-- =============================================================================

local function TestFileIOInitializationWithSMODS()
    setUp()
    
    -- Load FileIO module with SMODS available
    local success, FileIO_module = pcall(require, "file_io")
    assert_true(success, "Should load FileIO module with SMODS available")
    
    local fileio = FileIO_module.new("test_shared")
    
    assert_not_nil(fileio, "FileIO should initialize")
    assert_not_nil(fileio.json, "JSON should be available")
    assert_type("function", fileio.json.encode, "Should have encode function")
    assert_type("function", fileio.json.decode, "Should have decode function")
    
    tearDown()
end

local function TestFileIODefaultPathInitialization()
    setUp()
    
    -- Load FileIO module with SMODS available
    local FileIO_module = require("file_io")
    
    -- Test default initialization (no path provided)
    local fileio = FileIO_module.new()
    
    assert_not_nil(fileio, "FileIO should initialize with default path")
    assert_equal("shared", fileio.base_path, "Default base path should be 'shared' (relative path)")
    
    -- Verify directory was created
    assert_true(love.filesystem.directories["shared"], "Should create 'shared' directory by default")
    
    tearDown()
end

local function TestFileIOInitializationWithoutSMODSFailsGracefully()
    setUp()
    
    -- Don't setup SMODS - test failure case
    luaunit_helpers.cleanup_mock_smods()
    
    -- Clear any existing SMODS to ensure clean test
    _G.SMODS = nil
    
    local success, error_msg = pcall(function()
        local FileIO_module = require("file_io")
        FileIO_module.new("test_shared")
    end)
    
    -- Should fail because SMODS is not available for JSON loading
    assert_false(success, "Should fail when SMODS is not available")
    assert_contains(tostring(error_msg), "SMODS", "Error should mention SMODS dependency")
    
    -- Restore SMODS for subsequent tests
    luaunit_helpers.setup_mock_smods()
    
    tearDown()
end

local function TestSMODSLoadFileFailureHandling()
    setUp()
    
    -- Test SMODS loading failure
    local load_success, error_msg = pcall(function()
        return assert(SMODS.load_file("nonexistent_file.lua"))
    end)
    
    assert_false(load_success, "SMODS.load_file should fail for nonexistent file")
    assert_contains(tostring(error_msg), "File not found", "Should show file not found error")
    
    tearDown()
end

local function TestFileIOWriteGameState()
    setUp()
    
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
    assert_true(success, "Should successfully write game state")
    
    -- Verify file was written
    local file_content = love.filesystem.read("test_shared/game_state.json")
    assert_not_nil(file_content, "Should create game state file")
    assert_contains(file_content, "hand_selection", "Should contain phase data")
    assert_contains(file_content, "message_type", "Should contain message structure")
    
    tearDown()
end

local function TestFileIOWriteActionResult()
    setUp()
    
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
    assert_true(success, "Should successfully write action result")
    
    -- Verify file was written
    local file_content = love.filesystem.read("test_shared/action_results.json")
    assert_not_nil(file_content, "Should create action results file")
    assert_contains(file_content, "Action completed successfully", "Should contain result message")
    assert_contains(file_content, "action_result", "Should contain message type")
    
    tearDown()
end

local function TestFileIOReadActions()
    setUp()
    
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
    
    assert_not_nil(result, "Should successfully read actions")
    assert_equal("play_hand", result.data.action_type, "Should decode action type from data field")
    assert_equal("table", type(result.data.cards), "Should decode cards array from data field")
    assert_equal(2, #result.data.cards, "Should preserve cards count")
    
    -- Verify file was removed after reading
    local file_exists = love.filesystem.getInfo("test_shared/actions.json")
    assert_nil(file_exists, "Should remove actions file after reading")
    
    tearDown()
end

local function TestFileIOErrorHandlingNilData()
    setUp()
    
    local FileIO_module = require("file_io")
    local fileio = FileIO_module.new("test_shared")
    
    local success1 = fileio:write_game_state(nil)
    local success2 = fileio:write_action_result(nil)
    
    assert_false(success1, "Should fail to write nil game state")
    assert_false(success2, "Should fail to write nil action result")
    
    tearDown()
end

local function TestFileIOComprehensiveDependencyFailureHandling()
    setUp()
    
    -- Test 1: Missing love.filesystem dependency
    local original_love = love
    love = nil
    
    local FileIO_module = require("file_io")
    local fileio = FileIO_module.new("test_shared")
    
    local success1 = fileio:write_game_state({test = "data"})
    local success2 = fileio:write_action_result({test = "result"})
    local result1 = fileio:read_actions()
    
    assert_false(success1, "Should fail to write without love.filesystem")
    assert_false(success2, "Should fail to write without love.filesystem")
    assert_nil(result1, "Should fail to read without love.filesystem")
    
    -- Restore love for next test
    love = original_love
    
    -- Test 2: SMODS JSON loading failure
    luaunit_helpers.setup_mock_love_filesystem()
    _G.SMODS = {
        load_file = function(filename)
            if filename == "libs/json.lua" then
                error("Failed to load libs/json.lua via SMODS")
            end
            return function() end
        end
    }
    
    local success, err = pcall(function()
        local FileIO_module = require("file_io")
        FileIO_module.new("test_shared")
    end)
    
    assert_false(success, "Should fail when JSON library can't be loaded via SMODS")
    assert_contains(tostring(err), "Failed to load required JSON library", "Should show appropriate error message")
    
    -- Clean up the failing SMODS mock and restore
    luaunit_helpers.cleanup_mock_smods()
    luaunit_helpers.setup_mock_smods()
    
    -- Test 3: JSON encoding/decoding error handling
    local FileIO_module = require("file_io")
    local fileio = FileIO_module.new("test_shared")
    
    -- Test encoding errors
    local original_encode = fileio.json.encode
    fileio.json.encode = function(data) error("JSON encoding failed") end
    
    local encode_success1 = fileio:write_game_state({test = "data"})
    local encode_success2 = fileio:write_action_result({test = "result"})
    
    assert_false(encode_success1, "Should fail gracefully on JSON encoding error")
    assert_false(encode_success2, "Should fail gracefully on JSON encoding error")
    
    -- Test decoding errors
    fileio.json.encode = original_encode -- Restore encoder
    love.filesystem.write("test_shared/actions.json", '{"invalid": json content}')
    
    local original_decode = fileio.json.decode
    fileio.json.decode = function(content) error("JSON decoding failed") end
    
    local decode_result = fileio:read_actions()
    assert_nil(decode_result, "Should return nil on JSON decoding error")
    
    -- Restore original functions
    fileio.json.decode = original_decode
    
    tearDown()
end

local function TestFileIOSequenceIDManagement()
    setUp()
    
    local FileIO_module = require("file_io")
    local fileio = FileIO_module.new("test_shared")
    
    local id1 = fileio:get_next_sequence_id()
    local id2 = fileio:get_next_sequence_id()
    local id3 = fileio:get_next_sequence_id()
    
    assert_equal(1, id1, "First sequence ID should be 1")
    assert_equal(2, id2, "Second sequence ID should be 2")
    assert_equal(3, id3, "Third sequence ID should be 3")
    
    tearDown()
end

-- =============================================================================
-- PATH HANDLING TESTS - Testing "." (current directory) vs subdirectory logic
-- =============================================================================

local function TestFileIOCurrentDirectoryPathInitialization()
    setUp()
    
    local FileIO_module = require("file_io")
    
    -- Test initialization with "." (current directory)
    local fileio = FileIO_module.new(".")
    
    assert_not_nil(fileio, "FileIO should initialize with current directory path")
    assert_equal(".", fileio.base_path, "Base path should be '.' for current directory")
    
    -- Verify directory creation was attempted for "." (implementation always creates directory)
    assert_true(love.filesystem.directories["."], "Should attempt to create '.' directory")
    
    tearDown()
end

local function TestFileIOCurrentDirectoryVsSubdirectoryDirectoryCreation()
    setUp()
    
    local FileIO_module = require("file_io")
    
    -- Test subdirectory creation (existing behavior)
    local fileio_sub = FileIO_module.new("test_shared")
    assert_true(love.filesystem.directories["test_shared"], "Should create subdirectory")
    
    -- Clear filesystem state
    love.filesystem.directories = {}
    
    -- Test current directory initialization - implementation creates directory but uses different path construction
    local fileio_current = FileIO_module.new(".")
    assert_true(love.filesystem.directories["."], "Should create '.' directory (implementation always creates directory)")
    
    tearDown()
end

local function TestFileIOCurrentDirectoryWriteGameStatePathConstruction()
    setUp()
    
    local FileIO_module = require("file_io")
    local fileio = FileIO_module.new(".")
    
    local test_state = {
        current_phase = "hand_selection",
        ante = 1,
        money = 100
    }
    
    local success = fileio:write_game_state(test_state)
    assert_true(success, "Should successfully write game state to current directory")
    
    -- Verify file was written to current directory, not subdirectory
    local file_content = love.filesystem.read("game_state.json")
    assert_not_nil(file_content, "Should create game_state.json in current directory")
    
    -- Verify subdirectory path was NOT used
    local sub_file_content = love.filesystem.read("./game_state.json")
    assert_nil(sub_file_content, "Should not create file in './' subdirectory")
    
    tearDown()
end

local function TestFileIOCurrentDirectoryReadActionsPathConstruction()
    setUp()
    
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
    
    assert_not_nil(result, "Should successfully read actions from current directory")
    assert_equal("play_hand", result.data.action_type, "Should decode action type correctly from data field")
    
    -- Verify file was removed from current directory after reading
    local file_exists = love.filesystem.getInfo("actions.json")
    assert_nil(file_exists, "Should remove actions.json from current directory after reading")
    
    tearDown()
end

local function TestFileIOCurrentDirectoryWriteActionResultPathConstruction()
    setUp()
    
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
    assert_true(success, "Should successfully write action result to current directory")
    
    -- Verify file was written to current directory
    local file_content = love.filesystem.read("action_results.json")
    assert_not_nil(file_content, "Should create action_results.json in current directory")
    assert_contains(file_content, "Action completed successfully", "Should contain result message")
    
    tearDown()
end

local function TestFileIOCurrentDirectoryCleanupOldFilesPathConstruction()
    setUp()
    
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
    assert_nil(love.filesystem.files["game_state.json"], "Should remove old game_state.json from current directory")
    assert_nil(love.filesystem.files["actions.json"], "Should remove old actions.json from current directory")
    assert_nil(love.filesystem.files["action_results.json"], "Should remove old action_results.json from current directory")
    
    -- Restore original function
    love.filesystem.getInfo = original_getInfo
    
    tearDown()
end

local function TestFileIOPathConstructionComparisonCurrentVsSubdirectory()
    setUp()
    
    local FileIO_module = require("file_io")
    
    -- Test current directory FileIO
    local fileio_current = FileIO_module.new(".")
    
    -- Test subdirectory FileIO
    local fileio_sub = FileIO_module.new("test_shared")
    
    local test_state = {phase = "test"}
    
    -- Write with both instances
    local success_current = fileio_current:write_game_state(test_state)
    local success_sub = fileio_sub:write_game_state(test_state)
    
    assert_true(success_current, "Current directory write should succeed")
    assert_true(success_sub, "Subdirectory write should succeed")
    
    -- Verify files were written to different locations
    local current_file = love.filesystem.read("game_state.json")
    local sub_file = love.filesystem.read("test_shared/game_state.json")
    
    assert_not_nil(current_file, "Should create file in current directory")
    assert_not_nil(sub_file, "Should create file in subdirectory")
    assert_contains(current_file, "test", "Current directory file should contain test data")
    assert_contains(sub_file, "test", "Subdirectory file should contain test data")
    
    tearDown()
end

local function TestFileIOLogFilePathConstructionWithCurrentDirectory()
    setUp()
    
    local FileIO_module = require("file_io")
    local fileio = FileIO_module.new(".")
    
    -- Trigger logging which should create log file in current directory
    fileio:log("Test log message")
    
    -- Verify log file was created in current directory, not subdirectory
    local log_content = love.filesystem.read("file_io_debug.log")
    assert_not_nil(log_content, "Should create debug log in current directory")
    assert_contains(log_content, "Test log message", "Should contain logged message")
    
    -- Verify subdirectory log was NOT created
    local sub_log_content = love.filesystem.read("./file_io_debug.log")
    assert_nil(sub_log_content, "Should not create log in './' subdirectory")
    
    tearDown()
end

-- Add missing test function that is referenced in the return table
local function TestSMODSLoadFileJSONLoadingSuccess()
    setUp()
    
    local FileIO_module = require("file_io")
    local fileio = FileIO_module.new("test_shared")
    
    -- Test should pass - SMODS is available and can load JSON
    assert_not_nil(fileio, "FileIO should initialize successfully with SMODS available")
    assert_not_nil(fileio.json, "JSON should be loaded via SMODS")
    assert_type("function", fileio.json.encode, "Should have JSON encode function")
    assert_type("function", fileio.json.decode, "Should have JSON decode function")
    
    tearDown()
end

-- Export all test functions for LuaUnit registration
return {
    TestFileIOInitializationWithSMODS = TestFileIOInitializationWithSMODS,
    TestFileIODefaultPathInitialization = TestFileIODefaultPathInitialization,
    TestFileIOInitializationWithoutSMODSFailsGracefully = TestFileIOInitializationWithoutSMODSFailsGracefully,
    TestSMODSLoadFileJSONLoadingSuccess = TestSMODSLoadFileJSONLoadingSuccess,
    TestSMODSLoadFileFailureHandling = TestSMODSLoadFileFailureHandling,
    TestFileIOWriteGameState = TestFileIOWriteGameState,
    TestFileIOWriteActionResult = TestFileIOWriteActionResult,
    TestFileIOReadActions = TestFileIOReadActions,
    TestFileIOErrorHandlingNilData = TestFileIOErrorHandlingNilData,
    TestFileIOComprehensiveDependencyFailureHandling = TestFileIOComprehensiveDependencyFailureHandling,
    TestFileIOSequenceIDManagement = TestFileIOSequenceIDManagement,
    TestFileIOCurrentDirectoryPathInitialization = TestFileIOCurrentDirectoryPathInitialization,
    TestFileIOCurrentDirectoryVsSubdirectoryDirectoryCreation = TestFileIOCurrentDirectoryVsSubdirectoryDirectoryCreation,
    TestFileIOCurrentDirectoryWriteGameStatePathConstruction = TestFileIOCurrentDirectoryWriteGameStatePathConstruction,
    TestFileIOCurrentDirectoryReadActionsPathConstruction = TestFileIOCurrentDirectoryReadActionsPathConstruction,
    TestFileIOCurrentDirectoryWriteActionResultPathConstruction = TestFileIOCurrentDirectoryWriteActionResultPathConstruction,
    TestFileIOCurrentDirectoryCleanupOldFilesPathConstruction = TestFileIOCurrentDirectoryCleanupOldFilesPathConstruction,
    TestFileIOPathConstructionComparisonCurrentVsSubdirectory = TestFileIOPathConstructionComparisonCurrentVsSubdirectory,
    TestFileIOLogFilePathConstructionWithCurrentDirectory = TestFileIOLogFilePathConstructionWithCurrentDirectory
}
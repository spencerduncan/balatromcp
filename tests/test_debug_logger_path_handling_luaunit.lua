-- LuaUnit migration of DebugLogger path handling functionality tests
-- Tests the "." (current directory) vs subdirectory path logic
-- Migrated from test_debug_logger_path_handling.lua to use LuaUnit framework

local luaunit = require('../libs/luaunit')
local luaunit_helpers = require('luaunit_helpers')

-- DebugLogger Path Handling Test Class
local TestDebugLoggerPathHandling = {}
TestDebugLoggerPathHandling.__index = TestDebugLoggerPathHandling

function TestDebugLoggerPathHandling:new()
    local self = setmetatable({}, TestDebugLoggerPathHandling)
    return self
end

-- setUp method - executed before each test
function TestDebugLoggerPathHandling:setUp()
    -- Set up clean environment with mock love.filesystem
    self.original_love = love
    self.original_json = json
    self.original_require = require
    
    -- Use the helper to set up mock filesystem (preserves exact functionality)
    luaunit_helpers.setup_mock_love_filesystem()
    
    -- Set up JSON mock that can be required (required for DebugLogger test_file_communication)
    local json_mock = {
        encode = function(data) return '{"test": "data"}' end,
        decode = function(str) return {test = "data"} end
    }
    
    -- Mock require function to return JSON mock when "json" is requested
    require = function(module_name)
        if module_name == "json" then
            return json_mock
        else
            return self.original_require(module_name)
        end
    end
    
    -- Also set global json for any direct access
    json = json_mock
end

-- tearDown method - executed after each test
function TestDebugLoggerPathHandling:tearDown()
    -- Restore original environment
    love = self.original_love
    json = self.original_json
    require = self.original_require
end

-- Test 1: DebugLogger initialization with subdirectory
function TestDebugLoggerPathHandling:testDebugLoggerInitializationWithSubdirectory()
    local DebugLogger = require("debug_logger")
    
    -- Test initialization with subdirectory
    local logger = DebugLogger.new(nil, "./")
    
    luaunit.assertNotNil(logger, "DebugLogger should initialize with subdirectory")
    luaunit.assertEquals("./", logger.base_path, "Base path should be './' for subdirectory")
    luaunit.assertEquals(".//debug.log", logger.log_file, "Log file should be './/debug.log'")
    
    -- Verify directory creation was attempted for subdirectory
    luaunit.assertTrue(love.filesystem.directories["./"], "Should create './' directory")
end

-- Test 2: DebugLogger default initialization
function TestDebugLoggerPathHandling:testDebugLoggerDefaultInitialization()
    local DebugLogger = require("debug_logger")
    
    -- Test default initialization (no base_path provided)
    local logger = DebugLogger.new()
    
    luaunit.assertNotNil(logger, "DebugLogger should initialize with defaults")
    luaunit.assertEquals("./", logger.base_path, "Default base path should be './'")
    luaunit.assertEquals(".//debug.log", logger.log_file, "Default log file should be './/debug.log'")
    
    -- Verify default directory creation
    luaunit.assertTrue(love.filesystem.directories["./"], "Should create default './' directory")
end

-- Test 3: DebugLogger custom log file path with current directory
function TestDebugLoggerPathHandling:testDebugLoggerCustomLogFilePathWithCurrentDirectory()
    local DebugLogger = require("debug_logger")
    
    -- Test custom log file path with current directory base path
    local logger = DebugLogger.new("custom.log", ".")
    
    luaunit.assertNotNil(logger, "DebugLogger should initialize with custom log file")
    luaunit.assertEquals(".", logger.base_path, "Base path should be current directory")
    luaunit.assertEquals("custom.log", logger.log_file, "Should use custom log file path")
    
    -- Verify no directory creation for current directory
    luaunit.assertNil(love.filesystem.directories["."], "Should not create '.' directory")
end

-- Test 4: DebugLogger custom log file path with subdirectory
function TestDebugLoggerPathHandling:testDebugLoggerCustomLogFilePathWithSubdirectory()
    local DebugLogger = require("debug_logger")
    
    -- Test custom log file path with subdirectory base path
    local logger = DebugLogger.new("custom.log", "test_logs")
    
    luaunit.assertNotNil(logger, "DebugLogger should initialize with custom log and subdirectory")
    luaunit.assertEquals("test_logs", logger.base_path, "Base path should be 'test_logs'")
    luaunit.assertEquals("custom.log", logger.log_file, "Should use custom log file path")
    
    -- Verify directory creation for subdirectory
    luaunit.assertTrue(love.filesystem.directories["test_logs"], "Should create 'test_logs' directory")
end

-- Test 5: DebugLogger test_file_communication with current directory
function TestDebugLoggerPathHandling:testDebugLoggerTestFileCommunicationWithCurrentDirectory()
    local DebugLogger = require("debug_logger")
    local logger = DebugLogger.new(nil, ".")
    
    -- Run file communication test
    logger:test_file_communication()
    
    -- Verify test file was created in current directory
    local test_file_content = love.filesystem.read("test_write.json")
    luaunit.assertNotNil(test_file_content, "Should create test file in current directory")
    luaunit.assertStrContains(test_file_content, "test", "Test file should contain test data")
    
    -- Verify subdirectory test file was NOT created
    local sub_test_file = love.filesystem.read("./test_write.json")
    luaunit.assertNil(sub_test_file, "Should not create test file in './' subdirectory")
end

-- Test 6: DebugLogger test_file_communication with subdirectory
function TestDebugLoggerPathHandling:testDebugLoggerTestFileCommunicationWithSubdirectory()
    local DebugLogger = require("debug_logger")
    local logger = DebugLogger.new(nil, "test_shared")
    
    -- Run file communication test
    logger:test_file_communication()
    
    -- Verify test file was created in subdirectory
    local test_file_content = love.filesystem.read("test_shared/test_write.json")
    luaunit.assertNotNil(test_file_content, "Should create test file in subdirectory")
    luaunit.assertStrContains(test_file_content, "test", "Test file should contain test data")
    
    -- Verify current directory test file was NOT created
    local current_test_file = love.filesystem.read("test_write.json")
    luaunit.assertNil(current_test_file, "Should not create test file in current directory")
end

-- Test 7: DebugLogger directory creation behavior comparison
function TestDebugLoggerPathHandling:testDebugLoggerDirectoryCreationBehaviorComparison()
    local DebugLogger = require("debug_logger")
    
    -- Test current directory (should not create directory)
    local logger_current = DebugLogger.new(nil, ".")
    luaunit.assertNil(love.filesystem.directories["."], "Should not create '.' directory")
    
    -- Clear and test subdirectory (should create directory)
    love.filesystem.directories = {}
    local logger_sub = DebugLogger.new(nil, "logs")
    luaunit.assertTrue(love.filesystem.directories["logs"], "Should create 'logs' directory")
    
    -- Verify both loggers work correctly
    luaunit.assertEquals(".", logger_current.base_path, "Current directory logger should have '.' base path")
    luaunit.assertEquals("logs", logger_sub.base_path, "Subdirectory logger should have 'logs' base path")
end

-- Standalone test runner function (for compatibility with LuaUnit infrastructure)
local function run_debug_logger_path_tests_luaunit()
    print("Starting DebugLogger path handling tests (LuaUnit)...")
    
    local test_instance = TestDebugLoggerPathHandling:new()
    local passed = 0
    local failed = 0
    
    local tests = {
        {"testDebugLoggerInitializationWithSubdirectory", "DebugLogger initialization with subdirectory"},
        {"testDebugLoggerDefaultInitialization", "DebugLogger default initialization"},
        {"testDebugLoggerCustomLogFilePathWithCurrentDirectory", "DebugLogger custom log file path with current directory"},
        {"testDebugLoggerCustomLogFilePathWithSubdirectory", "DebugLogger custom log file path with subdirectory"},
        {"testDebugLoggerTestFileCommunicationWithCurrentDirectory", "DebugLogger test_file_communication with current directory"},
        {"testDebugLoggerTestFileCommunicationWithSubdirectory", "DebugLogger test_file_communication with subdirectory"},
        {"testDebugLoggerDirectoryCreationBehaviorComparison", "DebugLogger directory creation behavior comparison"}
    }
    
    for _, test_info in ipairs(tests) do
        local test_method = test_info[1]
        local test_description = test_info[2]
        
        -- Run setUp
        test_instance:setUp()
        
        local success, error_msg = pcall(function()
            test_instance[test_method](test_instance)
        end)
        
        -- Run tearDown
        test_instance:tearDown()
        
        if success then
            print("✓ " .. test_description)
            passed = passed + 1
        else
            print("✗ " .. test_description .. " - " .. tostring(error_msg))
            failed = failed + 1
        end
    end
    
    print(string.format("\n=== LuaUnit TEST RESULTS ===\nPassed: %d\nFailed: %d\nTotal: %d", 
        passed, failed, passed + failed))
    
    local success = (failed == 0)
    if success then
        print("\n🎉 All DebugLogger path handling tests passed! (LuaUnit)")
        print("✅ Current directory initialization")
        print("✅ Subdirectory initialization") 
        print("✅ Path construction logic")
        print("✅ Directory creation behavior")
        print("✅ File communication tests with different paths")
    else
        print("\n❌ Some DebugLogger path handling tests failed. Please review the implementation.")
    end
    
    return success
end

-- Convert class methods to standalone functions for LuaUnit registration
function TestDebugLoggerInitializationWithSubdirectory()
    local test_instance = TestDebugLoggerPathHandling:new()
    test_instance:setUp()
    test_instance:testDebugLoggerInitializationWithSubdirectory()
    test_instance:tearDown()
end

function TestDebugLoggerDefaultInitialization()
    local test_instance = TestDebugLoggerPathHandling:new()
    test_instance:setUp()
    test_instance:testDebugLoggerDefaultInitialization()
    test_instance:tearDown()
end

function TestDebugLoggerCustomLogFilePathWithCurrentDirectory()
    local test_instance = TestDebugLoggerPathHandling:new()
    test_instance:setUp()
    test_instance:testDebugLoggerCustomLogFilePathWithCurrentDirectory()
    test_instance:tearDown()
end

function TestDebugLoggerCustomLogFilePathWithSubdirectory()
    local test_instance = TestDebugLoggerPathHandling:new()
    test_instance:setUp()
    test_instance:testDebugLoggerCustomLogFilePathWithSubdirectory()
    test_instance:tearDown()
end

function TestDebugLoggerTestFileCommunicationWithCurrentDirectory()
    local test_instance = TestDebugLoggerPathHandling:new()
    test_instance:setUp()
    test_instance:testDebugLoggerTestFileCommunicationWithCurrentDirectory()
    test_instance:tearDown()
end

function TestDebugLoggerTestFileCommunicationWithSubdirectory()
    local test_instance = TestDebugLoggerPathHandling:new()
    test_instance:setUp()
    test_instance:testDebugLoggerTestFileCommunicationWithSubdirectory()
    test_instance:tearDown()
end

function TestDebugLoggerDirectoryCreationBehaviorComparison()
    local test_instance = TestDebugLoggerPathHandling:new()
    test_instance:setUp()
    test_instance:testDebugLoggerDirectoryCreationBehaviorComparison()
    test_instance:tearDown()
end

-- Export individual test functions for LuaUnit registration
return {
    TestDebugLoggerInitializationWithSubdirectory = TestDebugLoggerInitializationWithSubdirectory,
    TestDebugLoggerDefaultInitialization = TestDebugLoggerDefaultInitialization,
    TestDebugLoggerCustomLogFilePathWithCurrentDirectory = TestDebugLoggerCustomLogFilePathWithCurrentDirectory,
    TestDebugLoggerCustomLogFilePathWithSubdirectory = TestDebugLoggerCustomLogFilePathWithSubdirectory,
    TestDebugLoggerTestFileCommunicationWithCurrentDirectory = TestDebugLoggerTestFileCommunicationWithCurrentDirectory,
    TestDebugLoggerTestFileCommunicationWithSubdirectory = TestDebugLoggerTestFileCommunicationWithSubdirectory,
    TestDebugLoggerDirectoryCreationBehaviorComparison = TestDebugLoggerDirectoryCreationBehaviorComparison
}
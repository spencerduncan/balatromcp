-- Unit tests for DebugLogger path handling functionality
-- Tests the "." (current directory) vs subdirectory path logic

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
    print("=== RUNNING DEBUG LOGGER PATH HANDLING UNIT TESTS ===")
    
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

-- Test suite for DebugLogger path handling
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
-- DEBUG LOGGER PATH HANDLING TESTS
-- =============================================================================

test_framework:add_test("DebugLogger initialization with current directory", function(t)
    setup_mock_love_filesystem()
    
    local DebugLogger = require("debug_logger")
    
    -- Test initialization with "." (current directory)
    local logger = DebugLogger.new(nil, ".")
    
    t:assert_not_nil(logger, "DebugLogger should initialize with current directory")
    t:assert_equal(".", logger.base_path, "Base path should be '.' for current directory")
    t:assert_equal("debug.log", logger.log_file, "Log file should be 'debug.log' in current directory")
    
    -- Verify no directory creation attempt was made for "."
    t:assert_nil(love.filesystem.directories["."], "Should not attempt to create '.' directory")
end)

test_framework:add_test("DebugLogger initialization with subdirectory", function(t)
    setup_mock_love_filesystem()
    
    local DebugLogger = require("debug_logger")
    
    -- Test initialization with subdirectory
    local logger = DebugLogger.new(nil, "shared")
    
    t:assert_not_nil(logger, "DebugLogger should initialize with subdirectory")
    t:assert_equal("shared", logger.base_path, "Base path should be 'shared' for subdirectory")
    t:assert_equal("shared/debug.log", logger.log_file, "Log file should be 'shared/debug.log'")
    
    -- Verify directory creation was attempted for subdirectory
    t:assert_true(love.filesystem.directories["shared"], "Should create 'shared' directory")
end)

test_framework:add_test("DebugLogger default initialization", function(t)
    setup_mock_love_filesystem()
    
    local DebugLogger = require("debug_logger")
    
    -- Test default initialization (no base_path provided)
    local logger = DebugLogger.new()
    
    t:assert_not_nil(logger, "DebugLogger should initialize with defaults")
    t:assert_equal("shared", logger.base_path, "Default base path should be 'shared'")
    t:assert_equal("shared/debug.log", logger.log_file, "Default log file should be 'shared/debug.log'")
    
    -- Verify default directory creation
    t:assert_true(love.filesystem.directories["shared"], "Should create default 'shared' directory")
end)

test_framework:add_test("DebugLogger custom log file path with current directory", function(t)
    setup_mock_love_filesystem()
    
    local DebugLogger = require("debug_logger")
    
    -- Test custom log file path with current directory base path
    local logger = DebugLogger.new("custom.log", ".")
    
    t:assert_not_nil(logger, "DebugLogger should initialize with custom log file")
    t:assert_equal(".", logger.base_path, "Base path should be current directory")
    t:assert_equal("custom.log", logger.log_file, "Should use custom log file path")
    
    -- Verify no directory creation for current directory
    t:assert_nil(love.filesystem.directories["."], "Should not create '.' directory")
end)

test_framework:add_test("DebugLogger custom log file path with subdirectory", function(t)
    setup_mock_love_filesystem()
    
    local DebugLogger = require("debug_logger")
    
    -- Test custom log file path with subdirectory base path
    local logger = DebugLogger.new("custom.log", "test_logs")
    
    t:assert_not_nil(logger, "DebugLogger should initialize with custom log and subdirectory")
    t:assert_equal("test_logs", logger.base_path, "Base path should be 'test_logs'")
    t:assert_equal("custom.log", logger.log_file, "Should use custom log file path")
    
    -- Verify directory creation for subdirectory
    t:assert_true(love.filesystem.directories["test_logs"], "Should create 'test_logs' directory")
end)

test_framework:add_test("DebugLogger test_file_communication with current directory", function(t)
    setup_mock_love_filesystem()
    
    local DebugLogger = require("debug_logger")
    local logger = DebugLogger.new(nil, ".")
    
    -- Mock JSON library
    if not json then
        json = {
            encode = function(data) return '{"test": "data"}' end,
            decode = function(str) return {test = "data"} end
        }
    end
    
    -- Run file communication test
    logger:test_file_communication()
    
    -- Verify test file was created in current directory
    local test_file_content = love.filesystem.read("test_write.json")
    t:assert_not_nil(test_file_content, "Should create test file in current directory")
    t:assert_contains(test_file_content, "test", "Test file should contain test data")
    
    -- Verify subdirectory test file was NOT created
    local sub_test_file = love.filesystem.read("./test_write.json")
    t:assert_nil(sub_test_file, "Should not create test file in './' subdirectory")
end)

test_framework:add_test("DebugLogger test_file_communication with subdirectory", function(t)
    setup_mock_love_filesystem()
    
    local DebugLogger = require("debug_logger")
    local logger = DebugLogger.new(nil, "test_shared")
    
    -- Mock JSON library
    if not json then
        json = {
            encode = function(data) return '{"test": "data"}' end,
            decode = function(str) return {test = "data"} end
        }
    end
    
    -- Run file communication test
    logger:test_file_communication()
    
    -- Verify test file was created in subdirectory
    local test_file_content = love.filesystem.read("test_shared/test_write.json")
    t:assert_not_nil(test_file_content, "Should create test file in subdirectory")
    t:assert_contains(test_file_content, "test", "Test file should contain test data")
    
    -- Verify current directory test file was NOT created
    local current_test_file = love.filesystem.read("test_write.json")
    t:assert_nil(current_test_file, "Should not create test file in current directory")
end)

test_framework:add_test("DebugLogger directory creation behavior comparison", function(t)
    setup_mock_love_filesystem()
    
    local DebugLogger = require("debug_logger")
    
    -- Test current directory (should not create directory)
    local logger_current = DebugLogger.new(nil, ".")
    t:assert_nil(love.filesystem.directories["."], "Should not create '.' directory")
    
    -- Clear and test subdirectory (should create directory)
    love.filesystem.directories = {}
    local logger_sub = DebugLogger.new(nil, "logs")
    t:assert_true(love.filesystem.directories["logs"], "Should create 'logs' directory")
    
    -- Verify both loggers work correctly
    t:assert_equal(".", logger_current.base_path, "Current directory logger should have '.' base path")
    t:assert_equal("logs", logger_sub.base_path, "Subdirectory logger should have 'logs' base path")
end)

-- Run all tests
local function run_debug_logger_path_tests()
    print("Starting DebugLogger path handling tests...")
    local success = test_framework:run_tests()
    
    if success then
        print("\n🎉 All DebugLogger path handling tests passed!")
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

-- Export the test runner
return {
    run_tests = run_debug_logger_path_tests,
    test_framework = test_framework
}
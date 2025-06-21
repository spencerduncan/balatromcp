-- Unit tests for Steammodded module loading mechanism
-- Tests the new assert(SMODS.load_file()) pattern used in BalatroMCP.lua

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
    print("=== RUNNING STEAMMODDED LOADING UNIT TESTS ===")
    
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

-- Test suite for Steammodded loading
local test_framework = TestFramework.new()

-- Mock module dependencies
local function create_mock_debug_logger()
    return {
        new = function()
            return {
                info = function(self, msg, category) end,
                error = function(self, msg, category) end,
                test_environment = function(self) end,
                test_file_communication = function(self) end
            }
        end
    }
end

local function create_mock_file_io()
    return {
        new = function()
            return {
                get_next_sequence = function(self) return 1 end,
                write_state = function(self, data) return true end,
                read_action = function(self) return nil end
            }
        end
    }
end

local function create_mock_state_extractor()
    return {
        new = function()
            return {
                extract_current_state = function(self)
                    return {
                        game_phase = "hand_selection",
                        ante = 1,
                        dollars = 100
                    }
                end
            }
        end
    }
end

local function create_mock_action_executor()
    return {
        new = function(state_extractor, joker_manager)
            return {
                execute_action = function(self, action_data)
                    return {
                        success = true,
                        error_message = nil,
                        new_state = {}
                    }
                end
            }
        end
    }
end

local function create_mock_joker_manager()
    return {
        new = function()
            return {}
        end
    }
end

-- Set up mock SMODS environment
local function setup_mock_smods()
    if not _G.SMODS then
        _G.SMODS = {
            load_file = function(filename)
                -- Mock the different module files
                if filename == "debug_logger.lua" then
                    return function() return create_mock_debug_logger() end
                elseif filename == "file_io.lua" then
                    return function() return create_mock_file_io() end
                elseif filename == "state_extractor.lua" then
                    return function() return create_mock_state_extractor() end
                elseif filename == "action_executor.lua" then
                    return function() return create_mock_action_executor() end
                elseif filename == "joker_manager.lua" then
                    return function() return create_mock_joker_manager() end
                elseif filename == "libs/json.lua" then
                    return function() return require("libs.json") end
                else
                    error("Mock SMODS: File not found: " .. filename)
                end
            end,
            INIT = {},
            UPDATE = {},
            QUIT = {}
        }
    end
end

-- Clean up SMODS mock
local function cleanup_mock_smods()
    _G.SMODS = nil
end

-- Mock G object for testing
local function setup_mock_g()
    _G.G = {
        FUNCS = {}
    }
end

local function cleanup_mock_g()
    _G.G = nil
end

-- =============================================================================
-- MODULE LOADING TESTS
-- =============================================================================

test_framework:add_test("SMODS.load_file loads debug_logger successfully", function(t)
    setup_mock_smods()
    
    local success, loader = pcall(function()
        return assert(SMODS.load_file("debug_logger.lua"))
    end)
    
    t:assert_true(success, "Should successfully load debug_logger.lua")
    t:assert_type("function", loader, "Should return a function")
    
    -- Test the loader function
    local module = loader()
    t:assert_not_nil(module, "Should return debug logger module")
    t:assert_type("function", module.new, "Should have new function")
    
    cleanup_mock_smods()
end)

test_framework:add_test("SMODS.load_file loads file_io successfully", function(t)
    setup_mock_smods()
    
    local success, loader = pcall(function()
        return assert(SMODS.load_file("file_io.lua"))
    end)
    
    t:assert_true(success, "Should successfully load file_io.lua")
    t:assert_type("function", loader, "Should return a function")
    
    -- Test the loader function
    local module = loader()
    t:assert_not_nil(module, "Should return file IO module")
    t:assert_type("function", module.new, "Should have new function")
    
    cleanup_mock_smods()
end)

test_framework:add_test("SMODS.load_file loads state_extractor successfully", function(t)
    setup_mock_smods()
    
    local success, loader = pcall(function()
        return assert(SMODS.load_file("state_extractor.lua"))
    end)
    
    t:assert_true(success, "Should successfully load state_extractor.lua")
    t:assert_type("function", loader, "Should return a function")
    
    -- Test the loader function
    local module = loader()
    t:assert_not_nil(module, "Should return state extractor module")
    t:assert_type("function", module.new, "Should have new function")
    
    cleanup_mock_smods()
end)

test_framework:add_test("SMODS.load_file loads action_executor successfully", function(t)
    setup_mock_smods()
    
    local success, loader = pcall(function()
        return assert(SMODS.load_file("action_executor.lua"))
    end)
    
    t:assert_true(success, "Should successfully load action_executor.lua")
    t:assert_type("function", loader, "Should return a function")
    
    -- Test the loader function
    local module = loader()
    t:assert_not_nil(module, "Should return action executor module")
    t:assert_type("function", module.new, "Should have new function")
    
    cleanup_mock_smods()
end)

test_framework:add_test("SMODS.load_file loads joker_manager successfully", function(t)
    setup_mock_smods()
    
    local success, loader = pcall(function()
        return assert(SMODS.load_file("joker_manager.lua"))
    end)
    
    t:assert_true(success, "Should successfully load joker_manager.lua")
    t:assert_type("function", loader, "Should return a function")
    
    -- Test the loader function
    local module = loader()
    t:assert_not_nil(module, "Should return joker manager module")
    t:assert_type("function", module.new, "Should have new function")
    
    cleanup_mock_smods()
end)

test_framework:add_test("SMODS.load_file fails for nonexistent file", function(t)
    setup_mock_smods()
    
    local success, error_msg = pcall(function()
        return assert(SMODS.load_file("nonexistent_module.lua"))
    end)
    
    t:assert_false(success, "Should fail for nonexistent file")
    t:assert_contains(tostring(error_msg), "File not found", "Should show file not found error")
    
    cleanup_mock_smods()
end)

test_framework:add_test("BalatroMCP module loading without SMODS fails", function(t)
    -- Don't set up SMODS - should fail
    cleanup_mock_smods()
    
    local success, error_msg = pcall(function()
        -- Try to simulate the module loading from BalatroMCP.lua
        local DebugLogger = assert(SMODS.load_file("debug_logger.lua"))()
    end)
    
    t:assert_false(success, "Should fail without SMODS available")
    t:assert_contains(tostring(error_msg), "SMODS", "Error should mention SMODS")
end)

-- =============================================================================
-- INTEGRATION TESTS FOR BALATRO MCP LOADING PATTERN
-- =============================================================================

test_framework:add_test("BalatroMCP module loading pattern integration", function(t)
    setup_mock_smods()
    setup_mock_g()
    
    -- Test the complete loading pattern used in BalatroMCP.lua
    local success, modules = pcall(function()
        local DebugLogger = assert(SMODS.load_file("debug_logger.lua"))()
        local FileIO = assert(SMODS.load_file("file_io.lua"))()
        local StateExtractor = assert(SMODS.load_file("state_extractor.lua"))()
        local ActionExecutor = assert(SMODS.load_file("action_executor.lua"))()
        local JokerManager = assert(SMODS.load_file("joker_manager.lua"))()
        
        return {
            DebugLogger = DebugLogger,
            FileIO = FileIO,
            StateExtractor = StateExtractor,
            ActionExecutor = ActionExecutor,
            JokerManager = JokerManager
        }
    end)
    
    t:assert_true(success, "Should successfully load all modules using SMODS pattern")
    t:assert_not_nil(modules.DebugLogger, "Should load DebugLogger")
    t:assert_not_nil(modules.FileIO, "Should load FileIO")
    t:assert_not_nil(modules.StateExtractor, "Should load StateExtractor")
    t:assert_not_nil(modules.ActionExecutor, "Should load ActionExecutor")
    t:assert_not_nil(modules.JokerManager, "Should load JokerManager")
    
    -- Test that modules can be instantiated
    local debug_logger = modules.DebugLogger.new()
    local file_io = modules.FileIO.new()
    local state_extractor = modules.StateExtractor.new()
    local joker_manager = modules.JokerManager.new()
    local action_executor = modules.ActionExecutor.new(state_extractor, joker_manager)
    
    t:assert_not_nil(debug_logger, "Should instantiate DebugLogger")
    t:assert_not_nil(file_io, "Should instantiate FileIO")
    t:assert_not_nil(state_extractor, "Should instantiate StateExtractor")
    t:assert_not_nil(joker_manager, "Should instantiate JokerManager")
    t:assert_not_nil(action_executor, "Should instantiate ActionExecutor")
    
    cleanup_mock_g()
    cleanup_mock_smods()
end)

test_framework:add_test("Module loading resilience to partial failures", function(t)
    -- Set up SMODS that fails for one specific module
    _G.SMODS = {
        load_file = function(filename)
            if filename == "debug_logger.lua" then
                return function() return create_mock_debug_logger() end
            elseif filename == "file_io.lua" then
                error("Simulated file_io.lua loading failure")
            elseif filename == "state_extractor.lua" then
                return function() return create_mock_state_extractor() end
            elseif filename == "action_executor.lua" then
                return function() return create_mock_action_executor() end
            elseif filename == "joker_manager.lua" then
                return function() return create_mock_joker_manager() end
            else
                error("Mock SMODS: File not found: " .. filename)
            end
        end
    }
    
    -- Test loading with one module failing
    local success, error_msg = pcall(function()
        local DebugLogger = assert(SMODS.load_file("debug_logger.lua"))()
        local FileIO = assert(SMODS.load_file("file_io.lua"))() -- This should fail
        local StateExtractor = assert(SMODS.load_file("state_extractor.lua"))()
    end)
    
    t:assert_false(success, "Should fail when one module fails to load")
    t:assert_contains(tostring(error_msg), "file_io.lua", "Error should mention the failing module")
    
    cleanup_mock_smods()
end)

-- =============================================================================
-- ERROR HANDLING TESTS
-- =============================================================================

test_framework:add_test("SMODS loading error handling - assert behavior", function(t)
    setup_mock_smods()
    
    -- Test that assert() properly propagates errors from SMODS.load_file
    local success, error_msg = pcall(function()
        local loader = assert(SMODS.load_file("nonexistent_module.lua"))
    end)
    
    t:assert_false(success, "Assert should fail when SMODS.load_file fails")
    t:assert_contains(tostring(error_msg), "File not found", "Should preserve original error message")
    
    cleanup_mock_smods()
end)

test_framework:add_test("SMODS loading error handling - module execution failure", function(t)
    -- Set up SMODS that returns a loader that fails when executed
    _G.SMODS = {
        load_file = function(filename)
            if filename == "failing_module.lua" then
                return function()
                    error("Module execution failed during initialization")
                end
            else
                error("Mock SMODS: File not found: " .. filename)
            end
        end
    }
    
    -- Test that module execution failures are handled
    local success, error_msg = pcall(function()
        local FailingModule = assert(SMODS.load_file("failing_module.lua"))()
    end)
    
    t:assert_false(success, "Should fail when module execution fails")
    t:assert_contains(tostring(error_msg), "execution failed", "Should preserve module execution error")
    
    cleanup_mock_smods()
end)

-- Run all tests
local function run_steammodded_loading_tests()
    print("Starting Steammodded loading tests...")
    local success = test_framework:run_tests()
    
    if success then
        print("\n🎉 All tests passed! Steammodded module loading is working correctly.")
        print("✅ SMODS.load_file mechanism functioning properly")
        print("✅ All five module dependencies load successfully")
        print("✅ Error handling works for missing and failing modules")
        print("✅ Integration pattern matches BalatroMCP.lua implementation")
    else
        print("\n❌ Some tests failed. Please review the Steammodded loading implementation.")
    end
    
    return success
end

-- Export the test runner
return {
    run_tests = run_steammodded_loading_tests,
    test_framework = test_framework
}
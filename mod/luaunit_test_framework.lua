-- LuaUnit Compatibility Layer for Balatro MCP Mod
-- Provides a wrapper that maintains the current TestFramework API
-- Maps current assertions to luaunit equivalents while handling parameter order differences

local luaunit = require('luaunit')

-- TestFramework compatibility wrapper
local TestFramework = {}
TestFramework.__index = TestFramework

function TestFramework.new()
    local self = setmetatable({}, TestFramework)
    self.tests = {}
    self.passed = 0
    self.failed = 0
    self.current_test = ""
    self.luaunit_runner = luaunit.LuaUnit:new()
    return self
end

-- Add test method (maintains current API)
function TestFramework:add_test(name, test_func)
    table.insert(self.tests, {name = name, func = test_func})
end

-- Assertion methods (maintains current API with parameter order preservation)
-- Current framework uses (expected, actual) order, luaunit uses (actual, expected)
-- We need to swap parameters when calling luaunit

function TestFramework:assert_equal(expected, actual, message)
    -- Swap parameters: current API is (expected, actual), luaunit is (actual, expected)
    luaunit.assertEquals(actual, expected, message)
end

function TestFramework:assert_true(condition, message)
    luaunit.assertTrue(condition, message)
end

function TestFramework:assert_false(condition, message)
    luaunit.assertFalse(condition, message)
end

function TestFramework:assert_nil(value, message)
    luaunit.assertNil(value, message)
end

function TestFramework:assert_not_nil(value, message)
    luaunit.assertNotNil(value, message)
end

function TestFramework:assert_type(expected_type, value, message)
    -- Swap parameters: current API is (expected_type, value), luaunit is (value, expected_type)
    luaunit.assertType(value, expected_type, message)
end

function TestFramework:assert_contains(haystack, needle, message)
    if type(haystack) == "string" then
        luaunit.assertStrContains(haystack, needle, message)
    else
        error("assert_contains only supports string search in compatibility mode")
    end
end

function TestFramework:assert_match(text, pattern, message)
    luaunit.assertStrMatches(text, pattern, message)
end

-- Run tests method (maintains current API and behavior)
function TestFramework:run_tests()
    print("=== RUNNING TESTS (LuaUnit Compatibility Mode) ===")
    
    for _, test in ipairs(self.tests) do
        self.current_test = test.name
        local success, error_msg = pcall(test.func, self)
        
        if success then
            print("✓ " .. test.name)
            self.passed = self.passed + 1
        else
            print("✗ " .. test.name .. " - " .. tostring(error_msg))
            self.failed = self.failed + 1
        end
    end
    
    print(string.format("\n=== TEST RESULTS ===\nPassed: %d\nFailed: %d\nTotal: %d", 
        self.passed, self.failed, self.passed + self.failed))
    
    return self.failed == 0
end

-- LuaUnit Test Class Wrapper
-- This allows converting a TestFramework-based test to a LuaUnit test class
local LuaUnitTestClass = {}
LuaUnitTestClass.__index = LuaUnitTestClass

function LuaUnitTestClass:new(test_framework_instance)
    local self = setmetatable({}, LuaUnitTestClass)
    self.test_framework = test_framework_instance
    self.class_name = "LuaUnitTestClass"
    
    -- Convert TestFramework tests to LuaUnit test methods
    for i, test in ipairs(test_framework_instance.tests) do
        local method_name = "test" .. string.format("%03d", i) .. "_" .. test.name:gsub("[^%w]", "_")
        self[method_name] = function(instance)
            test.func(test_framework_instance)
        end
    end
    
    return self
end

-- Factory function to create LuaUnit-compatible test classes from TestFramework
function TestFramework:to_luaunit_class()
    return LuaUnitTestClass:new(self)
end

-- Hybrid runner that can run both TestFramework and LuaUnit styles
function TestFramework:run_with_luaunit()
    local test_class = self:to_luaunit_class()
    local runner = luaunit.LuaUnit:new()
    runner.verbosity = 2
    
    runner:runTestClass(test_class)
    
    -- Update our counters based on LuaUnit results
    local results = runner.result
    self.passed = results.run_tests - results.failed_tests - results.error_tests
    self.failed = results.failed_tests + results.error_tests
    
    runner:displayResults()
    
    return self.failed == 0
end

-- Export the compatibility layer
return {
    TestFramework = TestFramework,
    LuaUnitTestClass = LuaUnitTestClass,
    
    -- Re-export luaunit for direct access
    luaunit = luaunit,
    
    -- Convenience function for creating test framework instances
    new = function()
        return TestFramework.new()
    end,
    
    -- Migration helper functions
    create_test_framework = function()
        return TestFramework.new()
    end,
    
    convert_to_luaunit = function(test_framework_instance)
        return test_framework_instance:to_luaunit_class()
    end
}
-- Unit tests for CrashDiagnostics module
-- Tests object validation, hook safety, emergency diagnostics, and crash pattern detection

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

function TestFramework:assert_match(text, pattern, message)
    if not string.find(tostring(text), pattern) then
        error(string.format("ASSERTION FAILED: %s\nText '%s' does not match pattern '%s'",
            message or "", tostring(text), tostring(pattern)))
    end
end

function TestFramework:run_tests()
    print("=== RUNNING CRASH DIAGNOSTICS UNIT TESTS ===")
    
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

-- Load the CrashDiagnostics module
local CrashDiagnostics = assert(SMODS.load_file("crash_diagnostics.lua"))()
local test_framework = TestFramework.new()

-- Setup function to create clean test environment
local function setup_test_environment()
    -- Mock global G object with various corruption scenarios
    _G.G = {
        STATE = 1,
        hand = {
            cards = {}
        },
        jokers = {
            cards = {}
        },
        deck = {},
        FUNCS = {
            evaluate_play = function() end,
            play_cards_from_highlighted = function() end
        },
        STATES = {
            MENU = 0,
            PLAYING = 1,
            SHOP = 2
        }
    }
    
    -- Mock love.timer for hook chain timing
    _G.love = _G.love or {}
    _G.love.timer = _G.love.timer or {}
    _G.love.timer.getTime = function() return os.clock() end
    
    -- Mock os functions for consistent testing
    _G.os = _G.os or {}
    _G.os.date = function(format) return "12:34:56" end
    _G.os.time = function() return 1234567890 end
end

-- Helper functions to create test objects
local function create_valid_joker(key, name)
    return {
        config = {
            center = {
                key = key or "j_joker",
                name = name or "Joker"
            }
        },
        unique_val = math.random(1000, 9999),
        sell_cost = 3,
        T = { x = 0 }
    }
end

local function create_corrupted_joker_no_config()
    return {
        unique_val = math.random(1000, 9999),
        sell_cost = 3
        -- Missing config field
    }
end

local function create_corrupted_joker_no_center()
    return {
        config = {
            -- Missing center field
        },
        unique_val = math.random(1000, 9999)
    }
end

local function create_corrupted_joker_no_key()
    return {
        config = {
            center = {
                name = "Corrupted Joker"
                -- Missing key field
            }
        },
        unique_val = math.random(1000, 9999)
    }
end

-- === OBJECT VALIDATION TESTS ===

test_framework:add_test("CrashDiagnostics.new creates instance with correct initial state", function(t)
    setup_test_environment()
    
    local diagnostics = CrashDiagnostics.new()
    
    t:assert_not_nil(diagnostics, "CrashDiagnostics instance should be created")
    t:assert_equal(diagnostics.hook_call_count, 0, "Initial hook call count should be 0")
    t:assert_equal(diagnostics.object_access_count, 0, "Initial object access count should be 0")
    t:assert_equal(diagnostics.last_hook_called, "none", "Initial last hook should be 'none'")
    t:assert_equal(diagnostics.last_object_accessed, "none", "Initial last object accessed should be 'none'")
end)

test_framework:add_test("validate_object_config detects nil object", function(t)
    setup_test_environment()
    
    local diagnostics = CrashDiagnostics.new()
    local result = diagnostics:validate_object_config(nil, "test_object", "test_operation")
    
    t:assert_false(result, "Should return false for nil object")
    t:assert_equal(diagnostics.object_access_count, 1, "Should increment object access count")
    t:assert_match(diagnostics.last_object_accessed, "test_object at test_operation", "Should record object access")
end)

test_framework:add_test("validate_object_config detects nil config field", function(t)
    setup_test_environment()
    
    local diagnostics = CrashDiagnostics.new()
    local corrupted_joker = create_corrupted_joker_no_config()
    local result = diagnostics:validate_object_config(corrupted_joker, "corrupted_joker", "test_validation")
    
    t:assert_false(result, "Should return false for object with nil config")
    t:assert_equal(diagnostics.object_access_count, 1, "Should increment object access count")
end)

test_framework:add_test("validate_object_config passes for valid object", function(t)
    setup_test_environment()
    
    local diagnostics = CrashDiagnostics.new()
    local valid_joker = create_valid_joker("j_joker", "Joker")
    local result = diagnostics:validate_object_config(valid_joker, "valid_joker", "test_validation")
    
    t:assert_true(result, "Should return true for valid object with config")
    t:assert_equal(diagnostics.object_access_count, 1, "Should increment object access count")
end)

test_framework:add_test("validate_object_config logs available properties for corrupted objects", function(t)
    setup_test_environment()
    
    local diagnostics = CrashDiagnostics.new()
    local corrupted_joker = {
        unique_val = 1234,
        sell_cost = 5,
        some_field = "test"
        -- Missing config
    }
    
    -- Capture print output to verify diagnostic logging
    local print_calls = {}
    local original_print = print
    _G.print = function(msg) table.insert(print_calls, msg) end
    
    local result = diagnostics:validate_object_config(corrupted_joker, "test_joker", "property_test")
    
    _G.print = original_print
    
    t:assert_false(result, "Should return false for corrupted object")
    
    -- Check that diagnostic information was logged
    local found_properties_log = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "properties:") then
            found_properties_log = true
            t:assert_match(msg, "unique_val:number", "Should log unique_val property")
            t:assert_match(msg, "sell_cost:number", "Should log sell_cost property")
            break
        end
    end
    t:assert_true(found_properties_log, "Should log available properties for corrupted objects")
end)

-- === HOOK SAFETY TESTS ===

test_framework:add_test("pre_hook_validation detects nil G object", function(t)
    setup_test_environment()
    
    local diagnostics = CrashDiagnostics.new()
    _G.G = nil  -- Simulate G object corruption
    
    local result = diagnostics:pre_hook_validation("test_hook")
    
    t:assert_false(result, "Should return false when G object is nil")
    t:assert_equal(diagnostics.hook_call_count, 1, "Should increment hook call count")
    t:assert_equal(diagnostics.last_hook_called, "test_hook", "Should record hook name")
end)

test_framework:add_test("pre_hook_validation detects nil G.STATE", function(t)
    setup_test_environment()
    
    local diagnostics = CrashDiagnostics.new()
    _G.G.STATE = nil  -- Simulate STATE corruption
    
    local result = diagnostics:pre_hook_validation("test_hook")
    
    t:assert_false(result, "Should return false when G.STATE is nil")
    t:assert_equal(diagnostics.hook_call_count, 1, "Should increment hook call count")
end)

test_framework:add_test("pre_hook_validation validates hand cards for card hooks", function(t)
    setup_test_environment()
    
    local diagnostics = CrashDiagnostics.new()
    
    -- Add corrupted card to test validation
    G.hand.cards = {
        create_valid_joker("j_card", "Card"),
        create_corrupted_joker_no_config()  -- This should cause validation to fail
    }
    
    local result = diagnostics:pre_hook_validation("play_cards_test")
    
    t:assert_false(result, "Should return false when hand contains corrupted cards")
end)

test_framework:add_test("pre_hook_validation validates jokers for joker hooks", function(t)
    setup_test_environment()
    
    local diagnostics = CrashDiagnostics.new()
    
    -- Add mixed valid and corrupted jokers
    G.jokers.cards = {
        create_valid_joker("j_blueprint", "Blueprint"),
        create_corrupted_joker_no_center(),  -- This should cause validation to fail
        create_valid_joker("j_brainstorm", "Brainstorm")
    }
    
    local result = diagnostics:pre_hook_validation("joker_test_hook")
    
    t:assert_false(result, "Should return false when jokers contain corrupted objects")
end)

test_framework:add_test("pre_hook_validation passes for valid game state", function(t)
    setup_test_environment()
    
    local diagnostics = CrashDiagnostics.new()
    
    -- Setup valid game state
    G.hand.cards = { create_valid_joker("j_card", "Card") }
    G.jokers.cards = { create_valid_joker("j_joker", "Joker") }
    
    local result = diagnostics:pre_hook_validation("valid_hook_test")
    
    t:assert_true(result, "Should return true for valid game state")
end)

test_framework:add_test("create_safe_hook wraps function with error handling", function(t)
    setup_test_environment()
    
    local diagnostics = CrashDiagnostics.new()
    
    -- Create a function that throws an error
    local error_function = function() error("Test error") end
    local safe_hook = diagnostics:create_safe_hook(error_function, "error_test_hook")
    
    -- Capture print output to verify error handling
    local print_calls = {}
    local original_print = print
    _G.print = function(msg) table.insert(print_calls, msg) end
    
    local result = safe_hook()
    
    _G.print = original_print
    
    t:assert_nil(result, "Should return nil when wrapped function errors")
    
    -- Check that error was logged
    local found_error_log = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "ERROR: Hook error_test_hook failed") then
            found_error_log = true
            break
        end
    end
    t:assert_true(found_error_log, "Should log hook errors")
end)

test_framework:add_test("create_safe_hook skips execution on pre-hook validation failure", function(t)
    setup_test_environment()
    
    local diagnostics = CrashDiagnostics.new()
    _G.G = nil  -- Force pre-hook validation to fail
    
    local function_called = false
    local test_function = function() function_called = true end
    local safe_hook = diagnostics:create_safe_hook(test_function, "validation_skip_test")
    
    safe_hook()
    
    t:assert_false(function_called, "Original function should not be called when pre-hook validation fails")
end)

-- === HOOK CHAIN TRACKING TESTS ===

test_framework:add_test("track_hook_chain maintains hook history", function(t)
    setup_test_environment()
    
    local diagnostics = CrashDiagnostics.new()
    
    diagnostics:track_hook_chain("hook1")
    diagnostics:track_hook_chain("hook2")
    diagnostics:track_hook_chain("hook3")
    
    t:assert_not_nil(diagnostics.hook_chain, "Hook chain should be initialized")
    t:assert_equal(#diagnostics.hook_chain, 3, "Should track all hook calls")
    t:assert_equal(diagnostics.hook_chain[1].hook, "hook1", "Should maintain hook order")
    t:assert_equal(diagnostics.hook_chain[3].hook, "hook3", "Should record latest hook")
end)

test_framework:add_test("track_hook_chain limits chain length to 10", function(t)
    setup_test_environment()
    
    local diagnostics = CrashDiagnostics.new()
    
    -- Add more than 10 hooks
    for i = 1, 15 do
        diagnostics:track_hook_chain("hook" .. i)
    end
    
    t:assert_equal(#diagnostics.hook_chain, 10, "Should limit hook chain to 10 entries")
    t:assert_equal(diagnostics.hook_chain[1].hook, "hook6", "Should remove oldest entries")
    t:assert_equal(diagnostics.hook_chain[10].hook, "hook15", "Should keep newest entries")
end)

test_framework:add_test("analyze_hook_chain detects rapid hook calls", function(t)
    setup_test_environment()
    
    local diagnostics = CrashDiagnostics.new()
    
    -- Simulate rapid calls to same hook
    diagnostics:track_hook_chain("rapid_hook")
    diagnostics:track_hook_chain("rapid_hook")
    diagnostics:track_hook_chain("other_hook")
    diagnostics:track_hook_chain("rapid_hook")
    
    local analysis = diagnostics:analyze_hook_chain()
    
    t:assert_match(analysis, "rapid_hook", "Should include hook name in analysis")
    t:assert_match(analysis, "WARNING.*Rapid calls", "Should detect rapid calls pattern")
end)

test_framework:add_test("analyze_hook_chain handles empty hook chain", function(t)
    setup_test_environment()
    
    local diagnostics = CrashDiagnostics.new()
    
    local analysis = diagnostics:analyze_hook_chain()
    
    t:assert_match(analysis, "No hook chain data available", "Should handle empty hook chain gracefully")
end)

-- === GAME STATE VALIDATION TESTS ===

test_framework:add_test("validate_game_state detects critical object corruption", function(t)
    setup_test_environment()
    
    local diagnostics = CrashDiagnostics.new()
    _G.G.hand = nil  -- Corrupt critical game object
    
    local result = diagnostics:validate_game_state("critical_operation")
    
    t:assert_true(result, "Should still return true but log warnings for missing non-critical objects")
end)

test_framework:add_test("validate_game_state handles non-number G.STATE", function(t)
    setup_test_environment()
    
    local diagnostics = CrashDiagnostics.new()
    _G.G.STATE = "invalid_state"  -- G.STATE should be a number
    
    -- Capture print output to verify warning
    local print_calls = {}
    local original_print = print
    _G.print = function(msg) table.insert(print_calls, msg) end
    
    local result = diagnostics:validate_game_state("state_type_test")
    
    _G.print = original_print
    
    t:assert_true(result, "Should return true but warn about invalid state type")
    
    local found_warning = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "WARNING.*G.STATE is not a number") then
            found_warning = true
            break
        end
    end
    t:assert_true(found_warning, "Should warn about non-number G.STATE")
end)

-- === EMERGENCY STATE DUMP TESTS ===

test_framework:add_test("emergency_state_dump handles nil G object", function(t)
    setup_test_environment()
    
    local diagnostics = CrashDiagnostics.new()
    _G.G = nil
    
    -- Capture print output
    local print_calls = {}
    local original_print = print
    _G.print = function(msg) table.insert(print_calls, msg) end
    
    diagnostics:emergency_state_dump()
    
    _G.print = original_print
    
    local found_nil_g_log = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "G object is nil") then
            found_nil_g_log = true
            break
        end
    end
    t:assert_true(found_nil_g_log, "Should log when G object is nil")
end)

test_framework:add_test("emergency_state_dump analyzes joker corruption", function(t)
    setup_test_environment()
    
    local diagnostics = CrashDiagnostics.new()
    
    -- Setup mixed joker states
    G.jokers.cards = {
        create_valid_joker("j_blueprint", "Blueprint"),
        create_corrupted_joker_no_config(),
        nil,  -- Complete nil joker
        create_corrupted_joker_no_key()
    }
    
    -- Capture print output
    local print_calls = {}
    local original_print = print
    _G.print = function(msg) table.insert(print_calls, msg) end
    
    diagnostics:emergency_state_dump()
    
    _G.print = original_print
    
    -- Verify different corruption types are detected
    local corruption_types = {
        blueprint = false,
        corrupted_config = false,
        nil_joker = false
    }
    
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "j_blueprint") then
            corruption_types.blueprint = true
        elseif string.find(msg, "corrupted_config") then
            corruption_types.corrupted_config = true
        elseif string.find(msg, "nil_joker") then
            corruption_types.nil_joker = true
        end
    end
    
    t:assert_true(corruption_types.blueprint, "Should detect valid Blueprint joker")
    t:assert_true(corruption_types.corrupted_config, "Should detect corrupted config")
    t:assert_true(corruption_types.nil_joker, "Should detect nil joker")
end)

test_framework:add_test("emergency_state_dump includes hook chain analysis", function(t)
    setup_test_environment()
    
    local diagnostics = CrashDiagnostics.new()
    
    -- Add some hooks to the chain
    diagnostics:track_hook_chain("test_hook1")
    diagnostics:track_hook_chain("test_hook2")
    
    -- Capture print output
    local print_calls = {}
    local original_print = print
    _G.print = function(msg) table.insert(print_calls, msg) end
    
    diagnostics:emergency_state_dump()
    
    _G.print = original_print
    
    local found_hook_analysis = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "Hook chain analysis") then
            found_hook_analysis = true
            break
        end
    end
    t:assert_true(found_hook_analysis, "Should include hook chain analysis in emergency dump")
end)

-- === CONTEXT TRACKING TESTS ===

test_framework:add_test("get_crash_context provides comprehensive crash information", function(t)
    setup_test_environment()
    
    local diagnostics = CrashDiagnostics.new()
    
    -- Setup some state
    diagnostics:pre_hook_validation("test_hook")
    diagnostics:validate_object_config(create_valid_joker(), "test_joker", "context_test")
    diagnostics:track_hook_chain("context_hook")
    
    local context = diagnostics:get_crash_context()
    
    t:assert_not_nil(context, "Should return crash context")
    t:assert_equal(context.last_hook_called, "test_hook", "Should include last hook called")
    t:assert_equal(context.hook_call_count, 1, "Should include hook call count")
    t:assert_match(context.last_object_accessed, "test_joker at context_test", "Should include last object accessed")
    t:assert_equal(context.object_access_count, 1, "Should include object access count")
    t:assert_not_nil(context.hook_chain, "Should include hook chain")
    t:assert_not_nil(context.timestamp, "Should include timestamp")
    t:assert_type(context.emergency_dump, "function", "Should include emergency dump function")
end)

-- === INTEGRATION TESTS ===

test_framework:add_test("monitor_joker_operations detects and logs corrupted jokers", function(t)
    setup_test_environment()
    
    local diagnostics = CrashDiagnostics.new()
    
    -- Setup jokers with various corruption types
    G.jokers.cards = {
        create_valid_joker("j_joker", "Good Joker"),
        create_corrupted_joker_no_config(),
        create_corrupted_joker_no_center()
    }
    
    -- Capture print output
    local print_calls = {}
    local original_print = print
    _G.print = function(msg) table.insert(print_calls, msg) end
    
    diagnostics:monitor_joker_operations()
    
    _G.print = original_print
    
    -- Check that corruption was detected and logged
    local found_corruption_log = false
    local found_scanning_log = false
    
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "MONITORING.*Scanning.*jokers") then
            found_scanning_log = true
        elseif string.find(msg, "CRITICAL.*Found corrupted joker") then
            found_corruption_log = true
        end
    end
    
    t:assert_true(found_scanning_log, "Should log joker scanning activity")
    t:assert_true(found_corruption_log, "Should detect and log corrupted jokers")
end)

-- Run all tests
print("Running CrashDiagnostics unit tests...")
test_framework:run_tests()
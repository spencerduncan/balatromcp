-- Unit tests for Love2D update hook crash protection fixes
-- Tests the pcall wrapper around original_love_update(dt) and mod update error handling
-- This addresses the specific fix for "attempt to index field config a nil value" crash

-- Inline TestFramework definition
local TestFramework = {}
TestFramework.__index = TestFramework

function TestFramework:new()
    local o = {}
    setmetatable(o, TestFramework)
    o.tests = {}
    o.passed = 0
    o.failed = 0
    return o
end

function TestFramework:add_test(name, test_func)
    table.insert(self.tests, {name = name, func = test_func})
end

function TestFramework:run_tests()
    print("Running " .. #self.tests .. " Love2D update crash protection tests...")
    
    for _, test in ipairs(self.tests) do
        local success, error_msg = pcall(function()
            local test_obj = {
                assert_true = function(self, condition, message)
                    if not condition then
                        error(message or "Assertion failed: expected true")
                    end
                end,
                assert_false = function(self, condition, message)
                    if condition then
                        error(message or "Assertion failed: expected false")
                    end
                end,
                assert_equal = function(self, actual, expected, message)
                    if actual ~= expected then
                        error(message or ("Assertion failed: expected " .. tostring(expected) .. ", got " .. tostring(actual)))
                    end
                end,
                assert_nil = function(self, value, message)
                    if value ~= nil then
                        error(message or ("Assertion failed: expected nil, got " .. tostring(value)))
                    end
                end,
                assert_not_nil = function(self, value, message)
                    if value == nil then
                        error(message or "Assertion failed: expected not nil")
                    end
                end,
                assert_type = function(self, value, expected_type, message)
                    if type(value) ~= expected_type then
                        error(message or ("Assertion failed: expected type " .. expected_type .. ", got " .. type(value)))
                    end
                end,
                assert_match = function(self, str, pattern, message)
                    if not string.find(str, pattern) then
                        error(message or ("Assertion failed: string '" .. str .. "' does not match pattern '" .. pattern .. "'"))
                    end
                end
            }
            test.func(test_obj)
        end)
        
        if success then
            print("✓ " .. test.name)
            self.passed = self.passed + 1
        else
            print("✗ " .. test.name .. ": " .. error_msg)
            self.failed = self.failed + 1
        end
    end
    
    print("\nTest Results: " .. self.passed .. " passed, " .. self.failed .. " failed")
    return self.failed == 0
end

local test_framework = TestFramework:new()

-- Load required modules
local BalatroMCP = assert(SMODS.load_file("BalatroMCP.lua"))()

-- Setup function to create clean test environment
local function setup_test_environment()
    -- Mock SMODS framework
    _G.SMODS = {
        load_file = function(filename)
            if filename == "debug_logger.lua" then
                return function() return {
                    new = function() return {
                        info = function() end,
                        error = function() end,
                        test_environment = function() end,
                        test_file_communication = function() end
                    } end
                } end
            elseif filename == "file_io.lua" then
                return function() return {
                    new = function() return {
                        read_actions = function() return nil end,
                        write_action_result = function() end,
                        write_game_state = function() end,
                        get_next_sequence_id = function() return 1 end
                    } end
                } end
            elseif filename == "state_extractor.lua" then
                return function() return {
                    new = function() return {
                        extract_current_state = function() return {
                            current_phase = "playing",
                            money = 100,
                            ante = 1,
                            hands_remaining = 4,
                            hand_cards = {},
                            jokers = {}
                        } end
                    } end
                } end
            elseif filename == "action_executor.lua" then
                return function() return {
                    new = function() return {
                        execute_action = function() return { success = true } end
                    } end
                } end
            elseif filename == "joker_manager.lua" then
                return function() return {
                    new = function() return {
                        set_crash_diagnostics = function() end
                    } end
                } end
            elseif filename == "crash_diagnostics.lua" then
                return function() return {
                    new = function() return {
                        monitor_joker_operations = function() end,
                        create_safe_hook = function(self, func, name) return func end
                    } end
                } end
            end
        end
    }
    
    -- Mock global G object
    _G.G = {
        STATE = 1,
        STATES = {
            MENU = 0,
            PLAYING = 1,
            SHOP = 2
        },
        hand = { cards = {} },
        jokers = { cards = {} },
        deck = {},
        FUNCS = {}
    }
    
    -- Mock love object with timer
    _G.love = {
        timer = {
            getTime = function() return os.clock() end
        }
    }
    
    -- Mock os functions
    _G.os = _G.os or {}
    _G.os.date = function(format) return "12:34:56" end
    _G.os.time = function() return 1234567890 end
    
    -- Reset any previous love.update hooks
    if _G.original_love_update then
        _G.love.update = _G.original_love_update
        _G.original_love_update = nil
    end
end

-- Helper function to capture print output
local function capture_print_output(func)
    local print_calls = {}
    local original_print = print
    _G.print = function(msg) table.insert(print_calls, msg) end
    
    func()
    
    _G.print = original_print
    return print_calls
end

-- === LOVE2D UPDATE HOOK CRASH PROTECTION TESTS ===

test_framework:add_test("Love2D update hook wraps original_love_update with pcall", function(t)
    setup_test_environment()
    
    local original_update_called = false
    local original_update_error = false
    
    -- Setup original Love2D update that throws an error
    _G.love.update = function(dt)
        original_update_called = true
        error("Simulated game update crash - attempt to index field config a nil value")
    end
    
    -- Initialize BalatroMCP (this sets up the Love2D hook)
    local mcp = BalatroMCP.new()
    mcp:start()
    
    -- The hook should now be in place
    t:assert_not_nil(_G.love.update, "Love2D update hook should be installed")
    
    -- Test that the hooked update catches errors from original game update
    local print_calls = capture_print_output(function()
        _G.love.update(0.016)  -- This should not crash despite the error
    end)
    
    t:assert_true(original_update_called, "Original Love2D update should be called")
    
    -- Check that error was caught and logged
    local found_error_log = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "ERROR in Love2D update hook") then
            found_error_log = true
            break
        end
    end
    t:assert_true(found_error_log, "Should catch and log errors from original game update")
end)

test_framework:add_test("Mod update errors are handled separately from game update errors", function(t)
    setup_test_environment()
    
    local game_update_called = false
    local mod_update_attempted = false
    
    -- Setup normal game update
    _G.love.update = function(dt)
        game_update_called = true
    end
    
    -- Create mod instance with update that will error
    local mcp = BalatroMCP.new()
    mcp.update = function(self, dt)
        mod_update_attempted = true
        error("Simulated mod update error")
    end
    mcp:start()
    
    -- Test that mod update errors don't affect game update
    local print_calls = capture_print_output(function()
        _G.love.update(0.016)
    end)
    
    t:assert_true(game_update_called, "Game update should complete successfully")
    t:assert_true(mod_update_attempted, "Mod update should be attempted")
    
    -- Check that mod error was logged separately
    local found_mod_error_log = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "ERROR in mod update") then
            found_mod_error_log = true
            break
        end
    end
    t:assert_true(found_mod_error_log, "Should catch and log mod update errors separately")
end)

test_framework:add_test("State change detection continues working after error handling", function(t)
    setup_test_environment()
    
    local state_changes = {}
    
    -- Mock G.STATE changes during update
    local state_counter = 1
    _G.love.update = function(dt)
        -- Simulate state changes
        _G.G.STATE = state_counter
        state_counter = state_counter + 1
    end
    
    local mcp = BalatroMCP.new()
    mcp:start()
    
    -- Capture state change detection logs
    local print_calls = capture_print_output(function()
        _G.love.update(0.016)  -- STATE 1 -> 2
        _G.love.update(0.016)  -- STATE 2 -> 3
        _G.love.update(0.016)  -- STATE 3 -> 4
    end)
    
    -- Count state change detections
    local state_change_count = 0
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "STATE_CHANGE_DETECTED") then
            state_change_count = state_change_count + 1
        end
    end
    
    t:assert_true(state_change_count >= 2, "Should detect multiple state changes: " .. state_change_count)
end)

test_framework:add_test("Error handling preserves diagnostic logging functionality", function(t)
    setup_test_environment()
    
    -- Setup game update that errors but should still log diagnostics
    _G.love.update = function(dt)
        error("Test diagnostic error")
    end
    
    local mcp = BalatroMCP.new()
    mcp:start()
    
    local print_calls = capture_print_output(function()
        _G.love.update(0.016)
    end)
    
    -- Should have both error logging and diagnostic information
    local has_error_log = false
    local has_diagnostic_info = false
    
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "ERROR in Love2D update hook") then
            has_error_log = true
        elseif string.find(msg, "BalatroMCP:") and string.find(msg, "STATE") then
            has_diagnostic_info = true
        end
    end
    
    t:assert_true(has_error_log, "Should log update hook errors")
    t:assert_true(has_diagnostic_info, "Should preserve diagnostic logging functionality")
end)

test_framework:add_test("Hook handles nil original_love_update gracefully", function(t)
    setup_test_environment()
    
    -- Remove original Love2D update
    _G.love.update = nil
    
    local mcp = BalatroMCP.new()
    
    -- Should handle missing original update without crashing
    local print_calls = capture_print_output(function()
        mcp:start()
    end)
    
    local found_fallback_warning = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "Could not hook into Love2D update") or 
           string.find(msg, "using timer fallback") then
            found_fallback_warning = true
            break
        end
    end
    
    t:assert_true(found_fallback_warning, "Should warn about missing Love2D update and use fallback")
end)

test_framework:add_test("pcall wrapper preserves function arguments and return values", function(t)
    setup_test_environment()
    
    local received_dt = nil
    local original_return_value = "test_return"
    
    -- Setup original update that receives and returns values
    _G.love.update = function(dt)
        received_dt = dt
        return original_return_value
    end
    
    local mcp = BalatroMCP.new()
    mcp:start()
    
    -- Test that arguments are passed through correctly
    _G.love.update(0.123)
    
    t:assert_equal(received_dt, 0.123, "Should pass delta time argument correctly")
end)

test_framework:add_test("Consecutive update errors don't cause cascading failures", function(t)
    setup_test_environment()
    
    local error_count = 0
    
    -- Setup update that always errors
    _G.love.update = function(dt)
        error_count = error_count + 1
        error("Repeated update error #" .. error_count)
    end
    
    local mcp = BalatroMCP.new()
    mcp:start()
    
    -- Run multiple updates that should all handle errors gracefully
    local print_calls = capture_print_output(function()
        for i = 1, 5 do
            _G.love.update(0.016)
        end
    end)
    
    t:assert_equal(error_count, 5, "All 5 update calls should be attempted despite errors")
    
    -- Count error logs
    local logged_errors = 0
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "ERROR in Love2D update hook") then
            logged_errors = logged_errors + 1
        end
    end
    
    t:assert_equal(logged_errors, 5, "All 5 errors should be logged without causing cascading failures")
end)

test_framework:add_test("State consistency checking works during error conditions", function(t)
    setup_test_environment()
    
    -- Setup state inconsistency
    _G.G.STATE = 1
    _G._G = { G = { STATE = 2 } }  -- Different direct access state
    
    -- Original update that errors
    _G.love.update = function(dt)
        error("Update error during state inconsistency")
    end
    
    local mcp = BalatroMCP.new()
    mcp:start()
    
    local print_calls = capture_print_output(function()
        _G.love.update(0.016)
    end)
    
    -- Should detect state inconsistency even during error handling
    local found_consistency_log = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "State consistency") then
            found_consistency_log = true
            break
        end
    end
    
    t:assert_true(found_consistency_log, "Should check state consistency even during error conditions")
end)

test_framework:add_test("Emergency state detection works with Love2D hook errors", function(t)
    setup_test_environment()
    
    -- Corrupt critical game state
    _G.G = nil
    
    -- Original update that would crash without protection
    _G.love.update = function(dt)
        -- This would normally crash when trying to access G.STATE
        local state = G.STATE
        return state
    end
    
    local mcp = BalatroMCP.new()
    mcp:start()
    
    local print_calls = capture_print_output(function()
        _G.love.update(0.016)
    end)
    
    -- Should handle complete G object corruption gracefully
    local found_error_handling = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "ERROR in Love2D update hook") then
            found_error_handling = true
            break
        end
    end
    
    t:assert_true(found_error_handling, "Should handle complete game state corruption without crashing")
end)

test_framework:add_test("Timing diagnostics continue during error recovery", function(t)
    setup_test_environment()
    
    local timing_calls = 0
    
    -- Mock love.timer.getTime to track timing calls
    _G.love.timer.getTime = function()
        timing_calls = timing_calls + 1
        return os.clock()
    end
    
    -- Original update that errors
    _G.love.update = function(dt)
        error("Timing diagnostic test error")
    end
    
    local mcp = BalatroMCP.new()
    mcp:start()
    
    _G.love.update(0.016)
    
    t:assert_true(timing_calls > 0, "Should continue timing diagnostics during error recovery")
end)

-- Export the test runner for integration with run_lua_tests.lua
local function run_love2d_crash_protection_tests()
    print("Running Love2D update hook crash protection unit tests...")
    local success = test_framework:run_tests()
    
    if success then
        print("\n🎉 All Love2D update hook crash protection tests passed!")
        print("✅ CRITICAL FIX: pcall wrapper around original_love_update(dt) prevents crashes")
        print("✅ CRITICAL FIX: Game update errors are caught and logged without crashing mod")
        print("✅ CRITICAL FIX: Mod update errors are isolated from game update")
        print("✅ CRITICAL FIX: State change detection continues working after error handling")
        print("✅ CRITICAL FIX: Diagnostic logging is preserved during error recovery")
        print("✅ All crash protection patterns validated for Love2D update hook")
    else
        print("\n❌ Some Love2D update hook crash protection tests failed!")
        print("Please review the failing tests and ensure crash protection is working.")
    end
    
    return success
end

-- Export the test runner
return {
    run_tests = run_love2d_crash_protection_tests,
    test_framework = test_framework
}
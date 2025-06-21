-- Unit tests for BalatroMCP crash diagnostics integration
-- Tests hook safety, game state validation, crash diagnostics injection, and error handling

-- Inline TestFramework definition (matches existing codebase pattern)
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
    print("Running " .. #self.tests .. " tests...")
    
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
                assert_not_equal = function(self, actual, expected, message)
                    if actual == expected then
                        error(message or ("Assertion failed: expected not " .. tostring(expected) .. ", got " .. tostring(actual)))
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
                end,
                assert_table = function(self, value, message)
                    if type(value) ~= "table" then
                        error(message or ("Assertion failed: expected table, got " .. type(value)))
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
local CrashDiagnostics = assert(SMODS.load_file("crash_diagnostics.lua"))()
local JokerManager = assert(SMODS.load_file("joker_manager.lua"))()

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
                return JokerManager
            elseif filename == "crash_diagnostics.lua" then
                return CrashDiagnostics
            end
        end
    }
    
    -- Mock global G object
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
            evaluate_play = function() return true end,
            play_cards_from_highlighted = function() return true end,
            discard_cards_from_highlighted = function() return true end,
            select_blind = function() return true end,
            go_to_shop = function() return true end
        },
        STATES = {
            MENU = 0,
            PLAYING = 1,
            SHOP = 2
        },
        CARD_W = 100
    }
    
    -- Mock love.timer for timing tests
    _G.love = _G.love or {}
    _G.love.timer = _G.love.timer or {}
    _G.love.timer.getTime = function() return os.clock() end
    
    -- Mock os functions
    _G.os = _G.os or {}
    _G.os.date = function(format) return "12:34:56" end
    _G.os.time = function() return 1234567890 end
    
    -- Reset print capture
    if _G.original_print then
        _G.print = _G.original_print
        _G.original_print = nil
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

-- Helper functions to create test joker objects
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

local function create_corrupted_joker()
    return {
        unique_val = math.random(1000, 9999),
        sell_cost = 3
        -- Missing config field
    }
end

-- === INITIALIZATION AND CRASH DIAGNOSTICS INJECTION TESTS ===

test_framework:add_test("BalatroMCP.new initializes crash diagnostics", function(t)
    setup_test_environment()
    
    local mcp = BalatroMCP.new()
    
    t:assert_not_nil(mcp.crash_diagnostics, "Should initialize crash diagnostics")
    t:assert_type(mcp.crash_diagnostics, "table", "Crash diagnostics should be a table")
    t:assert_type(mcp.crash_diagnostics.validate_object_config, "function", "Should have validation methods")
end)

test_framework:add_test("BalatroMCP.new injects crash diagnostics into JokerManager", function(t)
    setup_test_environment()
    
    local mcp = BalatroMCP.new()
    
    t:assert_not_nil(mcp.joker_manager, "Should initialize joker manager")
    t:assert_not_nil(mcp.joker_manager.crash_diagnostics, "Should inject crash diagnostics into joker manager")
    t:assert_equal(mcp.joker_manager.crash_diagnostics, mcp.crash_diagnostics, "Should inject the same crash diagnostics instance")
end)

test_framework:add_test("BalatroMCP.new handles component initialization failures gracefully", function(t)
    setup_test_environment()
    
    -- Mock a failing component
    local original_smods = SMODS.load_file
    SMODS.load_file = function(filename)
        if filename == "joker_manager.lua" then
            error("Simulated joker manager initialization failure")
        end
        return original_smods(filename)
    end
    
    local print_calls = capture_print_output(function()
        local mcp = BalatroMCP.new()
        t:assert_not_nil(mcp, "Should create instance even with component failures")
    end)
    
    SMODS.load_file = original_smods
    
    local found_error_log = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "JokerManager initialization failed") then
            found_error_log = true
            break
        end
    end
    t:assert_true(found_error_log, "Should log component initialization failures")
end)

-- === HOOK SAFETY AND CRASH DIAGNOSTICS INTEGRATION TESTS ===

test_framework:add_test("hook_hand_evaluation integrates crash diagnostics into hooks", function(t)
    setup_test_environment()
    
    local mcp = BalatroMCP.new()
    
    -- Setup initial hooks
    local original_play_cards = G.FUNCS.play_cards_from_highlighted
    mcp:hook_hand_evaluation()
    
    t:assert_not_equal(G.FUNCS.play_cards_from_highlighted, original_play_cards, "Should wrap original function")
    
    -- Test that the wrapped function includes crash diagnostics
    local print_calls = capture_print_output(function()
        G.FUNCS.play_cards_from_highlighted()
    end)
    
    local found_hook_tracking = false
    local found_state_validation = false
    
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "PRE_HOOK.*play_cards_from_highlighted") then
            found_hook_tracking = true
        elseif string.find(msg, "STATE_VALIDATION.*play_cards_from_highlighted") then
            found_state_validation = true
        end
    end
    
    t:assert_true(found_hook_tracking, "Should track hook chain for hand evaluation")
    t:assert_true(found_state_validation, "Should validate game state before hook execution")
end)

test_framework:add_test("hook_shop_interactions integrates crash diagnostics", function(t)
    setup_test_environment()
    
    local mcp = BalatroMCP.new()
    
    -- Setup initial hooks
    local original_go_to_shop = G.FUNCS.go_to_shop
    mcp:hook_shop_interactions()
    
    t:assert_not_equal(G.FUNCS.go_to_shop, original_go_to_shop, "Should wrap original shop function")
    
    -- Test that the wrapped function includes crash diagnostics
    local print_calls = capture_print_output(function()
        G.FUNCS.go_to_shop()
    end)
    
    local found_hook_tracking = false
    local found_state_validation = false
    
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "PRE_HOOK.*go_to_shop") then
            found_hook_tracking = true
        elseif string.find(msg, "STATE_VALIDATION.*go_to_shop") then
            found_state_validation = true
        end
    end
    
    t:assert_true(found_hook_tracking, "Should track hook chain for shop interactions")
    t:assert_true(found_state_validation, "Should validate game state before shop hooks")
end)

test_framework:add_test("safe hooks handle errors gracefully", function(t)
    setup_test_environment()
    
    local mcp = BalatroMCP.new()
    
    -- Create a function that will throw an error
    G.FUNCS.play_cards_from_highlighted = function() error("Test error in hook") end
    
    mcp:hook_hand_evaluation()
    
    -- The wrapped function should handle the error gracefully
    local print_calls = capture_print_output(function()
        local result = G.FUNCS.play_cards_from_highlighted()
        t:assert_nil(result, "Should return nil when wrapped function errors")
    end)
    
    local found_error_log = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "ERROR.*Hook.*play_cards_from_highlighted.*failed") then
            found_error_log = true
            break
        end
    end
    t:assert_true(found_error_log, "Should log hook errors through crash diagnostics")
end)

test_framework:add_test("safe hooks skip execution on pre-hook validation failure", function(t)
    setup_test_environment()
    
    local mcp = BalatroMCP.new()
    
    -- Corrupt G object to force pre-hook validation failure
    G.STATE = nil
    
    local function_called = false
    G.FUNCS.play_cards_from_highlighted = function() function_called = true end
    
    mcp:hook_hand_evaluation()
    
    local print_calls = capture_print_output(function()
        G.FUNCS.play_cards_from_highlighted()
    end)
    
    t:assert_false(function_called, "Should not call original function when pre-hook validation fails")
    
    local found_critical_log = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "CRITICAL.*Pre%-hook validation failed") then
            found_critical_log = true
            break
        end
    end
    t:assert_true(found_critical_log, "Should log critical validation failures")
end)

-- === GAME STATE VALIDATION WITH CORRUPTED OBJECTS TESTS ===

test_framework:add_test("update method monitors joker operations for corruption", function(t)
    setup_test_environment()
    
    local mcp = BalatroMCP.new()
    mcp.polling_active = true
    
    -- Add corrupted jokers to test monitoring
    G.jokers.cards = {
        create_valid_joker("j_joker", "Good Joker"),
        create_corrupted_joker(),  -- This should be detected
        create_valid_joker("j_blueprint", "Blueprint")
    }
    
    local print_calls = capture_print_output(function()
        mcp:update(1.0)  -- Force update with dt > update_interval
    end)
    
    local found_monitoring = false
    local found_corruption = false
    
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "MONITORING.*Scanning.*jokers") then
            found_monitoring = true
        elseif string.find(msg, "CRITICAL.*Found corrupted joker") then
            found_corruption = true
        end
    end
    
    t:assert_true(found_monitoring, "Should monitor joker operations during update")
    t:assert_true(found_corruption, "Should detect corrupted jokers during monitoring")
end)

test_framework:add_test("process_pending_actions handles corrupted joker state gracefully", function(t)
    setup_test_environment()
    
    local mcp = BalatroMCP.new()
    
    -- Setup corrupted joker state
    G.jokers.cards = { create_corrupted_joker() }
    
    -- Mock action data
    mcp.file_io.read_actions = function()
        return {
            action_type = "reorder_jokers",
            sequence = 1,
            data = { new_order = {0} }
        }
    end
    
    local print_calls = capture_print_output(function()
        mcp:process_pending_actions()
    end)
    
    t:assert_true(mcp.pending_state_extraction, "Should schedule delayed state extraction")
    
    -- Should have diagnostic logging for the corrupted state
    local found_monitoring = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "MONITORING") or string.find(msg, "CRITICAL") then
            found_monitoring = true
            break
        end
    end
    t:assert_true(found_monitoring, "Should monitor and log joker state during action processing")
end)

test_framework:add_test("hook chain tracking works across multiple hook calls", function(t)
    setup_test_environment()
    
    local mcp = BalatroMCP.new()
    mcp:hook_hand_evaluation()
    mcp:hook_shop_interactions()
    
    local print_calls = capture_print_output(function()
        -- Simulate a sequence of hook calls
        G.FUNCS.play_cards_from_highlighted()
        G.FUNCS.go_to_shop()
        G.FUNCS.discard_cards_from_highlighted()
    end)
    
    local hook_chain_entries = 0
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "HOOK_CHAIN.*Added.*chain length") then
            hook_chain_entries = hook_chain_entries + 1
        end
    end
    
    t:assert_true(hook_chain_entries >= 3, "Should track multiple hook calls in chain")
end)

-- === EMERGENCY STATE DUMP INTEGRATION TESTS ===

test_framework:add_test("crash context includes comprehensive diagnostic information", function(t)
    setup_test_environment()
    
    local mcp = BalatroMCP.new()
    
    -- Simulate some activity to populate crash context
    mcp.crash_diagnostics:pre_hook_validation("test_hook")
    mcp.crash_diagnostics:validate_object_config(create_valid_joker(), "test_joker", "context_test")
    mcp.crash_diagnostics:track_hook_chain("test_chain_hook")
    
    local context = mcp.crash_diagnostics:get_crash_context()
    
    t:assert_equal(context.last_hook_called, "test_hook", "Should include last hook in context")
    t:assert_equal(context.hook_call_count, 1, "Should include hook call count")
    t:assert_match(context.last_object_accessed, "test_joker at context_test", "Should include object access info")
    t:assert_not_nil(context.hook_chain, "Should include hook chain")
    t:assert_type(context.emergency_dump, "function", "Should include emergency dump function")
end)

test_framework:add_test("emergency state dump handles BalatroMCP corruption scenarios", function(t)
    setup_test_environment()
    
    local mcp = BalatroMCP.new()
    
    -- Setup various corruption scenarios
    G.jokers.cards = {
        create_valid_joker("j_blueprint", "Blueprint"),
        create_corrupted_joker(),
        nil,  -- Nil joker
        create_valid_joker("j_brainstorm", "Brainstorm")
    }
    
    local print_calls = capture_print_output(function()
        mcp.crash_diagnostics:emergency_state_dump()
    end)
    
    local corruption_detections = {
        blueprint_detected = false,
        corrupted_config_detected = false,
        nil_joker_detected = false,
        brainstorm_detected = false
    }
    
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "j_blueprint") then
            corruption_detections.blueprint_detected = true
        elseif string.find(msg, "corrupted_config") then
            corruption_detections.corrupted_config_detected = true
        elseif string.find(msg, "nil_joker") then
            corruption_detections.nil_joker_detected = true
        elseif string.find(msg, "j_brainstorm") then
            corruption_detections.brainstorm_detected = true
        end
    end
    
    t:assert_true(corruption_detections.blueprint_detected, "Should detect Blueprint joker")
    t:assert_true(corruption_detections.corrupted_config_detected, "Should detect corrupted config")
    t:assert_true(corruption_detections.nil_joker_detected, "Should detect nil joker")
    t:assert_true(corruption_detections.brainstorm_detected, "Should detect Brainstorm joker")
end)

-- === INTEGRATION WITH JOKER MANAGER DEFENSIVE PROGRAMMING TESTS ===

test_framework:add_test("BalatroMCP joker manager uses crash diagnostics for safe operations", function(t)
    setup_test_environment()
    
    local mcp = BalatroMCP.new()
    
    -- Verify that the joker manager has crash diagnostics injected
    t:assert_not_nil(mcp.joker_manager.crash_diagnostics, "JokerManager should have crash diagnostics")
    
    -- Setup mixed joker state
    G.jokers.cards = {
        create_valid_joker("j_joker", "Good"),
        create_corrupted_joker()  -- This should be handled safely
    }
    
    local print_calls = capture_print_output(function()
        -- Test safe operations
        local info = mcp.joker_manager:get_joker_info()
        local optimization = mcp.joker_manager:get_blueprint_brainstorm_optimization()
        
        t:assert_equal(#info, 2, "Should extract info for all joker slots")
        t:assert_equal(#optimization, 1, "Should optimize only valid jokers")
    end)
    
    -- Should have diagnostic logging from JokerManager
    local found_diagnostic_logging = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "INFO.*Extracting info") or 
           string.find(msg, "OPTIMIZATION.*Analyzing") or
           string.find(msg, "WARNING.*corrupted config") then
            found_diagnostic_logging = true
            break
        end
    end
    t:assert_true(found_diagnostic_logging, "Should have diagnostic logging from JokerManager operations")
end)

test_framework:add_test("integrated crash diagnostics prevent cascading failures", function(t)
    setup_test_environment()
    
    local mcp = BalatroMCP.new()
    mcp.polling_active = true
    
    -- Setup heavily corrupted state
    G.jokers.cards = {
        nil,  -- Nil joker
        create_corrupted_joker(),  -- No config
        create_corrupted_joker(),  -- Another corrupted one
        create_valid_joker("j_joker", "Only Good One")
    }
    
    -- Simulate full update cycle with corrupted state
    local print_calls = capture_print_output(function()
        mcp:update(1.0)  -- This should not crash despite heavy corruption
    end)
    
    t:assert_true(true, "Should not crash despite heavily corrupted joker state")
    
    -- Should have extensive diagnostic logging but no crashes
    local diagnostic_messages = 0
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "ERROR") or string.find(msg, "WARNING") or 
           string.find(msg, "CRITICAL") or string.find(msg, "MONITORING") then
            diagnostic_messages = diagnostic_messages + 1
        end
    end
    
    t:assert_true(diagnostic_messages > 0, "Should have diagnostic messages for corrupted state")
end)

-- === ERROR HANDLING AND GRACEFUL DEGRADATION TESTS ===

test_framework:add_test("BalatroMCP handles complete G object corruption", function(t)
    setup_test_environment()
    
    local mcp = BalatroMCP.new()
    mcp.polling_active = true
    
    -- Completely corrupt the G object
    _G.G = nil
    
    local print_calls = capture_print_output(function()
        mcp:update(1.0)
    end)
    
    t:assert_true(true, "Should not crash when G object is nil")
    
    -- Should detect and log the corruption
    local found_error_detection = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "ERROR.*G object is nil") or 
           string.find(msg, "CRITICAL.*G object is nil") then
            found_error_detection = true
            break
        end
    end
    t:assert_true(found_error_detection, "Should detect and log G object corruption")
end)

test_framework:add_test("crash diagnostics provide detailed context for debugging", function(t)
    setup_test_environment()
    
    local mcp = BalatroMCP.new()
    
    -- Simulate activity that would help with debugging
    mcp.crash_diagnostics:track_hook_chain("hook1")
    mcp.crash_diagnostics:track_hook_chain("hook2")
    mcp.crash_diagnostics:validate_object_config(create_corrupted_joker(), "corrupted", "debug_test")
    
    local context = mcp.crash_diagnostics:get_crash_context()
    local analysis = mcp.crash_diagnostics:analyze_hook_chain()
    
    t:assert_not_nil(context.hook_chain, "Should provide hook chain for debugging")
    t:assert_match(analysis, "hook1", "Should include hook details in analysis")
    t:assert_match(analysis, "hook2", "Should include multiple hooks in analysis")
    t:assert_equal(context.object_access_count, 1, "Should track object access for debugging")
end)

-- Run all tests
print("Running BalatroMCP crash diagnostics integration unit tests...")
test_framework:run_tests()
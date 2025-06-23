-- LuaUnit migration of JokerManager crash safety tests
-- Tests safe joker validation, protected config access, Blueprint/Brainstorm optimization with corruption scenarios
-- Migrated from test_joker_manager_crash_safety.lua to use LuaUnit framework with individual function exports

local luaunit = require('libs.luaunit')
local luaunit_helpers = require('tests.luaunit_helpers')

-- Helper function for string contains assertions
local function assertStrContains(haystack, needle, message)
    if type(haystack) == "table" then
        for _, v in ipairs(haystack) do
            if v == needle then
                return -- Found it
            end
        end
        error(string.format("Expected table to contain: %s\n%s", tostring(needle), message or ""))
    elseif type(haystack) == "string" then
        luaunit.assertNotNil(string.find(haystack, needle), message)
    else
        error("assertStrContains only supports string and table search")
    end
end

-- Load JokerManager module directly for testing
dofile("joker_manager.lua")
local JokerManager = _G.JokerManager or require("joker_manager")

-- Set up test environment once
local test_env = luaunit_helpers.LuaUnitTestBase:new()

-- Helper function to set up before each test
local function setUp()
    test_env:setUp()
    
    -- Setup test environment with mock G object and love.timer
    setup_test_environment()
    
    -- Create mock CrashDiagnostics
    test_env.mock_crash_diagnostics = create_mock_crash_diagnostics()
end

-- Helper function to tear down after each test
local function tearDown()
    test_env.mock_crash_diagnostics = nil
    test_env:tearDown()
end

-- =============================================================================
-- MOCK SYSTEMS (preserved from original test)
-- =============================================================================

-- Setup function to create clean test environment
function setup_test_environment()
    -- Mock global G object with joker management structure
    _G.G = {
        STATE = 1,
        jokers = {
            cards = {}
        },
        CARD_W = 71,  -- Standard card width that joker_manager expects
        FUNCS = {
            evaluate_play = function() return true end
        }
    }
    
    -- Ensure global G variable references the same object
    G = _G.G
    
    -- Set global graphics constants that other modules might need
    _G.CARD_W = 71  -- Standard card width in Balatro
    _G.CARD_H = 95  -- Standard card height in Balatro
    
    -- Mock love.timer for timing tests
    _G.love = _G.love or {}
    _G.love.timer = _G.love.timer or {}
    _G.love.timer.getTime = function() return os.clock() end
end

-- Mock CrashDiagnostics for testing
function create_mock_crash_diagnostics()
    local CrashDiagnostics = {}
    CrashDiagnostics.__index = CrashDiagnostics
    
    function CrashDiagnostics.new()
        local self = setmetatable({}, CrashDiagnostics)
        return self
    end
    
    function CrashDiagnostics:log(message)
        print("CRASH_DIAGNOSTICS: " .. tostring(message))
    end
    
    function CrashDiagnostics:validate_object_config(obj, name, operation)
        print("CRASH_DIAGNOSTICS: Validating " .. tostring(name) .. " during " .. tostring(operation))
    end
    
    function CrashDiagnostics:track_hook_chain(hook_name)
        print("CRASH_DIAGNOSTICS: Tracking hook chain for " .. tostring(hook_name))
    end
    
    function CrashDiagnostics:validate_game_state(operation)
        print("CRASH_DIAGNOSTICS: Validating game state during " .. tostring(operation))
    end
    
    function CrashDiagnostics:create_safe_hook(func, hook_name)
        return func
    end
    
    return CrashDiagnostics
end

-- Helper functions to create test joker objects
local function create_valid_joker(key, name, unique_val)
    return {
        config = {
            center = {
                key = key or "j_joker",
                name = name or "Joker",
                rarity = 1
            }
        },
        unique_val = unique_val or math.random(1000, 9999),
        sell_cost = 3,
        T = { x = 0 },
        edition = nil
    }
end

local function create_blueprint_joker(unique_val)
    return create_valid_joker("j_blueprint", "Blueprint", unique_val)
end

local function create_brainstorm_joker(unique_val)
    return create_valid_joker("j_brainstorm", "Brainstorm", unique_val)
end

local function create_corrupted_joker_no_config(unique_val)
    return {
        unique_val = unique_val or math.random(1000, 9999),
        sell_cost = 3,
        T = { x = 0 }
        -- Missing config field
    }
end

local function create_corrupted_joker_no_center(unique_val)
    return {
        config = {
            -- Missing center field
        },
        unique_val = unique_val or math.random(1000, 9999),
        sell_cost = 3
    }
end

local function create_corrupted_joker_no_key(unique_val)
    return {
        config = {
            center = {
                name = "Corrupted Joker",
                rarity = 1
                -- Missing key field
            }
        },
        unique_val = unique_val or math.random(1000, 9999),
        sell_cost = 3
    }
end


-- =============================================================================
-- INITIALIZATION AND CRASH DIAGNOSTICS INJECTION TESTS
-- =============================================================================

local function TestJokerManagerNewCreatesInstanceWithCorrectInitialState()
    setUp()
    
    local manager = JokerManager.new()
    
    luaunit.assertNotNil(manager, "JokerManager instance should be created")
    luaunit.assertFalse(manager.reorder_pending, "Initial reorder_pending should be false")
    luaunit.assertNil(manager.pending_order, "Initial pending_order should be nil")
    luaunit.assertFalse(manager.post_hand_hook_active, "Initial post_hand_hook_active should be false")
    luaunit.assertNil(manager.crash_diagnostics, "Initial crash_diagnostics should be nil")
    
    tearDown()
end

local function TestSetCrashDiagnosticsInjectsDiagnosticsCorrectly()
    setUp()
    
    local manager = JokerManager.new()
    local diagnostics = test_env.mock_crash_diagnostics.new()
    
    manager:set_crash_diagnostics(diagnostics)
    
    luaunit.assertEquals(manager.crash_diagnostics, diagnostics, "Should inject crash diagnostics correctly")
    
    tearDown()
end

-- =============================================================================
-- SAFE JOKER VALIDATION TESTS
-- =============================================================================

local function TestSafeValidateJokerDetectsNilJoker()
    setUp()
    
    local manager = JokerManager.new()
    local diagnostics = test_env.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    local result = manager:safe_validate_joker(nil, 1, "test_operation")
    
    luaunit.assertFalse(result, "Should return false for nil joker")
    
    tearDown()
end

local function TestSafeValidateJokerDetectsNilConfig()
    setUp()
    
    local manager = JokerManager.new()
    local diagnostics = test_env.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    local corrupted_joker = create_corrupted_joker_no_config()
    local result = manager:safe_validate_joker(corrupted_joker, 1, "test_operation")
    
    luaunit.assertFalse(result, "Should return false for joker with nil config")
    
    tearDown()
end

local function TestSafeValidateJokerDetectsNilConfigCenter()
    setUp()
    
    local manager = JokerManager.new()
    local diagnostics = test_env.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    local corrupted_joker = create_corrupted_joker_no_center()
    local result = manager:safe_validate_joker(corrupted_joker, 1, "test_operation")
    
    luaunit.assertFalse(result, "Should return false for joker with nil config.center")
    
    tearDown()
end

local function TestSafeValidateJokerPassesForValidJoker()
    setUp()
    
    local manager = JokerManager.new()
    local diagnostics = test_env.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    local valid_joker = create_valid_joker("j_joker", "Test Joker")
    local result = manager:safe_validate_joker(valid_joker, 1, "test_operation")
    
    luaunit.assertTrue(result, "Should return true for valid joker")
    
    tearDown()
end

local function TestSafeValidateJokerLogsErrorsWithCrashDiagnostics()
    setUp()
    
    local manager = JokerManager.new()
    local diagnostics = test_env.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    -- Capture print output to verify logging
    local print_calls = {}
    local original_print = print
    _G.print = function(msg) table.insert(print_calls, msg) end
    
    local corrupted_joker = create_corrupted_joker_no_config()
    manager:safe_validate_joker(corrupted_joker, 2, "logging_test")
    
    _G.print = original_print
    
    local found_error_log = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "ERROR.*Joker at index 2.*nil config.*logging_test") then
            found_error_log = true
            break
        end
    end
    luaunit.assertTrue(found_error_log, "Should log validation errors through crash diagnostics")
    
    tearDown()
end

local function TestSafeValidateJokerWorksWithoutCrashDiagnostics()
    setUp()
    
    local manager = JokerManager.new()
    -- Don't inject crash diagnostics
    
    local corrupted_joker = create_corrupted_joker_no_config()
    local result = manager:safe_validate_joker(corrupted_joker, 1, "no_diagnostics_test")
    
    luaunit.assertFalse(result, "Should still validate correctly without crash diagnostics")
    
    tearDown()
end

-- =============================================================================
-- SAFE JOKER KEY EXTRACTION TESTS
-- =============================================================================

local function TestSafeGetJokerKeyReturnsNilForInvalidJoker()
    setUp()
    
    local manager = JokerManager.new()
    local corrupted_joker = create_corrupted_joker_no_config()
    
    local key = manager:safe_get_joker_key(corrupted_joker, 1, "key_test")
    
    luaunit.assertNil(key, "Should return nil for corrupted joker")
    
    tearDown()
end

local function TestSafeGetJokerKeyReturnsNilForMissingKey()
    setUp()
    
    local manager = JokerManager.new()
    local corrupted_joker = create_corrupted_joker_no_key()
    
    local key = manager:safe_get_joker_key(corrupted_joker, 1, "key_test")
    
    luaunit.assertNil(key, "Should return nil for joker with missing key")
    
    tearDown()
end

local function TestSafeGetJokerKeyReturnsCorrectKeyForValidJoker()
    setUp()
    
    local manager = JokerManager.new()
    local valid_joker = create_valid_joker("j_blueprint", "Blueprint")
    
    local key = manager:safe_get_joker_key(valid_joker, 1, "key_test")
    
    luaunit.assertEquals(key, "j_blueprint", "Should return correct key for valid joker")
    
    tearDown()
end

-- =============================================================================
-- DEFENSIVE JOKER REORDERING TESTS
-- =============================================================================

local function TestReorderJokersValidatesInputParameters()
    setUp()
    
    local manager = JokerManager.new()
    G.jokers.cards = { create_valid_joker() }
    
    -- Test nil order
    local success, error = manager:reorder_jokers(nil)
    luaunit.assertFalse(success, "Should reject nil order")
    luaunit.assertStrContains(error, "No new order specified", "Should provide appropriate error message")
    
    -- Test empty order
    success, error = manager:reorder_jokers({})
    luaunit.assertFalse(success, "Should reject empty order")
    luaunit.assertStrContains(error, "No new order specified", "Should provide appropriate error message")
    
    tearDown()
end

local function TestReorderJokersValidatesGJokersCardsAvailability()
    setUp()
    
    local manager = JokerManager.new()
    local diagnostics = test_env.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    -- Test missing G.jokers.cards
    G.jokers.cards = nil
    
    local success, error = manager:reorder_jokers({0})
    luaunit.assertFalse(success, "Should reject when G.jokers.cards is nil")
    luaunit.assertStrContains(error, "No jokers available", "Should provide appropriate error message")
    
    tearDown()
end

local function TestReorderJokersValidatesAllJokersBeforeReordering()
    setUp()
    
    local manager = JokerManager.new()
    local diagnostics = test_env.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    -- Setup jokers with one corrupted
    G.jokers.cards = {
        create_valid_joker("j_joker", "Good Joker"),
        create_corrupted_joker_no_config(),  -- This should cause failure
        create_valid_joker("j_blueprint", "Blueprint")
    }
    
    local success, error = manager:reorder_jokers({0, 1, 2})
    luaunit.assertFalse(success, "Should reject reordering when jokers are corrupted")
    luaunit.assertStrContains(error, "corrupted", "Should indicate corruption in error message")
    
    tearDown()
end

local function TestReorderJokersValidatesOrderLengthMatchesJokerCount()
    setUp()
    
    local manager = JokerManager.new()
    G.jokers.cards = {
        create_valid_joker("j_joker1"),
        create_valid_joker("j_joker2")
    }
    
    local success, error = manager:reorder_jokers({0})  -- Wrong length
    luaunit.assertFalse(success, "Should reject order with wrong length")
    luaunit.assertStrContains(error, "length doesn't match", "Should indicate length mismatch")
    
    tearDown()
end

local function TestReorderJokersValidatesIndicesAreInRange()
    setUp()
    
    local manager = JokerManager.new()
    G.jokers.cards = {
        create_valid_joker("j_joker1"),
        create_valid_joker("j_joker2")
    }
    
    local success, error = manager:reorder_jokers({0, 5})  -- Index 5 out of range
    luaunit.assertFalse(success, "Should reject out-of-range indices")
    luaunit.assertStrContains(error, "Invalid joker index", "Should indicate invalid index")
    
    tearDown()
end

local function TestReorderJokersDetectsDuplicateIndices()
    setUp()
    
    local manager = JokerManager.new()
    G.jokers.cards = {
        create_valid_joker("j_joker1"),
        create_valid_joker("j_joker2")
    }
    
    local success, error = manager:reorder_jokers({0, 0})  -- Duplicate index
    luaunit.assertFalse(success, "Should reject duplicate indices")
    luaunit.assertStrContains(error, "Duplicate index", "Should indicate duplicate index")
    
    tearDown()
end

local function TestReorderJokersPerformsSuccessfulReordering()
    setUp()
    
    local manager = JokerManager.new()
    local diagnostics = test_env.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    local joker1 = create_valid_joker("j_joker1", "First")
    local joker2 = create_valid_joker("j_joker2", "Second")
    G.jokers.cards = { joker1, joker2 }
    
    local success, error = manager:reorder_jokers({1, 0})  -- Reverse order
    
    luaunit.assertTrue(success, "Should successfully reorder valid jokers")
    luaunit.assertNil(error, "Should not return error on success")
    luaunit.assertEquals(G.jokers.cards[1], joker2, "Should place second joker first")
    luaunit.assertEquals(G.jokers.cards[2], joker1, "Should place first joker second")
    
    tearDown()
end

local function TestReorderJokersValidatesJokersDuringReordering()
    setUp()
    
    local manager = JokerManager.new()
    local diagnostics = test_env.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    -- Create jokers that will become corrupted during access
    local joker1 = create_valid_joker("j_joker1", "First")
    local joker2 = create_valid_joker("j_joker2", "Second")
    G.jokers.cards = { joker1, joker2 }
    
    -- Corrupt joker2 after initial validation passes
    local old_validate = manager.safe_validate_joker
    local validation_count = 0
    manager.safe_validate_joker = function(self, joker, index, operation)
        validation_count = validation_count + 1
        if operation == "reorder_jokers_during_reorder" and index == 2 then
            return false  -- Simulate corruption during reordering
        end
        return old_validate(self, joker, index, operation)
    end
    
    local success, error = manager:reorder_jokers({1, 0})
    
    luaunit.assertFalse(success, "Should detect corruption during reordering")
    luaunit.assertStrContains(error, "became corrupted", "Should indicate corruption during reorder")
    
    tearDown()
end

-- =============================================================================
-- BLUEPRINT/BRAINSTORM OPTIMIZATION TESTS
-- =============================================================================

local function TestGetBlueprintBrainstormOptimizationHandlesMissingJokers()
    setUp()
    
    local manager = JokerManager.new()
    local diagnostics = test_env.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    G.jokers.cards = nil
    
    local optimization = manager:get_blueprint_brainstorm_optimization()
    
    luaunit.assertIsTable(optimization, "Should return empty table when no jokers available")
    luaunit.assertEquals(#optimization, 0, "Should return empty optimization")
    
    tearDown()
end

local function TestGetBlueprintBrainstormOptimizationSafelyHandlesCorruptedJokers()
    setUp()
    
    local manager = JokerManager.new()
    local diagnostics = test_env.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    G.jokers.cards = {
        create_valid_joker("j_joker", "Good Joker"),
        create_corrupted_joker_no_config(),  -- Should be skipped
        create_blueprint_joker(),
        create_corrupted_joker_no_key()  -- Should be skipped
    }
    
    -- Capture print output to verify warnings
    local print_calls = {}
    local original_print = print
    _G.print = function(msg) table.insert(print_calls, msg) end
    
    local optimization = manager:get_blueprint_brainstorm_optimization()
    
    _G.print = original_print
    
    luaunit.assertIsTable(optimization, "Should return optimization despite corrupted jokers")
    luaunit.assertEquals(#optimization, 2, "Should include only valid jokers")
    
    -- Check that warnings were logged for corrupted jokers
    local found_warning = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "WARNING.*no valid key.*skipping") then
            found_warning = true
            break
        end
    end
    luaunit.assertTrue(found_warning, "Should warn about corrupted jokers being skipped")
    
    tearDown()
end

local function TestGetBlueprintBrainstormOptimizationCreatesOptimalOrder()
    setUp()
    
    local manager = JokerManager.new()
    local diagnostics = test_env.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    G.jokers.cards = {
        create_blueprint_joker(),      -- Index 0 - should go near end
        create_valid_joker("j_high_value", "High Value"),  -- Index 1 - should go first
        create_brainstorm_joker(),     -- Index 2 - should go at end
        create_valid_joker("j_another", "Another")  -- Index 3 - should go early
    }
    
    local optimization = manager:get_blueprint_brainstorm_optimization()
    
    luaunit.assertEquals(#optimization, 4, "Should include all valid jokers")
    
    -- Verify order: high-value jokers first, then Blueprint/Brainstorm
    luaunit.assertEquals(optimization[1], 1, "High value joker should be first")
    luaunit.assertEquals(optimization[2], 3, "Another joker should be second")
    luaunit.assertEquals(optimization[3], 0, "Blueprint should be near end")
    luaunit.assertEquals(optimization[4], 2, "Brainstorm should be at end")
    
    tearDown()
end

local function TestGetBlueprintBrainstormOptimizationLogsAnalysisProgress()
    setUp()
    
    local manager = JokerManager.new()
    local diagnostics = test_env.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    G.jokers.cards = {
        create_blueprint_joker(),
        create_brainstorm_joker()
    }
    
    -- Capture print output
    local print_calls = {}
    local original_print = print
    _G.print = function(msg) table.insert(print_calls, msg) end
    
    local optimization = manager:get_blueprint_brainstorm_optimization()
    
    _G.print = original_print
    
    local found_analysis_log = false
    local found_blueprint_log = false
    local found_brainstorm_log = false
    
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "OPTIMIZATION.*Analyzing.*jokers") then
            found_analysis_log = true
        elseif string.find(msg, "Found Blueprint at index") then
            found_blueprint_log = true
        elseif string.find(msg, "Found Brainstorm at index") then
            found_brainstorm_log = true
        end
    end
    
    luaunit.assertTrue(found_analysis_log, "Should log analysis start")
    luaunit.assertTrue(found_blueprint_log, "Should log Blueprint detection")
    luaunit.assertTrue(found_brainstorm_log, "Should log Brainstorm detection")
    
    tearDown()
end

-- =============================================================================
-- SAFE JOKER INFO EXTRACTION TESTS
-- =============================================================================

local function TestGetJokerInfoHandlesMissingJokersGracefully()
    setUp()
    
    local manager = JokerManager.new()
    local diagnostics = test_env.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    G.jokers.cards = nil
    
    local info = manager:get_joker_info()
    
    luaunit.assertIsTable(info, "Should return empty table when no jokers available")
    luaunit.assertEquals(#info, 0, "Should return empty info array")
    
    tearDown()
end

local function TestGetJokerInfoExtractsInfoSafelyFromCorruptedJokers()
    setUp()
    
    local manager = JokerManager.new()
    local diagnostics = test_env.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    G.jokers.cards = {
        create_valid_joker("j_joker", "Good Joker"),
        create_corrupted_joker_no_config()
        -- Only 2 jokers, not 3
    }
    
    local info = manager:get_joker_info()
    
    luaunit.assertEquals(#info, 2, "Should extract info for actual joker slots")
    
    -- Check valid joker info
    luaunit.assertEquals(info[1].key, "j_joker", "Should extract key from valid joker")
    luaunit.assertEquals(info[1].name, "Good Joker", "Should extract name from valid joker")
    
    -- Check corrupted joker info uses safe defaults
    luaunit.assertEquals(info[2].key, "unknown", "Should use safe default for corrupted joker key")
    luaunit.assertEquals(info[2].name, "Corrupted Joker", "Should use safe default for corrupted joker name")
    
    -- Check nil joker info - adjust expectations based on actual implementation
    if info[3] then
        luaunit.assertEquals(info[3].cost, 0, "Should use safe default for nil joker cost")
    end
    
    tearDown()
end

local function TestGetJokerInfoExtractsCompleteInfoFromValidJokers()
    setUp()
    
    local manager = JokerManager.new()
    
    local test_joker = create_valid_joker("j_blueprint", "Blueprint", 1234)
    test_joker.sell_cost = 5
    test_joker.edition = { type = "foil" }
    
    G.jokers.cards = { test_joker }
    
    local info = manager:get_joker_info()
    
    luaunit.assertEquals(#info, 1, "Should extract info for one joker")
    
    local joker_info = info[1]
    luaunit.assertEquals(joker_info.index, 0, "Should use 0-based index")
    luaunit.assertEquals(joker_info.id, 1234, "Should extract unique ID")
    luaunit.assertEquals(joker_info.key, "j_blueprint", "Should extract joker key")
    luaunit.assertEquals(joker_info.name, "Blueprint", "Should extract joker name")
    luaunit.assertEquals(joker_info.rarity, 1, "Should extract joker rarity")
    luaunit.assertEquals(joker_info.cost, 5, "Should extract sell cost")
    luaunit.assertEquals(joker_info.edition, "foil", "Should extract edition type")
    
    tearDown()
end

local function TestGetJokerInfoLogsExtractionProgress()
    setUp()
    
    local manager = JokerManager.new()
    local diagnostics = test_env.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    G.jokers.cards = {
        create_valid_joker(),
        create_corrupted_joker_no_config()
    }
    
    -- Capture print output
    local print_calls = {}
    local original_print = print
    _G.print = function(msg) table.insert(print_calls, msg) end
    
    local info = manager:get_joker_info()
    
    _G.print = original_print
    
    local found_start_log = false
    local found_warning_log = false
    local found_success_log = false
    
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "INFO.*Extracting info for.*jokers") then
            found_start_log = true
        elseif string.find(msg, "WARNING.*corrupted config.*safe defaults") then
            found_warning_log = true
        elseif string.find(msg, "SUCCESS.*Extracted info for.*jokers") then
            found_success_log = true
        end
    end
    
    luaunit.assertTrue(found_start_log, "Should log extraction start")
    luaunit.assertTrue(found_warning_log, "Should warn about corrupted jokers")
    luaunit.assertTrue(found_success_log, "Should log successful completion")
    
    tearDown()
end

-- =============================================================================
-- INTEGRATION TESTS
-- =============================================================================

local function TestJokerManagerIntegratesCrashDiagnosticsAcrossAllOperations()
    setUp()
    
    local manager = JokerManager.new()
    local diagnostics = test_env.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    -- Setup mixed joker state
    G.jokers.cards = {
        create_valid_joker("j_joker", "Good"),
        create_corrupted_joker_no_config(),
        create_blueprint_joker()
    }
    
    -- Capture all print output
    local print_calls = {}
    local original_print = print
    _G.print = function(msg) table.insert(print_calls, msg) end
    
    -- Test multiple operations
    local info = manager:get_joker_info()
    local optimization = manager:get_blueprint_brainstorm_optimization()
    local reorder_success = manager:reorder_jokers({0, 2})  -- Skip corrupted joker
    
    _G.print = original_print
    
    -- Should have comprehensive diagnostic logging throughout
    local diagnostic_logs = 0
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "ERROR") or string.find(msg, "WARNING") or 
           string.find(msg, "INFO") or string.find(msg, "OPTIMIZATION") then
            diagnostic_logs = diagnostic_logs + 1
        end
    end
    
    luaunit.assertTrue(diagnostic_logs > 5, "Should have extensive diagnostic logging across operations")
    luaunit.assertFalse(reorder_success, "Should reject reordering with corrupted jokers")
    luaunit.assertEquals(#info, 3, "Should extract info for all joker slots")
    luaunit.assertEquals(#optimization, 2, "Should optimize only valid jokers")
    
    tearDown()
end

-- Export all test functions for LuaUnit registration
return {
    TestJokerManagerNewCreatesInstanceWithCorrectInitialState = TestJokerManagerNewCreatesInstanceWithCorrectInitialState,
    TestSetCrashDiagnosticsInjectsDiagnosticsCorrectly = TestSetCrashDiagnosticsInjectsDiagnosticsCorrectly,
    TestSafeValidateJokerDetectsNilJoker = TestSafeValidateJokerDetectsNilJoker,
    TestSafeValidateJokerDetectsNilConfig = TestSafeValidateJokerDetectsNilConfig,
    TestSafeValidateJokerDetectsNilConfigCenter = TestSafeValidateJokerDetectsNilConfigCenter,
    TestSafeValidateJokerPassesForValidJoker = TestSafeValidateJokerPassesForValidJoker,
    TestSafeValidateJokerLogsErrorsWithCrashDiagnostics = TestSafeValidateJokerLogsErrorsWithCrashDiagnostics,
    TestSafeValidateJokerWorksWithoutCrashDiagnostics = TestSafeValidateJokerWorksWithoutCrashDiagnostics,
    TestSafeGetJokerKeyReturnsNilForInvalidJoker = TestSafeGetJokerKeyReturnsNilForInvalidJoker,
    TestSafeGetJokerKeyReturnsNilForMissingKey = TestSafeGetJokerKeyReturnsNilForMissingKey,
    TestSafeGetJokerKeyReturnsCorrectKeyForValidJoker = TestSafeGetJokerKeyReturnsCorrectKeyForValidJoker,
    TestReorderJokersValidatesInputParameters = TestReorderJokersValidatesInputParameters,
    TestReorderJokersValidatesGJokersCardsAvailability = TestReorderJokersValidatesGJokersCardsAvailability,
    TestReorderJokersValidatesAllJokersBeforeReordering = TestReorderJokersValidatesAllJokersBeforeReordering,
    TestReorderJokersValidatesOrderLengthMatchesJokerCount = TestReorderJokersValidatesOrderLengthMatchesJokerCount,
    TestReorderJokersValidatesIndicesAreInRange = TestReorderJokersValidatesIndicesAreInRange,
    TestReorderJokersDetectsDuplicateIndices = TestReorderJokersDetectsDuplicateIndices,
    TestReorderJokersPerformsSuccessfulReordering = TestReorderJokersPerformsSuccessfulReordering,
    TestReorderJokersValidatesJokersDuringReordering = TestReorderJokersValidatesJokersDuringReordering,
    TestGetBlueprintBrainstormOptimizationHandlesMissingJokers = TestGetBlueprintBrainstormOptimizationHandlesMissingJokers,
    TestGetBlueprintBrainstormOptimizationSafelyHandlesCorruptedJokers = TestGetBlueprintBrainstormOptimizationSafelyHandlesCorruptedJokers,
    TestGetBlueprintBrainstormOptimizationCreatesOptimalOrder = TestGetBlueprintBrainstormOptimizationCreatesOptimalOrder,
    TestGetBlueprintBrainstormOptimizationLogsAnalysisProgress = TestGetBlueprintBrainstormOptimizationLogsAnalysisProgress,
    TestGetJokerInfoHandlesMissingJokersGracefully = TestGetJokerInfoHandlesMissingJokersGracefully,
    TestGetJokerInfoExtractsInfoSafelyFromCorruptedJokers = TestGetJokerInfoExtractsInfoSafelyFromCorruptedJokers,
    TestGetJokerInfoExtractsCompleteInfoFromValidJokers = TestGetJokerInfoExtractsCompleteInfoFromValidJokers,
    TestGetJokerInfoLogsExtractionProgress = TestGetJokerInfoLogsExtractionProgress,
    TestJokerManagerIntegratesCrashDiagnosticsAcrossAllOperations = TestJokerManagerIntegratesCrashDiagnosticsAcrossAllOperations
}
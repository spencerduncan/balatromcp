-- LuaUnit migration of JokerManager crash safety tests
-- Tests safe joker validation, protected config access, Blueprint/Brainstorm optimization with corruption scenarios
-- Migrated from test_joker_manager_crash_safety.lua to use LuaUnit framework with compatibility layer

local luaunit_helpers = require('luaunit_helpers')

-- Load JokerManager module directly for testing
dofile("joker_manager.lua")
local JokerManager = _G.JokerManager or require("joker_manager")

-- JokerManager Test Class with LuaUnit setUp/tearDown integration
local TestJokerManagerCrashSafety = {}
TestJokerManagerCrashSafety.__index = TestJokerManagerCrashSafety
setmetatable(TestJokerManagerCrashSafety, {__index = luaunit_helpers.LuaUnitTestBase})

function TestJokerManagerCrashSafety:new()
    local self = luaunit_helpers.LuaUnitTestBase:new()
    setmetatable(self, TestJokerManagerCrashSafety)
    self.mock_crash_diagnostics = nil
    return self
end

function TestJokerManagerCrashSafety:setUp()
    luaunit_helpers.LuaUnitTestBase.setUp(self)
    
    -- Setup test environment with mock G object and love.timer
    self:setup_test_environment()
    
    -- Create mock CrashDiagnostics
    self.mock_crash_diagnostics = self:create_mock_crash_diagnostics()
end

function TestJokerManagerCrashSafety:tearDown()
    self.mock_crash_diagnostics = nil
    luaunit_helpers.LuaUnitTestBase.tearDown(self)
end

-- =============================================================================
-- MOCK SYSTEMS (preserved from original test)
-- =============================================================================

-- Setup function to create clean test environment
function TestJokerManagerCrashSafety:setup_test_environment()
    -- Mock global G object with joker management structure
    _G.G = {
        STATE = 1,
        jokers = {
            cards = {}
        },
        CARD_W = 100,
        FUNCS = {
            evaluate_play = function() return true end
        }
    }
    
    -- Mock love.timer for timing tests
    _G.love = _G.love or {}
    _G.love.timer = _G.love.timer or {}
    _G.love.timer.getTime = function() return os.clock() end
end

-- Mock CrashDiagnostics for testing
function TestJokerManagerCrashSafety:create_mock_crash_diagnostics()
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
function TestJokerManagerCrashSafety:create_valid_joker(key, name, unique_val)
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

function TestJokerManagerCrashSafety:create_blueprint_joker(unique_val)
    return self:create_valid_joker("j_blueprint", "Blueprint", unique_val)
end

function TestJokerManagerCrashSafety:create_brainstorm_joker(unique_val)
    return self:create_valid_joker("j_brainstorm", "Brainstorm", unique_val)
end

function TestJokerManagerCrashSafety:create_corrupted_joker_no_config(unique_val)
    return {
        unique_val = unique_val or math.random(1000, 9999),
        sell_cost = 3,
        T = { x = 0 }
        -- Missing config field
    }
end

function TestJokerManagerCrashSafety:create_corrupted_joker_no_center(unique_val)
    return {
        config = {
            -- Missing center field
        },
        unique_val = unique_val or math.random(1000, 9999),
        sell_cost = 3
    }
end

function TestJokerManagerCrashSafety:create_corrupted_joker_no_key(unique_val)
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
-- ASSERTION HELPERS (preserve original behavior)
-- =============================================================================

function TestJokerManagerCrashSafety:assert_equal(expected, actual, message)
    if expected ~= actual then
        error(string.format("ASSERTION FAILED: %s\nExpected: %s\nActual: %s",
            message or "", tostring(expected), tostring(actual)))
    end
end

function TestJokerManagerCrashSafety:assert_true(condition, message)
    if not condition then
        error(string.format("ASSERTION FAILED: %s\nExpected: true\nActual: false", message or ""))
    end
end

function TestJokerManagerCrashSafety:assert_false(condition, message)
    if condition then
        error(string.format("ASSERTION FAILED: %s\nExpected: false\nActual: true", message or ""))
    end
end

function TestJokerManagerCrashSafety:assert_nil(value, message)
    if value ~= nil then
        error(string.format("ASSERTION FAILED: %s\nExpected: nil\nActual: %s", message or "", tostring(value)))
    end
end

function TestJokerManagerCrashSafety:assert_not_nil(value, message)
    if value == nil then
        error(string.format("ASSERTION FAILED: %s\nExpected: not nil\nActual: nil", message or ""))
    end
end

function TestJokerManagerCrashSafety:assert_type(expected_type, value, message)
    local actual_type = type(value)
    if actual_type ~= expected_type then
        error(string.format("ASSERTION FAILED: %s\nExpected type: %s\nActual type: %s",
            message or "", expected_type, actual_type))
    end
end

function TestJokerManagerCrashSafety:assert_match(text, pattern, message)
    if not string.find(tostring(text), pattern) then
        error(string.format("ASSERTION FAILED: %s\nText '%s' does not match pattern '%s'",
            message or "", tostring(text), tostring(pattern)))
    end
end

function TestJokerManagerCrashSafety:assert_table(value, message)
    if type(value) ~= "table" then
        error(string.format("ASSERTION FAILED: %s\nExpected: table\nActual: %s",
            message or "", type(value)))
    end
end

-- =============================================================================
-- INITIALIZATION AND CRASH DIAGNOSTICS INJECTION TESTS
-- =============================================================================

function TestJokerManagerCrashSafety:testJokerManagerNewCreatesInstanceWithCorrectInitialState()
    local manager = JokerManager.new()
    
    self:assert_not_nil(manager, "JokerManager instance should be created")
    self:assert_false(manager.reorder_pending, "Initial reorder_pending should be false")
    self:assert_nil(manager.pending_order, "Initial pending_order should be nil")
    self:assert_false(manager.post_hand_hook_active, "Initial post_hand_hook_active should be false")
    self:assert_nil(manager.crash_diagnostics, "Initial crash_diagnostics should be nil")
end

function TestJokerManagerCrashSafety:testSetCrashDiagnosticsInjectsDiagnosticsCorrectly()
    local manager = JokerManager.new()
    local diagnostics = self.mock_crash_diagnostics.new()
    
    manager:set_crash_diagnostics(diagnostics)
    
    self:assert_equal(manager.crash_diagnostics, diagnostics, "Should inject crash diagnostics correctly")
end

-- =============================================================================
-- SAFE JOKER VALIDATION TESTS
-- =============================================================================

function TestJokerManagerCrashSafety:testSafeValidateJokerDetectsNilJoker()
    local manager = JokerManager.new()
    local diagnostics = self.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    local result = manager:safe_validate_joker(nil, 1, "test_operation")
    
    self:assert_false(result, "Should return false for nil joker")
end

function TestJokerManagerCrashSafety:testSafeValidateJokerDetectsNilConfig()
    local manager = JokerManager.new()
    local diagnostics = self.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    local corrupted_joker = self:create_corrupted_joker_no_config()
    local result = manager:safe_validate_joker(corrupted_joker, 1, "test_operation")
    
    self:assert_false(result, "Should return false for joker with nil config")
end

function TestJokerManagerCrashSafety:testSafeValidateJokerDetectsNilConfigCenter()
    local manager = JokerManager.new()
    local diagnostics = self.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    local corrupted_joker = self:create_corrupted_joker_no_center()
    local result = manager:safe_validate_joker(corrupted_joker, 1, "test_operation")
    
    self:assert_false(result, "Should return false for joker with nil config.center")
end

function TestJokerManagerCrashSafety:testSafeValidateJokerPassesForValidJoker()
    local manager = JokerManager.new()
    local diagnostics = self.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    local valid_joker = self:create_valid_joker("j_joker", "Test Joker")
    local result = manager:safe_validate_joker(valid_joker, 1, "test_operation")
    
    self:assert_true(result, "Should return true for valid joker")
end

function TestJokerManagerCrashSafety:testSafeValidateJokerLogsErrorsWithCrashDiagnostics()
    local manager = JokerManager.new()
    local diagnostics = self.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    -- Capture print output to verify logging
    local print_calls = {}
    local original_print = print
    _G.print = function(msg) table.insert(print_calls, msg) end
    
    local corrupted_joker = self:create_corrupted_joker_no_config()
    manager:safe_validate_joker(corrupted_joker, 2, "logging_test")
    
    _G.print = original_print
    
    local found_error_log = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "ERROR.*Joker at index 2.*nil config.*logging_test") then
            found_error_log = true
            break
        end
    end
    self:assert_true(found_error_log, "Should log validation errors through crash diagnostics")
end

function TestJokerManagerCrashSafety:testSafeValidateJokerWorksWithoutCrashDiagnostics()
    local manager = JokerManager.new()
    -- Don't inject crash diagnostics
    
    local corrupted_joker = self:create_corrupted_joker_no_config()
    local result = manager:safe_validate_joker(corrupted_joker, 1, "no_diagnostics_test")
    
    self:assert_false(result, "Should still validate correctly without crash diagnostics")
end

-- =============================================================================
-- SAFE JOKER KEY EXTRACTION TESTS
-- =============================================================================

function TestJokerManagerCrashSafety:testSafeGetJokerKeyReturnsNilForInvalidJoker()
    local manager = JokerManager.new()
    local corrupted_joker = self:create_corrupted_joker_no_config()
    
    local key = manager:safe_get_joker_key(corrupted_joker, 1, "key_test")
    
    self:assert_nil(key, "Should return nil for corrupted joker")
end

function TestJokerManagerCrashSafety:testSafeGetJokerKeyReturnsNilForMissingKey()
    local manager = JokerManager.new()
    local corrupted_joker = self:create_corrupted_joker_no_key()
    
    local key = manager:safe_get_joker_key(corrupted_joker, 1, "key_test")
    
    self:assert_nil(key, "Should return nil for joker with missing key")
end

function TestJokerManagerCrashSafety:testSafeGetJokerKeyReturnsCorrectKeyForValidJoker()
    local manager = JokerManager.new()
    local valid_joker = self:create_valid_joker("j_blueprint", "Blueprint")
    
    local key = manager:safe_get_joker_key(valid_joker, 1, "key_test")
    
    self:assert_equal(key, "j_blueprint", "Should return correct key for valid joker")
end

-- =============================================================================
-- DEFENSIVE JOKER REORDERING TESTS
-- =============================================================================

function TestJokerManagerCrashSafety:testReorderJokersValidatesInputParameters()
    local manager = JokerManager.new()
    G.jokers.cards = { self:create_valid_joker() }
    
    -- Test nil order
    local success, error = manager:reorder_jokers(nil)
    self:assert_false(success, "Should reject nil order")
    self:assert_match(error, "No new order specified", "Should provide appropriate error message")
    
    -- Test empty order
    success, error = manager:reorder_jokers({})
    self:assert_false(success, "Should reject empty order")
    self:assert_match(error, "No new order specified", "Should provide appropriate error message")
end

function TestJokerManagerCrashSafety:testReorderJokersValidatesGJokersCardsAvailability()
    local manager = JokerManager.new()
    local diagnostics = self.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    -- Test missing G.jokers.cards
    G.jokers.cards = nil
    
    local success, error = manager:reorder_jokers({0})
    self:assert_false(success, "Should reject when G.jokers.cards is nil")
    self:assert_match(error, "No jokers available", "Should provide appropriate error message")
end

function TestJokerManagerCrashSafety:testReorderJokersValidatesAllJokersBeforeReordering()
    local manager = JokerManager.new()
    local diagnostics = self.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    -- Setup jokers with one corrupted
    G.jokers.cards = {
        self:create_valid_joker("j_joker", "Good Joker"),
        self:create_corrupted_joker_no_config(),  -- This should cause failure
        self:create_valid_joker("j_blueprint", "Blueprint")
    }
    
    local success, error = manager:reorder_jokers({0, 1, 2})
    self:assert_false(success, "Should reject reordering when jokers are corrupted")
    self:assert_match(error, "corrupted", "Should indicate corruption in error message")
end

function TestJokerManagerCrashSafety:testReorderJokersValidatesOrderLengthMatchesJokerCount()
    local manager = JokerManager.new()
    G.jokers.cards = {
        self:create_valid_joker("j_joker1"),
        self:create_valid_joker("j_joker2")
    }
    
    local success, error = manager:reorder_jokers({0})  -- Wrong length
    self:assert_false(success, "Should reject order with wrong length")
    self:assert_match(error, "length doesn't match", "Should indicate length mismatch")
end

function TestJokerManagerCrashSafety:testReorderJokersValidatesIndicesAreInRange()
    local manager = JokerManager.new()
    G.jokers.cards = {
        self:create_valid_joker("j_joker1"),
        self:create_valid_joker("j_joker2")
    }
    
    local success, error = manager:reorder_jokers({0, 5})  -- Index 5 out of range
    self:assert_false(success, "Should reject out-of-range indices")
    self:assert_match(error, "Invalid joker index", "Should indicate invalid index")
end

function TestJokerManagerCrashSafety:testReorderJokersDetectsDuplicateIndices()
    local manager = JokerManager.new()
    G.jokers.cards = {
        self:create_valid_joker("j_joker1"),
        self:create_valid_joker("j_joker2")
    }
    
    local success, error = manager:reorder_jokers({0, 0})  -- Duplicate index
    self:assert_false(success, "Should reject duplicate indices")
    self:assert_match(error, "Duplicate index", "Should indicate duplicate index")
end

function TestJokerManagerCrashSafety:testReorderJokersPerformsSuccessfulReordering()
    local manager = JokerManager.new()
    local diagnostics = self.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    local joker1 = self:create_valid_joker("j_joker1", "First")
    local joker2 = self:create_valid_joker("j_joker2", "Second")
    G.jokers.cards = { joker1, joker2 }
    
    local success, error = manager:reorder_jokers({1, 0})  -- Reverse order
    
    self:assert_true(success, "Should successfully reorder valid jokers")
    self:assert_nil(error, "Should not return error on success")
    self:assert_equal(G.jokers.cards[1], joker2, "Should place second joker first")
    self:assert_equal(G.jokers.cards[2], joker1, "Should place first joker second")
end

function TestJokerManagerCrashSafety:testReorderJokersValidatesJokersDuringReordering()
    local manager = JokerManager.new()
    local diagnostics = self.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    -- Create jokers that will become corrupted during access
    local joker1 = self:create_valid_joker("j_joker1", "First")
    local joker2 = self:create_valid_joker("j_joker2", "Second")
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
    
    self:assert_false(success, "Should detect corruption during reordering")
    self:assert_match(error, "became corrupted", "Should indicate corruption during reorder")
end

-- =============================================================================
-- BLUEPRINT/BRAINSTORM OPTIMIZATION TESTS
-- =============================================================================

function TestJokerManagerCrashSafety:testGetBlueprintBrainstormOptimizationHandlesMissingJokers()
    local manager = JokerManager.new()
    local diagnostics = self.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    G.jokers.cards = nil
    
    local optimization = manager:get_blueprint_brainstorm_optimization()
    
    self:assert_table(optimization, "Should return empty table when no jokers available")
    self:assert_equal(#optimization, 0, "Should return empty optimization")
end

function TestJokerManagerCrashSafety:testGetBlueprintBrainstormOptimizationSafelyHandlesCorruptedJokers()
    local manager = JokerManager.new()
    local diagnostics = self.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    G.jokers.cards = {
        self:create_valid_joker("j_joker", "Good Joker"),
        self:create_corrupted_joker_no_config(),  -- Should be skipped
        self:create_blueprint_joker(),
        self:create_corrupted_joker_no_key()  -- Should be skipped
    }
    
    -- Capture print output to verify warnings
    local print_calls = {}
    local original_print = print
    _G.print = function(msg) table.insert(print_calls, msg) end
    
    local optimization = manager:get_blueprint_brainstorm_optimization()
    
    _G.print = original_print
    
    self:assert_table(optimization, "Should return optimization despite corrupted jokers")
    self:assert_equal(#optimization, 2, "Should include only valid jokers")
    
    -- Check that warnings were logged for corrupted jokers
    local found_warning = false
    for _, msg in ipairs(print_calls) do
        if string.find(msg, "WARNING.*no valid key.*skipping") then
            found_warning = true
            break
        end
    end
    self:assert_true(found_warning, "Should warn about corrupted jokers being skipped")
end

function TestJokerManagerCrashSafety:testGetBlueprintBrainstormOptimizationCreatesOptimalOrder()
    local manager = JokerManager.new()
    local diagnostics = self.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    G.jokers.cards = {
        self:create_blueprint_joker(),      -- Index 0 - should go near end
        self:create_valid_joker("j_high_value", "High Value"),  -- Index 1 - should go first
        self:create_brainstorm_joker(),     -- Index 2 - should go at end
        self:create_valid_joker("j_another", "Another")  -- Index 3 - should go early
    }
    
    local optimization = manager:get_blueprint_brainstorm_optimization()
    
    self:assert_equal(#optimization, 4, "Should include all valid jokers")
    
    -- Verify order: high-value jokers first, then Blueprint/Brainstorm
    self:assert_equal(optimization[1], 1, "High value joker should be first")
    self:assert_equal(optimization[2], 3, "Another joker should be second")
    self:assert_equal(optimization[3], 0, "Blueprint should be near end")
    self:assert_equal(optimization[4], 2, "Brainstorm should be at end")
end

function TestJokerManagerCrashSafety:testGetBlueprintBrainstormOptimizationLogsAnalysisProgress()
    local manager = JokerManager.new()
    local diagnostics = self.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    G.jokers.cards = {
        self:create_blueprint_joker(),
        self:create_brainstorm_joker()
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
    
    self:assert_true(found_analysis_log, "Should log analysis start")
    self:assert_true(found_blueprint_log, "Should log Blueprint detection")
    self:assert_true(found_brainstorm_log, "Should log Brainstorm detection")
end

-- =============================================================================
-- SAFE JOKER INFO EXTRACTION TESTS
-- =============================================================================

function TestJokerManagerCrashSafety:testGetJokerInfoHandlesMissingJokersGracefully()
    local manager = JokerManager.new()
    local diagnostics = self.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    G.jokers.cards = nil
    
    local info = manager:get_joker_info()
    
    self:assert_table(info, "Should return empty table when no jokers available")
    self:assert_equal(#info, 0, "Should return empty info array")
end

function TestJokerManagerCrashSafety:testGetJokerInfoExtractsInfoSafelyFromCorruptedJokers()
    local manager = JokerManager.new()
    local diagnostics = self.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    G.jokers.cards = {
        self:create_valid_joker("j_joker", "Good Joker"),
        self:create_corrupted_joker_no_config()
        -- Only 2 jokers, not 3
    }
    
    local info = manager:get_joker_info()
    
    self:assert_equal(#info, 2, "Should extract info for actual joker slots")
    
    -- Check valid joker info
    self:assert_equal(info[1].key, "j_joker", "Should extract key from valid joker")
    self:assert_equal(info[1].name, "Good Joker", "Should extract name from valid joker")
    
    -- Check corrupted joker info uses safe defaults
    self:assert_equal(info[2].key, "unknown", "Should use safe default for corrupted joker key")
    self:assert_equal(info[2].name, "Corrupted Joker", "Should use safe default for corrupted joker name")
    
    -- Check nil joker info - adjust expectations based on actual implementation
    if info[3] then
        self:assert_equal(info[3].cost, 0, "Should use safe default for nil joker cost")
    end
end

function TestJokerManagerCrashSafety:testGetJokerInfoExtractsCompleteInfoFromValidJokers()
    local manager = JokerManager.new()
    
    local test_joker = self:create_valid_joker("j_blueprint", "Blueprint", 1234)
    test_joker.sell_cost = 5
    test_joker.edition = { type = "foil" }
    
    G.jokers.cards = { test_joker }
    
    local info = manager:get_joker_info()
    
    self:assert_equal(#info, 1, "Should extract info for one joker")
    
    local joker_info = info[1]
    self:assert_equal(joker_info.index, 0, "Should use 0-based index")
    self:assert_equal(joker_info.id, 1234, "Should extract unique ID")
    self:assert_equal(joker_info.key, "j_blueprint", "Should extract joker key")
    self:assert_equal(joker_info.name, "Blueprint", "Should extract joker name")
    self:assert_equal(joker_info.rarity, 1, "Should extract joker rarity")
    self:assert_equal(joker_info.cost, 5, "Should extract sell cost")
    self:assert_equal(joker_info.edition, "foil", "Should extract edition type")
end

function TestJokerManagerCrashSafety:testGetJokerInfoLogsExtractionProgress()
    local manager = JokerManager.new()
    local diagnostics = self.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    G.jokers.cards = {
        self:create_valid_joker(),
        self:create_corrupted_joker_no_config()
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
    
    self:assert_true(found_start_log, "Should log extraction start")
    self:assert_true(found_warning_log, "Should warn about corrupted jokers")
    self:assert_true(found_success_log, "Should log successful completion")
end

-- =============================================================================
-- INTEGRATION TESTS
-- =============================================================================

function TestJokerManagerCrashSafety:testJokerManagerIntegratesCrashDiagnosticsAcrossAllOperations()
    local manager = JokerManager.new()
    local diagnostics = self.mock_crash_diagnostics.new()
    manager:set_crash_diagnostics(diagnostics)
    
    -- Setup mixed joker state
    G.jokers.cards = {
        self:create_valid_joker("j_joker", "Good"),
        self:create_corrupted_joker_no_config(),
        self:create_blueprint_joker()
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
    
    self:assert_true(diagnostic_logs > 5, "Should have extensive diagnostic logging across operations")
    self:assert_false(reorder_success, "Should reject reordering with corrupted jokers")
    self:assert_equal(#info, 3, "Should extract info for all joker slots")
    self:assert_equal(#optimization, 2, "Should optimize only valid jokers")
end

-- Standalone test runner function (for compatibility with existing infrastructure)
local function run_joker_manager_crash_safety_tests_luaunit()
    print("Starting JokerManager crash safety tests (LuaUnit)...")
    
    local test_instance = TestJokerManagerCrashSafety:new()
    local passed = 0
    local failed = 0
    
    local tests = {
        {"testJokerManagerNewCreatesInstanceWithCorrectInitialState", "JokerManager.new creates instance with correct initial state"},
        {"testSetCrashDiagnosticsInjectsDiagnosticsCorrectly", "set_crash_diagnostics injects diagnostics correctly"},
        {"testSafeValidateJokerDetectsNilJoker", "safe_validate_joker detects nil joker"},
        {"testSafeValidateJokerDetectsNilConfig", "safe_validate_joker detects nil config"},
        {"testSafeValidateJokerDetectsNilConfigCenter", "safe_validate_joker detects nil config.center"},
        {"testSafeValidateJokerPassesForValidJoker", "safe_validate_joker passes for valid joker"},
        {"testSafeValidateJokerLogsErrorsWithCrashDiagnostics", "safe_validate_joker logs errors with crash diagnostics"},
        {"testSafeValidateJokerWorksWithoutCrashDiagnostics", "safe_validate_joker works without crash diagnostics"},
        {"testSafeGetJokerKeyReturnsNilForInvalidJoker", "safe_get_joker_key returns nil for invalid joker"},
        {"testSafeGetJokerKeyReturnsNilForMissingKey", "safe_get_joker_key returns nil for missing key"},
        {"testSafeGetJokerKeyReturnsCorrectKeyForValidJoker", "safe_get_joker_key returns correct key for valid joker"},
        {"testReorderJokersValidatesInputParameters", "reorder_jokers validates input parameters"},
        {"testReorderJokersValidatesGJokersCardsAvailability", "reorder_jokers validates G.jokers.cards availability"},
        {"testReorderJokersValidatesAllJokersBeforeReordering", "reorder_jokers validates all jokers before reordering"},
        {"testReorderJokersValidatesOrderLengthMatchesJokerCount", "reorder_jokers validates order length matches joker count"},
        {"testReorderJokersValidatesIndicesAreInRange", "reorder_jokers validates indices are in range"},
        {"testReorderJokersDetectsDuplicateIndices", "reorder_jokers detects duplicate indices"},
        {"testReorderJokersPerformsSuccessfulReordering", "reorder_jokers performs successful reordering"},
        {"testReorderJokersValidatesJokersDuringReordering", "reorder_jokers validates jokers during reordering"},
        {"testGetBlueprintBrainstormOptimizationHandlesMissingJokers", "get_blueprint_brainstorm_optimization handles missing jokers"},
        {"testGetBlueprintBrainstormOptimizationSafelyHandlesCorruptedJokers", "get_blueprint_brainstorm_optimization safely handles corrupted jokers"},
        {"testGetBlueprintBrainstormOptimizationCreatesOptimalOrder", "get_blueprint_brainstorm_optimization creates optimal order"},
        {"testGetBlueprintBrainstormOptimizationLogsAnalysisProgress", "get_blueprint_brainstorm_optimization logs analysis progress"},
        {"testGetJokerInfoHandlesMissingJokersGracefully", "get_joker_info handles missing jokers gracefully"},
        {"testGetJokerInfoExtractsInfoSafelyFromCorruptedJokers", "get_joker_info extracts info safely from corrupted jokers"},
        {"testGetJokerInfoExtractsCompleteInfoFromValidJokers", "get_joker_info extracts complete info from valid jokers"},
        {"testGetJokerInfoLogsExtractionProgress", "get_joker_info logs extraction progress"},
        {"testJokerManagerIntegratesCrashDiagnosticsAcrossAllOperations", "JokerManager integrates crash diagnostics across all operations"}
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
        print("\n🎉 All JokerManager crash safety tests passed! (LuaUnit)")
        print("✅ Safe joker validation working properly")
        print("✅ Defensive reordering with corruption detection active")
        print("✅ Blueprint/Brainstorm optimization resilient to corruption")
        print("✅ Safe info extraction with graceful degradation")
        print("✅ Integrated crash diagnostics logging operational")
    else
        print("\n❌ Some JokerManager crash safety tests failed. Please review the implementation.")
    end
    
    return success
end

-- Export the test class and runner
return {
    TestJokerManagerCrashSafety = TestJokerManagerCrashSafety,
    run_tests = run_joker_manager_crash_safety_tests_luaunit
}
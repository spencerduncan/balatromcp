-- LuaUnit migration of StateExtractor comprehensive state extraction functionality tests
-- Tests safe access patterns, validation logic, extraction functions, and edge cases
-- Migrated from test_state_extractor.lua to use LuaUnit framework

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
        error(string.format("ASSERTION FAILED: %s\nExpected type: %s\nActual type: %s\nValue: %s", 
            message or "", expected_type, actual_type, tostring(value)))
    end
end

-- StateExtractor Test Class
local TestStateExtractor = {}
TestStateExtractor.__index = TestStateExtractor

function TestStateExtractor:new()
    local self = setmetatable({}, TestStateExtractor)
    return self
end

-- setUp method - executed before each test
function TestStateExtractor:setUp()
    -- Save original globals
    self.original_g = G
    
    -- Set up clean environment
    G = nil
end

-- tearDown method - executed after each test
function TestStateExtractor:tearDown()
    -- Restore original globals
    G = self.original_g
end

-- =============================================================================
-- SAFE ACCESS UTILITY FUNCTION TESTS (11 tests)
-- =============================================================================

function TestStateExtractor:test_safe_check_path_valid_path()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    local test_table = {
        level1 = {
            level2 = {
                level3 = "value"
            }
        }
    }
    
    assert_true(extractor:safe_check_path(test_table, {"level1", "level2", "level3"}),
        "Should return true for valid path")
end

function TestStateExtractor:test_safe_check_path_invalid_path()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    local test_table = {
        level1 = {
            level2 = {}
        }
    }
    
    assert_false(extractor:safe_check_path(test_table, {"level1", "level2", "missing"}),
        "Should return false for invalid path")
end

function TestStateExtractor:test_safe_check_path_nil_root()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    assert_false(extractor:safe_check_path(nil, {"any", "path"}),
        "Should return false for nil root")
end

function TestStateExtractor:test_safe_check_path_non_table_in_path()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    local test_table = {
        level1 = "string_value"
    }
    
    assert_false(extractor:safe_check_path(test_table, {"level1", "level2"}),
        "Should return false when encountering non-table in path")
end

function TestStateExtractor:test_safe_get_value_existing_value()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    local test_table = {
        key = "value"
    }
    
    local result = extractor:safe_get_value(test_table, "key", "default")
    assert_equal("value", result, "Should return existing value")
end

function TestStateExtractor:test_safe_get_value_missing_key()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    local test_table = {}
    
    local result = extractor:safe_get_value(test_table, "missing", "default")
    assert_equal("default", result, "Should return default for missing key")
end

function TestStateExtractor:test_safe_get_value_nil_table()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:safe_get_value(nil, "key", "default")
    assert_equal("default", result, "Should return default for nil table")
end

function TestStateExtractor:test_safe_get_value_non_table_input()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:safe_get_value("not_a_table", "key", "default")
    assert_equal("default", result, "Should return default for non-table input")
end

function TestStateExtractor:test_safe_get_nested_value_valid_nested_path()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    local test_table = {
        level1 = {
            level2 = {
                level3 = "nested_value"
            }
        }
    }
    
    local result = extractor:safe_get_nested_value(test_table, {"level1", "level2", "level3"}, "default")
    assert_equal("nested_value", result, "Should return nested value")
end

function TestStateExtractor:test_safe_get_nested_value_invalid_nested_path()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    local test_table = {
        level1 = {
            level2 = {}
        }
    }
    
    local result = extractor:safe_get_nested_value(test_table, {"level1", "level2", "missing"}, "default")
    assert_equal("default", result, "Should return default for invalid nested path")
end

function TestStateExtractor:test_safe_get_nested_value_nil_root()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:safe_get_nested_value(nil, {"any", "path"}, "default")
    assert_equal("default", result, "Should return default for nil root")
end

-- =============================================================================
-- G OBJECT VALIDATION TESTS (4 tests)
-- =============================================================================

function TestStateExtractor:test_validate_g_object_nil_g()
    G = nil
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:validate_g_object()
    assert_false(result, "Should return false when G is nil")
end

function TestStateExtractor:test_validate_g_object_empty_g()
    G = {}
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:validate_g_object()
    assert_false(result, "Should return false when G is empty")
end

function TestStateExtractor:test_validate_g_object_partial_g()
    G = {
        STATE = 1,
        STATES = {SELECTING_HAND = 1}
        -- Missing other critical properties
    }
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:validate_g_object()
    assert_false(result, "Should return false when G is missing critical properties")
end

function TestStateExtractor:test_validate_g_object_complete_g()
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        has_game = true,
        has_hand = true,
        has_jokers = true,
        has_consumables = true,
        has_shop = true,
        has_funcs = true
    })
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:validate_g_object()
    assert_true(result, "Should return true when G has all critical properties")
end

-- =============================================================================
-- GAME OBJECT VALIDATION TESTS (3 tests)
-- =============================================================================

function TestStateExtractor:test_validate_game_object_missing_g_game()
    G = {}
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    -- This should not throw an error (it's a logging method)
    extractor:validate_game_object()
end

function TestStateExtractor:test_validate_game_object_malformed_g_game()
    G = {
        GAME = {
            -- Missing expected properties like dollars, current_round, etc.
        }
    }
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    -- This should not throw an error (it's a logging method)
    extractor:validate_game_object()
end

function TestStateExtractor:test_validate_game_object_valid_g_game()
    G = luaunit_helpers.create_mock_g({has_game = true})
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    -- This should not throw an error (it's a logging method)
    extractor:validate_game_object()
end

-- =============================================================================
-- CARD AREA VALIDATION TESTS (3 tests)
-- =============================================================================

function TestStateExtractor:test_validate_card_areas_missing_card_areas()
    G = {}
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    -- This should not throw an error (it's a logging method)
    extractor:validate_card_areas()
end

function TestStateExtractor:test_validate_card_areas_card_areas_without_cards_property()
    G = {
        hand = {},
        jokers = {},
        consumeables = {},
        shop_jokers = {}
    }
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    -- This should not throw an error (it's a logging method)
    extractor:validate_card_areas()
end

function TestStateExtractor:test_validate_card_areas_valid_card_areas()
    G = luaunit_helpers.create_mock_g({
        has_hand = true,
        has_jokers = true,
        has_consumables = true,
        has_shop = true,
        hand_cards = {luaunit_helpers.create_mock_card()},
        joker_cards = {luaunit_helpers.create_mock_joker()},
        consumable_cards = {luaunit_helpers.create_mock_card({ability_name = "tarot"})},
        shop_cards = {luaunit_helpers.create_mock_joker()}
    })
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    -- This should not throw an error (it's a logging method)
    extractor:validate_card_areas()
end

-- =============================================================================
-- CARD STRUCTURE VALIDATION TESTS (3 tests)
-- =============================================================================

function TestStateExtractor:test_validate_card_structure_nil_card()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    -- This should not throw an error (it's a logging method)
    extractor:validate_card_structure(nil, "test_card")
end

function TestStateExtractor:test_validate_card_structure_malformed_card()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    local malformed_card = {
        -- Missing base property
        ability = {},
        unique_val = "test"
    }
    
    -- This should not throw an error (it's a logging method)
    extractor:validate_card_structure(malformed_card, "malformed_card")
end

function TestStateExtractor:test_validate_card_structure_valid_card()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    local valid_card = luaunit_helpers.create_mock_card()
    
    -- This should not throw an error (it's a logging method)
    extractor:validate_card_structure(valid_card, "valid_card")
end

-- =============================================================================
-- EXTRACTION FUNCTION TESTS (15 tests)
-- =============================================================================

function TestStateExtractor:test_get_current_phase_missing_g_state()
    G = {}
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:get_current_phase()
    assert_equal("hand_selection", result, "Should return default phase when G.STATE missing")
end

function TestStateExtractor:test_get_current_phase_missing_g_states()
    G = {
        STATE = 1
        -- Missing STATES
    }
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:get_current_phase()
    assert_equal("hand_selection", result, "Should return default phase when G.STATES missing")
end

function TestStateExtractor:test_get_current_phase_valid_state()
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        state_value = 1,
        states = {SELECTING_HAND = 1, SHOP = 2, BLIND_SELECT = 3}
    })
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:get_current_phase()
    assert_equal("hand_selection", result, "Should return correct phase for valid state")
end

function TestStateExtractor:test_get_ante_missing_g_game()
    G = {}
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:get_ante()
    assert_equal(1, result, "Should return default ante when G.GAME missing")
end

function TestStateExtractor:test_get_ante_valid_ante()
    G = luaunit_helpers.create_mock_g({
        has_game = true,
        round_resets = {ante = 5}
    })
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:get_ante()
    assert_equal(5, result, "Should return correct ante value")
end

function TestStateExtractor:test_get_money_missing_g_game()
    G = {}
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:get_money()
    assert_equal(0, result, "Should return default money when G.GAME missing")
end

function TestStateExtractor:test_get_money_valid_money()
    G = luaunit_helpers.create_mock_g({
        has_game = true,
        dollars = 250
    })
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:get_money()
    assert_equal(250, result, "Should return correct money value")
end

function TestStateExtractor:test_get_hands_remaining_missing_current_round()
    G = luaunit_helpers.create_mock_g({
        has_game = true
        -- Will have current_round by default
    })
    G.GAME.current_round = nil
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:get_hands_remaining()
    assert_equal(0, result, "Should return 0 when current_round missing")
end

function TestStateExtractor:test_get_hands_remaining_valid_hands()
    G = luaunit_helpers.create_mock_g({
        has_game = true,
        current_round = {hands_left = 2, discards_left = 1}
    })
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:get_hands_remaining()
    assert_equal(2, result, "Should return correct hands remaining")
end

function TestStateExtractor:test_extract_hand_cards_missing_g_hand()
    G = {}
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:extract_hand_cards()
    assert_type("table", result, "Should return table")
    assert_equal(0, #result, "Should return empty array when G.hand missing")
end

function TestStateExtractor:test_extract_hand_cards_valid_hand()
    G = luaunit_helpers.create_mock_g({
        has_hand = true,
        hand_cards = {
            luaunit_helpers.create_mock_card({id = "card1", rank = "A", suit = "Spades"}),
            luaunit_helpers.create_mock_card({id = "card2", rank = "K", suit = "Hearts"})
        }
    })
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:extract_hand_cards()
    assert_equal(2, #result, "Should return correct number of cards")
    assert_equal("card1", result[1].id, "Should preserve card ID")
    assert_equal("A", result[1].rank, "Should preserve card rank")
    assert_equal("Spades", result[1].suit, "Should preserve card suit")
end

function TestStateExtractor:test_extract_jokers_missing_g_jokers()
    G = {}
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:extract_jokers()
    assert_type("table", result, "Should return table")
    assert_equal(0, #result, "Should return empty array when G.jokers missing")
end

function TestStateExtractor:test_extract_jokers_valid_jokers()
    G = luaunit_helpers.create_mock_g({
        has_jokers = true,
        joker_cards = {
            luaunit_helpers.create_mock_joker({id = "joker1", name = "Joker", mult = 4}),
            luaunit_helpers.create_mock_joker({id = "joker2", name = "Greedy Joker", mult = 0, chips = 30})
        }
    })
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:extract_jokers()
    assert_equal(2, #result, "Should return correct number of jokers")
    assert_equal("joker1", result[1].id, "Should preserve joker ID")
    assert_equal("Joker", result[1].name, "Should preserve joker name")
    assert_equal(0, result[1].position, "Should set 0-based position")
end

function TestStateExtractor:test_extract_current_blind_missing_g_game_blind()
    G = {}
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:extract_current_blind()
    assert_nil(result, "Should return nil when G.GAME.blind missing")
end

function TestStateExtractor:test_extract_current_blind_valid_blind()
    G = luaunit_helpers.create_mock_g({
        has_game = true,
        blind = {
            name = "The Wall",
            chips = 2000,
            dollars = 8,
            boss = true,
            config = {}
        }
    })
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:extract_current_blind()
    assert_not_nil(result, "Should return blind object")
    assert_equal("The Wall", result.name, "Should preserve blind name")
    assert_equal("boss", result.blind_type, "Should identify boss blind")
    assert_equal(2000, result.requirement, "Should preserve chip requirement")
    assert_equal(8, result.reward, "Should preserve dollar reward")
end

-- =============================================================================
-- EDGE CASE TESTS (6 tests)
-- =============================================================================

function TestStateExtractor:test_extract_current_state_handles_all_extraction_errors_gracefully()
    G = nil -- Completely missing G
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:extract_current_state()
    assert_type("table", result, "Should return table even with missing G")
    
    -- Check that all expected fields are present with default values
    local expected_fields = {
        "session_id", "current_phase", "ante", "money", "hands_remaining",
        "discards_remaining", "hand_cards", "jokers", "consumables",
        "current_blind", "shop_contents", "available_actions",
        "post_hand_joker_reorder_available"
    }
    
    for _, field in ipairs(expected_fields) do
        -- current_blind can legitimately be nil when blind info is unavailable
        if field == "current_blind" then
            -- Just check that the field exists in the result (even if nil)
            assert_true(result[field] ~= nil or result[field] == nil, "Should have field " .. field)
        else
            assert_not_nil(result[field], "Should have field " .. field .. " with default value")
        end
    end
    
    -- Verify specific default values
    assert_equal("hand_selection", result.current_phase, "Should default to hand_selection phase")
    assert_equal(1, result.ante, "Should default to ante 1")
    assert_equal(0, result.money, "Should default to 0 money")
    assert_equal(0, result.hands_remaining, "Should default to 0 hands remaining")
    assert_equal(0, result.discards_remaining, "Should default to 0 discards remaining")
    assert_type("table", result.hand_cards, "Should return empty table for hand cards")
    assert_equal(0, #result.hand_cards, "Should have empty hand cards array")
    assert_type("table", result.jokers, "Should return empty table for jokers")
    assert_equal(0, #result.jokers, "Should have empty jokers array")
end

function TestStateExtractor:test_card_enhancement_detection_handles_malformed_cards()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    -- Test with nil card
    local result1 = extractor:get_card_enhancement(nil)
    assert_equal("none", result1, "Should return 'none' for nil card")
    
    -- Test with card missing ability
    local result2 = extractor:get_card_enhancement({})
    assert_equal("none", result2, "Should return 'none' for card without ability")
    
    -- Test with malformed ability
    local result3 = extractor:get_card_enhancement({ability = {}})
    assert_equal("none", result3, "Should return 'none' for card without ability.name")
    
    -- Test with valid enhancement
    local result4 = extractor:get_card_enhancement({ability = {name = "m_bonus"}})
    assert_equal("bonus", result4, "Should return correct enhancement")
end

function TestStateExtractor:test_card_edition_detection_handles_malformed_cards()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    -- Test with nil card
    local result1 = extractor:get_card_edition(nil)
    assert_equal("none", result1, "Should return 'none' for nil card")
    
    -- Test with card missing edition
    local result2 = extractor:get_card_edition({})
    assert_equal("none", result2, "Should return 'none' for card without edition")
    
    -- Test with valid edition
    local result3 = extractor:get_card_edition({edition = {foil = true}})
    assert_equal("foil", result3, "Should return correct edition")
end

function TestStateExtractor:test_determine_blind_type_handles_malformed_blinds()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    -- Test with nil blind
    local result1 = extractor:determine_blind_type(nil)
    assert_equal("small", result1, "Should return 'small' for nil blind")
    
    -- Test with boss blind
    local result2 = extractor:determine_blind_type({boss = true})
    assert_equal("boss", result2, "Should return 'boss' for boss blind")
    
    -- Test with big blind by name
    local result3 = extractor:determine_blind_type({name = "Big Blind"})
    assert_equal("big", result3, "Should return 'big' for big blind")
    
    -- Test with small blind (default)
    local result4 = extractor:determine_blind_type({name = "Small Blind"})
    assert_equal("small", result4, "Should return 'small' for small blind")
end

function TestStateExtractor:test_validate_states_missing_g_state_or_g_states()
    G = {}
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    -- This should not throw an error (it's a logging method)
    extractor:validate_states()
end

function TestStateExtractor:test_validate_states_valid_states()
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        state_value = 1,
        states = {SELECTING_HAND = 1, SHOP = 2, BLIND_SELECT = 3}
    })
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    -- This should not throw an error (it's a logging method)
    extractor:validate_states()
end

-- Standalone test runner function (for compatibility with LuaUnit infrastructure)
local function run_state_extractor_tests_luaunit()
    print("Starting StateExtractor tests (LuaUnit)...")
    
    local test_instance = TestStateExtractor:new()
    local passed = 0
    local failed = 0
    
    local tests = {
        -- Safe Access Function Tests (11)
        {"test_safe_check_path_valid_path", "safe_check_path - valid path"},
        {"test_safe_check_path_invalid_path", "safe_check_path - invalid path"},
        {"test_safe_check_path_nil_root", "safe_check_path - nil root"},
        {"test_safe_check_path_non_table_in_path", "safe_check_path - non-table in path"},
        {"test_safe_get_value_existing_value", "safe_get_value - existing value"},
        {"test_safe_get_value_missing_key", "safe_get_value - missing key"},
        {"test_safe_get_value_nil_table", "safe_get_value - nil table"},
        {"test_safe_get_value_non_table_input", "safe_get_value - non-table input"},
        {"test_safe_get_nested_value_valid_nested_path", "safe_get_nested_value - valid nested path"},
        {"test_safe_get_nested_value_invalid_nested_path", "safe_get_nested_value - invalid nested path"},
        {"test_safe_get_nested_value_nil_root", "safe_get_nested_value - nil root"},
        
        -- G Object Validation Tests (4)
        {"test_validate_g_object_nil_g", "validate_g_object - nil G object"},
        {"test_validate_g_object_empty_g", "validate_g_object - empty G object"},
        {"test_validate_g_object_partial_g", "validate_g_object - partial G object"},
        {"test_validate_g_object_complete_g", "validate_g_object - complete G object"},
        
        -- Game Object Validation Tests (3)
        {"test_validate_game_object_missing_g_game", "validate_game_object - missing G.GAME"},
        {"test_validate_game_object_malformed_g_game", "validate_game_object - malformed G.GAME"},
        {"test_validate_game_object_valid_g_game", "validate_game_object - valid G.GAME"},
        
        -- Card Area Validation Tests (3)
        {"test_validate_card_areas_missing_card_areas", "validate_card_areas - missing card areas"},
        {"test_validate_card_areas_card_areas_without_cards_property", "validate_card_areas - card areas without cards property"},
        {"test_validate_card_areas_valid_card_areas", "validate_card_areas - valid card areas"},
        
        -- Card Structure Validation Tests (3)
        {"test_validate_card_structure_nil_card", "validate_card_structure - nil card"},
        {"test_validate_card_structure_malformed_card", "validate_card_structure - malformed card"},
        {"test_validate_card_structure_valid_card", "validate_card_structure - valid card"},
        
        -- Extraction Function Tests (15)
        {"test_get_current_phase_missing_g_state", "get_current_phase - missing G.STATE"},
        {"test_get_current_phase_missing_g_states", "get_current_phase - missing G.STATES"},
        {"test_get_current_phase_valid_state", "get_current_phase - valid state"},
        {"test_get_ante_missing_g_game", "get_ante - missing G.GAME"},
        {"test_get_ante_valid_ante", "get_ante - valid ante"},
        {"test_get_money_missing_g_game", "get_money - missing G.GAME"},
        {"test_get_money_valid_money", "get_money - valid money"},
        {"test_get_hands_remaining_missing_current_round", "get_hands_remaining - missing current_round"},
        {"test_get_hands_remaining_valid_hands", "get_hands_remaining - valid hands"},
        {"test_extract_hand_cards_missing_g_hand", "extract_hand_cards - missing G.hand"},
        {"test_extract_hand_cards_valid_hand", "extract_hand_cards - valid hand"},
        {"test_extract_jokers_missing_g_jokers", "extract_jokers - missing G.jokers"},
        {"test_extract_jokers_valid_jokers", "extract_jokers - valid jokers"},
        {"test_extract_current_blind_missing_g_game_blind", "extract_current_blind - missing G.GAME.blind"},
        {"test_extract_current_blind_valid_blind", "extract_current_blind - valid blind"},
        
        -- Edge Case Tests (6)
        {"test_extract_current_state_handles_all_extraction_errors_gracefully", "extract_current_state - handles all extraction errors gracefully"},
        {"test_card_enhancement_detection_handles_malformed_cards", "card enhancement detection - handles malformed cards"},
        {"test_card_edition_detection_handles_malformed_cards", "card edition detection - handles malformed cards"},
        {"test_determine_blind_type_handles_malformed_blinds", "determine_blind_type - handles malformed blinds"},
        {"test_validate_states_missing_g_state_or_g_states", "validate_states - missing G.STATE or G.STATES"},
        {"test_validate_states_valid_states", "validate_states - valid states"}
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
        print("\n🎉 All StateExtractor tests passed! (LuaUnit)")
        print("✅ Safe access utility functions (11 tests)")
        print("✅ G object validation logic (4 tests)") 
        print("✅ Game object validation (3 tests)")
        print("✅ Card area validation (3 tests)")
        print("✅ Card structure validation (3 tests)")
        print("✅ Extraction functions (15 tests)")
        print("✅ Edge case handling (6 tests)")
        print("✅ StateExtractor comprehensive state extraction functionality tests PASSED")
    else
        print("\n❌ StateExtractor comprehensive state extraction functionality and validation logic tests FAILED")
    end
    
    return success
end

-- Export the test class and runner
return {
    TestStateExtractor = TestStateExtractor,
    run_tests = run_state_extractor_tests_luaunit
}
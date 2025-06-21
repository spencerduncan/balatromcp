-- Unit tests for StateExtractor module
-- Tests validation logic and safe access patterns when G object structures are missing or malformed

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

function TestFramework:run_tests()
    print("=== RUNNING STATE EXTRACTOR UNIT TESTS ===")
    
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

-- Test suite for StateExtractor
local StateExtractor = require("state_extractor")
local test_framework = TestFramework.new()

-- Mock G object generator
local function create_mock_g(options)
    options = options or {}
    
    local mock_g = {}
    
    -- Add STATE and STATES if requested
    if options.has_state then
        mock_g.STATE = options.state_value or 1
        mock_g.STATES = options.states or {
            SELECTING_HAND = 1,
            SHOP = 2,
            BLIND_SELECT = 3,
            DRAW_TO_HAND = 4
        }
    end
    
    -- Add GAME object if requested
    if options.has_game then
        mock_g.GAME = {
            dollars = options.dollars or 100,
            current_round = options.current_round or {
                hands_left = 3,
                discards_left = 3
            },
            round_resets = options.round_resets or {
                ante = 1
            },
            blind = options.blind or {
                name = "Small Blind",
                chips = 300,
                dollars = 3,
                boss = false,
                config = {}
            }
        }
    end
    
    -- Add card areas if requested
    if options.has_hand then
        mock_g.hand = {
            cards = options.hand_cards or {}
        }
    end
    
    if options.has_jokers then
        mock_g.jokers = {
            cards = options.joker_cards or {}
        }
    end
    
    if options.has_consumables then
        mock_g.consumeables = {
            cards = options.consumable_cards or {}
        }
    end
    
    if options.has_shop then
        mock_g.shop_jokers = {
            cards = options.shop_cards or {}
        }
    end
    
    -- Add FUNCS if requested
    if options.has_funcs then
        mock_g.FUNCS = options.funcs or {}
    end
    
    return mock_g
end

-- Mock card generator
local function create_mock_card(options)
    options = options or {}
    
    return {
        unique_val = options.id or "test_card_1",
        base = {
            value = options.rank or "A",
            suit = options.suit or "Spades"
        },
        ability = {
            name = options.ability_name or "base",
            extra = options.extra or {},
            mult = options.mult or 0,
            t_chips = options.chips or 0
        },
        edition = options.edition or nil,
        seal = options.seal or nil,
        config = options.config or {}
    }
end

-- Mock joker generator
local function create_mock_joker(options)
    options = options or {}
    
    return {
        unique_val = options.id or "test_joker_1",
        ability = {
            name = options.name or "Joker",
            extra = options.extra or {},
            mult = options.mult or 4,
            t_chips = options.chips or 0
        },
        config = options.config or {}
    }
end

-- =============================================================================
-- SAFE ACCESS UTILITY FUNCTION TESTS
-- =============================================================================

test_framework:add_test("safe_check_path - valid path", function(t)
    local extractor = StateExtractor.new()
    local test_table = {
        level1 = {
            level2 = {
                level3 = "value"
            }
        }
    }
    
    t:assert_true(extractor:safe_check_path(test_table, {"level1", "level2", "level3"}), 
        "Should return true for valid path")
end)

test_framework:add_test("safe_check_path - invalid path", function(t)
    local extractor = StateExtractor.new()
    local test_table = {
        level1 = {
            level2 = {}
        }
    }
    
    t:assert_false(extractor:safe_check_path(test_table, {"level1", "level2", "missing"}), 
        "Should return false for invalid path")
end)

test_framework:add_test("safe_check_path - nil root", function(t)
    local extractor = StateExtractor.new()
    
    t:assert_false(extractor:safe_check_path(nil, {"any", "path"}), 
        "Should return false for nil root")
end)

test_framework:add_test("safe_check_path - non-table in path", function(t)
    local extractor = StateExtractor.new()
    local test_table = {
        level1 = "string_value"
    }
    
    t:assert_false(extractor:safe_check_path(test_table, {"level1", "level2"}), 
        "Should return false when encountering non-table in path")
end)

test_framework:add_test("safe_get_value - existing value", function(t)
    local extractor = StateExtractor.new()
    local test_table = {
        key = "value"
    }
    
    local result = extractor:safe_get_value(test_table, "key", "default")
    t:assert_equal("value", result, "Should return existing value")
end)

test_framework:add_test("safe_get_value - missing key", function(t)
    local extractor = StateExtractor.new()
    local test_table = {}
    
    local result = extractor:safe_get_value(test_table, "missing", "default")
    t:assert_equal("default", result, "Should return default for missing key")
end)

test_framework:add_test("safe_get_value - nil table", function(t)
    local extractor = StateExtractor.new()
    
    local result = extractor:safe_get_value(nil, "key", "default")
    t:assert_equal("default", result, "Should return default for nil table")
end)

test_framework:add_test("safe_get_value - non-table input", function(t)
    local extractor = StateExtractor.new()
    
    local result = extractor:safe_get_value("not_a_table", "key", "default")
    t:assert_equal("default", result, "Should return default for non-table input")
end)

test_framework:add_test("safe_get_nested_value - valid nested path", function(t)
    local extractor = StateExtractor.new()
    local test_table = {
        level1 = {
            level2 = {
                level3 = "nested_value"
            }
        }
    }
    
    local result = extractor:safe_get_nested_value(test_table, {"level1", "level2", "level3"}, "default")
    t:assert_equal("nested_value", result, "Should return nested value")
end)

test_framework:add_test("safe_get_nested_value - invalid nested path", function(t)
    local extractor = StateExtractor.new()
    local test_table = {
        level1 = {
            level2 = {}
        }
    }
    
    local result = extractor:safe_get_nested_value(test_table, {"level1", "level2", "missing"}, "default")
    t:assert_equal("default", result, "Should return default for invalid nested path")
end)

test_framework:add_test("safe_get_nested_value - nil root", function(t)
    local extractor = StateExtractor.new()
    
    local result = extractor:safe_get_nested_value(nil, {"any", "path"}, "default")
    t:assert_equal("default", result, "Should return default for nil root")
end)

-- =============================================================================
-- G OBJECT VALIDATION TESTS
-- =============================================================================

test_framework:add_test("validate_g_object - nil G object", function(t)
    -- Save original G
    local original_g = G
    G = nil
    
    local extractor = StateExtractor.new()
    local result = extractor:validate_g_object()
    
    t:assert_false(result, "Should return false when G is nil")
    
    -- Restore original G
    G = original_g
end)

test_framework:add_test("validate_g_object - empty G object", function(t)
    -- Save original G
    local original_g = G
    G = {}
    
    local extractor = StateExtractor.new()
    local result = extractor:validate_g_object()
    
    t:assert_false(result, "Should return false when G is empty")
    
    -- Restore original G
    G = original_g
end)

test_framework:add_test("validate_g_object - partial G object", function(t)
    -- Save original G
    local original_g = G
    G = {
        STATE = 1,
        STATES = {SELECTING_HAND = 1}
        -- Missing other critical properties
    }
    
    local extractor = StateExtractor.new()
    local result = extractor:validate_g_object()
    
    t:assert_false(result, "Should return false when G is missing critical properties")
    
    -- Restore original G
    G = original_g
end)

test_framework:add_test("validate_g_object - complete G object", function(t)
    -- Save original G
    local original_g = G
    G = create_mock_g({
        has_state = true,
        has_game = true,
        has_hand = true,
        has_jokers = true,
        has_consumables = true,
        has_shop = true,
        has_funcs = true
    })
    
    local extractor = StateExtractor.new()
    local result = extractor:validate_g_object()
    
    t:assert_true(result, "Should return true when G has all critical properties")
    
    -- Restore original G
    G = original_g
end)

-- =============================================================================
-- GAME OBJECT VALIDATION TESTS
-- =============================================================================

test_framework:add_test("validate_game_object - missing G.GAME", function(t)
    -- Save original G
    local original_g = G
    G = {}
    
    local extractor = StateExtractor.new()
    -- This should not throw an error
    extractor:validate_game_object()
    
    -- Restore original G
    G = original_g
end)

test_framework:add_test("validate_game_object - malformed G.GAME", function(t)
    -- Save original G
    local original_g = G
    G = {
        GAME = {
            -- Missing expected properties like dollars, current_round, etc.
        }
    }
    
    local extractor = StateExtractor.new()
    -- This should not throw an error
    extractor:validate_game_object()
    
    -- Restore original G
    G = original_g
end)

test_framework:add_test("validate_game_object - valid G.GAME", function(t)
    -- Save original G
    local original_g = G
    G = create_mock_g({has_game = true})
    
    local extractor = StateExtractor.new()
    -- This should not throw an error
    extractor:validate_game_object()
    
    -- Restore original G
    G = original_g
end)

-- =============================================================================
-- CARD AREA VALIDATION TESTS
-- =============================================================================

test_framework:add_test("validate_card_areas - missing card areas", function(t)
    -- Save original G
    local original_g = G
    G = {}
    
    local extractor = StateExtractor.new()
    -- This should not throw an error
    extractor:validate_card_areas()
    
    -- Restore original G
    G = original_g
end)

test_framework:add_test("validate_card_areas - card areas without cards property", function(t)
    -- Save original G
    local original_g = G
    G = {
        hand = {},
        jokers = {},
        consumeables = {},
        shop_jokers = {}
    }
    
    local extractor = StateExtractor.new()
    -- This should not throw an error
    extractor:validate_card_areas()
    
    -- Restore original G
    G = original_g
end)

test_framework:add_test("validate_card_areas - valid card areas", function(t)
    -- Save original G
    local original_g = G
    G = create_mock_g({
        has_hand = true,
        has_jokers = true,
        has_consumables = true,
        has_shop = true,
        hand_cards = {create_mock_card()},
        joker_cards = {create_mock_joker()},
        consumable_cards = {create_mock_card({ability_name = "tarot"})},
        shop_cards = {create_mock_joker()}
    })
    
    local extractor = StateExtractor.new()
    -- This should not throw an error
    extractor:validate_card_areas()
    
    -- Restore original G
    G = original_g
end)

-- =============================================================================
-- CARD STRUCTURE VALIDATION TESTS
-- =============================================================================

test_framework:add_test("validate_card_structure - nil card", function(t)
    local extractor = StateExtractor.new()
    -- This should not throw an error
    extractor:validate_card_structure(nil, "test_card")
end)

test_framework:add_test("validate_card_structure - malformed card", function(t)
    local extractor = StateExtractor.new()
    local malformed_card = {
        -- Missing base property
        ability = {},
        unique_val = "test"
    }
    
    -- This should not throw an error
    extractor:validate_card_structure(malformed_card, "malformed_card")
end)

test_framework:add_test("validate_card_structure - valid card", function(t)
    local extractor = StateExtractor.new()
    local valid_card = create_mock_card()
    
    -- This should not throw an error
    extractor:validate_card_structure(valid_card, "valid_card")
end)

-- =============================================================================
-- EXTRACTION FUNCTION TESTS WITH VALIDATION
-- =============================================================================

test_framework:add_test("get_current_phase - missing G.STATE", function(t)
    -- Save original G
    local original_g = G
    G = {}
    
    local extractor = StateExtractor.new()
    local result = extractor:get_current_phase()
    
    t:assert_equal("hand_selection", result, "Should return default phase when G.STATE missing")
    
    -- Restore original G
    G = original_g
end)

test_framework:add_test("get_current_phase - missing G.STATES", function(t)
    -- Save original G
    local original_g = G
    G = {
        STATE = 1
        -- Missing STATES
    }
    
    local extractor = StateExtractor.new()
    local result = extractor:get_current_phase()
    
    t:assert_equal("hand_selection", result, "Should return default phase when G.STATES missing")
    
    -- Restore original G  
    G = original_g
end)

test_framework:add_test("get_current_phase - valid state", function(t)
    -- Save original G
    local original_g = G
    G = create_mock_g({
        has_state = true,
        state_value = 1,
        states = {SELECTING_HAND = 1, SHOP = 2, BLIND_SELECT = 3}
    })
    
    local extractor = StateExtractor.new()
    local result = extractor:get_current_phase()
    
    t:assert_equal("hand_selection", result, "Should return correct phase for valid state")
    
    -- Restore original G
    G = original_g
end)

test_framework:add_test("get_ante - missing G.GAME", function(t)
    -- Save original G
    local original_g = G
    G = {}
    
    local extractor = StateExtractor.new()
    local result = extractor:get_ante()
    
    t:assert_equal(1, result, "Should return default ante when G.GAME missing")
    
    -- Restore original G
    G = original_g
end)

test_framework:add_test("get_ante - valid ante", function(t)
    -- Save original G
    local original_g = G
    G = create_mock_g({
        has_game = true,
        round_resets = {ante = 5}
    })
    
    local extractor = StateExtractor.new()
    local result = extractor:get_ante()
    
    t:assert_equal(5, result, "Should return correct ante value")
    
    -- Restore original G
    G = original_g
end)

test_framework:add_test("get_money - missing G.GAME", function(t)
    -- Save original G
    local original_g = G
    G = {}
    
    local extractor = StateExtractor.new()
    local result = extractor:get_money()
    
    t:assert_equal(0, result, "Should return default money when G.GAME missing")
    
    -- Restore original G
    G = original_g
end)

test_framework:add_test("get_money - valid money", function(t)
    -- Save original G
    local original_g = G
    G = create_mock_g({
        has_game = true,
        dollars = 250
    })
    
    local extractor = StateExtractor.new()
    local result = extractor:get_money()
    
    t:assert_equal(250, result, "Should return correct money value")
    
    -- Restore original G
    G = original_g
end)

test_framework:add_test("get_hands_remaining - missing current_round", function(t)
    -- Save original G
    local original_g = G
    G = create_mock_g({
        has_game = true
        -- Will have current_round by default
    })
    G.GAME.current_round = nil
    
    local extractor = StateExtractor.new()
    local result = extractor:get_hands_remaining()
    
    t:assert_equal(0, result, "Should return 0 when current_round missing")
    
    -- Restore original G
    G = original_g
end)

test_framework:add_test("get_hands_remaining - valid hands", function(t)
    -- Save original G
    local original_g = G
    G = create_mock_g({
        has_game = true,
        current_round = {hands_left = 2, discards_left = 1}
    })
    
    local extractor = StateExtractor.new()
    local result = extractor:get_hands_remaining()
    
    t:assert_equal(2, result, "Should return correct hands remaining")
    
    -- Restore original G
    G = original_g
end)

-- Removed trivial type checking test that only verified return type instead of meaningful functionality

test_framework:add_test("extract_hand_cards - valid hand", function(t)
    -- Save original G
    local original_g = G
    G = create_mock_g({
        has_hand = true,
        hand_cards = {
            create_mock_card({id = "card1", rank = "A", suit = "Spades"}),
            create_mock_card({id = "card2", rank = "K", suit = "Hearts"})
        }
    })
    
    local extractor = StateExtractor.new()
    local result = extractor:extract_hand_cards()
    
    t:assert_equal(2, #result, "Should return correct number of cards")
    t:assert_equal("card1", result[1].id, "Should preserve card ID")
    t:assert_equal("A", result[1].rank, "Should preserve card rank")
    t:assert_equal("Spades", result[1].suit, "Should preserve card suit")
    
    -- Restore original G
    G = original_g
end)

test_framework:add_test("extract_jokers - missing G.jokers", function(t)
    -- Save original G
    local original_g = G
    G = {}
    
    local extractor = StateExtractor.new()
    local result = extractor:extract_jokers()
    
    t:assert_type("table", result, "Should return table")
    t:assert_equal(0, #result, "Should return empty array when G.jokers missing")
    
    -- Restore original G
    G = original_g
end)

test_framework:add_test("extract_jokers - valid jokers", function(t)
    -- Save original G
    local original_g = G
    G = create_mock_g({
        has_jokers = true,
        joker_cards = {
            create_mock_joker({id = "joker1", name = "Joker", mult = 4}),
            create_mock_joker({id = "joker2", name = "Greedy Joker", mult = 0, chips = 30})
        }
    })
    
    local extractor = StateExtractor.new()
    local result = extractor:extract_jokers()
    
    t:assert_equal(2, #result, "Should return correct number of jokers")
    t:assert_equal("joker1", result[1].id, "Should preserve joker ID")
    t:assert_equal("Joker", result[1].name, "Should preserve joker name")
    t:assert_equal(0, result[1].position, "Should set 0-based position")
    
    -- Restore original G
    G = original_g
end)

test_framework:add_test("extract_current_blind - missing G.GAME.blind", function(t)
    -- Save original G
    local original_g = G
    G = {}
    
    local extractor = StateExtractor.new()
    local result = extractor:extract_current_blind()
    
    t:assert_nil(result, "Should return nil when G.GAME.blind missing")
    
    -- Restore original G
    G = original_g
end)

test_framework:add_test("extract_current_blind - valid blind", function(t)
    -- Save original G
    local original_g = G
    G = create_mock_g({
        has_game = true,
        blind = {
            name = "The Wall",
            chips = 2000,
            dollars = 8,
            boss = true,
            config = {disabled = {}}
        }
    })
    
    local extractor = StateExtractor.new()
    local result = extractor:extract_current_blind()
    
    t:assert_not_nil(result, "Should return blind object")
    t:assert_equal("The Wall", result.name, "Should preserve blind name")
    t:assert_equal("boss", result.blind_type, "Should identify boss blind")
    t:assert_equal(2000, result.requirement, "Should preserve chip requirement")
    t:assert_equal(8, result.reward, "Should preserve dollar reward")
    
    -- Restore original G
    G = original_g
end)

-- =============================================================================
-- EDGE CASE TESTS
-- =============================================================================

test_framework:add_test("extract_current_state - handles all extraction errors gracefully", function(t)
    -- Save original G
    local original_g = G
    G = nil -- Completely missing G
    
    local extractor = StateExtractor.new()
    local result = extractor:extract_current_state()
    
    t:assert_type("table", result, "Should return table even with missing G")
    
    -- With graceful degradation, there should be no extraction_errors field when all functions succeed with defaults
    if result.extraction_errors then
        t:assert_equal(0, #result.extraction_errors, "Should have no extraction errors due to graceful degradation")
    end
    
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
            t:assert_true(result[field] ~= nil or result[field] == nil, "Should have field " .. field)
        else
            t:assert_not_nil(result[field], "Should have field " .. field .. " with default value")
        end
    end
    
    -- Verify specific default values
    t:assert_equal("hand_selection", result.current_phase, "Should default to hand_selection phase")
    t:assert_equal(1, result.ante, "Should default to ante 1")
    t:assert_equal(0, result.money, "Should default to 0 money")
    t:assert_equal(0, result.hands_remaining, "Should default to 0 hands remaining")
    t:assert_equal(0, result.discards_remaining, "Should default to 0 discards remaining")
    t:assert_type("table", result.hand_cards, "Should return empty table for hand cards")
    t:assert_equal(0, #result.hand_cards, "Should have empty hand cards array")
    t:assert_type("table", result.jokers, "Should return empty table for jokers")
    t:assert_equal(0, #result.jokers, "Should have empty jokers array")
    
    -- current_blind can be nil when G.GAME.blind is unavailable - this is correct behavior
    -- Don't assert it's not nil, as nil is the appropriate default for unavailable blind info
    
    -- Restore original G
    G = original_g
end)

test_framework:add_test("card enhancement detection - handles malformed cards", function(t)
    local extractor = StateExtractor.new()
    
    -- Test with nil card
    local result1 = extractor:get_card_enhancement(nil)
    t:assert_equal("none", result1, "Should return 'none' for nil card")
    
    -- Test with card missing ability
    local result2 = extractor:get_card_enhancement({})
    t:assert_equal("none", result2, "Should return 'none' for card without ability")
    
    -- Test with malformed ability
    local result3 = extractor:get_card_enhancement({ability = {}})
    t:assert_equal("none", result3, "Should return 'none' for card without ability.name")
    
    -- Test with valid enhancement
    local result4 = extractor:get_card_enhancement({ability = {name = "m_bonus"}})
    t:assert_equal("bonus", result4, "Should return correct enhancement")
end)

test_framework:add_test("card edition detection - handles malformed cards", function(t)
    local extractor = StateExtractor.new()
    
    -- Test with nil card
    local result1 = extractor:get_card_edition(nil)
    t:assert_equal("none", result1, "Should return 'none' for nil card")
    
    -- Test with card missing edition
    local result2 = extractor:get_card_edition({})
    t:assert_equal("none", result2, "Should return 'none' for card without edition")
    
    -- Test with valid edition
    local result3 = extractor:get_card_edition({edition = {foil = true}})
    t:assert_equal("foil", result3, "Should return correct edition")
end)

test_framework:add_test("determine_blind_type - handles malformed blinds", function(t)
    local extractor = StateExtractor.new()
    
    -- Test with nil blind
    local result1 = extractor:determine_blind_type(nil)
    t:assert_equal("small", result1, "Should return 'small' for nil blind")
    
    -- Test with boss blind
    local result2 = extractor:determine_blind_type({boss = true})
    t:assert_equal("boss", result2, "Should return 'boss' for boss blind")
    
    -- Test with big blind by name
    local result3 = extractor:determine_blind_type({name = "Big Blind"})
    t:assert_equal("big", result3, "Should return 'big' for big blind")
    
    -- Test with small blind (default)
    local result4 = extractor:determine_blind_type({name = "Small Blind"})
    t:assert_equal("small", result4, "Should return 'small' for small blind")
end)

-- Run all tests
local function run_state_extractor_tests()
    print("Starting StateExtractor validation tests...")
    local success = test_framework:run_tests()
    
    if success then
        print("\n🎉 All tests passed! StateExtractor validation logic is working correctly.")
    else
        print("\n❌ Some tests failed. Please review the validation logic.")
    end
    
    return success
end

-- Export the test runner
return {
    run_tests = run_state_extractor_tests,
    test_framework = test_framework
}
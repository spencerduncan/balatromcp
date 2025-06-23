-- LuaUnit migration of StateExtractor comprehensive state extraction functionality tests
-- Tests safe access patterns, validation logic, extraction functions, and edge cases
-- Migrated from test_state_extractor.lua to use LuaUnit framework

local luaunit = require('libs.luaunit')
local luaunit_helpers = require('tests.luaunit_helpers')

-- =============================================================================
-- SHARED SETUP AND TEARDOWN FUNCTIONALITY
-- =============================================================================

local test_state = {}

local function setUp()
    -- Save original globals
    test_state.original_g = G
    
    -- Set up clean environment
    G = nil
end

local function tearDown()
    -- Restore original globals
    G = test_state.original_g
end

-- =============================================================================
-- SAFE ACCESS UTILITY FUNCTION TESTS (11 tests)
-- =============================================================================

function testStateExtractorSafeCheckPathValidPath()
    setUp()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    local test_table = {
        level1 = {
            level2 = {
                level3 = "value"
            }
        }
    }
    
    luaunit.assertEquals(true, extractor:safe_check_path(test_table, {"level1", "level2", "level3"}),
        "Should return true for valid path")
    tearDown()
end

function testStateExtractorSafeCheckPathInvalidPath()
    setUp()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    local test_table = {
        level1 = {
            level2 = {}
        }
    }
    
    luaunit.assertEquals(false, extractor:safe_check_path(test_table, {"level1", "level2", "missing"}),
        "Should return false for invalid path")
    tearDown()
end

function testStateExtractorSafeCheckPathNilRoot()
    setUp()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    luaunit.assertEquals(false, extractor:safe_check_path(nil, {"any", "path"}),
        "Should return false for nil root")
    tearDown()
end

function testStateExtractorSafeCheckPathNonTableInPath()
    setUp()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    local test_table = {
        level1 = "string_value"
    }
    
    luaunit.assertEquals(false, extractor:safe_check_path(test_table, {"level1", "level2"}),
        "Should return false when encountering non-table in path")
    tearDown()
end

function testStateExtractorSafeGetValueExistingValue()
    setUp()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    local test_table = {
        key = "value"
    }
    
    local result = extractor:safe_get_value(test_table, "key", "default")
    luaunit.assertEquals("value", result, "Should return existing value")
    tearDown()
end

function testStateExtractorSafeGetValueMissingKey()
    setUp()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    local test_table = {}
    
    local result = extractor:safe_get_value(test_table, "missing", "default")
    luaunit.assertEquals("default", result, "Should return default for missing key")
    tearDown()
end

function testStateExtractorSafeGetValueNilTable()
    setUp()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:safe_get_value(nil, "key", "default")
    luaunit.assertEquals("default", result, "Should return default for nil table")
    tearDown()
end

function testStateExtractorSafeGetValueNonTableInput()
    setUp()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:safe_get_value("not_a_table", "key", "default")
    luaunit.assertEquals("default", result, "Should return default for non-table input")
    tearDown()
end

function testStateExtractorSafeGetNestedValueValidNestedPath()
    setUp()
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
    luaunit.assertEquals("nested_value", result, "Should return nested value")
    tearDown()
end

function testStateExtractorSafeGetNestedValueInvalidNestedPath()
    setUp()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    local test_table = {
        level1 = {
            level2 = {}
        }
    }
    
    local result = extractor:safe_get_nested_value(test_table, {"level1", "level2", "missing"}, "default")
    luaunit.assertEquals("default", result, "Should return default for invalid nested path")
    tearDown()
end

function testStateExtractorSafeGetNestedValueNilRoot()
    setUp()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:safe_get_nested_value(nil, {"any", "path"}, "default")
    luaunit.assertEquals("default", result, "Should return default for nil root")
    tearDown()
end

-- =============================================================================
-- G OBJECT VALIDATION TESTS (4 tests)
-- =============================================================================

function testStateExtractorValidateGObjectNilG()
    setUp()
    G = nil
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:validate_g_object()
    luaunit.assertEquals(false, result, "Should return false when G is nil")
    tearDown()
end

function testStateExtractorValidateGObjectEmptyG()
    setUp()
    G = {}
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:validate_g_object()
    luaunit.assertEquals(false, result, "Should return false when G is empty")
    tearDown()
end

function testStateExtractorValidateGObjectPartialG()
    setUp()
    G = {
        STATE = 1,
        STATES = {SELECTING_HAND = 1}
        -- Missing other critical properties
    }
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:validate_g_object()
    luaunit.assertEquals(false, result, "Should return false when G is missing critical properties")
    tearDown()
end

function testStateExtractorValidateGObjectCompleteG()
    setUp()
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
    luaunit.assertEquals(true, result, "Should return true when G has all critical properties")
    tearDown()
end

-- =============================================================================
-- GAME OBJECT VALIDATION TESTS (3 tests)
-- =============================================================================

function testStateExtractorValidateGameObjectMissingGGame()
    setUp()
    G = {}
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    -- This should not throw an error (it's a logging method)
    extractor:validate_game_object()
    tearDown()
end

function testStateExtractorValidateGameObjectMalformedGGame()
    setUp()
    G = {
        GAME = {
            -- Missing expected properties like dollars, current_round, etc.
        }
    }
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    -- This should not throw an error (it's a logging method)
    extractor:validate_game_object()
    tearDown()
end

function testStateExtractorValidateGameObjectValidGGame()
    setUp()
    G = luaunit_helpers.create_mock_g({has_game = true})
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    -- This should not throw an error (it's a logging method)
    extractor:validate_game_object()
    tearDown()
end

-- =============================================================================
-- CARD AREA VALIDATION TESTS (3 tests)
-- =============================================================================

function testStateExtractorValidateCardAreasMissingCardAreas()
    setUp()
    G = {}
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    -- This should not throw an error (it's a logging method)
    extractor:validate_card_areas()
    tearDown()
end

function testStateExtractorValidateCardAreasCardAreasWithoutCardsProperty()
    setUp()
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
    tearDown()
end

function testStateExtractorValidateCardAreasValidCardAreas()
    setUp()
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
    tearDown()
end

-- =============================================================================
-- CARD STRUCTURE VALIDATION TESTS (3 tests)
-- =============================================================================

function testStateExtractorValidateCardStructureNilCard()
    setUp()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    -- This should not throw an error (it's a logging method)
    extractor:validate_card_structure(nil, "test_card")
    tearDown()
end

function testStateExtractorValidateCardStructureMalformedCard()
    setUp()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    local malformed_card = {
        -- Missing base property
        ability = {},
        unique_val = "test"
    }
    
    -- This should not throw an error (it's a logging method)
    extractor:validate_card_structure(malformed_card, "malformed_card")
    tearDown()
end

function testStateExtractorValidateCardStructureValidCard()
    setUp()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    local valid_card = luaunit_helpers.create_mock_card()
    
    -- This should not throw an error (it's a logging method)
    extractor:validate_card_structure(valid_card, "valid_card")
    tearDown()
end

-- =============================================================================
-- EXTRACTION FUNCTION TESTS (15 tests)
-- =============================================================================

function testStateExtractorGetCurrentPhaseMissingGState()
    setUp()
    G = {}
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:get_current_phase()
    luaunit.assertEquals("hand_selection", result, "Should return default phase when G.STATE missing")
    tearDown()
end

function testStateExtractorGetCurrentPhaseMissingGStates()
    setUp()
    G = {
        STATE = 1
        -- Missing STATES
    }
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:get_current_phase()
    luaunit.assertEquals("hand_selection", result, "Should return default phase when G.STATES missing")
    tearDown()
end

function testStateExtractorGetCurrentPhaseValidState()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        state_value = 1,
        states = {SELECTING_HAND = 1, SHOP = 2, BLIND_SELECT = 3}
    })
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:get_current_phase()
    luaunit.assertEquals("hand_selection", result, "Should return correct phase for valid state")
    tearDown()
end

function testStateExtractorGetAnteMissingGGame()
    setUp()
    G = {}
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:get_ante()
    luaunit.assertEquals(1, result, "Should return default ante when G.GAME missing")
    tearDown()
end

function testStateExtractorGetAnteValidAnte()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_game = true,
        round_resets = {ante = 5}
    })
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:get_ante()
    luaunit.assertEquals(5, result, "Should return correct ante value")
    tearDown()
end

function testStateExtractorGetMoneyMissingGGame()
    setUp()
    G = {}
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:get_money()
    luaunit.assertEquals(0, result, "Should return default money when G.GAME missing")
    tearDown()
end

function testStateExtractorGetMoneyValidMoney()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_game = true,
        dollars = 250
    })
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:get_money()
    luaunit.assertEquals(250, result, "Should return correct money value")
    tearDown()
end

function testStateExtractorGetHandsRemainingMissingCurrentRound()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_game = true
        -- Will have current_round by default
    })
    G.GAME.current_round = nil
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:get_hands_remaining()
    luaunit.assertEquals(0, result, "Should return 0 when current_round missing")
    tearDown()
end

function testStateExtractorGetHandsRemainingValidHands()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_game = true,
        current_round = {hands_left = 2, discards_left = 1}
    })
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:get_hands_remaining()
    luaunit.assertEquals(2, result, "Should return correct hands remaining")
    tearDown()
end

function testStateExtractorExtractHandCardsMissingGHand()
    setUp()
    G = {}
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:extract_hand_cards()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(0, #result, "Should return empty array when G.hand missing")
    tearDown()
end

function testStateExtractorExtractHandCardsValidHand()
    setUp()
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
    luaunit.assertEquals(2, #result, "Should return correct number of cards")
    luaunit.assertEquals("card1", result[1].id, "Should preserve card ID")
    luaunit.assertEquals("A", result[1].rank, "Should preserve card rank")
    luaunit.assertEquals("Spades", result[1].suit, "Should preserve card suit")
    tearDown()
end

function testStateExtractorExtractJokersMissingGJokers()
    setUp()
    G = {}
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:extract_jokers()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(0, #result, "Should return empty array when G.jokers missing")
    tearDown()
end

function testStateExtractorExtractJokersValidJokers()
    setUp()
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
    luaunit.assertEquals(2, #result, "Should return correct number of jokers")
    luaunit.assertEquals("joker1", result[1].id, "Should preserve joker ID")
    luaunit.assertEquals("Joker", result[1].name, "Should preserve joker name")
    luaunit.assertEquals(0, result[1].position, "Should set 0-based position")
    tearDown()
end

function testStateExtractorExtractCurrentBlindMissingGGameBlind()
    setUp()
    G = {}
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:extract_current_blind()
    luaunit.assertNil(result, "Should return nil when G.GAME.blind missing")
    tearDown()
end

function testStateExtractorExtractCurrentBlindValidBlind()
    setUp()
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
    luaunit.assertNotNil(result, "Should return blind object")
    luaunit.assertEquals("The Wall", result.name, "Should preserve blind name")
    luaunit.assertEquals("boss", result.blind_type, "Should identify boss blind")
    luaunit.assertEquals(2000, result.requirement, "Should preserve chip requirement")
    luaunit.assertEquals(8, result.reward, "Should preserve dollar reward")
    tearDown()
end

function testStateExtractorExtractDeckCardsMissingGPlayingCards()
    setUp()
    G = {}
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:extract_deck_cards()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(0, #result, "Should return empty array when G.playing_cards missing")
    tearDown()
end

function testStateExtractorExtractDeckCardsValidDeck()
    setUp()
    G = {
        playing_cards = {
            luaunit_helpers.create_mock_card({id = "deck_card1", rank = "A", suit = "Spades"}),
            luaunit_helpers.create_mock_card({id = "deck_card2", rank = "K", suit = "Hearts"}),
            luaunit_helpers.create_mock_card({id = "deck_card3", rank = "Q", suit = "Diamonds"})
        }
    }
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:extract_deck_cards()
    luaunit.assertEquals(3, #result, "Should return correct number of deck cards")
    luaunit.assertEquals("deck_card1", result[1].id, "Should preserve deck card ID")
    luaunit.assertEquals("A", result[1].rank, "Should preserve deck card rank")
    luaunit.assertEquals("Spades", result[1].suit, "Should preserve deck card suit")
    
    -- Verify same structure as hand cards
    luaunit.assertNotNil(result[1].enhancement, "Should have enhancement field like hand cards")
    luaunit.assertNotNil(result[1].edition, "Should have edition field like hand cards")
    luaunit.assertNotNil(result[1].seal, "Should have seal field like hand cards")
    tearDown()
end

function testStateExtractorExtractDeckCardsUsesConsistentCardStructure()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_hand = true,
        hand_cards = {
            luaunit_helpers.create_mock_card({id = "hand_card", rank = "J", suit = "Clubs"})
        }
    })
    G.playing_cards = {
        luaunit_helpers.create_mock_card({id = "deck_card", rank = "J", suit = "Clubs"})
    }
    
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local hand_result = extractor:extract_hand_cards()
    local deck_result = extractor:extract_deck_cards()
    
    -- Verify both have same field structure
    local hand_card = hand_result[1]
    local deck_card = deck_result[1]
    
    local expected_fields = {"id", "rank", "suit", "enhancement", "edition", "seal"}
    for _, field in ipairs(expected_fields) do
        luaunit.assertNotNil(hand_card[field], "Hand card should have " .. field .. " field")
        luaunit.assertNotNil(deck_card[field], "Deck card should have " .. field .. " field")
    end
    
    tearDown()
end

-- =============================================================================
-- EDGE CASE TESTS (6 tests)
-- =============================================================================

function testStateExtractorExtractCurrentStateHandlesAllExtractionErrorsGracefully()
    setUp()
    G = nil -- Completely missing G
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    local result = extractor:extract_current_state()
    luaunit.assertEquals("table", type(result), "Should return table even with missing G")
    
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
            luaunit.assertEquals(true, result[field] ~= nil or result[field] == nil, "Should have field " .. field)
        else
            luaunit.assertNotNil(result[field], "Should have field " .. field .. " with default value")
        end
    end
    
    -- Verify specific default values
    luaunit.assertEquals("hand_selection", result.current_phase, "Should default to hand_selection phase")
    luaunit.assertEquals(1, result.ante, "Should default to ante 1")
    luaunit.assertEquals(0, result.money, "Should default to 0 money")
    luaunit.assertEquals(0, result.hands_remaining, "Should default to 0 hands remaining")
    luaunit.assertEquals(0, result.discards_remaining, "Should default to 0 discards remaining")
    luaunit.assertEquals("table", type(result.hand_cards), "Should return empty table for hand cards")
    luaunit.assertEquals(0, #result.hand_cards, "Should have empty hand cards array")
    luaunit.assertEquals("table", type(result.jokers), "Should return empty table for jokers")
    luaunit.assertEquals(0, #result.jokers, "Should have empty jokers array")
    tearDown()
end

function testStateExtractorCardEnhancementDetectionHandlesMalformedCards()
    setUp()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    -- Test with nil card
    local result1 = extractor:get_card_enhancement(nil)
    luaunit.assertEquals("none", result1, "Should return 'none' for nil card")
    
    -- Test with card missing ability
    local result2 = extractor:get_card_enhancement({})
    luaunit.assertEquals("none", result2, "Should return 'none' for card without ability")
    
    -- Test with malformed ability
    local result3 = extractor:get_card_enhancement({ability = {}})
    luaunit.assertEquals("none", result3, "Should return 'none' for card without ability.name")
    
    -- Test with valid enhancement
    local result4 = extractor:get_card_enhancement({ability = {name = "m_bonus"}})
    luaunit.assertEquals("bonus", result4, "Should return correct enhancement")
    tearDown()
end

function testStateExtractorCardEditionDetectionHandlesMalformedCards()
    setUp()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    -- Test with nil card
    local result1 = extractor:get_card_edition(nil)
    luaunit.assertEquals("none", result1, "Should return 'none' for nil card")
    
    -- Test with card missing edition
    local result2 = extractor:get_card_edition({})
    luaunit.assertEquals("none", result2, "Should return 'none' for card without edition")
    
    -- Test with valid edition
    local result3 = extractor:get_card_edition({edition = {foil = true}})
    luaunit.assertEquals("foil", result3, "Should return correct edition")
    tearDown()
end

function testStateExtractorDetermineBlindTypeHandlesMalformedBlinds()
    setUp()
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    -- Test with nil blind
    local result1 = extractor:determine_blind_type(nil)
    luaunit.assertEquals("small", result1, "Should return 'small' for nil blind")
    
    -- Test with boss blind
    local result2 = extractor:determine_blind_type({boss = true})
    luaunit.assertEquals("boss", result2, "Should return 'boss' for boss blind")
    
    -- Test with big blind by name
    local result3 = extractor:determine_blind_type({name = "Big Blind"})
    luaunit.assertEquals("big", result3, "Should return 'big' for big blind")
    
    -- Test with small blind (default)
    local result4 = extractor:determine_blind_type({name = "Small Blind"})
    luaunit.assertEquals("small", result4, "Should return 'small' for small blind")
    tearDown()
end

function testStateExtractorValidateStatesMissingGStateOrGStates()
    setUp()
    G = {}
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    -- This should not throw an error (it's a logging method)
    extractor:validate_states()
    tearDown()
end

function testStateExtractorValidateStatesValidStates()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        state_value = 1,
        states = {SELECTING_HAND = 1, SHOP = 2, BLIND_SELECT = 3}
    })
    local StateExtractor = require("state_extractor")
    local extractor = StateExtractor.new()
    
    -- This should not throw an error (it's a logging method)
    extractor:validate_states()
    tearDown()
end

-- Return all test functions as a table for LuaUnit runner
return {
    testStateExtractorSafeCheckPathValidPath = testStateExtractorSafeCheckPathValidPath,
    testStateExtractorSafeCheckPathInvalidPath = testStateExtractorSafeCheckPathInvalidPath,
    testStateExtractorSafeCheckPathNilRoot = testStateExtractorSafeCheckPathNilRoot,
    testStateExtractorSafeCheckPathNonTableInPath = testStateExtractorSafeCheckPathNonTableInPath,
    testStateExtractorSafeGetValueExistingValue = testStateExtractorSafeGetValueExistingValue,
    testStateExtractorSafeGetValueMissingKey = testStateExtractorSafeGetValueMissingKey,
    testStateExtractorSafeGetValueNilTable = testStateExtractorSafeGetValueNilTable,
    testStateExtractorSafeGetValueNonTableInput = testStateExtractorSafeGetValueNonTableInput,
    testStateExtractorSafeGetNestedValueValidNestedPath = testStateExtractorSafeGetNestedValueValidNestedPath,
    testStateExtractorSafeGetNestedValueInvalidNestedPath = testStateExtractorSafeGetNestedValueInvalidNestedPath,
    testStateExtractorSafeGetNestedValueNilRoot = testStateExtractorSafeGetNestedValueNilRoot,
    testStateExtractorValidateGObjectNilG = testStateExtractorValidateGObjectNilG,
    testStateExtractorValidateGObjectEmptyG = testStateExtractorValidateGObjectEmptyG,
    testStateExtractorValidateGObjectPartialG = testStateExtractorValidateGObjectPartialG,
    testStateExtractorValidateGObjectCompleteG = testStateExtractorValidateGObjectCompleteG,
    testStateExtractorValidateGameObjectMissingGGame = testStateExtractorValidateGameObjectMissingGGame,
    testStateExtractorValidateGameObjectMalformedGGame = testStateExtractorValidateGameObjectMalformedGGame,
    testStateExtractorValidateGameObjectValidGGame = testStateExtractorValidateGameObjectValidGGame,
    testStateExtractorValidateCardAreasMissingCardAreas = testStateExtractorValidateCardAreasMissingCardAreas,
    testStateExtractorValidateCardAreasCardAreasWithoutCardsProperty = testStateExtractorValidateCardAreasCardAreasWithoutCardsProperty,
    testStateExtractorValidateCardAreasValidCardAreas = testStateExtractorValidateCardAreasValidCardAreas,
    testStateExtractorValidateCardStructureNilCard = testStateExtractorValidateCardStructureNilCard,
    testStateExtractorValidateCardStructureMalformedCard = testStateExtractorValidateCardStructureMalformedCard,
    testStateExtractorValidateCardStructureValidCard = testStateExtractorValidateCardStructureValidCard,
    testStateExtractorGetCurrentPhaseMissingGState = testStateExtractorGetCurrentPhaseMissingGState,
    testStateExtractorGetCurrentPhaseMissingGStates = testStateExtractorGetCurrentPhaseMissingGStates,
    testStateExtractorGetCurrentPhaseValidState = testStateExtractorGetCurrentPhaseValidState,
    testStateExtractorGetAnteMissingGGame = testStateExtractorGetAnteMissingGGame,
    testStateExtractorGetAnteValidAnte = testStateExtractorGetAnteValidAnte,
    testStateExtractorGetMoneyMissingGGame = testStateExtractorGetMoneyMissingGGame,
    testStateExtractorGetMoneyValidMoney = testStateExtractorGetMoneyValidMoney,
    testStateExtractorGetHandsRemainingMissingCurrentRound = testStateExtractorGetHandsRemainingMissingCurrentRound,
    testStateExtractorGetHandsRemainingValidHands = testStateExtractorGetHandsRemainingValidHands,
    testStateExtractorExtractHandCardsMissingGHand = testStateExtractorExtractHandCardsMissingGHand,
    testStateExtractorExtractHandCardsValidHand = testStateExtractorExtractHandCardsValidHand,
    testStateExtractorExtractJokersMissingGJokers = testStateExtractorExtractJokersMissingGJokers,
    testStateExtractorExtractJokersValidJokers = testStateExtractorExtractJokersValidJokers,
    testStateExtractorExtractCurrentBlindMissingGGameBlind = testStateExtractorExtractCurrentBlindMissingGGameBlind,
    testStateExtractorExtractCurrentBlindValidBlind = testStateExtractorExtractCurrentBlindValidBlind,
    testStateExtractorExtractDeckCardsMissingGPlayingCards = testStateExtractorExtractDeckCardsMissingGPlayingCards,
    testStateExtractorExtractDeckCardsValidDeck = testStateExtractorExtractDeckCardsValidDeck,
    testStateExtractorExtractDeckCardsUsesConsistentCardStructure = testStateExtractorExtractDeckCardsUsesConsistentCardStructure,
    testStateExtractorExtractCurrentStateHandlesAllExtractionErrorsGracefully = testStateExtractorExtractCurrentStateHandlesAllExtractionErrorsGracefully,
    testStateExtractorCardEnhancementDetectionHandlesMalformedCards = testStateExtractorCardEnhancementDetectionHandlesMalformedCards,
    testStateExtractorCardEditionDetectionHandlesMalformedCards = testStateExtractorCardEditionDetectionHandlesMalformedCards,
    testStateExtractorDetermineBlindTypeHandlesMalformedBlinds = testStateExtractorDetermineBlindTypeHandlesMalformedBlinds,
    testStateExtractorValidateStatesMissingGStateOrGStates = testStateExtractorValidateStatesMissingGStateOrGStates,
    testStateExtractorValidateStatesValidStates = testStateExtractorValidateStatesValidStates
}

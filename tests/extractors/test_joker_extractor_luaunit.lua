-- LuaUnit tests for JokerExtractor
-- Tests joker cards extraction

local luaunit = require('libs.luaunit')
local luaunit_helpers = require('tests.luaunit_helpers')

-- =============================================================================
-- SETUP AND TEARDOWN
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
-- JOKER EXTRACTOR TESTS
-- =============================================================================

function testJokerExtractorExtractMissingGJokers()
    setUp()
    G = {}
    local JokerExtractor = require("state_extractor.extractors.joker_extractor")
    local extractor = JokerExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("table", type(result.jokers), "Should return jokers table")
    luaunit.assertEquals(0, #result.jokers, "Should return empty array when G.jokers missing")
    tearDown()
end

function testJokerExtractorExtractValidJokers()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_jokers = true,
        joker_cards = {
            luaunit_helpers.create_mock_joker({id = "joker1", name = "Joker", mult = 4}),
            luaunit_helpers.create_mock_joker({id = "joker2", name = "Greedy Joker", mult = 0, chips = 30})
        }
    })
    local JokerExtractor = require("state_extractor.extractors.joker_extractor")
    local extractor = JokerExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("table", type(result.jokers), "Should return jokers table")
    luaunit.assertEquals(2, #result.jokers, "Should return correct number of jokers")
    
    -- Check first joker
    luaunit.assertEquals("joker1", result.jokers[1].id, "Should preserve joker ID")
    luaunit.assertEquals("Joker", result.jokers[1].name, "Should preserve joker name")
    luaunit.assertEquals(0, result.jokers[1].position, "Should set 0-based position")
    luaunit.assertNotNil(result.jokers[1].properties, "Should have properties field")
    
    -- Check second joker
    luaunit.assertEquals("joker2", result.jokers[2].id, "Should preserve second joker ID")
    luaunit.assertEquals("Greedy Joker", result.jokers[2].name, "Should preserve second joker name")
    luaunit.assertEquals(1, result.jokers[2].position, "Should set correct 0-based position for second joker")
    tearDown()
end

function testJokerExtractorExtractEmptyJokers()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_jokers = true,
        joker_cards = {}
    })
    local JokerExtractor = require("state_extractor.extractors.joker_extractor")
    local extractor = JokerExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("table", type(result.jokers), "Should return jokers table")
    luaunit.assertEquals(0, #result.jokers, "Should return empty array for empty jokers")
    tearDown()
end

function testJokerExtractorExtractJokersDirectCall()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_jokers = true,
        joker_cards = {
            luaunit_helpers.create_mock_joker({id = "direct_joker", name = "Direct Joker", mult = 8})
        }
    })
    local JokerExtractor = require("state_extractor.extractors.joker_extractor")
    local extractor = JokerExtractor.new()
    
    local result = extractor:extract_jokers()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(1, #result, "Should return correct number of jokers")
    luaunit.assertEquals("direct_joker", result[1].id, "Should preserve joker ID")
    luaunit.assertEquals("Direct Joker", result[1].name, "Should preserve joker name")
    luaunit.assertEquals(0, result[1].position, "Should set 0-based position")
    tearDown()
end

function testJokerExtractorHandleNilJokers()
    setUp()
    G = {
        jokers = {
            cards = {
                luaunit_helpers.create_mock_joker({id = "valid_joker", name = "Valid Joker"}),
                nil, -- Nil joker in the middle
                luaunit_helpers.create_mock_joker({id = "another_valid", name = "Another Valid"})
            }
        }
    }
    local JokerExtractor = require("state_extractor.extractors.joker_extractor")
    local extractor = JokerExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("table", type(result.jokers), "Should return jokers table")
    luaunit.assertEquals(2, #result.jokers, "Should skip nil jokers and return only valid ones")
    luaunit.assertEquals("valid_joker", result.jokers[1].id, "Should preserve first valid joker")
    luaunit.assertEquals("another_valid", result.jokers[2].id, "Should preserve second valid joker")
    luaunit.assertEquals(1, result.jokers[2].position, "Should set correct position for second joker")
    tearDown()
end

function testJokerExtractorGetName()
    setUp()
    local JokerExtractor = require("state_extractor.extractors.joker_extractor")
    local extractor = JokerExtractor.new()
    
    luaunit.assertEquals("joker_extractor", extractor:get_name(), "Should return correct extractor name")
    tearDown()
end

function testJokerExtractorExtractWithMissingAbilityName()
    setUp()
    local joker_without_name = {
        unique_val = "unnamed_joker",
        ability = {} -- Missing name field
    }
    
    G = luaunit_helpers.create_mock_g({
        has_jokers = true,
        joker_cards = {joker_without_name}
    })
    local JokerExtractor = require("state_extractor.extractors.joker_extractor")
    local extractor = JokerExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(1, #result.jokers, "Should return one joker")
    
    local joker = result.jokers[1]
    luaunit.assertEquals("unnamed_joker", joker.id, "Should preserve joker ID")
    luaunit.assertEquals("Unknown", joker.name, "Should use default name for missing ability name")
    luaunit.assertEquals(0, joker.position, "Should set 0-based position")
    tearDown()
end

function testJokerExtractorExtractWithMissingAbility()
    setUp()
    local joker_without_ability = {
        unique_val = "no_ability_joker"
        -- Missing ability field entirely
    }
    
    G = luaunit_helpers.create_mock_g({
        has_jokers = true,
        joker_cards = {joker_without_ability}
    })
    local JokerExtractor = require("state_extractor.extractors.joker_extractor")
    local extractor = JokerExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(1, #result.jokers, "Should return one joker")
    
    local joker = result.jokers[1]
    luaunit.assertEquals("no_ability_joker", joker.id, "Should preserve joker ID")
    luaunit.assertEquals("Unknown", joker.name, "Should use default name for missing ability")
    tearDown()
end

function testJokerExtractorValidateCardAreasDoesNotThrow()
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
    local JokerExtractor = require("state_extractor.extractors.joker_extractor")
    local extractor = JokerExtractor.new()
    
    -- This should not throw an error (it's a validation method)
    extractor:validate_card_areas()
    tearDown()
end

function testJokerExtractorExtractHandlesException()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_jokers = true,
        joker_cards = {luaunit_helpers.create_mock_joker()}
    })
    local JokerExtractor = require("state_extractor.extractors.joker_extractor")
    local extractor = JokerExtractor.new()
    
    -- Override extract_jokers to throw an error
    local original_extract = extractor.extract_jokers
    extractor.extract_jokers = function(self)
        error("Test error")
    end
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table even on error")
    luaunit.assertEquals("table", type(result.jokers), "Should return jokers table on error")
    luaunit.assertEquals(0, #result.jokers, "Should return empty array on error")
    tearDown()
end

-- Return all test functions as a table for LuaUnit runner
return {
    testJokerExtractorExtractMissingGJokers = testJokerExtractorExtractMissingGJokers,
    testJokerExtractorExtractValidJokers = testJokerExtractorExtractValidJokers,
    testJokerExtractorExtractEmptyJokers = testJokerExtractorExtractEmptyJokers,
    testJokerExtractorExtractJokersDirectCall = testJokerExtractorExtractJokersDirectCall,
    testJokerExtractorHandleNilJokers = testJokerExtractorHandleNilJokers,
    testJokerExtractorGetName = testJokerExtractorGetName,
    testJokerExtractorExtractWithMissingAbilityName = testJokerExtractorExtractWithMissingAbilityName,
    testJokerExtractorExtractWithMissingAbility = testJokerExtractorExtractWithMissingAbility,
    testJokerExtractorValidateCardAreasDoesNotThrow = testJokerExtractorValidateCardAreasDoesNotThrow,
    testJokerExtractorExtractHandlesException = testJokerExtractorExtractHandlesException
}
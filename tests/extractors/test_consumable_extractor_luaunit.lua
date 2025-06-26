-- LuaUnit tests for ConsumableExtractor
-- Tests consumable cards extraction

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
-- CONSUMABLE EXTRACTOR TESTS
-- =============================================================================

function testConsumableExtractorExtractMissingGConsumables()
    setUp()
    G = {}
    local ConsumableExtractor = require("state_extractor.extractors.consumable_extractor")
    local extractor = ConsumableExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("table", type(result.consumables), "Should return consumables table")
    luaunit.assertEquals(0, #result.consumables, "Should return empty array when G.consumeables missing")
    tearDown()
end

function testConsumableExtractorExtractValidConsumables()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_consumables = true,
        consumable_cards = {
            luaunit_helpers.create_mock_card({id = "tarot1", ability_name = "c_fool"}),
            luaunit_helpers.create_mock_card({id = "planet1", ability_name = "c_mercury"})
        }
    })
    local ConsumableExtractor = require("state_extractor.extractors.consumable_extractor")
    local extractor = ConsumableExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("table", type(result.consumables), "Should return consumables table")
    luaunit.assertEquals(2, #result.consumables, "Should return correct number of consumables")
    
    -- Check first consumable
    luaunit.assertEquals("tarot1", result.consumables[1].id, "Should preserve consumable ID")
    luaunit.assertEquals("c_fool", result.consumables[1].name, "Should preserve consumable name")
    luaunit.assertEquals("Tarot", result.consumables[1].card_type, "Should set default card_type")
    luaunit.assertNotNil(result.consumables[1].properties, "Should have properties field")
    
    -- Check second consumable
    luaunit.assertEquals("planet1", result.consumables[2].id, "Should preserve second consumable ID")
    luaunit.assertEquals("c_mercury", result.consumables[2].name, "Should preserve second consumable name")
    tearDown()
end

function testConsumableExtractorExtractEmptyConsumables()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_consumables = true,
        consumable_cards = {}
    })
    local ConsumableExtractor = require("state_extractor.extractors.consumable_extractor")
    local extractor = ConsumableExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("table", type(result.consumables), "Should return consumables table")
    luaunit.assertEquals(0, #result.consumables, "Should return empty array for empty consumables")
    tearDown()
end

function testConsumableExtractorExtractConsumablesDirectCall()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_consumables = true,
        consumable_cards = {
            luaunit_helpers.create_mock_card({id = "direct_consumable", ability_name = "c_strength"})
        }
    })
    local ConsumableExtractor = require("state_extractor.extractors.consumable_extractor")
    local extractor = ConsumableExtractor.new()
    
    local result = extractor:extract_consumables()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(1, #result, "Should return correct number of consumables")
    luaunit.assertEquals("direct_consumable", result[1].id, "Should preserve consumable ID")
    luaunit.assertEquals("c_strength", result[1].name, "Should preserve consumable name")
    tearDown()
end

function testConsumableExtractorHandleNilConsumables()
    setUp()
    G = {
        consumeables = {
            cards = {
                luaunit_helpers.create_mock_card({id = "valid_consumable", ability_name = "c_lovers"}),
                nil, -- Nil consumable in the middle
                luaunit_helpers.create_mock_card({id = "another_valid", ability_name = "c_star"})
            }
        }
    }
    local ConsumableExtractor = require("state_extractor.extractors.consumable_extractor")
    local extractor = ConsumableExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("table", type(result.consumables), "Should return consumables table")
    luaunit.assertEquals(2, #result.consumables, "Should skip nil consumables and return only valid ones")
    luaunit.assertEquals("valid_consumable", result.consumables[1].id, "Should preserve first valid consumable")
    luaunit.assertEquals("another_valid", result.consumables[2].id, "Should preserve second valid consumable")
    tearDown()
end

function testConsumableExtractorGetName()
    setUp()
    local ConsumableExtractor = require("state_extractor.extractors.consumable_extractor")
    local extractor = ConsumableExtractor.new()
    
    luaunit.assertEquals("consumable_extractor", extractor:get_name(), "Should return correct extractor name")
    tearDown()
end

function testConsumableExtractorExtractWithMissingAbilityName()
    setUp()
    local consumable_without_name = {
        unique_val = "unnamed_consumable",
        ability = {} -- Missing name field
    }
    
    G = luaunit_helpers.create_mock_g({
        has_consumables = true,
        consumable_cards = {consumable_without_name}
    })
    local ConsumableExtractor = require("state_extractor.extractors.consumable_extractor")
    local extractor = ConsumableExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(1, #result.consumables, "Should return one consumable")
    
    local consumable = result.consumables[1]
    luaunit.assertEquals("unnamed_consumable", consumable.id, "Should preserve consumable ID")
    luaunit.assertEquals("Unknown", consumable.name, "Should use default name for missing ability name")
    luaunit.assertEquals("Tarot", consumable.card_type, "Should use default card_type")
    tearDown()
end

function testConsumableExtractorExtractWithMissingAbility()
    setUp()
    local consumable_without_ability = {
        unique_val = "no_ability_consumable"
        -- Missing ability field entirely
    }
    
    G = luaunit_helpers.create_mock_g({
        has_consumables = true,
        consumable_cards = {consumable_without_ability}
    })
    local ConsumableExtractor = require("state_extractor.extractors.consumable_extractor")
    local extractor = ConsumableExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(1, #result.consumables, "Should return one consumable")
    
    local consumable = result.consumables[1]
    luaunit.assertEquals("no_ability_consumable", consumable.id, "Should preserve consumable ID")
    luaunit.assertEquals("Unknown", consumable.name, "Should use default name for missing ability")
    luaunit.assertEquals("Tarot", consumable.card_type, "Should use default card_type for missing ability")
    tearDown()
end

function testConsumableExtractorExtractWithCustomCardType()
    setUp()
    local planet_consumable = luaunit_helpers.create_mock_card({
        id = "planet_consumable", 
        ability_name = "c_mercury"
    })
    planet_consumable.ability.set = "Planet"
    
    G = luaunit_helpers.create_mock_g({
        has_consumables = true,
        consumable_cards = {planet_consumable}
    })
    local ConsumableExtractor = require("state_extractor.extractors.consumable_extractor")
    local extractor = ConsumableExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(1, #result.consumables, "Should return one consumable")
    
    local consumable = result.consumables[1]
    luaunit.assertEquals("planet_consumable", consumable.id, "Should preserve consumable ID")
    luaunit.assertEquals("Planet", consumable.card_type, "Should preserve custom card_type")
    tearDown()
end

function testConsumableExtractorValidateCardAreasDoesNotThrow()
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
    local ConsumableExtractor = require("state_extractor.extractors.consumable_extractor")
    local extractor = ConsumableExtractor.new()
    
    -- This should not throw an error (it's a validation method)
    extractor:validate_card_areas()
    tearDown()
end

function testConsumableExtractorExtractHandlesException()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_consumables = true,
        consumable_cards = {luaunit_helpers.create_mock_card({ability_name = "c_fool"})}
    })
    local ConsumableExtractor = require("state_extractor.extractors.consumable_extractor")
    local extractor = ConsumableExtractor.new()
    
    -- Override extract_consumables to throw an error
    local original_extract = extractor.extract_consumables
    extractor.extract_consumables = function(self)
        error("Test error")
    end
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table even on error")
    luaunit.assertEquals("table", type(result.consumables), "Should return consumables table on error")
    luaunit.assertEquals(0, #result.consumables, "Should return empty array on error")
    tearDown()
end

-- Return all test functions as a table for LuaUnit runner
return {
    testConsumableExtractorExtractMissingGConsumables = testConsumableExtractorExtractMissingGConsumables,
    testConsumableExtractorExtractValidConsumables = testConsumableExtractorExtractValidConsumables,
    testConsumableExtractorExtractEmptyConsumables = testConsumableExtractorExtractEmptyConsumables,
    testConsumableExtractorExtractConsumablesDirectCall = testConsumableExtractorExtractConsumablesDirectCall,
    testConsumableExtractorHandleNilConsumables = testConsumableExtractorHandleNilConsumables,
    testConsumableExtractorGetName = testConsumableExtractorGetName,
    testConsumableExtractorExtractWithMissingAbilityName = testConsumableExtractorExtractWithMissingAbilityName,
    testConsumableExtractorExtractWithMissingAbility = testConsumableExtractorExtractWithMissingAbility,
    testConsumableExtractorExtractWithCustomCardType = testConsumableExtractorExtractWithCustomCardType,
    testConsumableExtractorValidateCardAreasDoesNotThrow = testConsumableExtractorValidateCardAreasDoesNotThrow,
    testConsumableExtractorExtractHandlesException = testConsumableExtractorExtractHandlesException
}
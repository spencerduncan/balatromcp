-- LuaUnit tests for HandCardExtractor
-- Tests hand cards extraction

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
-- HAND CARD EXTRACTOR TESTS
-- =============================================================================

function testHandCardExtractorExtractMissingGHand()
    setUp()
    G = {}
    local HandCardExtractor = require("state_extractor.extractors.hand_card_extractor")
    local extractor = HandCardExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("table", type(result.hand_cards), "Should return hand_cards table")
    luaunit.assertEquals(0, #result.hand_cards, "Should return empty array when G.hand missing")
    tearDown()
end

function testHandCardExtractorExtractValidHand()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_hand = true,
        hand_cards = {
            luaunit_helpers.create_mock_card({id = "card1", rank = "A", suit = "Spades"}),
            luaunit_helpers.create_mock_card({id = "card2", rank = "K", suit = "Hearts"})
        }
    })
    local HandCardExtractor = require("state_extractor.extractors.hand_card_extractor")
    local extractor = HandCardExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("table", type(result.hand_cards), "Should return hand_cards table")
    luaunit.assertEquals(2, #result.hand_cards, "Should return correct number of cards")
    
    -- Check first card
    luaunit.assertEquals("card1", result.hand_cards[1].id, "Should preserve card ID")
    luaunit.assertEquals("A", result.hand_cards[1].rank, "Should preserve card rank")
    luaunit.assertEquals("Spades", result.hand_cards[1].suit, "Should preserve card suit")
    luaunit.assertNotNil(result.hand_cards[1].enhancement, "Should have enhancement field")
    luaunit.assertNotNil(result.hand_cards[1].edition, "Should have edition field")
    luaunit.assertNotNil(result.hand_cards[1].seal, "Should have seal field")
    
    -- Check second card
    luaunit.assertEquals("card2", result.hand_cards[2].id, "Should preserve second card ID")
    luaunit.assertEquals("K", result.hand_cards[2].rank, "Should preserve second card rank")
    luaunit.assertEquals("Hearts", result.hand_cards[2].suit, "Should preserve second card suit")
    tearDown()
end

function testHandCardExtractorExtractEmptyHand()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_hand = true,
        hand_cards = {}
    })
    local HandCardExtractor = require("state_extractor.extractors.hand_card_extractor")
    local extractor = HandCardExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("table", type(result.hand_cards), "Should return hand_cards table")
    luaunit.assertEquals(0, #result.hand_cards, "Should return empty array for empty hand")
    tearDown()
end

function testHandCardExtractorExtractHandCardsDirectCall()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_hand = true,
        hand_cards = {
            luaunit_helpers.create_mock_card({id = "direct_card", rank = "Q", suit = "Diamonds"})
        }
    })
    local HandCardExtractor = require("state_extractor.extractors.hand_card_extractor")
    local extractor = HandCardExtractor.new()
    
    local result = extractor:extract_hand_cards()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(1, #result, "Should return correct number of cards")
    luaunit.assertEquals("direct_card", result[1].id, "Should preserve card ID")
    luaunit.assertEquals("Q", result[1].rank, "Should preserve card rank")
    luaunit.assertEquals("Diamonds", result[1].suit, "Should preserve card suit")
    tearDown()
end

function testHandCardExtractorHandleNilCards()
    setUp()
    G = {
        hand = {
            cards = {
                luaunit_helpers.create_mock_card({id = "valid_card", rank = "J", suit = "Clubs"}),
                nil, -- Nil card in the middle
                luaunit_helpers.create_mock_card({id = "another_valid", rank = "10", suit = "Spades"})
            }
        }
    }
    local HandCardExtractor = require("state_extractor.extractors.hand_card_extractor")
    local extractor = HandCardExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("table", type(result.hand_cards), "Should return hand_cards table")
    luaunit.assertEquals(2, #result.hand_cards, "Should skip nil cards and return only valid ones")
    luaunit.assertEquals("valid_card", result.hand_cards[1].id, "Should preserve first valid card")
    luaunit.assertEquals("another_valid", result.hand_cards[2].id, "Should preserve second valid card")
    tearDown()
end

function testHandCardExtractorGetName()
    setUp()
    local HandCardExtractor = require("state_extractor.extractors.hand_card_extractor")
    local extractor = HandCardExtractor.new()
    
    luaunit.assertEquals("hand_card_extractor", extractor:get_name(), "Should return correct extractor name")
    tearDown()
end

function testHandCardExtractorExtractWithCardEnhancements()
    setUp()
    local enhanced_card = luaunit_helpers.create_mock_card({
        id = "enhanced_card", 
        rank = "A", 
        suit = "Hearts",
        ability_name = "m_bonus"
    })
    enhanced_card.edition = {foil = true}
    enhanced_card.seal = "Red"
    
    G = luaunit_helpers.create_mock_g({
        has_hand = true,
        hand_cards = {enhanced_card}
    })
    local HandCardExtractor = require("state_extractor.extractors.hand_card_extractor")
    local extractor = HandCardExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(1, #result.hand_cards, "Should return one card")
    
    local card = result.hand_cards[1]
    luaunit.assertEquals("enhanced_card", card.id, "Should preserve card ID")
    luaunit.assertEquals("A", card.rank, "Should preserve card rank")
    luaunit.assertEquals("Hearts", card.suit, "Should preserve card suit")
    luaunit.assertNotNil(card.enhancement, "Should have enhancement field")
    luaunit.assertNotNil(card.edition, "Should have edition field")  
    luaunit.assertNotNil(card.seal, "Should have seal field")
    tearDown()
end

function testHandCardExtractorValidateCardAreasDoesNotThrow()
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
    local HandCardExtractor = require("state_extractor.extractors.hand_card_extractor")
    local extractor = HandCardExtractor.new()
    
    -- This should not throw an error (it's a validation method)
    extractor:validate_card_areas()
    tearDown()
end

function testHandCardExtractorExtractHandlesException()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_hand = true,
        hand_cards = {luaunit_helpers.create_mock_card()}
    })
    local HandCardExtractor = require("state_extractor.extractors.hand_card_extractor")
    local extractor = HandCardExtractor.new()
    
    -- Override extract_hand_cards to throw an error
    local original_extract = extractor.extract_hand_cards
    extractor.extract_hand_cards = function(self)
        error("Test error")
    end
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table even on error")
    luaunit.assertEquals("table", type(result.hand_cards), "Should return hand_cards table on error")
    luaunit.assertEquals(0, #result.hand_cards, "Should return empty array on error")
    tearDown()
end

-- Return all test functions as a table for LuaUnit runner
return {
    testHandCardExtractorExtractMissingGHand = testHandCardExtractorExtractMissingGHand,
    testHandCardExtractorExtractValidHand = testHandCardExtractorExtractValidHand,
    testHandCardExtractorExtractEmptyHand = testHandCardExtractorExtractEmptyHand,
    testHandCardExtractorExtractHandCardsDirectCall = testHandCardExtractorExtractHandCardsDirectCall,
    testHandCardExtractorHandleNilCards = testHandCardExtractorHandleNilCards,
    testHandCardExtractorGetName = testHandCardExtractorGetName,
    testHandCardExtractorExtractWithCardEnhancements = testHandCardExtractorExtractWithCardEnhancements,
    testHandCardExtractorValidateCardAreasDoesNotThrow = testHandCardExtractorValidateCardAreasDoesNotThrow,
    testHandCardExtractorExtractHandlesException = testHandCardExtractorExtractHandlesException
}
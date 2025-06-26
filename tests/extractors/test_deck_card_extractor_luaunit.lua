-- LuaUnit tests for DeckCardExtractor
-- Tests deck cards extraction

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
-- DECK CARD EXTRACTOR TESTS
-- =============================================================================

function testDeckCardExtractorExtractMissingGPlayingCards()
    setUp()
    G = {}
    local DeckCardExtractor = require("state_extractor.extractors.deck_card_extractor")
    local extractor = DeckCardExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("table", type(result.deck_cards), "Should return deck_cards table")
    luaunit.assertEquals(0, #result.deck_cards, "Should return empty array when G.playing_cards missing")
    tearDown()
end

function testDeckCardExtractorExtractValidDeck()
    setUp()
    G = {
        playing_cards = {
            luaunit_helpers.create_mock_card({id = "deck_card1", rank = "A", suit = "Spades"}),
            luaunit_helpers.create_mock_card({id = "deck_card2", rank = "K", suit = "Hearts"}),
            luaunit_helpers.create_mock_card({id = "deck_card3", rank = "Q", suit = "Diamonds"})
        }
    }
    local DeckCardExtractor = require("state_extractor.extractors.deck_card_extractor")
    local extractor = DeckCardExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("table", type(result.deck_cards), "Should return deck_cards table")
    luaunit.assertEquals(3, #result.deck_cards, "Should return correct number of deck cards")
    
    -- Check first deck card
    luaunit.assertEquals("deck_card1", result.deck_cards[1].id, "Should preserve deck card ID")
    luaunit.assertEquals("A", result.deck_cards[1].rank, "Should preserve deck card rank")
    luaunit.assertEquals("Spades", result.deck_cards[1].suit, "Should preserve deck card suit")
    
    -- Verify same structure as hand cards
    luaunit.assertNotNil(result.deck_cards[1].enhancement, "Should have enhancement field like hand cards")
    luaunit.assertNotNil(result.deck_cards[1].edition, "Should have edition field like hand cards")
    luaunit.assertNotNil(result.deck_cards[1].seal, "Should have seal field like hand cards")
    tearDown()
end

function testDeckCardExtractorExtractEmptyDeck()
    setUp()
    G = {
        playing_cards = {}
    }
    local DeckCardExtractor = require("state_extractor.extractors.deck_card_extractor")
    local extractor = DeckCardExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("table", type(result.deck_cards), "Should return deck_cards table")
    luaunit.assertEquals(0, #result.deck_cards, "Should return empty array for empty deck")
    tearDown()
end

function testDeckCardExtractorExtractDeckCardsDirectCall()
    setUp()
    G = {
        playing_cards = {
            luaunit_helpers.create_mock_card({id = "direct_deck_card", rank = "J", suit = "Clubs"})
        }
    }
    local DeckCardExtractor = require("state_extractor.extractors.deck_card_extractor")
    local extractor = DeckCardExtractor.new()
    
    local result = extractor:extract_deck_cards()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(1, #result, "Should return correct number of deck cards")
    luaunit.assertEquals("direct_deck_card", result[1].id, "Should preserve deck card ID")
    luaunit.assertEquals("J", result[1].rank, "Should preserve deck card rank")
    luaunit.assertEquals("Clubs", result[1].suit, "Should preserve deck card suit")
    tearDown()
end

function testDeckCardExtractorHandleNilCards()
    setUp()
    G = {
        playing_cards = {
            luaunit_helpers.create_mock_card({id = "valid_deck_card", rank = "10", suit = "Hearts"}),
            nil, -- Nil card in the middle
            luaunit_helpers.create_mock_card({id = "another_valid_deck", rank = "9", suit = "Diamonds"})
        }
    }
    local DeckCardExtractor = require("state_extractor.extractors.deck_card_extractor")
    local extractor = DeckCardExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("table", type(result.deck_cards), "Should return deck_cards table")
    luaunit.assertEquals(2, #result.deck_cards, "Should skip nil cards and return only valid ones")
    luaunit.assertEquals("valid_deck_card", result.deck_cards[1].id, "Should preserve first valid deck card")
    luaunit.assertEquals("another_valid_deck", result.deck_cards[2].id, "Should preserve second valid deck card")
    tearDown()
end

function testDeckCardExtractorGetName()
    setUp()
    local DeckCardExtractor = require("state_extractor.extractors.deck_card_extractor")
    local extractor = DeckCardExtractor.new()
    
    luaunit.assertEquals("deck_card_extractor", extractor:get_name(), "Should return correct extractor name")
    tearDown()
end

function testDeckCardExtractorUsesConsistentCardStructure()
    setUp()
    -- Create both hand and deck cards to compare structure
    G = luaunit_helpers.create_mock_g({
        has_hand = true,
        hand_cards = {
            luaunit_helpers.create_mock_card({id = "hand_card", rank = "J", suit = "Clubs"})
        }
    })
    G.playing_cards = {
        luaunit_helpers.create_mock_card({id = "deck_card", rank = "J", suit = "Clubs"})
    }
    
    local HandCardExtractor = require("state_extractor.extractors.hand_card_extractor")
    local DeckCardExtractor = require("state_extractor.extractors.deck_card_extractor")
    local hand_extractor = HandCardExtractor.new()
    local deck_extractor = DeckCardExtractor.new()
    
    local hand_result = hand_extractor:extract()
    local deck_result = deck_extractor:extract()
    
    -- Verify both have same field structure
    local hand_card = hand_result.hand_cards[1]
    local deck_card = deck_result.deck_cards[1]
    
    local expected_fields = {"id", "rank", "suit", "enhancement", "edition", "seal"}
    for _, field in ipairs(expected_fields) do
        luaunit.assertNotNil(hand_card[field], "Hand card should have " .. field .. " field")
        luaunit.assertNotNil(deck_card[field], "Deck card should have " .. field .. " field")
    end
    
    tearDown()
end

function testDeckCardExtractorExtractWithCardEnhancements()
    setUp()
    local enhanced_deck_card = luaunit_helpers.create_mock_card({
        id = "enhanced_deck_card", 
        rank = "K", 
        suit = "Spades",
        ability_name = "m_stone"
    })
    enhanced_deck_card.edition = {holo = true}
    enhanced_deck_card.seal = "Blue"
    
    G = {
        playing_cards = {enhanced_deck_card}
    }
    local DeckCardExtractor = require("state_extractor.extractors.deck_card_extractor")
    local extractor = DeckCardExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(1, #result.deck_cards, "Should return one deck card")
    
    local card = result.deck_cards[1]
    luaunit.assertEquals("enhanced_deck_card", card.id, "Should preserve deck card ID")
    luaunit.assertEquals("K", card.rank, "Should preserve deck card rank")
    luaunit.assertEquals("Spades", card.suit, "Should preserve deck card suit")
    luaunit.assertNotNil(card.enhancement, "Should have enhancement field")
    luaunit.assertNotNil(card.edition, "Should have edition field")  
    luaunit.assertNotNil(card.seal, "Should have seal field")
    tearDown()
end

function testDeckCardExtractorExtractHandlesException()
    setUp()
    G = {
        playing_cards = {luaunit_helpers.create_mock_card()}
    }
    local DeckCardExtractor = require("state_extractor.extractors.deck_card_extractor")
    local extractor = DeckCardExtractor.new()
    
    -- Override extract_deck_cards to throw an error
    local original_extract = extractor.extract_deck_cards
    extractor.extract_deck_cards = function(self)
        error("Test error")
    end
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table even on error")
    luaunit.assertEquals("table", type(result.deck_cards), "Should return deck_cards table on error")
    luaunit.assertEquals(0, #result.deck_cards, "Should return empty array on error")
    tearDown()
end

-- Return all test functions as a table for LuaUnit runner
return {
    testDeckCardExtractorExtractMissingGPlayingCards = testDeckCardExtractorExtractMissingGPlayingCards,
    testDeckCardExtractorExtractValidDeck = testDeckCardExtractorExtractValidDeck,
    testDeckCardExtractorExtractEmptyDeck = testDeckCardExtractorExtractEmptyDeck,
    testDeckCardExtractorExtractDeckCardsDirectCall = testDeckCardExtractorExtractDeckCardsDirectCall,
    testDeckCardExtractorHandleNilCards = testDeckCardExtractorHandleNilCards,
    testDeckCardExtractorGetName = testDeckCardExtractorGetName,
    testDeckCardExtractorUsesConsistentCardStructure = testDeckCardExtractorUsesConsistentCardStructure,
    testDeckCardExtractorExtractWithCardEnhancements = testDeckCardExtractorExtractWithCardEnhancements,
    testDeckCardExtractorExtractHandlesException = testDeckCardExtractorExtractHandlesException
}
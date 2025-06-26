-- LuaUnit tests for RoundStateExtractor
-- Tests hands and discards remaining extraction

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
-- ROUND STATE EXTRACTOR TESTS
-- =============================================================================

function testRoundStateExtractorExtractMissingCurrentRound()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_game = true
        -- Will have current_round by default
    })
    G.GAME.current_round = nil
    local RoundStateExtractor = require("state_extractor.extractors.round_state_extractor")
    local extractor = RoundStateExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(0, result.hands_remaining, "Should return 0 when current_round missing")
    luaunit.assertEquals(0, result.discards_remaining, "Should return 0 when current_round missing")
    tearDown()
end

function testRoundStateExtractorExtractValidRoundState()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_game = true,
        current_round = {hands_left = 2, discards_left = 1}
    })
    local RoundStateExtractor = require("state_extractor.extractors.round_state_extractor")
    local extractor = RoundStateExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(2, result.hands_remaining, "Should return correct hands remaining")
    luaunit.assertEquals(1, result.discards_remaining, "Should return correct discards remaining")
    tearDown()
end

function testRoundStateExtractorExtractZeroRemainingValues()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_game = true,
        current_round = {hands_left = 0, discards_left = 0}
    })
    local RoundStateExtractor = require("state_extractor.extractors.round_state_extractor")
    local extractor = RoundStateExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(0, result.hands_remaining, "Should handle zero hands remaining")
    luaunit.assertEquals(0, result.discards_remaining, "Should handle zero discards remaining")
    tearDown()
end

function testRoundStateExtractorExtractMissingGGame()
    setUp()
    G = {}
    local RoundStateExtractor = require("state_extractor.extractors.round_state_extractor")
    local extractor = RoundStateExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(0, result.hands_remaining, "Should return default when G.GAME missing")
    luaunit.assertEquals(0, result.discards_remaining, "Should return default when G.GAME missing")
    tearDown()
end

function testRoundStateExtractorExtractPartialCurrentRound()
    setUp()
    G = {
        GAME = {
            current_round = {
                hands_left = 3
                -- Missing discards_left
            }
        }
    }
    local RoundStateExtractor = require("state_extractor.extractors.round_state_extractor")
    local extractor = RoundStateExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(3, result.hands_remaining, "Should return hands when available")
    luaunit.assertEquals(0, result.discards_remaining, "Should return default for missing discards")
    tearDown()
end

function testRoundStateExtractorGetName()
    setUp()
    local RoundStateExtractor = require("state_extractor.extractors.round_state_extractor")
    local extractor = RoundStateExtractor.new()
    
    luaunit.assertEquals("round_state_extractor", extractor:get_name(), "Should return correct extractor name")
    tearDown()
end

function testRoundStateExtractorGetHandsRemainingDirectCall()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_game = true,
        current_round = {hands_left = 4, discards_left = 2}
    })
    local RoundStateExtractor = require("state_extractor.extractors.round_state_extractor")
    local extractor = RoundStateExtractor.new()
    
    local result = extractor:get_hands_remaining()
    luaunit.assertEquals(4, result, "Direct call should return correct hands remaining")
    tearDown()
end

function testRoundStateExtractorGetDiscardsRemainingDirectCall()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_game = true,
        current_round = {hands_left = 4, discards_left = 2}
    })
    local RoundStateExtractor = require("state_extractor.extractors.round_state_extractor")
    local extractor = RoundStateExtractor.new()
    
    local result = extractor:get_discards_remaining()
    luaunit.assertEquals(2, result, "Direct call should return correct discards remaining")
    tearDown()
end

function testRoundStateExtractorHandleNonNumericValues()
    setUp()
    G = {
        GAME = {
            current_round = {
                hands_left = "invalid",
                discards_left = "also_invalid"
            }
        }
    }
    local RoundStateExtractor = require("state_extractor.extractors.round_state_extractor")
    local extractor = RoundStateExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(0, result.hands_remaining, "Should return default for non-numeric hands")
    luaunit.assertEquals(0, result.discards_remaining, "Should return default for non-numeric discards")
    tearDown()
end

function testRoundStateExtractorExtractHandlesException()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_game = true,
        current_round = {hands_left = 3, discards_left = 2}
    })
    local RoundStateExtractor = require("state_extractor.extractors.round_state_extractor")
    local extractor = RoundStateExtractor.new()
    
    -- Override get_hands_remaining to throw an error
    local original_get_hands = extractor.get_hands_remaining
    extractor.get_hands_remaining = function(self)
        error("Test error")
    end
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table even on error")
    luaunit.assertEquals(0, result.hands_remaining, "Should return default hands on error")
    luaunit.assertEquals(0, result.discards_remaining, "Should return default discards on error")
    tearDown()
end

-- Return all test functions as a table for LuaUnit runner
return {
    testRoundStateExtractorExtractMissingCurrentRound = testRoundStateExtractorExtractMissingCurrentRound,
    testRoundStateExtractorExtractValidRoundState = testRoundStateExtractorExtractValidRoundState,
    testRoundStateExtractorExtractZeroRemainingValues = testRoundStateExtractorExtractZeroRemainingValues,
    testRoundStateExtractorExtractMissingGGame = testRoundStateExtractorExtractMissingGGame,
    testRoundStateExtractorExtractPartialCurrentRound = testRoundStateExtractorExtractPartialCurrentRound,
    testRoundStateExtractorGetName = testRoundStateExtractorGetName,
    testRoundStateExtractorGetHandsRemainingDirectCall = testRoundStateExtractorGetHandsRemainingDirectCall,
    testRoundStateExtractorGetDiscardsRemainingDirectCall = testRoundStateExtractorGetDiscardsRemainingDirectCall,
    testRoundStateExtractorHandleNonNumericValues = testRoundStateExtractorHandleNonNumericValues,
    testRoundStateExtractorExtractHandlesException = testRoundStateExtractorExtractHandlesException
}
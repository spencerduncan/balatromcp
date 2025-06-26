-- LuaUnit tests for GameStateExtractor
-- Tests ante and money extraction

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
-- GAME STATE EXTRACTOR TESTS
-- =============================================================================

function testGameStateExtractorExtractMissingGGame()
    setUp()
    G = {}
    local GameStateExtractor = require("state_extractor.extractors.game_state_extractor")
    local extractor = GameStateExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(1, result.ante, "Should return default ante when G.GAME missing")
    luaunit.assertEquals(0, result.money, "Should return default money when G.GAME missing")
    tearDown()
end

function testGameStateExtractorExtractValidGameState()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_game = true,
        round_resets = {ante = 5},
        dollars = 250
    })
    local GameStateExtractor = require("state_extractor.extractors.game_state_extractor")
    local extractor = GameStateExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(5, result.ante, "Should return correct ante value")
    luaunit.assertEquals(250, result.money, "Should return correct money value")
    tearDown()
end

function testGameStateExtractorExtractPartialGameState()
    setUp()
    G = {
        GAME = {
            dollars = 150
            -- Missing round_resets
        }
    }
    local GameStateExtractor = require("state_extractor.extractors.game_state_extractor")
    local extractor = GameStateExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(1, result.ante, "Should return default ante when round_resets missing")
    luaunit.assertEquals(150, result.money, "Should return correct money value")
    tearDown()
end

function testGameStateExtractorExtractZeroValues()
    setUp()
    G = {
        GAME = {
            dollars = 0,
            round_resets = {ante = 0}
        }
    }
    local GameStateExtractor = require("state_extractor.extractors.game_state_extractor")
    local extractor = GameStateExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals(0, result.ante, "Should handle zero ante")
    luaunit.assertEquals(0, result.money, "Should handle zero money")
    tearDown()
end

function testGameStateExtractorGetName()
    setUp()
    local GameStateExtractor = require("state_extractor.extractors.game_state_extractor")
    local extractor = GameStateExtractor.new()
    
    luaunit.assertEquals("game_state_extractor", extractor:get_name(), "Should return correct extractor name")
    tearDown()
end

function testGameStateExtractorGetAnteDirectCall()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_game = true,
        round_resets = {ante = 3}
    })
    local GameStateExtractor = require("state_extractor.extractors.game_state_extractor")
    local extractor = GameStateExtractor.new()
    
    local result = extractor:get_ante()
    luaunit.assertEquals(3, result, "Direct call should return correct ante")
    tearDown()
end

function testGameStateExtractorGetMoneyDirectCall()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_game = true,
        dollars = 175
    })
    local GameStateExtractor = require("state_extractor.extractors.game_state_extractor")
    local extractor = GameStateExtractor.new()
    
    local result = extractor:get_money()
    luaunit.assertEquals(175, result, "Direct call should return correct money")
    tearDown()
end

function testGameStateExtractorGetAnteWithMissingPath()
    setUp()
    G = {
        GAME = {
            dollars = 100
            -- Missing round_resets
        }
    }
    local GameStateExtractor = require("state_extractor.extractors.game_state_extractor")
    local extractor = GameStateExtractor.new()
    
    local result = extractor:get_ante()
    luaunit.assertEquals(1, result, "Should return default ante when path missing")
    tearDown()
end

function testGameStateExtractorGetMoneyWithMissingPath()
    setUp()
    G = {
        GAME = {
            round_resets = {ante = 2}
            -- Missing dollars
        }
    }
    local GameStateExtractor = require("state_extractor.extractors.game_state_extractor")
    local extractor = GameStateExtractor.new()
    
    local result = extractor:get_money()
    luaunit.assertEquals(0, result, "Should return default money when path missing")
    tearDown()
end

function testGameStateExtractorExtractHandlesException()
    setUp()
    -- Create a mock G that will cause an exception in the extractor
    G = {}
    -- Override the safe_get_nested_value to throw an error
    local GameStateExtractor = require("state_extractor.extractors.game_state_extractor")
    local extractor = GameStateExtractor.new()
    
    -- Override get_ante to throw an error
    local original_get_ante = extractor.get_ante
    extractor.get_ante = function(self)
        error("Test error")
    end
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table even on error")
    luaunit.assertEquals(1, result.ante, "Should return default ante on error")
    luaunit.assertEquals(0, result.money, "Should return default money on error")
    tearDown()
end

-- Return all test functions as a table for LuaUnit runner
return {
    testGameStateExtractorExtractMissingGGame = testGameStateExtractorExtractMissingGGame,
    testGameStateExtractorExtractValidGameState = testGameStateExtractorExtractValidGameState,
    testGameStateExtractorExtractPartialGameState = testGameStateExtractorExtractPartialGameState,
    testGameStateExtractorExtractZeroValues = testGameStateExtractorExtractZeroValues,
    testGameStateExtractorGetName = testGameStateExtractorGetName,
    testGameStateExtractorGetAnteDirectCall = testGameStateExtractorGetAnteDirectCall,
    testGameStateExtractorGetMoneyDirectCall = testGameStateExtractorGetMoneyDirectCall,
    testGameStateExtractorGetAnteWithMissingPath = testGameStateExtractorGetAnteWithMissingPath,
    testGameStateExtractorGetMoneyWithMissingPath = testGameStateExtractorGetMoneyWithMissingPath,
    testGameStateExtractorExtractHandlesException = testGameStateExtractorExtractHandlesException
}
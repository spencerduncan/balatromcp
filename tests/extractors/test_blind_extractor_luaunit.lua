-- LuaUnit tests for BlindExtractor
-- Tests current blind information extraction

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
-- BLIND EXTRACTOR TESTS
-- =============================================================================

function testBlindExtractorExtractMissingGGameBlind()
    setUp()
    G = {}
    local BlindExtractor = require("state_extractor.extractors.blind_extractor")
    local extractor = BlindExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertNotNil(result.current_blind, "Should have current_blind field")
    luaunit.assertEquals("", result.current_blind.name, "Should return empty name when G.GAME.blind missing")
    luaunit.assertEquals("small", result.current_blind.blind_type, "Should return default blind type")
    luaunit.assertEquals(0, result.current_blind.requirement, "Should return default requirement")
    luaunit.assertEquals(0, result.current_blind.reward, "Should return default reward")
    luaunit.assertEquals("table", type(result.current_blind.properties), "Should have properties table")
    tearDown()
end

function testBlindExtractorExtractValidBlind()
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
    local BlindExtractor = require("state_extractor.extractors.blind_extractor")
    local extractor = BlindExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertNotNil(result.current_blind, "Should return blind object")
    luaunit.assertEquals("The Wall", result.current_blind.name, "Should preserve blind name")
    luaunit.assertEquals("boss", result.current_blind.blind_type, "Should identify boss blind")
    luaunit.assertEquals(2000, result.current_blind.requirement, "Should preserve chip requirement")
    luaunit.assertEquals(8, result.current_blind.reward, "Should preserve dollar reward")
    tearDown()
end

function testBlindExtractorExtractSmallBlind()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_game = true,
        blind = {
            name = "Small Blind",
            chips = 300,
            dollars = 3,
            boss = false,
            config = {}
        }
    })
    local BlindExtractor = require("state_extractor.extractors.blind_extractor")
    local extractor = BlindExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("Small Blind", result.current_blind.name, "Should preserve small blind name")
    luaunit.assertEquals("small", result.current_blind.blind_type, "Should identify small blind")
    luaunit.assertEquals(300, result.current_blind.requirement, "Should preserve small blind requirement")
    luaunit.assertEquals(3, result.current_blind.reward, "Should preserve small blind reward")
    tearDown()
end

function testBlindExtractorExtractBigBlind()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_game = true,
        blind = {
            name = "Big Blind",
            chips = 600,
            dollars = 5,
            boss = false,
            config = {}
        }
    })
    local BlindExtractor = require("state_extractor.extractors.blind_extractor")
    local extractor = BlindExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("Big Blind", result.current_blind.name, "Should preserve big blind name")
    luaunit.assertEquals("big", result.current_blind.blind_type, "Should identify big blind")
    luaunit.assertEquals(600, result.current_blind.requirement, "Should preserve big blind requirement")
    luaunit.assertEquals(5, result.current_blind.reward, "Should preserve big blind reward")
    tearDown()
end

function testBlindExtractorExtractCurrentBlindDirectCall()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_game = true,
        blind = {
            name = "Direct Blind",
            chips = 1000,
            dollars = 6,
            boss = false,
            config = {}
        }
    })
    local BlindExtractor = require("state_extractor.extractors.blind_extractor")
    local extractor = BlindExtractor.new()
    
    local result = extractor:extract_current_blind()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("Direct Blind", result.name, "Should preserve blind name")
    luaunit.assertEquals("big", result.blind_type, "Should identify blind type")
    luaunit.assertEquals(1000, result.requirement, "Should preserve requirement")
    luaunit.assertEquals(6, result.reward, "Should preserve reward")
    tearDown()
end

function testBlindExtractorExtractBlindSelectionPhase()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        state_value = 5, -- BLIND_SELECT
        states = {SELECTING_HAND = 1, BLIND_SELECT = 5},
        blind_select_opts = {
            big = {
                config = {
                    blind = {
                        name = "Big Blind Selection",
                        chips = 800,
                        dollars = 5
                    }
                }
            }
        }
    })
    G.GAME = {
        blind_on_deck = "big"
    }
    local BlindExtractor = require("state_extractor.extractors.blind_extractor")
    local extractor = BlindExtractor.new()
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("big", result.current_blind.blind_type, "Should identify blind selection type")
    luaunit.assertEquals("Big Blind Selection", result.current_blind.name, "Should get name from selection options")
    luaunit.assertEquals(800, result.current_blind.requirement, "Should get requirement from selection options")
    luaunit.assertEquals(5, result.current_blind.reward, "Should get reward from selection options")
    tearDown()
end

function testBlindExtractorGetName()
    setUp()
    local BlindExtractor = require("state_extractor.extractors.blind_extractor")
    local extractor = BlindExtractor.new()
    
    luaunit.assertEquals("blind_extractor", extractor:get_name(), "Should return correct extractor name")
    tearDown()
end

function testBlindExtractorExtractBlindSelectionInfoFallback()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        state_value = 5, -- BLIND_SELECT
        states = {SELECTING_HAND = 1, BLIND_SELECT = 5},
        blind_select_opts = {
            small = {
                config = {
                    blind = {
                        name = "Small Blind Fallback",
                        chips = 300,
                        dollars = 3
                    }
                }
            },
            big = {
                config = {
                    blind = {
                        name = "Big Blind Fallback",
                        chips = 600,
                        dollars = 5
                    }
                }
            }
        }
    })
    -- No blind_on_deck, should fallback to big blind
    local BlindExtractor = require("state_extractor.extractors.blind_extractor")
    local extractor = BlindExtractor.new()
    
    local result = extractor:extract_blind_selection_info()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("big", result.blind_type, "Should fallback to big blind when both available")
    luaunit.assertEquals("Big Blind Fallback", result.name, "Should get big blind name")
    tearDown()
end

function testBlindExtractorExtractBlindSelectionInfoBossBlind()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_state = true,
        state_value = 5, -- BLIND_SELECT
        states = {SELECTING_HAND = 1, BLIND_SELECT = 5},
        blind_select_opts = {
            boss = {
                config = {
                    blind = {
                        name = "Boss Blind Selection",
                        chips = 3000,
                        dollars = 10
                    }
                }
            }
        }
    })
    local BlindExtractor = require("state_extractor.extractors.blind_extractor")
    local extractor = BlindExtractor.new()
    
    local result = extractor:extract_blind_selection_info()
    luaunit.assertEquals("table", type(result), "Should return table")
    luaunit.assertEquals("boss", result.blind_type, "Should identify boss blind selection")
    luaunit.assertEquals("Boss Blind Selection", result.name, "Should get boss blind name")
    luaunit.assertEquals(3000, result.requirement, "Should get boss blind requirement")
    luaunit.assertEquals(10, result.reward, "Should get boss blind reward")
    tearDown()
end

function testBlindExtractorExtractHandlesException()
    setUp()
    G = luaunit_helpers.create_mock_g({
        has_game = true,
        blind = {
            name = "Test Blind",
            chips = 500,
            dollars = 4
        }
    })
    local BlindExtractor = require("state_extractor.extractors.blind_extractor")
    local extractor = BlindExtractor.new()
    
    -- Override extract_current_blind to throw an error
    local original_extract = extractor.extract_current_blind
    extractor.extract_current_blind = function(self)
        error("Test error")
    end
    
    local result = extractor:extract()
    luaunit.assertEquals("table", type(result), "Should return table even on error")
    luaunit.assertNotNil(result.current_blind, "Should have current_blind field on error")
    luaunit.assertEquals("", result.current_blind.name, "Should return default name on error")
    luaunit.assertEquals("small", result.current_blind.blind_type, "Should return default type on error")
    luaunit.assertEquals(0, result.current_blind.requirement, "Should return default requirement on error")
    luaunit.assertEquals(0, result.current_blind.reward, "Should return default reward on error")
    tearDown()
end

-- Return all test functions as a table for LuaUnit runner
return {
    testBlindExtractorExtractMissingGGameBlind = testBlindExtractorExtractMissingGGameBlind,
    testBlindExtractorExtractValidBlind = testBlindExtractorExtractValidBlind,
    testBlindExtractorExtractSmallBlind = testBlindExtractorExtractSmallBlind,
    testBlindExtractorExtractBigBlind = testBlindExtractorExtractBigBlind,
    testBlindExtractorExtractCurrentBlindDirectCall = testBlindExtractorExtractCurrentBlindDirectCall,
    testBlindExtractorExtractBlindSelectionPhase = testBlindExtractorExtractBlindSelectionPhase,
    testBlindExtractorGetName = testBlindExtractorGetName,
    testBlindExtractorExtractBlindSelectionInfoFallback = testBlindExtractorExtractBlindSelectionInfoFallback,
    testBlindExtractorExtractBlindSelectionInfoBossBlind = testBlindExtractorExtractBlindSelectionInfoBossBlind,
    testBlindExtractorExtractHandlesException = testBlindExtractorExtractHandlesException
}